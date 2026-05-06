#!/usr/bin/env python3
# service.py — restart, reload, or query the status of a systemd unit
# on this host. Writes a single JSON document to stdout. Invoked by
# service.yml via ansible.builtin.script with two args:
#   <service> <action>
# action is one of restart | reload | status.
#
# Whitelisting (which units are allowed) is the playbook's job — by the
# time this script runs, the unit name is trusted.
#
# For mutating actions, captures unit state before AND after the action
# so the UI can show the transition. For status, before == after.

import json
import subprocess
import sys


def get_state(service: str) -> dict:
    try:
        out = subprocess.check_output(
            ['systemctl', 'show', service,
             '-p', 'LoadState',
             '-p', 'ActiveState',
             '-p', 'SubState',
             '-p', 'UnitFileState'],
            stderr=subprocess.STDOUT, timeout=5,
        ).decode(errors='replace')
    except Exception:
        return {}
    state = {}
    for line in out.splitlines():
        if '=' in line:
            k, v = line.split('=', 1)
            state[k] = v
    return state


def main() -> int:
    if len(sys.argv) < 3:
        print(json.dumps({'error': 'usage: service.py <service> <action>'}))
        return 2
    service = sys.argv[1]
    action  = sys.argv[2]
    if action not in ('restart', 'reload', 'status'):
        print(json.dumps({'error': 'invalid action'}))
        return 2

    before  = get_state(service)
    mutated = False
    error   = None

    if action != 'status':
        try:
            subprocess.check_call(
                ['systemctl', action, service],
                stderr=subprocess.STDOUT, timeout=30,
            )
            mutated = True
        except subprocess.CalledProcessError as e:
            error = 'systemctl ' + action + ' ' + service + ' failed: rc=' + str(e.returncode)
        except Exception as e:
            error = str(e)

    after = get_state(service) if mutated else before

    print(json.dumps({
        'service': service,
        'action':  action,
        'before':  before,
        'after':   after,
        'mutated': mutated,
        'error':   error,
    }))
    return 1 if error else 0


if __name__ == '__main__':
    sys.exit(main())
