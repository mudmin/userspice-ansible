#!/usr/bin/env python3
# grep_log.py — search a whitelisted log for a pattern. Writes a single
# JSON document to stdout. Invoked by grep_log.yml via ansible.builtin.script
# with four args: <log_key> <pattern_type:plain|regex> <pattern> <context>.
#
# log_key is one of the same keys tail.yml accepts; the script resolves
# it to a real path (or runs through journalctl). pattern is a literal
# string when pattern_type=plain (passed to `grep -F`) or an extended
# regex when pattern_type=regex (passed to `grep -E`). context is the
# number of context lines to include (-C N).
#
# All subprocess calls are argv-based — never shell-formatted. The
# pattern is passed as a positional arg, never interpolated into a
# string. So a pattern like `; rm -rf /` is harmless: grep treats it as
# a literal search expression.

import json
import os
import subprocess
import sys

LOG_PATHS = {
    'apache_error':  '/var/log/apache2/error.log',
    'apache_access': '/var/log/apache2/access.log',
    'mariadb_error': '/var/log/mysql/error.log',
    'syslog':        '/var/log/syslog',
    'journalctl':    None,
}


def main() -> int:
    if len(sys.argv) < 5:
        print(json.dumps({'error': 'usage: grep_log.py <log_key> <pattern_type> <pattern> <context>'}))
        return 2
    log_key      = sys.argv[1]
    pattern_type = sys.argv[2]
    pattern      = sys.argv[3]
    try:
        context = int(sys.argv[4])
    except ValueError:
        print(json.dumps({'error': 'invalid context arg'}))
        return 2
    if log_key not in LOG_PATHS:
        print(json.dumps({'error': 'invalid log key'}))
        return 2
    if pattern_type not in ('plain', 'regex'):
        print(json.dumps({'error': 'invalid pattern_type'}))
        return 2
    if context < 0 or context > 10:
        print(json.dumps({'error': 'context out of bounds (0..10)'}))
        return 2
    if not pattern or len(pattern) > 200:
        print(json.dumps({'error': 'pattern empty or too long'}))
        return 2

    grep_flag = '-F' if pattern_type == 'plain' else '-E'

    if log_key == 'journalctl':
        path = '(systemd journal)'
        try:
            jproc = subprocess.Popen(
                ['journalctl', '--no-pager'],
                stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
            )
            try:
                grep_out = subprocess.check_output(
                    ['grep', grep_flag, '-C', str(context), '--', pattern],
                    stdin=jproc.stdout, stderr=subprocess.STDOUT, timeout=30,
                )
                text   = grep_out.decode(errors='replace')
                exists = True
            except subprocess.CalledProcessError as e:
                # grep exits 1 when no match; that's not an error for us.
                if e.returncode == 1:
                    text   = ''
                    exists = True
                else:
                    text   = (e.output or b'').decode(errors='replace')
                    exists = False
            finally:
                if jproc.stdout:
                    jproc.stdout.close()
                try:
                    jproc.wait(timeout=10)
                except Exception:
                    jproc.kill()
        except Exception:
            text   = ''
            exists = False
    else:
        path = LOG_PATHS[log_key]
        if not os.path.exists(path):
            text   = ''
            exists = False
        else:
            try:
                grep_out = subprocess.check_output(
                    ['grep', grep_flag, '-C', str(context), '--', pattern, path],
                    stderr=subprocess.STDOUT, timeout=30,
                )
                text   = grep_out.decode(errors='replace')
                exists = True
            except subprocess.CalledProcessError as e:
                if e.returncode == 1:
                    text   = ''
                    exists = True
                else:
                    text   = (e.output or b'').decode(errors='replace')
                    exists = False
            except Exception:
                text   = ''
                exists = False

    lines = text.splitlines()
    print(json.dumps({
        'log_key':      log_key,
        'path':         path,
        'pattern':      pattern,
        'pattern_type': pattern_type,
        'context':      context,
        'exists':       exists,
        'lines':        lines,
        'line_count':   len(lines),
    }))
    return 0


if __name__ == '__main__':
    sys.exit(main())
