#!/usr/bin/env python3
# webstack.py — collect Apache + vhosts + PHP + Node + /var/www inventory
# for the host this runs on. Writes a single JSON document to stdout.
# Invoked by webstack.yml via ansible.builtin.script.

import glob
import grp
import json
import os
import pwd
import re
import subprocess


def sh(cmd, **kwargs):
    try:
        return subprocess.check_output(
            cmd, stderr=subprocess.STDOUT, **kwargs
        ).decode(errors='replace')
    except Exception:
        return ''


def read_file(path):
    try:
        with open(path) as f:
            return f.read()
    except Exception:
        return ''


# ---------- Apache section ----------
apache_ver = ''
apache_full = sh(['apache2', '-v'])
m = re.search(r'^Server version:\s*(\S+.*)$', apache_full, re.M)
if m:
    apache_ver = m.group(1).strip()
modules_raw = sh(['apache2ctl', '-M'])
modules = []
for line in modules_raw.splitlines():
    mm = re.match(r'\s*(\S+_module)', line)
    if mm:
        modules.append(mm.group(1))
mpm = ''
for m_name in modules:
    if m_name.startswith('mpm_'):
        mpm = m_name.replace('mpm_', '').replace('_module', '')
        break
# mod_php detection: Ubuntu's libapache2-mod-php<X.Y> loads the module
# as plain `php_module` (no version), with the version only visible in
# /etc/apache2/mods-enabled/php<X.Y>.load. Older packaging used
# `phpX_module` directly. Try both.
mod_php_loaded = ('php_module' in modules) or any(
    re.match(r'php\d+_module', m_name) for m_name in modules
)
mod_php_version = None
if mod_php_loaded:
    for path in glob.glob('/etc/apache2/mods-enabled/php*.load'):
        mv = re.search(r'php(\d+(?:\.\d+)?)\.load$', os.path.basename(path))
        if mv:
            mod_php_version = mv.group(1)
            break
    if mod_php_version is None:
        for m_name in modules:
            mp = re.match(r'php(\d+)_module', m_name)
            if mp:
                mod_php_version = mp.group(1)
                break
modsec = 'security2_module' in modules
INTEREST = (
    'ssl_module', 'rewrite_module', 'headers_module', 'proxy_fcgi_module',
    'proxy_module', 'expires_module', 'deflate_module', 'security2_module',
    'mpm_event_module', 'mpm_worker_module', 'mpm_prefork_module',
)
of_interest = sorted([m_name for m_name in modules if m_name in INTEREST])
apache = {
    'installed':           apache_ver != '',
    'version':             apache_ver,
    'mpm':                 mpm,
    'modules_of_interest': of_interest,
    'modsecurity':         modsec,
    'mod_php_version':     mod_php_version,
}

# ---------- Vhosts section ----------
# `apache2ctl -S` blocks (paraphrased):
#   port 443 namevhost <name> (<file>:<line>)
#           alias <other>
# Plus single-vhost lines like `*:80 <name> (<file>:<line>)`.
vhosts_raw = sh(['apache2ctl', '-S'])
vhosts = []
current = None
line_re   = re.compile(r'port\s+(\d+)\s+namevhost\s+(\S+)\s+\((\S+?):\d+\)')
single_re = re.compile(r'\*:(\d+)\s+(\S+)\s+\((\S+?):\d+\)')
alias_re  = re.compile(r'^\s+alias\s+(\S+)')
for line in vhosts_raw.splitlines():
    ml = line_re.search(line) or single_re.search(line)
    if ml:
        if current:
            vhosts.append(current)
        current = {
            'port':         int(ml.group(1)),
            'server_name':  ml.group(2),
            'aliases':      [],
            'config_file':  ml.group(3),
        }
        continue
    ma = alias_re.match(line)
    if ma and current:
        current['aliases'].append(ma.group(1))
if current:
    vhosts.append(current)

# Deduplicate (apache2ctl reports both "default server" and "namevhost"
# lines — same site, two entries). Key by (port, server_name, file).
seen = set()
deduped = []
for v in vhosts:
    key = (v['port'], v['server_name'], v['config_file'])
    if key in seen:
        continue
    seen.add(key)
    deduped.append(v)
vhosts = deduped

# Per-vhost: open the config file, extract DocumentRoot, PHP handler,
# SSL cert. Falls back to globally-enabled php-fpm conf for vhosts
# that don't declare a handler themselves.
global_fpm_version = None
for conf in glob.glob('/etc/apache2/conf-enabled/php*-fpm.conf'):
    mg = re.search(r'php(\d+\.\d+)-fpm\.conf$', conf)
    if mg:
        global_fpm_version = mg.group(1)
        break
