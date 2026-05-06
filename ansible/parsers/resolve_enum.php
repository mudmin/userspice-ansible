<?php
// resolve_enum.php — AJAX endpoint that returns the effective list of
// enum values for a parameterized playbook + target.
//
// For enum params declared with `extra_var=NAME`, the dropdown's options
// depend on which target the user picked: the static defaults plus each
// host's `NAME` group_var/host_var. The playbook page hits this endpoint
// when the target Tom Select changes so the dependent enum can refresh
// its options without a full page reload.
//
// GET params:
//   playbook  — known playbook (validated)
//   param     — name of an enum parameter on that playbook
//   target    — host or group name (validated)
//
// Returns:
//   {"values": [...]}  on success
//   {"error":  "..."}  on failure (non-200)

require_once __DIR__ . '/../includes/bootstrap.php';
header('Content-Type: application/json');

function rfail(string $msg, int $http = 400): never {
    http_response_code($http);
    echo json_encode(['error' => $msg]);
    exit;
}

$playbook = $_GET['playbook'] ?? '';
$param    = $_GET['param']    ?? '';
$target   = $_GET['target']   ?? '';

if (!ansible_validate_playbook($playbook)) rfail('Invalid playbook');
if (!preg_match('/^\w+$/', $param))         rfail('Invalid param name');
if (!ansible_validate_target($target))      rfail('Invalid target');

$schema = null;
foreach (ansible_playbook_params($playbook) as $p) {
    if ($p['name'] === $param) { $schema = $p; break; }
}
if (!$schema)                            rfail('Unknown parameter for this playbook');
if (($schema['type'] ?? '') !== 'enum')  rfail('Param is not an enum');

echo json_encode(['values' => ansible_resolve_param_enum($schema, $target)]);
