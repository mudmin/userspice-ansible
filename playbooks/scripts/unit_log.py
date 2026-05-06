#!/usr/bin/env python3
# unit_log.py — read the last N lines of `journalctl -u <unit>` for a
# whitelisted systemd unit on this host. Writes a single JSON document
# to stdout. Invoked by unit_log.yml via ansible.builtin.script with two
# args: <unit> <lines>.
#
# Whitelisting (which units are allowed) is the playbook's job. By the
# time this script runs, the unit name is trusted.
#
# Hosts where the unit isn't loaded return exists:false rather than
# failing — important for fleet-wide log pulls of e.g. apache2 across
# managed_vps where some hosts may not have apache.

import json
import subprocess
import sys


def unit_loaded(unit: str) -> bool:
    try:
        out = subprocess.check_output(
            ['systemctl', 'show', unit, '-p', 'LoadState'],
            stderr=subprocess.DEVNULL, timeout=5,
        ).decode(errors='replace').strip()
    except Exception:
        return False
    return out == 'LoadState=loaded'


def main() -> int:
    if len(sys.argv) < 3:
        print(json.dumps({'error': 'usage: unit_log.py <unit> <lines>'}))
        return 2
    unit = sys.argv[1]
    try:
        n = int(sys.argv[2])
    except ValueError:
        print(json.dumps({'error': 'invalid lines arg'}))
        return 2
    if n < 1 or n > 10000:
        print(json.dumps({'error': 'lines out of bounds (1..10000)'}))
        return 2

    if not unit_loaded(unit):
        print(json.dumps({
            'unit':        unit,
            'exists':      False,
            'lines':       [],
            'n_returned':  0,
            'n_requested': n,
        }))
        return 0

    try:
        out = subprocess.check_output(
            ['journalctl', '-u', unit, '-n', str(n), '--no-pager'],
            stderr=subprocess.STDOUT, timeout=30,
        ).decode(errors='replace')
        lines  = out.splitlines()
        exists = True
    except Exception:
        lines  = []
        exists = False

    print(json.dumps({
        'unit':        unit,
        'exists':      exists,
        'lines':       lines,
        'n_returned':  len(lines),
        'n_requested': n,
    }))
    return 0


if __name__ == '__main__':
    sys.exit(main())
