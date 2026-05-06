#!/usr/bin/env python3
# db.py — collect MariaDB/MySQL inventory for the host this runs on.
# Writes a single JSON document to stdout. Invoked by db.yml via
# ansible.builtin.script.

import json
import os
import re
import subprocess


def sh(cmd, **kwargs):
    try:
        return subprocess.check_output(
            cmd, stderr=subprocess.STDOUT, timeout=10, **kwargs
        ).decode(errors='replace')
    except Exception:
        return ''


def dpkg_version(pkg):
    out = sh(['dpkg-query', '-W', '-f', '${Status}|${Version}', pkg])
    if '|' not in out:
        return None
    status, ver = out.split('|', 1)
    return ver if 'install ok installed' in status else None


# Flavor detection — mariadb-server takes precedence (Ubuntu's mysql
# package has been a meta for mariadb-server since 22.04). If neither
# is installed, flavor=none.
mariadb_ver = dpkg_version('mariadb-server')
mysql_ver   = dpkg_version('mysql-server')
if mariadb_ver:
    flavor          = 'mariadb'
    package_version = mariadb_ver
elif mysql_ver:
    flavor          = 'mysql'
    package_version = mysql_ver
else:
    flavor          = 'none'
    package_version = None

out = {
    'flavor':           flavor,
    'package_version':  package_version,
    'binary_version':   None,
    'running_version':  None,
    'service_state':    None,
    'datadir_path':     None,
    'datadir_size_gb':  None,
    'tunables':         {},
}

if flavor != 'none':
    # Binary banner — works without auth, just confirms which binary
    # is on PATH.
    for cmd in (['mariadb', '-V'], ['mysql', '-V']):
        banner = sh(cmd).strip()
        if banner:
            out['binary_version'] = banner
            break

    # Running version — try unix-socket auth as root, then debian.cnf.
    auth_attempts = [
        ['mariadb', '-BNe', 'SELECT VERSION()'],
        ['mysql',   '-BNe', 'SELECT VERSION()'],
        ['mysql',   '--defaults-file=/etc/mysql/debian.cnf', '-BNe', 'SELECT VERSION()'],
        ['mariadb', '--defaults-file=/etc/mysql/debian.cnf', '-BNe', 'SELECT VERSION()'],
    ]
    for argv in auth_attempts:
        v = sh(argv).strip()
        if v and 'ERROR' not in v and len(v.splitlines()) == 1 and re.match(r'^\d+\.', v):
            out['running_version'] = v
            break

    # Service state.
    for unit in ('mariadb', 'mysql'):
        state = sh(['systemctl', 'is-active', unit]).strip()
        if state in ('active', 'inactive', 'failed', 'activating'):
            out['service_state'] = state
            break

    # Datadir from running my.cnf hierarchy.
    datadir = '/var/lib/mysql'
    cnf_text = ''
    for cnf in (
        '/etc/mysql/my.cnf',
        '/etc/mysql/mariadb.conf.d/50-server.cnf',
        '/etc/mysql/mysql.conf.d/mysqld.cnf',
    ):
        try:
            with open(cnf) as f:
                cnf_text += f.read() + '\n'
        except Exception:
            pass
    md = re.search(r'^\s*datadir\s*=\s*(\S+)', cnf_text, re.M)
    if md:
        datadir = md.group(1)
    out['datadir_path'] = datadir
    if os.path.isdir(datadir):
        try:
            raw = subprocess.check_output(
                ['du', '-sb', datadir], stderr=subprocess.DEVNULL, timeout=30,
            ).decode().split()
            out['datadir_size_gb'] = round(int(raw[0]) / 1073741824, 2)
        except Exception:
            pass

    # Tunables — prefer running values via SHOW VARIABLES, fall back
    # to grepping config. Only keys that matter for capacity drift.
    for key in ('max_connections', 'innodb_buffer_pool_size'):
        val = None
        if out['running_version']:
            sql = "SHOW VARIABLES LIKE " + repr(key)
            attempts = [
                ['mariadb', '-BNe', sql],
                ['mysql',   '-BNe', sql],
                ['mysql',   '--defaults-file=/etc/mysql/debian.cnf', '-BNe', sql],
            ]
            for argv in attempts:
                r = sh(argv).strip().split('\t')
                if len(r) == 2 and r[0] == key:
                    val = r[1]
                    break
        if val is None:
            pat = r'^\s*' + re.escape(key) + r'\s*=\s*(\S+)'
            mk = re.search(pat, cnf_text, re.M)
            if mk:
                val = mk.group(1)
        out['tunables'][key] = val

print(json.dumps(out))
