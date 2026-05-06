<?php
require_once __DIR__ . '/../includes/bootstrap.php';

header('Content-Type: application/json');

$run_id = $_GET['id'] ?? '';
if (!preg_match('/^[0-9]{8}-[0-9]{6}-[a-f0-9]{8}$/', $run_id)) {
    http_response_code(400);
    echo json_encode(['error' => 'bad run id']);
    exit;
}

global $db;
$r = $db->query(
    "SELECT run_id, playbook, target, flags, started_at, finished_at, exit_code, pid
     FROM ansible_runs WHERE run_id = ? LIMIT 1",
    [$run_id]
)->first();
if (!$r) {
    http_response_code(404);
    echo json_encode(['error' => 'no such run']);
    exit;
}

echo json_encode([
    'run_id'      => $r->run_id,
    'playbook'    => $r->playbook,
    'target'      => $r->target,
    'flags'       => $r->flags,
    'started_at'  => $r->started_at,
    'finished_at' => $r->finished_at,
    'exit_code'   => $r->exit_code !== null ? (int) $r->exit_code : null,
    'state'       => $r->finished_at === null ? 'running' : 'finished',
]);
