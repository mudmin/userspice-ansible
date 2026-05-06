#!/usr/bin/env python3
# config_test.py — preflight syntax check for a service's config files.
# Writes a single JSON document to stdout. Invoked by config_test.yml
# via ansible.builtin.script with one arg: <what>.
#
# what is one of: apache | nginx | sshd | mariadb. The corresponding
# tool's "validate config" command runs; output and exit code are
# captured. Read-only.
#
# Hosts that don't have the tool installed return applicable:false
# (rather than failing) so a fleet-wide config_test --what=apache against
# a mixed group skips non-Apache hosts gracefully.

import json
import shutil
import subprocess
import sys


# Each entry: (binary used to detect presence, command argv).
# The binary key is what we look up via shutil.which to determine if
# the host is even applicable. The argv is what we run.
TESTS = {
    'apache':  ('apache2ctl',  ['apache2ctl', 'configtest']),
    'nginx':   ('nginx',       ['nginx',      '-t']),
    'sshd':    ('sshd',        ['sshd',       '-t']),
    'mariadb': ('mariadbd',    ['mariadbd',   '--validate-config']),
}


def main() -> int:
    if len(sys.argv) < 2:
        print(json.dumps({'error': 'usage: config_test.py <apache|nginx|sshd|mariadb>'}))
        return 2
    what = sys.argv[1]
    if what not in TESTS:
        print(json.dumps({'error': 'invalid what'}))
        return 2

    binary, argv = TESTS[what]
    if shutil.which(binary) is None:
        # mariadb's mariadbd may live at /usr/sbin/mariadbd which isn't
        # always on PATH — check the canonical path too before giving up.
        canonical = '/usr/sbin/' + binary
        try:
            import os
            if os.path.isfile(canonical) and os.access(canonical, os.X_OK):
                argv = [canonical] + argv[1:]
            else:
                print(json.dumps({
                    'what':       what,
                    'applicable': False,
                    'ok':         None,
                    'output':     '',
                    'exit_code':  None,
                }))
                return 0
        except Exception:
            print(json.dumps({
                'what':       what,
                'applicable': False,
                'ok':         None,
                'output':     '',
                'exit_code':  None,
            }))
            return 0

    try:
        out = subprocess.check_output(
            argv, stderr=subprocess.STDOUT, timeout=30,
        ).decode(errors='replace')
        rc = 0
    except subprocess.CalledProcessError as e:
        out = (e.output or b'').decode(errors='replace')
        rc  = e.returncode
    except Exception as e:
        out = str(e)
        rc  = -1

    print(json.dumps({
        'what':       what,
        'applicable': True,
        'ok':         rc == 0,
        'output':     out.strip(),
        'exit_code':  rc,
    }))
    return 0


if __name__ == '__main__':
    sys.exit(main())
