<?php
require_once __DIR__ . '/../includes/bootstrap.php';
require_once $abs_us_root . $us_url_root . 'users/includes/template/prep.php';

$page     = max(1, (int)($_GET['p'] ?? 1));
$per_page = 50;
$offset   = ($page - 1) * $per_page;

global $db;
$total = (int) $db->query("SELECT COUNT(*) AS c FROM ansible_runs")->first()->c;
$rows  = $db->query(
    "SELECT r.run_id, r.playbook, r.target, r.flags, r.exit_code, r.started_at, r.finished_at, u.username
     FROM ansible_runs r LEFT JOIN users u ON u.id=r.user_id
     ORDER BY r.started_at DESC
     LIMIT $per_page OFFSET $offset"
)->results();

$pages = max(1, (int) ceil($total / $per_page));
?>

<div class="container py-4">
    <p><a href="../">&larr; dashboard</a></p>
    <h1>Run history</h1>
    <p class="text-muted"><?= $total ?> total</p>

    <div class="table-responsive">
        <table class="table table-sm">
            <thead><tr>
                <th>Started</th><th>User</th><th>Playbook</th><th>Target</th><th>Flags</th><th>Exit</th><th></th>
            </tr></thead>
            <tbody>
                <?php foreach ($rows as $r):
                    $running = $r->finished_at === null;
                    $rc = $r->exit_code;
                    $cls = $running ? 'bg-warning' : ((int)$rc === 0 ? 'bg-success' : 'bg-danger');
                    $label = $running ? 'running' : (string)$rc;
                ?>
                    <tr>
                        <td><small><?= safeReturn($r->started_at) ?></small></td>
                        <td><?= safeReturn($r->username ?? '?') ?></td>
                        <td><code><?= safeReturn($r->playbook) ?></code></td>
                        <td><code><?= safeReturn($r->target) ?></code></td>
                        <td><small><?= safeReturn($r->flags) ?></small></td>
                        <td><span class="badge <?= $cls ?>"><?= safeReturn($label) ?></span></td>
                        <td><a href="run.php?id=<?= urlencode($r->run_id) ?>" class="btn btn-sm btn-outline-secondary">log</a></td>
                    </tr>
                <?php endforeach; ?>
                <?php if (!$rows): ?>
                    <tr><td colspan="7" class="text-muted text-center">No runs yet.</td></tr>
                <?php endif; ?>
            </tbody>
        </table>
    </div>

    <?php if ($pages > 1): ?>
        <nav>
            <ul class="pagination pagination-sm">
                <?php for ($i = 1; $i <= $pages; $i++): ?>
                    <li class="page-item <?= $i === $page ? 'active' : '' ?>">
                        <a class="page-link" href="?p=<?= $i ?>"><?= $i ?></a>
                    </li>
                <?php endfor; ?>
            </ul>
        </nav>
    <?php endif; ?>
</div>

<?php require_once $abs_us_root . $us_url_root . 'users/includes/html_footer.php'; ?>
