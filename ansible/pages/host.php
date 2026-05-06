<?php
require_once __DIR__ . '/../includes/bootstrap.php';
require_once $abs_us_root . $us_url_root . 'users/includes/template/prep.php';

$name = $_GET['name'] ?? '';
if (!ansible_validate_target($name) || !in_array($name, ansible_hosts(), true)) {
    echo '<div class="container py-4"><div class="alert alert-danger">Unknown host.</div></div>';
    require_once $abs_us_root . $us_url_root . 'users/includes/html_footer.php';
    die();
}

$groups = ansible_host_groups($name);
$vars   = ansible_host_vars($name);
$hv     = ansible_read_host_vars($name);
$pbs    = ansible_list_playbooks();

global $db;
$recent = $db->query(
    "SELECT run_id, playbook, target, exit_code, started_at, finished_at
     FROM ansible_runs WHERE target = ? ORDER BY started_at DESC LIMIT 10",
    [$name]
)->results();

// Hide encrypted vars in the merged display: Symfony Yaml returns a TaggedValue.
function ansible_pretty_var($v): string {
    if ($v instanceof \Symfony\Component\Yaml\Tag\TaggedValue) {
        return '(vault encrypted)';
    }
    if (is_array($v) || is_object($v)) {
        return json_encode($v, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
    }
    if (is_bool($v)) return $v ? 'true' : 'false';
    if ($v === null) return 'null';
    return (string) $v;
}
?>

<div class="container py-4">
    <p><a href="../">&larr; dashboard</a></p>
    <h1>Host: <code><?= safeReturn($name) ?></code></h1>

    <div class="row g-4">
        <div class="col-md-6">
            <div class="card">
                <div class="card-header"><strong>Group memberships</strong></div>
                <ul class="list-group list-group-flush">
                    <?php foreach ($groups as $g): ?>
                        <li class="list-group-item">
                            <a href="group.php?name=<?= urlencode($g) ?>"><?= safeReturn($g) ?></a>
                        </li>
                    <?php endforeach; ?>
                    <?php if (!$groups): ?><li class="list-group-item text-muted">None.</li><?php endif; ?>
                </ul>
            </div>

            <div class="card mt-4">
                <div class="card-header"><strong>host_vars/<?= safeReturn($name) ?>.yml</strong></div>
                <div class="card-body">
                    <?php if (!$hv['exists']): ?>
                        <em class="text-muted">No file.</em>
                    <?php elseif ($hv['encrypted']): ?>
                        <em class="text-muted">(vault-encrypted file — not displayed)</em>
                    <?php else: ?>
                        <ul class="mb-0 small">
                            <?php foreach ($hv['vars'] as $k => $v): ?>
                                <li><code><?= safeReturn($k) ?></code>: <?= safeReturn(ansible_pretty_var($v)) ?></li>
                            <?php endforeach; ?>
                            <?php if (!$hv['vars']): ?><li class="text-muted">empty</li><?php endif; ?>
                        </ul>
                    <?php endif; ?>
                </div>
            </div>
        </div>

        <div class="col-md-6">
            <div class="card">
                <div class="card-header"><strong>Merged variables</strong> <small class="text-muted">(ansible-inventory --host)</small></div>
                <div class="card-body">
                    <?php if (!$vars): ?>
                        <em class="text-muted">No vars resolved.</em>
                    <?php else: ?>
                        <table class="table table-sm small mb-0">
                            <tbody>
                                <?php foreach ($vars as $k => $v): ?>
                                    <tr>
                                        <td><code><?= safeReturn($k) ?></code></td>
                                        <td><?= safeReturn(ansible_pretty_var($v)) ?></td>
                                    </tr>
                                <?php endforeach; ?>
                            </tbody>
                        </table>
                    <?php endif; ?>
                </div>
            </div>

            <div class="card mt-4">
                <div class="card-header"><strong>Run a playbook on this host</strong></div>
                <ul class="list-group list-group-flush">
                    <?php foreach ($pbs as $pb): ?>
                        <li class="list-group-item d-flex justify-content-between align-items-center">
                            <a href="playbook.php?name=<?= urlencode($pb['file']) ?>&target=<?= urlencode($name) ?>">
                                <?= safeReturn($pb['file']) ?>
                            </a>
                            <?php if ($pb['readonly']): ?>
                                <span class="badge bg-info">read-only</span>
                            <?php endif; ?>
                        </li>
                    <?php endforeach; ?>
                </ul>
            </div>
        </div>
    </div>

    <div class="card mt-4">
        <div class="card-header"><strong>Recent runs targeting <code><?= safeReturn($name) ?></code></strong></div>
        <div class="table-responsive">
            <table class="table table-sm mb-0">
                <thead><tr><th>Started</th><th>Playbook</th><th>Exit</th><th></th></tr></thead>
                <tbody>
                    <?php foreach ($recent as $r):
                        $running = $r->finished_at === null;
                        $rc = $r->exit_code;
                        $cls = $running ? 'bg-warning' : ((int)$rc === 0 ? 'bg-success' : 'bg-danger');
                        $label = $running ? 'running' : (string)$rc;
                    ?>
                        <tr>
                            <td><small><?= safeReturn($r->started_at) ?></small></td>
                            <td><code><?= safeReturn($r->playbook) ?></code></td>
                            <td><span class="badge <?= $cls ?>"><?= safeReturn($label) ?></span></td>
                            <td><a href="run.php?id=<?= urlencode($r->run_id) ?>" class="btn btn-sm btn-outline-secondary">log</a></td>
                        </tr>
                    <?php endforeach; ?>
                    <?php if (!$recent): ?><tr><td colspan="4" class="text-muted text-center">None.</td></tr><?php endif; ?>
                </tbody>
            </table>
        </div>
    </div>
</div>

<?php require_once $abs_us_root . $us_url_root . 'users/includes/html_footer.php'; ?>
