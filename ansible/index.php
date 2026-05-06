<?php
require_once __DIR__ . '/includes/bootstrap.php';
require_once $abs_us_root . $us_url_root . 'users/includes/template/prep.php';

global $db;
$recent = $db->query(
    "SELECT r.run_id, r.playbook, r.target, r.flags, r.exit_code, r.started_at, r.finished_at,
            u.username
     FROM ansible_runs r
     LEFT JOIN users u ON u.id = r.user_id
     ORDER BY r.started_at DESC
     LIMIT 10"
)->results();

$groups    = ansible_groups();
$inventory = ansible_load_inventory();
$playbooks = ansible_list_playbooks();
?>

<div class="container py-4">
    <div class="d-flex justify-content-between align-items-start mb-4">
        <h1 class="mb-0">Ansible UI</h1>
        <div class="btn-group btn-group-sm" role="group">
            <a href="pages/help.php" class="btn btn-outline-secondary">Getting started</a>
            <a href="https://userspice.com/donate/" target="_blank" rel="noopener" class="btn btn-outline-success">Donate</a>
        </div>
    </div>
    <p class="text-muted">Repo: <code><?= safeReturn(ANSIBLE_REPO) ?></code></p>

    <div class="row g-4">
        <div class="col-md-6">
            <div class="card">
                <div class="card-header"><strong>Groups</strong></div>
                <ul class="list-group list-group-flush">
                    <?php foreach ($groups as $g):
                        $count = count(ansible_group_hosts($g)); ?>
                        <li class="list-group-item d-flex justify-content-between align-items-center">
                            <a href="pages/group.php?name=<?= urlencode($g) ?>"><?= safeReturn($g) ?></a>
                            <span class="badge bg-secondary rounded-pill"><?= (int) $count ?></span>
                        </li>
                    <?php endforeach; ?>
                    <?php if (!$groups): ?>
                        <li class="list-group-item text-muted">No groups found in inventory.</li>
                    <?php endif; ?>
                </ul>
            </div>
        </div>

        <div class="col-md-6">
            <div class="card">
                <div class="card-header"><strong>Playbooks</strong></div>
                <ul class="list-group list-group-flush">
                    <?php foreach ($playbooks as $pb): ?>
                        <li class="list-group-item d-flex justify-content-between align-items-center">
                            <a href="pages/playbook.php?name=<?= urlencode($pb['file']) ?>">
                                <?= safeReturn($pb['file']) ?>
                            </a>
                            <span>
                                <?php if ($pb['readonly']): ?>
                                    <span class="badge bg-info">read-only</span>
                                <?php endif; ?>
                                <small class="text-muted ms-2"><?= safeReturn($pb['name']) ?></small>
                            </span>
                        </li>
                    <?php endforeach; ?>
                    <?php if (!$playbooks): ?>
                        <li class="list-group-item text-muted">No playbooks found in <code><?= safeReturn(ANSIBLE_REPO) ?></code>.</li>
                    <?php endif; ?>
                </ul>
            </div>
        </div>
    </div>

    <div class="card mt-4">
        <div class="card-header d-flex justify-content-between align-items-center">
            <strong>Recent runs</strong>
            <a href="pages/runs.php" class="small">history &rarr;</a>
        </div>
        <div class="table-responsive">
            <table class="table table-sm mb-0">
                <thead>
                    <tr>
                        <th>Started</th>
                        <th>User</th>
                        <th>Playbook</th>
                        <th>Target</th>
                        <th>Flags</th>
                        <th>Exit</th>
                        <th></th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach ($recent as $r):
                        $running = $r->finished_at === null;
                        $rc = $r->exit_code;
                        $cls = $running ? 'bg-warning' : ($rc === 0 || $rc === '0' ? 'bg-success' : 'bg-danger');
                        $label = $running ? 'running' : (string) $rc;
                    ?>
                        <tr>
                            <td><small><?= safeReturn($r->started_at) ?></small></td>
                            <td><?= safeReturn($r->username ?? '?') ?></td>
                            <td><code><?= safeReturn($r->playbook) ?></code></td>
                            <td><code><?= safeReturn($r->target) ?></code></td>
                            <td><small><?= safeReturn($r->flags) ?></small></td>
                            <td><span class="badge <?= $cls ?>"><?= safeReturn($label) ?></span></td>
                            <td><a href="pages/run.php?id=<?= urlencode($r->run_id) ?>" class="btn btn-sm btn-outline-secondary">log</a></td>
                        </tr>
                    <?php endforeach; ?>
                    <?php if (!$recent): ?>
                        <tr><td colspan="7" class="text-muted text-center">No runs yet.</td></tr>
                    <?php endif; ?>
                </tbody>
            </table>
        </div>
    </div>
</div>

<?php require_once $abs_us_root . $us_url_root . 'users/includes/html_footer.php'; ?>
