#!/bin/bash
# Wrapper for ansible-playbook. Runs the real command, captures exit code,
# notifies run_finish.php so the audit row gets stamped.
#
# Usage:
#   run_wrapper.sh <run_id> <log_path> <finish_url> <secret> -- <argv...>

set -u

RUN_ID="$1"; shift
LOG_PATH="$1"; shift
FINISH_URL="$1"; shift
SECRET="$1"; shift
[ "$1" = "--" ] && shift

# Run ansible in the background so we can trap SIGTERM and forward it to
# the child. Without this the sudo'd ansible-playbook is orphaned to init
# when the cancel button SIGTERMs the wrapper, and keeps running.
"$@" &
CHILD=$!
trap 'kill -TERM "$CHILD" 2>/dev/null' TERM INT
wait "$CHILD"
RC=$?
trap - TERM INT

# Notify the UI. -m 5 = max 5 sec; if the web server is dead the run is still
# logged, the UI will reconcile from the log file's mtime later.
curl -sS -m 5 -X POST \
    --data-urlencode "run_id=${RUN_ID}" \
    --data-urlencode "exit_code=${RC}" \
    --data-urlencode "secret=${SECRET}" \
    "$FINISH_URL" >/dev/null 2>&1 || true

exit $RC
