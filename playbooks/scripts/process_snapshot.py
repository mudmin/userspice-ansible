#!/usr/bin/env python3
# process_snapshot.py — top N processes by CPU and by RAM on this host.
# Writes a single JSON document to stdout. Invoked by process_snapshot.yml
# via ansible.builtin.script with one arg: <n>.
#
# Note on the %CPU number: ps's `pcpu` is the *cumulative* cputime/walltime
# ratio since the process started. It's the same number top shows on its
# first refresh, before delta-sampling kicks in. For a snapshot this is
# what callers want; if instantaneous CPU matters they should run this
# twice or use top.

import json
import subprocess
import sys


def get_processes() -> list:
    fmt = 'pid,user,pcpu,pmem,rss,etime,args'
    try:
        out = subprocess.check_output(
            ['ps', '-eo', fmt, '--no-headers'],
            stderr=subprocess.STDOUT, timeout=10,
        ).decode(errors='replace')
    except Exception:
        return []
    rows = []
    for line in out.splitlines():
        # 7 fields, last (args) can contain spaces
        parts = line.split(None, 6)
        if len(parts) < 7:
            continue
        try:
            rows.append({
                'pid':     int(parts[0]),
                'user':    parts[1],
                'pcpu':    float(parts[2]),
                'pmem':    float(parts[3]),
                'rss_kb':  int(parts[4]),
                'etime':   parts[5],
                'command': parts[6],
            })
        except ValueError:
            continue
    return rows


def main() -> int:
    if len(sys.argv) < 2:
        print(json.dumps({'error': 'usage: process_snapshot.py <n>'}))
        return 2
    try:
        n = int(sys.argv[1])
    except ValueError:
        print(json.dumps({'error': 'invalid n arg'}))
        return 2
    if n < 1 or n > 100:
        print(json.dumps({'error': 'n out of bounds (1..100)'}))
        return 2

    procs = get_processes()
    by_cpu = sorted(procs, key=lambda p: p['pcpu'],   reverse=True)[:n]
    by_mem = sorted(procs, key=lambda p: p['rss_kb'], reverse=True)[:n]

    print(json.dumps({
        'top_cpu': by_cpu,
        'top_mem': by_mem,
    }))
    return 0


if __name__ == '__main__':
    sys.exit(main())
