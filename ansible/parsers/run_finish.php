<?php
// Called by run_wrapper.sh on the loopback. NOT auth-gated — secured by a
// shared secret defined in config.php.
$ansible_ui_root = dirname(__DIR__);
require_once $ansible_ui_root . '/config.php';

$webroot = dirname($ansible_ui_root);
require_once $webroot . '/users/init.php';

header('Content-Type: text/plain');

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405); echo "POST only"; exit;
}

$secret = $_POST['secret']    ?? '';
$run_id = $_POST['run_id']    ?? '';
$rc     = $_POST['exit_code'] ?? '';

if (!hash_equals(ANSIBLE_FINISH_SECRET, $secret)) {
    http_response_code(403); echo "bad secret"; exit;
}
if (!preg_match('/^[0-9]{8}-[0-9]{6}-[a-f0-9]{8}$/', $run_id)) {
    http_response_code(400); echo "bad run id"; exit;
}
if (!preg_match('/^-?[0-9]+$/', $rc) || (int)$rc < -255 || (int)$rc > 255) {
    http_response_code(400); echo "bad exit code"; exit;
}

global $db;
$row = $db->query("SELECT id FROM ansible_runs WHERE run_id = ? LIMIT 1", [$run_id])->first();
if (!$row) { http_response_code(404); echo "no such run"; exit; }

$db->update('ansible_runs', $row->id, [
    'finished_at' => date('Y-m-d H:i:s'),
    'exit_code'   => (int) $rc,
]);
echo "ok";
