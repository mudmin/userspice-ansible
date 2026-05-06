#!/usr/bin/env python3
# cleanup.py — disk hygiene: apt autoremove, apt autoclean, journalctl
# vacuum, /tmp prune. Writes a single JSON document to stdout.
# Invoked by cleanup.yml via ansible.builtin.script with two args:
#   <apply:true|false> <keep_days>
#
# apply=false  → preview only. Reports what *would* change. No mutations.
# apply=true   → execute. Reports what was actually changed.
#
# /tmp prune is intentionally conservative: top-level regular files only
# (no subdirs, sockets, FIFOs, dotfiles), and BOTH atime and mtime must
# exceed keep_days. Real app data tends to live in subdirectories or has
# its access time updated; this rule deletes only stale debris.

import json
import os
import re
import stat
import subprocess
import sys
import time


def sh(cmd, timeout=120):
    """Run a command, capture stdout+stderr, return (text, rc)."""
    try:
        out = subprocess.check_output(
            cmd, stderr=subprocess.STDOUT, timeout=timeout,
        ).decode(errors='replace')
        return out, 0
    except subprocess.CalledProcessError as e:
        text = e.output.decode(errors='replace') if e.output else ''
        return text, e.returncode
    except Exception as e:
        return str(e), -1


def parse_freed_kb(text: str) -> int:
    """Extract apt's 'After this operation, X (kB|MB|GB|B) ... freed'."""
    m = re.search(
        r'After this operation,\s*([\d,.]+)\s*(B|kB|MB|GB)\s+disk space will be freed',
        text,
    )
    if not m:
        return 0
    n = float(m.group(1).replace(',', ''))
    unit = m.group(2)
    if unit == 'GB': return int(n * 1024 * 1024)
    if unit == 'MB': return int(n * 1024)
    if unit == 'kB': return int(n)
    if unit == 'B':  return int(n / 1024)
    return 0


def parse_packages(text: str) -> list:
    """Extract package list from apt's 'The following packages will be REMOVED' block."""
    pkgs = []
    in_block = False
    for raw in text.splitlines():
        s = raw.rstrip()
        if s.startswith('The following packages will be REMOVED'):
            in_block = True
            continue
        if in_block:
            stripped = s.strip()
            if not stripped or re.match(r'^\d+ upgraded', stripped):
                in_block = False
                continue
            # apt indents package names; tokens on the line are package names.
            for tok in stripped.split():
                if tok and not tok.startswith('-'):
                    pkgs.append(tok)
    return pkgs


def journal_disk_kb() -> int:
    """journalctl --disk-usage → KB. 0 if not parseable."""
    out, _ = sh(['journalctl', '--disk-usage'], timeout=10)
    m = re.search(r'take up\s+([\d,.]+)([BKMGT])', out)
    if not m:
        return 0
    n = float(m.group(1).replace(',', ''))
    unit = m.group(2)
    mults = {'B': 1.0/1024, 'K': 1, 'M': 1024, 'G': 1024*1024, 'T': 1024*1024*1024}
    return int(n * mults.get(unit, 1))


def list_tmp_candidates(keep_days: int) -> list:
    """Top-level /tmp regular files where both atime and mtime are older than keep_days."""
    candidates = []
    cutoff = int(time.time()) - keep_days * 86400
    try:
        entries = os.listdir('/tmp')
    except Exception:
        return candidates
    for entry in entries:
        full = os.path.join('/tmp', entry)
        try:
            st = os.lstat(full)
        except Exception:
            continue
        if not stat.S_ISREG(st.st_mode):
            continue
        if st.st_atime < cutoff and st.st_mtime < cutoff:
            candidates.append({'path': full, 'size': st.st_size})
    return candidates


def main() -> int:
    if len(sys.argv) < 3:
        print(json.dumps({'error': 'usage: cleanup.py <true|false> <keep_days>'}))
        return 2
    apply = sys.argv[1].strip().lower() == 'true'
    try:
        keep_days = int(sys.argv[2])
    except ValueError:
        print(json.dumps({'error': 'invalid keep_days'}))
        return 2
    if keep_days < 1 or keep_days > 365:
        print(json.dumps({'error': 'keep_days out of bounds (1..365)'}))
        return 2

    out = {
        'apply':     apply,
        'keep_days': keep_days,
        'apt':       {},
        'journal':   {},
        'tmp':       {},
    }

    # ---- apt autoremove ----
    sim_remove, _ = sh(['apt-get', '--simulate', '-y', 'autoremove'])
    out['apt']['autoremove_packages']           = parse_packages(sim_remove)
    out['apt']['autoremove_freed_kb_estimate']  = parse_freed_kb(sim_remove)
    if apply:
        # Need DEBIAN_FRONTEND so apt doesn't try to prompt.
        env = os.environ.copy()
        env['DEBIAN_FRONTEND'] = 'noninteractive'
        try:
            real_remove = subprocess.check_output(
                ['apt-get', '-y', 'autoremove'],
                stderr=subprocess.STDOUT, timeout=300, env=env,
            ).decode(errors='replace')
            out['apt']['autoremove_freed_kb'] = parse_freed_kb(real_remove)
            out['apt']['autoremove_rc']       = 0
        except subprocess.CalledProcessError as e:
            out['apt']['autoremove_rc']  = e.returncode
            out['apt']['autoremove_err'] = (e.output or b'').decode(errors='replace')[:500]

    # ---- apt autoclean ----
    sim_clean, _ = sh(['apt-get', '--simulate', '-y', 'autoclean'])
    out['apt']['autoclean_freed_kb_estimate'] = parse_freed_kb(sim_clean)
    if apply:
        env = os.environ.copy()
        env['DEBIAN_FRONTEND'] = 'noninteractive'
        try:
            real_clean = subprocess.check_output(
                ['apt-get', '-y', 'autoclean'],
                stderr=subprocess.STDOUT, timeout=120, env=env,
            ).decode(errors='replace')
            out['apt']['autoclean_freed_kb'] = parse_freed_kb(real_clean)
            out['apt']['autoclean_rc']       = 0
        except subprocess.CalledProcessError as e:
            out['apt']['autoclean_rc']  = e.returncode
            out['apt']['autoclean_err'] = (e.output or b'').decode(errors='replace')[:500]

    # ---- journalctl ----
    out['journal']['before_kb'] = journal_disk_kb()
    if apply:
        sh(['journalctl', '--vacuum-time=' + str(keep_days) + 'd'], timeout=60)
        out['journal']['after_kb'] = journal_disk_kb()
        out['journal']['freed_kb'] = max(0, out['journal']['before_kb'] - out['journal']['after_kb'])

    # ---- /tmp prune ----
    candidates = list_tmp_candidates(keep_days)
    out['tmp']['candidate_count']        = len(candidates)
    out['tmp']['candidate_bytes']        = sum(c['size'] for c in candidates)
    out['tmp']['candidate_paths_sample'] = [c['path'] for c in candidates[:10]]
    if apply:
        removed_count = 0
        removed_bytes = 0
        for c in candidates:
            try:
                os.unlink(c['path'])
                removed_count += 1
                removed_bytes += c['size']
            except Exception:
                pass
        out['tmp']['removed_count'] = removed_count
        out['tmp']['removed_bytes'] = removed_bytes

    print(json.dumps(out))
    return 0


if __name__ == '__main__':
    sys.exit(main())
