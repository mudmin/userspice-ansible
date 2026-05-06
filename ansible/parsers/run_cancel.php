<?php
require_once __DIR__ . '/../includes/bootstrap.php';
header('Content-Type: application/json');

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405); echo json_encode(['error' => 'POST only']); exit;
}
if (!Token::check($_POST['csrf'] ?? '')) {
    http_response_code(403); echo json_encode(['error' => 'invalid csrf']); exit;
}

$run_id = $_POST['run_id'] ?? '';
if (!preg_match('/^[0-9]{8}-[0-9]{6}-[a-f0-9]{8}$/', $run_id)) {
    http_response_code(400); echo json_encode(['error' => 'bad run id']); exit;
}

global $db;
$r = $db->query(
    "SELECT id, pid, finished_at FROM ansible_runs WHERE run_id = ? LIMIT 1",
    [$run_id]
)->first();
if (!$r) { http_response_code(404); echo json_encode(['error' => 'no such run']); exit; }
if ($r->finished_at !== null) { echo json_encode(['ok' => true, 'note' => 'already finished']); exit; }
if (!$r->pid) { http_response_code(400); echo json_encode(['error' => 'no pid recorded']); exit; }

if (!function_exists('posix_kill')) {
    http_response_code(500); echo json_encode(['error' => 'posix extension missing']); exit;
}

// SIGTERM the wrapper process group. ansible-playbook handles SIGTERM
// gracefully (drains current task, exits with non-zero).
$ok = posix_kill((int)$r->pid, SIGTERM);
echo json_encode(['ok' => (bool) $ok]);