for v in vhosts:
    cfg = read_file(v['config_file'])
    md = re.search(r'^\s*DocumentRoot\s+"?([^"\s]+)', cfg, re.M)
    v['document_root'] = md.group(1) if md else None
    ms = re.search(r'^\s*SSLCertificateFile\s+"?(/etc/letsencrypt/live/([^/"]+)/[^"\s]+)', cfg, re.M)
    v['ssl_cert_lineage'] = ms.group(2) if ms else None
    # PHP handler resolution.
    mp = re.search(r'SetHandler\s+"?proxy:unix:(/run/php/php(\d+\.\d+)-fpm\.sock)', cfg)
    if mp:
        v['php_handler'] = 'fpm'
        v['php_version'] = mp.group(2)
        v['php_socket']  = mp.group(1)
    elif re.search(r'SetHandler\s+["\']?application/x-httpd-php', cfg) and mod_php_version:
        v['php_handler'] = 'mod_php'
        v['php_version'] = mod_php_version
        v['php_socket']  = None
    elif global_fpm_version:
        v['php_handler'] = 'fpm'
        v['php_version'] = global_fpm_version
        v['php_socket']  = '/run/php/php' + global_fpm_version + '-fpm.sock'
    elif mod_php_version:
        v['php_handler'] = 'mod_php'
        v['php_version'] = mod_php_version
        v['php_socket']  = None
    else:
        v['php_handler'] = None
        v['php_version'] = None
        v['php_socket']  = None

# ---------- PHP section ----------
installed_php = []
for d in sorted(glob.glob('/etc/php/*')):
    base = os.path.basename(d)
    if re.match(r'^\d+\.\d+$', base):
        installed_php.append(base)
php_v_full = sh(['php', '-v'])
cli_default_full, cli_default = '', ''
mc = re.match(r'PHP\s+(\d+\.\d+\.\d+)', php_v_full)
if mc:
    cli_default_full = mc.group(1)
    cli_default      = '.'.join(cli_default_full.split('.')[:2])
fpm_pools = []
for ver in installed_php:
    for pconf in sorted(glob.glob('/etc/php/' + ver + '/fpm/pool.d/*.conf')):
        pool_text = read_file(pconf)
        mn = re.search(r'^\[(\S+)\]', pool_text, re.M)
        ml = re.search(r'^\s*listen\s*=\s*(\S+)', pool_text, re.M)
        mu = re.search(r'^\s*user\s*=\s*(\S+)',   pool_text, re.M)
        active = sh(['systemctl', 'is-active', 'php' + ver + '-fpm']).strip() == 'active'
        fpm_pools.append({
            'version':     ver,
            'pool':        mn.group(1) if mn else os.path.basename(pconf),
            'config_file': pconf,
            'socket':      ml.group(1) if ml else None,
            'user':        mu.group(1) if mu else None,
            'active':      active,
        })
php = {
    'installed_versions': installed_php,
    'default_cli':        cli_default,
    'default_cli_full':   cli_default_full,
    'fpm_pools':          fpm_pools,
}

# ---------- Node section ----------
node_v = sh(['node', '-v']).strip()
node = {
    'installed': node_v.startswith('v'),
    'version':   node_v if node_v.startswith('v') else None,
}

# ---------- /var/www section ----------
# Top-level dirs only, with owner/size/mtime + match to vhost
# by DocumentRoot prefix (so /var/www/<name>/public still matches
# the /var/www/<name> entry).
webroot = []
if os.path.isdir('/var/www'):
    for entry in sorted(os.listdir('/var/www')):
        full = os.path.join('/var/www', entry)
        if not os.path.isdir(full):
            continue
        try:
            st = os.stat(full)
        except Exception:
            continue
        size_bytes = 0
        try:
            out = subprocess.check_output(
                ['du', '-sb', full], stderr=subprocess.DEVNULL
            ).decode().split()
            size_bytes = int(out[0])
        except Exception:
            pass
        try:
            owner = pwd.getpwuid(st.st_uid).pw_name
        except Exception:
            owner = str(st.st_uid)
        try:
            group = grp.getgrgid(st.st_gid).gr_name
        except Exception:
            group = str(st.st_gid)
        matched_vhosts = []
        for v in vhosts:
            dr = v.get('document_root') or ''
            if dr == full or dr.startswith(full + '/'):
                matched_vhosts.append(v['server_name'])
        webroot.append({
            'name':           entry,
            'path':           full,
            'owner':          owner,
            'group':          group,
            'size_bytes':     size_bytes,
            'mtime_epoch':    int(st.st_mtime),
            'matched_vhosts': sorted(set(matched_vhosts)),
        })

print(json.dumps({
    'apache':  apache,
    'vhosts':  vhosts,
    'php':     php,
    'node':    node,
    'webroot': webroot,
}))
