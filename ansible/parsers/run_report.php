<?php
require_once __DIR__ . '/../includes/bootstrap.php';

$run_id = $_GET['id'] ?? '';
if (!preg_match('/^[0-9]{8}-[0-9]{6}-[a-f0-9]{8}$/', $run_id)) {
    http_response_code(400); echo "bad run id"; exit;
}
$path = ansible_runs_dir() . '/' . $run_id . '.report.json';
if (!is_file($path)) {
    http_response_code(404); echo "no report"; exit;
}
header('Content-Type: application/json');
readfile($path);
