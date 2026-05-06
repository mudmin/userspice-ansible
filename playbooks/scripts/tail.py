#!/usr/bin/env python3
# tail.py — read the last N lines of a whitelisted log on this host.
# Writes a single JSON document to stdout. Invoked by tail.yml via
# ansible.builtin.script with two args: <log_key> <lines>.
#
# log_key is a *key*, not a path. Real paths are resolved here so the
# UI never types `/var/log/...` directly; that's what makes the input
# safe to come from the web. Hosts that don't have the log return
# exists:false instead of failing — important for fleet-wide tails
# where some hosts are missing some logs.

import json
import os
import subprocess
import sys

LOG_PATHS = {
    'apache_error':  '/var/log/apache2/error.log',
    'apache_access': '/var/log/apache2/access.log',
    'mariadb_error': '/var/log/mysql/error.log',
    'syslog':        '/var/log/syslog',
    'journalctl':    None,   # special-cased below
}


def main() -> int:
    if len(sys.argv) < 3:
        print(json.dumps({'error': 'usage: tail.py <log_key> <lines>'}))
        return 2
    log_key = sys.argv[1]
    try:
        n = int(sys.argv[2])
    except ValueError:
        print(json.dumps({'error': 'invalid lines arg'}))
        return 2
    if log_key not in LOG_PATHS:
        print(json.dumps({'error': 'invalid log key', 'log_key': log_key}))
        return 2
    if n < 1 or n > 10000:
        print(json.dumps({'error': 'lines out of bounds (1..10000)'}))
        return 2

    if log_key == 'journalctl':
        path = '(systemd journal)'
        try:
            out = subprocess.check_output(
                ['journalctl', '-n', str(n), '--no-pager'],
                stderr=subprocess.STDOUT, timeout=30,
            ).decode(errors='replace')
            exists = True
        except Exception:
            out = ''
            exists = False
    else:
        path = LOG_PATHS[log_key]
        if not os.path.exists(path):
            out = ''
            exists = False
        else:
            try:
                out = subprocess.check_output(
                    ['tail', '-n', str(n), path],
                    stderr=subprocess.STDOUT, timeout=30,
                ).decode(errors='replace')
                exists = True
            except Exception:
                out = ''
                exists = False

    lines = out.splitlines()
    print(json.dumps({
        'log_key':     log_key,
        'path':        path,
        'exists':      exists,
        'lines':       lines,
        'n_returned':  len(lines),
        'n_requested': n,
    }))
    return 0


if __name__ == '__main__':
    sys.exit(main())
