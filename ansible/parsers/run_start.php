<?php
require_once __DIR__ . '/../includes/bootstrap.php';

header('Content-Type: application/json');

function fail(string $msg, int $http = 400): never {
    http_response_code($http);
    echo json_encode(['error' => $msg]);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') fail('POST only', 405);
if (!Token::check($_POST['csrf'] ?? '')) fail('Invalid CSRF token', 403);

$playbook = $_POST['playbook'] ?? '';
$target   = $_POST['target']   ?? '';
$mode     = $_POST['mode']     ?? '';
$verb     = $_POST['verbosity'] ?? '';

if (!ansible_validate_playbook($playbook)) fail('Invalid playbook');
if (!ansible_validate_target($target))     fail('Invalid target');
if (!in_array($mode, ['check', 'diff', 'run'], true)) fail('Invalid mode');
if ($verb !== '' && !in_array($verb, ['-v', '-vv'], true)) fail('Invalid verbosity');

$flags = [];
if ($mode === 'check') { $flags[] = '--check'; $flags[] = '--diff'; }
if ($mode === 'diff')  { $flags[] = '--diff'; }
if ($verb !== '')      { $flags[] = $verb; }
if (!ansible_validate_flags($flags)) fail('Invalid flags');

// Read the playbook's declared parameter schema (UI_PARAMS comment block).
// For each declared param, pull the value from $_POST['param_<name>'],
// fall back to default, validate against the schema, and accumulate into
// $params_dict. Params not declared by the playbook are silently dropped
// so a malicious POST can't smuggle extra-vars through.
//
// We hand the dict to ansible as a single JSON document via
//   -e '{"key":"val","key2":"val with spaces"}'
// rather than the simpler `-e key=val` form. Ansible's `-e key=val`
// parser splits the *value* on whitespace, treating the second word as
// another `key=val` pair — which silently corrupts string params (e.g.
// grep_log's `pattern`). The JSON form is unambiguous.
$param_schema = ansible_playbook_params($playbook);
$params_dict  = [];   // for ansible -e (JSON-encoded)
$param_log    = [];   // human-readable record for the audit trail
foreach ($param_schema as $p) {
    $name = $p['name'];
    $val  = $_POST['param_' . $name] ?? null;

    if ($val === null || $val === '') {
        if (!empty($p['required'])) fail("Missing required parameter: $name");
        if (isset($p['default'])) {
            $val = (string)$p['default'];
        } else {
            continue;   // optional, no default: omit
        }
    }
    if (!is_string($val)) fail("Bad value for $name");
    // For enum-with-extras, validate against the composed list for the
    // chosen target so per-group additions are accepted. The UI form
    // would only have offered values from this same list.
    if (!ansible_validate_param_value($p, $val, $target)) {
        fail("Invalid value for $name");
    }
    $params_dict[$name] = $val;
    $param_log[]        = $name . '=' . $val;
}
$param_argv = $params_dict
    ? ['-e', json_encode($params_dict, JSON_UNESCAPED_SLASHES)]
    : [];

$lock = ansible_lock_target($target);
if ($lock === null) fail('Another run against this target is already in progress.', 409);

$run_id   = ansible_new_run_id();
$log_path = ansible_run_log_path($run_id);

// Pre-create the log file with a small header.
file_put_contents(
    $log_path,
    "# run_id=$run_id\n# playbook=$playbook target=$target flags=" . implode(' ', $flags)
        . " mode=$mode params=" . implode(' ', $param_log)
        . " user_id=" . (int)$user->data()->id . "\n# started=" . date('c') . "\n\n"
);

$report_path = ansible_runs_dir() . '/' . $run_id . '.report.json';
$argv = ansible_sudo_argv(
    ansible_bin('ansible-playbook'),
    array_merge(
        ['-i', ANSIBLE_REPO . '/inventory.ini', $playbook, '--limit', $target,
         '-e', 'ui_run_id=' . $run_id, '-e', 'ui_report_path=' . $report_path],
        $param_argv,    // single -e <json> when there are params, else []
        $flags
    )
);

// Store flags + params together in the flags column so the runs table
// shows the complete invocation. The rerun parser only inspects flag
// tokens (--check/--diff/-v/-vv) and ignores name=value pairs.
global $db;
$db->insert('ansible_runs', [
    'run_id'     => $run_id,
    'user_id'    => (int) $user->data()->id,
    'playbook'   => $playbook,
    'target'     => $target,
    'flags'      => trim(implode(' ', array_merge($flags, $param_log))),
    'pid'        => null,
    'started_at' => date('Y-m-d H:i:s'),
    'log_path'   => $log_path,
]);

$pid = ansible_run_spawn($argv, $run_id, $log_path);
if ($pid <= 0) {
    $db->update('ansible_runs', $db->lastId(), ['exit_code' => -1, 'finished_at' => date('Y-m-d H:i:s')]);
    fail('Failed to spawn ansible process', 500);
}
$db->update('ansible_runs', $db->lastId(), ['pid' => $pid]);

// Lock fp is intentionally NOT closed here — the wrapper inherits the fd
// briefly, but flock is per-process so this lock will release when this PHP
// request ends. Subsequent cancel/status requests don't need the lock; the
// wrapper's lifetime is what matters for "another run already in progress",
// and that's enforced by the row lookup in cancel + the per-target lock at
// next start. For finer concurrency control we'd need a daemon. Good enough
// for v1: the lock prevents double-clicks.
fclose($lock);

echo json_encode(['run_id' => $run_id, 'pid' => $pid]);
