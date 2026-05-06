<?php
require_once __DIR__ . '/../includes/bootstrap.php';
require_once $abs_us_root . $us_url_root . 'users/includes/template/prep.php';

$name = $_GET['name'] ?? '';
if (!ansible_validate_target($name) || !in_array($name, ansible_groups(), true)) {
    echo '<div class="container py-4"><div class="alert alert-danger">Unknown group.</div></div>';
    require_once $abs_us_root . $us_url_root . 'users/includes/html_footer.php';
    die();
}

$inv      = ansible_load_inventory();
$hosts    = ansible_group_hosts($name);
$direct   = $inv[$name]['hosts']    ?? [];
$children = $inv[$name]['children'] ?? [];
$gv       = ansible_read_group_vars($name);
$pbs      = ansible_list_playbooks();

global $db;
$recent = $db->query(
    "SELECT run_id, playbook, target, exit_code, started_at, finished_at
     FROM ansible_runs WHERE target = ? ORDER BY started_at DESC LIMIT 10",
    [$name]
)->results();
?>

<div class="container py-4">
    <p><a href="../">&larr; dashboard</a></p>
    <h1>Group: <code><?= safeReturn($name) ?></code></h1>
    <p class="text-muted"><?= count($hosts) ?> host<?= count($hosts) === 1 ? '' : 's' ?> (recursive)</p>

    <div class="row g-4">
        <div class="col-md-6">
            <div class="card">
                <div class="card-header"><strong>Hosts</strong></div>
                <ul class="list-group list-group-flush">
                    <?php foreach ($hosts as $h): ?>
                        <li class="list-group-item">
                            <a href="host.php?name=<?= urlencode($h) ?>"><?= safeReturn($h) ?></a>
                        </li>
                    <?php endforeach; ?>
                    <?php if (!$hosts): ?>
                        <li class="list-group-item text-muted">No hosts.</li>
                    <?php endif; ?>
                </ul>
            </div>

            <?php if ($children): ?>
                <div class="card mt-4">
                    <div class="card-header"><strong>Child groups</strong></div>
                    <ul class="list-group list-group-flush">
                        <?php foreach ($children as $c): ?>
                            <li class="list-group-item">
                                <a href="group.php?name=<?= urlencode($c) ?>"><?= safeReturn($c) ?></a>
                            </li>
                        <?php endforeach; ?>
                    </ul>
                </div>
            <?php endif; ?>
        </div>

        <div class="col-md-6">
            <div class="card">
                <div class="card-header"><strong>group_vars/<?= safeReturn($name) ?>.yml</strong></div>
                <div class="card-body">
                    <?php if (!$gv['exists']): ?>
                        <em class="text-muted">No file.</em>
                    <?php elseif ($gv['encrypted']): ?>
                        <em class="text-muted">(vault-encrypted file — not displayed)</em>
                    <?php elseif ($gv['error']): ?>
                        <div class="alert alert-warning small mb-0"><?= safeReturn($gv['error']) ?></div>
                    <?php else: ?>
                        <ul class="mb-0 small">
                            <?php foreach (array_keys($gv['vars']) as $k): ?>
                                <li><code><?= safeReturn($k) ?></code></li>
                            <?php endforeach; ?>
                            <?php if (!$gv['vars']): ?>
                                <li class="text-muted">empty</li>
                            <?php endif; ?>
                        </ul>
                    <?php endif; ?>
                </div>
            </div>

            <div class="card mt-4">
                <div class="card-header"><strong>Run a playbook on this group</strong></div>
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
