<?php
require_once __DIR__ . '/../includes/bootstrap.php';

$run_id = $_GET['id'] ?? '';
if (!preg_match('/^[0-9]{8}-[0-9]{6}-[a-f0-9]{8}$/', $run_id)) {
    http_response_code(400); echo "bad run id"; exit;
}

global $db;
$r = $db->query("SELECT log_path FROM ansible_runs WHERE run_id = ? LIMIT 1", [$run_id])->first();
if (!$r) { http_response_code(404); echo "no such run"; exit; }
if (!is_file($r->log_path)) { http_response_code(410); echo "log file missing"; exit; }

header('Content-Type: text/plain; charset=utf-8');
readfile($r->log_path);
