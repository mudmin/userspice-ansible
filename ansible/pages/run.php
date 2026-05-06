<?php
require_once __DIR__ . '/../includes/bootstrap.php';
require_once $abs_us_root . $us_url_root . 'users/includes/template/prep.php';

$run_id = $_GET['id'] ?? '';
if (!preg_match('/^[0-9]{8}-[0-9]{6}-[a-f0-9]{8}$/', $run_id)) {
    echo '<div class="container py-4"><div class="alert alert-danger">Bad run id.</div></div>';
    require_once $abs_us_root . $us_url_root . 'users/includes/html_footer.php';
    die();
}

global $db;
$r = $db->query(
    "SELECT r.*, u.username FROM ansible_runs r LEFT JOIN users u ON u.id=r.user_id
     WHERE r.run_id = ? LIMIT 1",
    [$run_id]
)->first();
if (!$r) {
    echo '<div class="container py-4"><div class="alert alert-danger">No such run.</div></div>';
    require_once $abs_us_root . $us_url_root . 'users/includes/html_footer.php';
    die();
}

$running = $r->finished_at === null;

// Reconstruct (mode, verbosity) from the stored flags string so a Re-run
// button can replay the same parameters via run_start.php.
$flag_set = array_filter(explode(' ', $r->flags));
$rerun_mode = in_array('--check', $flag_set, true) ? 'check'
            : (in_array('--diff', $flag_set, true) ? 'diff' : 'run');
$rerun_verbosity = in_array('-vv', $flag_set, true) ? '-vv'
                 : (in_array('-v', $flag_set, true) ? '-v' : '');
?>

<div class="container-fluid py-4 px-4">
    <p><a href="../">&larr; dashboard</a> &nbsp;<a href="runs.php">all runs</a></p>
    <h1>Run <small class="text-muted"><?= safeReturn($run_id) ?></small></h1>
    <p>
        <code><?= safeReturn($r->playbook) ?></code>
        on <a href="group.php?name=<?= urlencode($r->target) ?>"><code><?= safeReturn($r->target) ?></code></a>
        — flags <code><?= safeReturn($r->flags) ?: '(none)' ?></code>
        — by <?= safeReturn($r->username ?? '?') ?>
        — started <?= safeReturn($r->started_at) ?>
    </p>

    <div class="d-flex gap-2 align-items-center mb-3">
        <span id="status-pill" class="badge bg-warning"><?= $running ? 'running' : 'finished' ?></span>
        <span id="exit-info" class="text-muted small">
            <?php if (!$running): ?>exit code <?= safeReturn((string)$r->exit_code) ?><?php endif; ?>
        </span>
        <?php if ($running): ?>
            <form method="post" action="../parsers/run_cancel.php" id="cancel-form" class="ms-auto m-0">
                <?php tokenHere(); ?>
                <input type="hidden" name="run_id" value="<?= safeReturn($run_id) ?>">
                <button type="submit" class="btn btn-sm btn-outline-danger" onclick="return confirm('Send SIGTERM to this run?');">Cancel</button>
            </form>
        <?php else: ?>
            <form method="post" action="../parsers/run_start.php" id="rerun-form" class="ms-auto m-0">
                <?php tokenHere(); ?>
                <input type="hidden" name="playbook"  value="<?= safeReturn($r->playbook) ?>">
                <input type="hidden" name="target"    value="<?= safeReturn($r->target) ?>">
                <input type="hidden" name="mode"      value="<?= safeReturn($rerun_mode) ?>">
                <input type="hidden" name="verbosity" value="<?= safeReturn($rerun_verbosity) ?>">
                <button type="submit" class="btn btn-sm btn-primary">Re-run</button>
            </form>
        <?php endif; ?>
    </div>

    <div id="report" class="mb-3"></div>

    <div id="recap" class="mb-3"></div>

    <pre id="log" style="background:#0b0e14;color:#e6e1cf;padding:1rem;border-radius:6px;max-height:50vh;overflow:auto;font-size:12px;line-height:1.4;white-space:pre-wrap;word-break:break-word;margin-bottom:3rem;"></pre>
</div>

<style>
    #log .log-ok          { color: #98c379; }
    #log .log-changed     { color: #e5c07b; }
    #log .log-failed,
    #log .log-fatal,
    #log .log-error       { color: #e06c75; font-weight: 600; }
    #log .log-unreachable { color: #c678dd; font-weight: 600; }
    #log .log-skipping    { color: #5c6370; }
    #log .log-recap       { color: #61afef; }
</style>

<script>
(function () {
    const runId = <?= safeJsonEncodeForJs($run_id) ?>;
    const isRunning = <?= $running ? 'true' : 'false' ?>;
    const log = document.getElementById('log');
    const statusPill = document.getElementById('status-pill');
    const exitInfo = document.getElementById('exit-info');

    function classifyLine(line) {
        if (/^ok:/.test(line))                                                     return 'log-ok';
        if (/^changed:/.test(line))                                                return 'log-changed';
        if (/^skipping:/.test(line))                                               return 'log-skipping';
        if (/^unreachable:/.test(line) || /UNREACHABLE/.test(line))                return 'log-unreachable';
        if (/^failed:/.test(line) || /^fatal:/.test(line) || /FAILED/.test(line))  return 'log-failed';
        if (/^\[ERROR\]/.test(line) || /\bERROR!/.test(line))                      return 'log-error';
        if (/^PLAY RECAP/.test(line))                                              return 'log-recap';
        return '';
    }

    function append(text) {
        // Wrap each line in a span so we can colorize per ansible status.
        // Using DOM nodes (not innerHTML +=) to keep append O(1) per line.
        const lines = text.split('\n');
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i];
            const cls = classifyLine(line);
            if (cls && line.length) {
                const span = document.createElement('span');
                span.className = cls;
                span.textContent = line;
                log.appendChild(span);
            } else if (line.length) {
                log.appendChild(document.createTextNode(line));
            }
            if (i < lines.length - 1) log.appendChild(document.createTextNode('\n'));
        }
        log.scrollTop = log.scrollHeight;
    }

    function renderRecap() {
        // Parse the PLAY RECAP block out of whatever's currently in the log.
        const txt = log.textContent;
        const m = txt.match(/PLAY RECAP \*+\s*\n([\s\S]*?)(?:\n\s*\n|$)/);
        if (!m) return;
        const hosts = [];
        for (const line of m[1].split('\n')) {
            const hm = line.match(/^(\S+)\s*:\s*ok=(\d+)\s+changed=(\d+)\s+unreachable=(\d+)\s+failed=(\d+)\s+skipped=(\d+)(?:\s+rescued=(\d+))?(?:\s+ignored=(\d+))?/);
            if (hm) hosts.push({
                name: hm[1],
                ok: +hm[2], changed: +hm[3], unreachable: +hm[4],
                failed: +hm[5], skipped: +hm[6],
                rescued: +(hm[7] || 0), ignored: +(hm[8] || 0),
            });
        }
        if (!hosts.length) return;

        const cell = (n, cls) =>
            `<td class="text-end"><span class="badge ${n > 0 ? cls : 'bg-secondary'}" style="min-width:2.25rem">${n}</span></td>`;

        const rows = ['<div class="card"><div class="card-header"><strong>Play recap</strong></div>',
            '<div class="table-responsive"><table class="table table-sm mb-0"><thead><tr>',
            '<th>Host</th>',
            '<th class="text-end">ok</th>',
            '<th class="text-end">changed</th>',
            '<th class="text-end">unreachable</th>',
            '<th class="text-end">failed</th>',
            '<th class="text-end">skipped</th>',
            '<th class="text-end">rescued</th>',
            '<th class="text-end">ignored</th>',
            '</tr></thead><tbody>'];
        for (const h of hosts) {
            const failing = h.failed > 0 || h.unreachable > 0;
            rows.push(`<tr${failing ? ' class="table-danger"' : ''}>`);
            rows.push(`<td><code>${escapeHtml(h.name)}</code></td>`);
            rows.push(cell(h.ok,          'bg-success'));
            rows.push(cell(h.changed,     'bg-warning'));
            rows.push(cell(h.unreachable, 'bg-danger'));
            rows.push(cell(h.failed,      'bg-danger'));
            rows.push(cell(h.skipped,     'bg-secondary'));
            rows.push(cell(h.rescued,     'bg-info'));
            rows.push(cell(h.ignored,     'bg-secondary'));
            rows.push('</tr>');
        }
        rows.push('</tbody></table></div></div>');
        document.getElementById('recap').innerHTML = rows.join('');
    }

    function escapeHtml(s) {
        return String(s).replace(/[&<>"']/g, c => ({
            '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'
        }[c]));
    }

    function renderDiskReport(r) {
        const host = document.getElementById('report');
        const rows = ['<div class="card"><div class="card-header d-flex justify-content-between align-items-center"><strong>Disk usage</strong>',
            `<small class="text-muted">${escapeHtml(r.generated_at || '')}</small></div>`,
            '<div class="table-responsive"><table class="table table-sm mb-0"><thead><tr>',
            '<th>Host</th><th>Mount</th><th>FS</th><th class="text-end">Size</th><th class="text-end">Free</th><th style="width:25%">Used</th></tr></thead><tbody>'];
        for (const h of (r.hosts || [])) {
            const mounts = h.mounts || [];
            mounts.forEach((m, i) => {
                rows.push('<tr>');
                rows.push(i === 0 ? `<td rowspan="${mounts.length}"><code>${escapeHtml(h.name)}</code></td>` : '');
                rows.push(`<td><code>${escapeHtml(m.mount)}</code></td>`);
                rows.push(`<td><small class="text-muted">${escapeHtml(m.fstype || '')}</small></td>`);
                rows.push(`<td class="text-end">${m.size_gb} G</td>`);
                rows.push(`<td class="text-end">${m.free_gb} G</td>`);
                rows.push(`<td>${pctBar(m.used_pct)}</td>`);
                rows.push('</tr>');
            });
            if (mounts.length === 0) {
                rows.push(`<tr><td><code>${escapeHtml(h.name)}</code></td><td colspan="5" class="text-muted">no mount data</td></tr>`);
            }
        }
        rows.push('</tbody></table></div></div>');
        host.innerHTML = rows.join('');
    }

    function pctClass(pct) {
        return pct >= 90 ? 'bg-danger' : pct >= 75 ? 'bg-warning' : 'bg-success';
    }

    function pctBar(pct) {
        return `<div class="progress" style="height:1.25rem"><div class="progress-bar ${pctClass(pct)}" style="width:${pct}%">${pct}%</div></div>`;
    }

    function renderMemoryReport(r) {
        const host = document.getElementById('report');
        const rows = ['<div class="card"><div class="card-header d-flex justify-content-between align-items-center"><strong>Memory usage</strong>',
            `<small class="text-muted">${escapeHtml(r.generated_at || '')}</small></div>`,
            '<div class="table-responsive"><table class="table table-sm mb-0"><thead><tr>',
            '<th>Host</th><th class="text-end">RAM used</th><th class="text-end">RAM total</th><th style="width:25%">RAM</th>',
            '<th class="text-end">Swap used</th><th class="text-end">Swap total</th><th style="width:25%">Swap</th></tr></thead><tbody>'];
        for (const h of (r.hosts || [])) {
            rows.push('<tr>');
            rows.push(`<td><code>${escapeHtml(h.name)}</code></td>`);
            rows.push(`<td class="text-end">${h.ram_used_mb} M</td>`);
            rows.push(`<td class="text-end">${h.ram_total_mb} M</td>`);
            rows.push(`<td>${pctBar(h.ram_pct)}</td>`);
            rows.push(`<td class="text-end">${h.swap_used_mb} M</td>`);
            rows.push(`<td class="text-end">${h.swap_total_mb} M</td>`);
            rows.push(`<td>${h.swap_total_mb > 0 ? pctBar(h.swap_pct) : '<small class="text-muted">no swap</small>'}</td>`);
            rows.push('</tr>');
        }
        rows.push('</tbody></table></div></div>');
        host.innerHTML = rows.join('');
    }

    function renderGlanceReport(r) {
        const host = document.getElementById('report');
        const rows = ['<div class="card"><div class="card-header d-flex justify-content-between align-items-center"><strong>System glance</strong>',
            `<small class="text-muted">${escapeHtml(r.generated_at || '')}</small></div>`,
            '<div class="table-responsive"><table class="table table-sm mb-0"><thead><tr>',
            '<th>Host</th><th>OS</th><th>Kernel</th><th class="text-end">Uptime</th><th class="text-end">Load (1/5/15)</th>',
            '<th class="text-end">vCPU</th><th style="width:15%">RAM</th><th style="width:15%">Root /</th><th>Reboot</th></tr></thead><tbody>'];
        for (const h of (r.hosts || [])) {
            const reboot = h.reboot_required
                ? '<span class="badge bg-danger">required</span>'
                : '<span class="badge bg-success">no</span>';
            rows.push('<tr>');
            rows.push(`<td><code>${escapeHtml(h.name)}</code></td>`);
            rows.push(`<td><small>${escapeHtml(h.distro)}</small></td>`);
            rows.push(`<td><small class="text-muted">${escapeHtml(h.kernel)}</small></td>`);
            rows.push(`<td class="text-end">${h.uptime_days}d</td>`);
            rows.push(`<td class="text-end"><small>${h.load_1m} / ${h.load_5m} / ${h.load_15m}</small></td>`);
            rows.push(`<td class="text-end">${h.vcpus}</td>`);
            rows.push(`<td>${pctBar(h.ram_pct)}</td>`);
            rows.push(`<td>${pctBar(h.root_pct)}</td>`);
            rows.push(`<td>${reboot}</td>`);
            rows.push('</tr>');
        }
        rows.push('</tbody></table></div></div>');
        host.innerHTML = rows.join('');
    }

    function renderFleetHealthReport(r) {
        const host = document.getElementById('report');
        const hosts = r.hosts || [];
        const summary = {
            unreachable: hosts.filter(h => h.unreachable).length,
            reboot: hosts.filter(h => !h.unreachable && h.reboot_required).length,
            failed_units: hosts.filter(h => !h.unreachable && (h.failed_units || 0) > 0).length,
            kernel_stale: hosts.filter(h => !h.unreachable && h.kernel_stale).length,
        };
        const pill = (n, cls) =>
            `<span class="badge ${n > 0 ? cls : 'bg-secondary'}">${n}</span>`;

        const rows = ['<div class="card"><div class="card-header d-flex justify-content-between align-items-center"><strong>Fleet health</strong>',
            `<small class="text-muted">${escapeHtml(r.generated_at || '')}</small></div>`,
            '<div class="card-body py-2"><div class="d-flex gap-3 small">',
            `<span>Unreachable ${pill(summary.unreachable, 'bg-danger')}</span>`,
            `<span>Reboot required ${pill(summary.reboot, 'bg-warning')}</span>`,
            `<span>Hosts with failed units ${pill(summary.failed_units, 'bg-danger')}</span>`,
            `<span>Kernel outdated ${pill(summary.kernel_stale, 'bg-warning')}</span>`,
            '</div></div>',
            '<div class="table-responsive"><table class="table table-sm mb-0"><thead><tr>',
            '<th>Host</th><th>OS</th><th>Uptime</th><th>RAM</th><th>Storage</th>',
            '<th>Kernel</th><th>Reboot</th><th>Failed units</th><th>Last unattended</th></tr></thead><tbody>'];
        for (const h of hosts) {
            if (h.unreachable) {
                rows.push(`<tr class="table-danger"><td><code>${escapeHtml(h.name)}</code></td>`);
                rows.push('<td colspan="8" class="text-danger fw-bold">UNREACHABLE</td></tr>');
                continue;
            }
            const reboot = h.reboot_required
                ? '<span class="badge bg-danger">required</span>'
                : '<span class="badge bg-success">no</span>';
            const kernel = h.kernel_stale
                ? `<small><code>${escapeHtml(h.kernel_running)}</code> &rarr; <code>${escapeHtml(h.kernel_latest)}</code></small>`
                : `<small class="text-muted"><code>${escapeHtml(h.kernel_running)}</code></small>`;
            let fu;
            if ((h.failed_units || 0) === 0) {
                fu = '<span class="text-muted small">none</span>';
            } else {
                const lines = (h.failed_units_raw || '').split('\n').filter(Boolean);
                const items = lines.map(l => `<li><code>${escapeHtml(l.trim())}</code></li>`).join('');
                fu = `<details><summary><span class="badge bg-danger">${h.failed_units}</span></summary>`
                   + `<ul class="small mb-0 mt-1 ps-3">${items}</ul></details>`;
            }
            rows.push('<tr>');
            rows.push(`<td><code>${escapeHtml(h.name)}</code></td>`);
            rows.push(`<td><small>${escapeHtml(h.distro || '')}</small></td>`);
            rows.push(`<td><small class="text-muted">${escapeHtml(h.uptime || '')}</small></td>`);
            rows.push(`<td style="width:12%">${pctBar(h.ram_pct)}</td>`);
            rows.push(`<td style="width:12%">${h.root_used_pct !== null ? pctBar(h.root_used_pct) : '<small class="text-muted">—</small>'}</td>`);
            rows.push(`<td>${kernel}</td>`);
            rows.push(`<td>${reboot}</td>`);
            rows.push(`<td>${fu}</td>`);
            rows.push(`<td><small class="text-muted">${escapeHtml(h.unattended_last || '—')}</small></td>`);
            rows.push('</tr>');
        }
        rows.push('</tbody></table></div></div>');
        host.innerHTML = rows.join('');
    }

    function renderCertsReport(r) {
        // Flatten certs across hosts and sort by days_left ascending so urgent
        // expiries float to the top — that's the operational question this
        // report answers.
        const all = [];
        for (const h of (r.hosts || [])) {
            for (const c of (h.certs || [])) all.push(Object.assign({host_name: h.name}, c));
        }
        all.sort((a, b) => (a.days_left || 0) - (b.days_left || 0));
        const statusBadge = (s) => {
            const cls = s === 'expired' || s === 'critical' ? 'bg-danger'
                      : s === 'warn' ? 'bg-warning'
                      : 'bg-success';
            return `<span class="badge ${cls}">${escapeHtml(s || '?')}</span>`;
        };
        const host = document.getElementById('report');
        const rows = ['<div class="card"><div class="card-header d-flex justify-content-between align-items-center"><strong>TLS certificates</strong>',
            `<small class="text-muted">${escapeHtml(r.generated_at || '')}</small></div>`,
            '<div class="table-responsive"><table class="table table-sm mb-0"><thead><tr>',
            '<th>Host</th><th>Lineage</th><th class="text-end">Days left</th><th>Expires</th><th>Issuer</th><th>SANs</th><th>Status</th></tr></thead><tbody>'];
        for (const c of all) {
            const sans = c.sans || [];
            const sansCell = sans.length > 0
                ? `<details><summary>${sans.length}</summary><small class="text-muted">${escapeHtml(sans.join(', '))}</small></details>`
                : '<small class="text-muted">—</small>';
            rows.push('<tr>');
            rows.push(`<td><code>${escapeHtml(c.host_name)}</code></td>`);
            rows.push(`<td><code>${escapeHtml(c.lineage || '?')}</code></td>`);
            rows.push(`<td class="text-end">${c.days_left}d</td>`);
            rows.push(`<td><small>${escapeHtml(c.not_after || '')}</small></td>`);
            rows.push(`<td><small class="text-muted">${escapeHtml((c.issuer || '').slice(0, 60))}</small></td>`);
            rows.push(`<td>${sansCell}</td>`);
            rows.push(`<td>${statusBadge(c.status)}</td>`);
            rows.push('</tr>');
        }
        if (all.length === 0) {
            rows.push('<tr><td colspan="7" class="text-muted text-center">No certs found.</td></tr>');
        }
        rows.push('</tbody></table></div></div>');
        host.innerHTML = rows.join('');
    }

    function renderPortsReport(r) {
        const host = document.getElementById('report');
        const rows = ['<div class="card"><div class="card-header d-flex justify-content-between align-items-center"><strong>Listening sockets</strong>',
            `<small class="text-muted">${escapeHtml(r.generated_at || '')}</small></div>`,
            '<div class="table-responsive"><table class="table table-sm mb-0"><thead><tr>',
            '<th>Host</th><th>Proto</th><th>Address</th><th class="text-end">Port</th><th>Process</th></tr></thead><tbody>'];
        for (const h of (r.hosts || [])) {
            const listeners = h.listeners || [];
            listeners.forEach((l, i) => {
                rows.push('<tr>');
                rows.push(i === 0 ? `<td rowspan="${listeners.length}"><code>${escapeHtml(h.name)}</code></td>` : '');
                rows.push(`<td><small class="text-muted">${escapeHtml(l.proto || '')}</small></td>`);
                rows.push(`<td><code>${escapeHtml(l.address || '')}</code></td>`);
                rows.push(`<td class="text-end"><strong>${l.port}</strong></td>`);
                rows.push(`<td>${escapeHtml(l.process || '—')}</td>`);
                rows.push('</tr>');
            });
            if (listeners.length === 0) {
                rows.push(`<tr><td><code>${escapeHtml(h.name)}</code></td><td colspan="4" class="text-muted">no listeners</td></tr>`);
            }
        }
        rows.push('</tbody></table></div></div>');
        host.innerHTML = rows.join('');
    }

    function renderPackagesReport(r) {
        const host = document.getElementById('report');
        const rows = ['<div class="card"><div class="card-header d-flex justify-content-between align-items-center"><strong>Installed packages</strong>',
            `<small class="text-muted">${escapeHtml(r.generated_at || '')}</small></div>`,
            '<div class="card-body p-0">'];
        for (const h of (r.hosts || [])) {
            rows.push('<div class="border-bottom px-3 py-2">');
            rows.push(`<h6 class="mb-2"><code>${escapeHtml(h.name)}</code> <small class="text-muted">${escapeHtml(h.distro || '')}</small></h6>`);
            rows.push('<div class="row"><div class="col-md-6">');
            rows.push('<table class="table table-sm table-borderless mb-0"><tbody>');
            for (const p of (h.curated || [])) {
                const cell = p.installed
                    ? `<code>${escapeHtml(p.version || '')}</code>`
                    : '<small class="text-muted">—</small>';
                rows.push(`<tr><td><small>${escapeHtml(p.name)}</small></td><td>${cell}</td></tr>`);
            }
            rows.push('</tbody></table></div><div class="col-md-6">');
            const phpPkgs = h.php_pkgs || [];
            if (phpPkgs.length > 0) {
                rows.push(`<details><summary class="small"><strong>PHP packages</strong> (${phpPkgs.length})</summary>`);
                rows.push('<table class="table table-sm table-borderless mb-0 mt-1"><tbody>');
                for (const p of phpPkgs) {
                    rows.push(`<tr><td><small>${escapeHtml(p.name)}</small></td><td><code><small>${escapeHtml(p.version)}</small></code></td></tr>`);
                }
                rows.push('</tbody></table></details>');
            } else {
                rows.push('<small class="text-muted">No PHP packages installed.</small>');
            }
            rows.push('</div></div></div>');
        }
        rows.push('</div></div>');
        host.innerHTML = rows.join('');
    }

    function renderServicesReport(r) {
        const host = document.getElementById('report');
        const rows = ['<div class="card"><div class="card-header d-flex justify-content-between align-items-center"><strong>Service inventory</strong>',
            `<small class="text-muted">${escapeHtml(r.generated_at || '')}</small></div>`,
            '<div class="card-body p-0">'];
        for (const h of (r.hosts || [])) {
            const failed = h.failed || [];
            const key = h.key || [];
            rows.push('<div class="border-bottom px-3 py-2">');
            rows.push('<div class="d-flex align-items-center gap-2 mb-2">');
            rows.push(`<h6 class="mb-0"><code>${escapeHtml(h.name)}</code></h6>`);
            rows.push(`<small class="text-muted">${h.enabled_count || 0} enabled .service units</small>`);
            if (failed.length > 0) {
                rows.push(`<details class="ms-auto"><summary><span class="badge bg-danger">${failed.length} failed</span></summary>`);
                rows.push('<ul class="small mt-1 mb-0 ps-3">');
                for (const u of failed) rows.push(`<li><code>${escapeHtml(u)}</code></li>`);
                rows.push('</ul></details>');
            } else {
                rows.push('<span class="ms-auto badge bg-success">no failed units</span>');
            }
            rows.push('</div>');
            if (key.length > 0) {
                rows.push('<table class="table table-sm table-borderless mb-0"><thead><tr>');
                rows.push('<th>Unit</th><th>Active</th><th>Sub</th><th>Enabled</th></tr></thead><tbody>');
                for (const s of key) {
                    const cls = s.active === 'active' ? 'bg-success'
                              : s.active === 'failed' ? 'bg-danger'
                              : 'bg-secondary';
                    rows.push('<tr>');
                    rows.push(`<td><code>${escapeHtml(s.unit)}</code></td>`);
                    rows.push(`<td><span class="badge ${cls}">${escapeHtml(s.active || '')}</span></td>`);
                    rows.push(`<td><small class="text-muted">${escapeHtml(s.sub || '')}</small></td>`);
                    rows.push(`<td><small>${escapeHtml(s.enabled || '')}</small></td>`);
                    rows.push('</tr>');
                }
                rows.push('</tbody></table>');
            }
            rows.push('</div>');
        }
        rows.push('</div></div>');
        host.innerHTML = rows.join('');
    }

    function renderUsersReport(r) {
        const host = document.getElementById('report');
        const rows = ['<div class="card"><div class="card-header d-flex justify-content-between align-items-center"><strong>Users + SSH keys</strong>',
            `<small class="text-muted">${escapeHtml(r.generated_at || '')}</small></div>`,
            '<div class="table-responsive"><table class="table table-sm mb-0"><thead><tr>',
            '<th>Host</th><th>User</th><th class="text-end">UID</th><th>Login</th><th class="text-end">Keys</th><th>Shell</th></tr></thead><tbody>'];
        for (const h of (r.hosts || [])) {
            const users = h.users || [];
            users.forEach((u, i) => {
                const loginBadge = u.login
                    ? '<span class="badge bg-success">login</span>'
                    : '<span class="badge bg-secondary">nologin</span>';
                let keysCell;
                if (u.key_count > 0) {
                    const items = (u.keys || []).map(k =>
                        `<li><code>${escapeHtml(k.type || '?')}</code> <small class="text-muted">${escapeHtml(k.comment || '')}</small></li>`
                    ).join('');
                    keysCell = `<details><summary>${u.key_count}</summary><ul class="small mb-0 mt-1 ps-3 text-start">${items}</ul></details>`;
                } else {
                    keysCell = '<small class="text-muted">0</small>';
                }
                rows.push('<tr>');
                rows.push(i === 0 ? `<td rowspan="${users.length}"><code>${escapeHtml(h.name)}</code></td>` : '');
                rows.push(`<td><code>${escapeHtml(u.name)}</code></td>`);
                rows.push(`<td class="text-end">${u.uid}</td>`);
                rows.push(`<td>${loginBadge}</td>`);
                rows.push(`<td class="text-end">${keysCell}</td>`);
                rows.push(`<td><small class="text-muted">${escapeHtml(u.shell || '')}</small></td>`);
                rows.push('</tr>');
            });
            if (users.length === 0) {
                rows.push(`<tr><td><code>${escapeHtml(h.name)}</code></td><td colspan="5" class="text-muted">no users</td></tr>`);
            }
        }
        rows.push('</tbody></table></div></div>');
        host.innerHTML = rows.join('');
    }

    function renderWebstackReport(r) {
        const host = document.getElementById('report');
        const rows = ['<div class="card"><div class="card-header d-flex justify-content-between align-items-center"><strong>Apache stack inventory</strong>',
            `<small class="text-muted">${escapeHtml(r.generated_at || '')}</small></div>`,
            '<div class="card-body p-0">'];

        // Cross-host vhost roll-up — the drift-discovery view.
        const allVhosts = [];
        for (const h of (r.hosts || [])) {
            for (const v of (h.vhosts || [])) allVhosts.push(Object.assign({host_name: h.name}, v));
        }
        if (allVhosts.length > 0) {
            allVhosts.sort((a, b) =>
                (a.server_name || '').localeCompare(b.server_name || '') ||
                (a.host_name || '').localeCompare(b.host_name || ''));
            rows.push('<div class="px-3 py-2 border-bottom"><h6 class="mb-2">All vhosts (across hosts)</h6>');
            rows.push('<div class="table-responsive"><table class="table table-sm mb-0"><thead><tr>');
            rows.push('<th>Host</th><th>Server name</th><th class="text-end">Port</th><th>Document root</th><th>PHP</th><th>Handler</th><th>SSL lineage</th></tr></thead><tbody>');
            for (const v of allVhosts) {
                const phpCell = v.php_version
                    ? `<span class="badge bg-info">${escapeHtml(v.php_version)}</span>`
                    : '<small class="text-muted">—</small>';
                rows.push('<tr>');
                rows.push(`<td><code>${escapeHtml(v.host_name)}</code></td>`);
                rows.push(`<td><code>${escapeHtml(v.server_name || '?')}</code></td>`);
                rows.push(`<td class="text-end">${v.port || '?'}</td>`);
                rows.push(`<td><small>${escapeHtml(v.document_root || '?')}</small></td>`);
                rows.push(`<td>${phpCell}</td>`);
                rows.push(`<td><small class="text-muted">${escapeHtml(v.php_handler || '—')}</small></td>`);
                rows.push(`<td>${v.ssl_cert_lineage ? `<small><code>${escapeHtml(v.ssl_cert_lineage)}</code></small>` : '<small class="text-muted">—</small>'}</td>`);
                rows.push('</tr>');
            }
            rows.push('</tbody></table></div></div>');
        }

        // Per-host detail sections.
        for (const h of (r.hosts || [])) {
            const a = h.apache || {};
            const p = h.php || {};
            const n = h.node || {};
            rows.push('<div class="border-bottom px-3 py-2">');
            rows.push(`<h6 class="mb-2"><code>${escapeHtml(h.name)}</code></h6>`);
            rows.push('<dl class="row mb-2 small">');
            rows.push('<dt class="col-sm-2">Apache</dt><dd class="col-sm-10">');
            if (a.installed) {
                rows.push(`${escapeHtml(a.version || '')} <small class="text-muted">mpm=${escapeHtml(a.mpm || '?')}`);
                if (a.mod_php_version) rows.push(` mod_php=${escapeHtml(a.mod_php_version)}`);
                if (a.modsecurity) rows.push(' modsec=on');
                rows.push('</small>');
                const mods = (a.modules_of_interest || []).join(', ');
                if (mods) rows.push(`<br><small class="text-muted">modules: ${escapeHtml(mods)}</small>`);
            } else {
                rows.push('<small class="text-muted">(not installed)</small>');
            }
            rows.push('</dd>');
            rows.push('<dt class="col-sm-2">PHP</dt><dd class="col-sm-10">');
            if (p.default_cli_full) {
                rows.push(`CLI default <code>${escapeHtml(p.default_cli_full)}</code>`);
                if ((p.installed_versions || []).length) {
                    rows.push(` <small class="text-muted">(versions installed: ${escapeHtml((p.installed_versions || []).join(', '))})</small>`);
                }
                const pools = p.fpm_pools || [];
                if (pools.length) {
                    rows.push('<br><small class="text-muted">FPM pools: ');
                    rows.push(pools.map(f => {
                        const pill = f.active
                            ? '<span class="badge bg-success">active</span>'
                            : '<span class="badge bg-secondary">inactive</span>';
                        return `${escapeHtml(f.version)}/${escapeHtml(f.pool)}@${escapeHtml(f.user || '')} ${pill}`;
                    }).join(' &nbsp; '));
                    rows.push('</small>');
                }
            } else {
                rows.push('<small class="text-muted">(not installed)</small>');
            }
            rows.push('</dd>');
            rows.push('<dt class="col-sm-2">Node</dt><dd class="col-sm-10">');
            rows.push(n.installed ? `<code>${escapeHtml(n.version || '')}</code>` : '<small class="text-muted">(not installed)</small>');
            rows.push('</dd></dl>');

            const wr = h.webroot || [];
            if (wr.length > 0) {
                rows.push(`<details><summary class="small"><strong>/var/www</strong> (${wr.length} entries)</summary>`);
                rows.push('<table class="table table-sm table-borderless mb-0 mt-1"><thead><tr>');
                rows.push('<th>Path</th><th>Owner</th><th class="text-end">Size</th><th>Vhosts</th></tr></thead><tbody>');
                for (const w of wr) {
                    const sz = w.size_bytes >= 1073741824
                        ? `${(w.size_bytes / 1073741824).toFixed(1)} GB`
                        : `${(w.size_bytes / 1048576).toFixed(1)} MB`;
                    const matched = (w.matched_vhosts || []).map(v => `<code>${escapeHtml(v)}</code>`).join(', ')
                        || '<span class="text-muted">no match</span>';
                    rows.push('<tr>');
                    rows.push(`<td><small><code>${escapeHtml(w.path)}</code></small></td>`);
                    rows.push(`<td><small>${escapeHtml(w.owner || '')}:${escapeHtml(w.group || '')}</small></td>`);
                    rows.push(`<td class="text-end"><small>${sz}</small></td>`);
                    rows.push(`<td><small>${matched}</small></td>`);
                    rows.push('</tr>');
                }
                rows.push('</tbody></table></details>');
            }
            rows.push('</div>');
        }
        rows.push('</div></div>');
        host.innerHTML = rows.join('');
    }

    function renderCleanupReport(r) {
        const host = document.getElementById('report');
        const params = r.params || {};
        const isApply = params.apply === true;
        const modeBadge = isApply
            ? '<span class="badge bg-warning text-dark">APPLIED</span>'
            : '<span class="badge bg-secondary">preview</span>';
        const headerLabel = `Cleanup ${modeBadge} <small class="text-muted">(keep_days=${params.keep_days || '?'})</small>`;
        const fmtMb = (kb) => ((kb || 0) / 1024).toFixed(1) + ' MB';
        const fmtMbBytes = (b) => ((b || 0) / 1048576).toFixed(1) + ' MB';

        const rows = ['<div class="card"><div class="card-header d-flex justify-content-between align-items-center"><strong>'+headerLabel+'</strong>',
            `<small class="text-muted">${escapeHtml(r.generated_at || '')}</small></div>`,
            '<div class="card-body p-0">'];

        for (const h of (r.hosts || [])) {
            const apt = h.apt || {};
            const j = h.journal || {};
            const t = h.tmp || {};
            const aptPkgs = apt.autoremove_packages || [];
            rows.push('<div class="border-bottom px-3 py-2">');
            rows.push(`<h6 class="mb-2"><code>${escapeHtml(h.name)}</code></h6>`);
            rows.push('<dl class="row mb-2 small">');

            // apt
            rows.push('<dt class="col-sm-2">apt</dt><dd class="col-sm-10">');
            if (aptPkgs.length > 0) {
                rows.push(`<details><summary>autoremove: ${aptPkgs.length} packages, ~${fmtMb(apt.autoremove_freed_kb_estimate)}</summary>`);
                rows.push('<ul class="small mb-0 mt-1 ps-3">');
                for (const p of aptPkgs) rows.push(`<li><code>${escapeHtml(p)}</code></li>`);
                rows.push('</ul></details>');
            } else {
                rows.push('autoremove: 0 packages');
            }
            rows.push(`<br>autoclean: ~${fmtMb(apt.autoclean_freed_kb_estimate)}`);
            if (isApply) {
                const total = (apt.autoremove_freed_kb || 0) + (apt.autoclean_freed_kb || 0);
                rows.push(`<br><small class="text-muted">applied: freed ${fmtMb(total)}</small>`);
                if (apt.autoremove_rc) rows.push(`<br><span class="text-danger small">autoremove rc=${apt.autoremove_rc}</span>`);
                if (apt.autoclean_rc)  rows.push(`<br><span class="text-danger small">autoclean rc=${apt.autoclean_rc}</span>`);
            }
            rows.push('</dd>');

            // journal
            rows.push('<dt class="col-sm-2">journal</dt><dd class="col-sm-10">');
            rows.push(`current ${fmtMb(j.before_kb)}`);
            if (isApply) {
                rows.push(` &rarr; ${fmtMb(j.after_kb)} <small class="text-muted">(freed ${fmtMb(j.freed_kb)})</small>`);
            }
            rows.push('</dd>');

            // /tmp
            rows.push('<dt class="col-sm-2">/tmp</dt><dd class="col-sm-10">');
            rows.push(`${t.candidate_count || 0} files older than ${h.keep_days}d, ${fmtMbBytes(t.candidate_bytes)}`);
            if (isApply) {
                rows.push(`<br><small class="text-muted">applied: removed ${t.removed_count || 0} files, ${fmtMbBytes(t.removed_bytes)}</small>`);
            }
            const sample = t.candidate_paths_sample || [];
            if (sample.length > 0) {
                rows.push('<br><details class="small"><summary>sample paths (first '+sample.length+')</summary><ul class="mb-0 mt-1 ps-3">');
                for (const p of sample) rows.push(`<li><code>${escapeHtml(p)}</code></li>`);
                rows.push('</ul></details>');
            }
            rows.push('</dd>');

            rows.push('</dl></div>');
        }
        rows.push('</div></div>');
        host.innerHTML = rows.join('');
    }

    function renderServiceReport(r) {
        const host = document.getElementById('report');
        const params = r.params || {};
        const verbed = params.action === 'restart' ? 'Restart'
                     : params.action === 'reload'  ? 'Reload'
                     : 'Status';
        const headerLabel = `${verbed}: <code>${escapeHtml(params.service || '?')}</code>`;
        const rows = ['<div class="card"><div class="card-header d-flex justify-content-between align-items-center"><strong>'+headerLabel+'</strong>',
            `<small class="text-muted">${escapeHtml(r.generated_at || '')}</small></div>`,
            '<div class="table-responsive"><table class="table table-sm mb-0"><thead><tr>',
            '<th>Host</th><th>Outcome</th><th>Active</th><th>Sub</th><th>Unit file</th>',
            (params.action !== 'status' ? '<th>Before</th>' : ''),
            '</tr></thead><tbody>'];
        for (const h of (r.hosts || [])) {
            const before = h.before || {};
            const after  = h.after  || before;
            let outcomeBadge;
            if (h.error) {
                outcomeBadge = `<span class="badge bg-danger" title="${escapeHtml(h.error)}">FAILED</span>`;
            } else if (h.mutated) {
                outcomeBadge = '<span class="badge bg-warning text-dark">applied</span>';
            } else {
                outcomeBadge = '<span class="badge bg-success">queried</span>';
            }
            const activeCls = (after.ActiveState === 'active') ? 'bg-success'
                            : (after.ActiveState === 'failed') ? 'bg-danger'
                            : 'bg-secondary';
            rows.push('<tr>');
            rows.push(`<td><code>${escapeHtml(h.name)}</code></td>`);
            rows.push(`<td>${outcomeBadge}</td>`);
            rows.push(`<td><span class="badge ${activeCls}">${escapeHtml(after.ActiveState || '?')}</span></td>`);
            rows.push(`<td><small class="text-muted">${escapeHtml(after.SubState || '?')}</small></td>`);
            rows.push(`<td><small>${escapeHtml(after.UnitFileState || '?')}</small></td>`);
            if (params.action !== 'status') {
                rows.push(`<td><small class="text-muted">${escapeHtml(before.ActiveState || '?')} / ${escapeHtml(before.SubState || '?')}</small></td>`);
            }
            rows.push('</tr>');
        }
        if ((r.hosts || []).length === 0) {
            rows.push('<tr><td colspan="6" class="text-muted text-center">No hosts in scope.</td></tr>');
        }
        rows.push('</tbody></table></div></div>');
        host.innerHTML = rows.join('');
    }

    function renderProcessSnapshotReport(r) {
        const host = document.getElementById('report');
        const params = r.params || {};
        const headerLabel = `Process snapshot — top ${params.n || '?'} per host`;
        const rows = ['<div class="card"><div class="card-header d-flex justify-content-between align-items-center"><strong>'+headerLabel+'</strong>',
            `<small class="text-muted">${escapeHtml(r.generated_at || '')}</small></div>`,
            '<div class="card-body p-0">'];

        function procTable(label, list) {
            const out = ['<div class="col-lg-6">',
                `<h6 class="mb-1 small text-muted">${label}</h6>`,
                '<div class="table-responsive"><table class="table table-sm table-borderless mb-0"><thead><tr>',
                '<th>PID</th><th>User</th><th class="text-end">%CPU</th><th class="text-end">%MEM</th><th class="text-end">RSS</th><th>Cmd</th></tr></thead><tbody>'];
            for (const p of (list || [])) {
                const rss_mb = Math.round((p.rss_kb || 0) / 1024);
                const cmd = p.command || '';
                const cmd_short = cmd.length > 50 ? cmd.slice(0, 50) + '…' : cmd;
                out.push('<tr>');
                out.push(`<td><code>${p.pid}</code></td>`);
                out.push(`<td><small>${escapeHtml(p.user || '')}</small></td>`);
                out.push(`<td class="text-end">${(p.pcpu || 0).toFixed(1)}</td>`);
                out.push(`<td class="text-end">${(p.pmem || 0).toFixed(1)}</td>`);
                out.push(`<td class="text-end">${rss_mb}M</td>`);
                out.push(`<td><small title="${escapeHtml(cmd)}"><code>${escapeHtml(cmd_short)}</code></small></td>`);
                out.push('</tr>');
            }
            if ((list || []).length === 0) {
                out.push('<tr><td colspan="6" class="text-muted small">no processes</td></tr>');
            }
            out.push('</tbody></table></div></div>');
            return out.join('');
        }

        for (const h of (r.hosts || [])) {
            rows.push('<div class="border-bottom px-3 py-2">');
            rows.push(`<h6 class="mb-2"><code>${escapeHtml(h.name)}</code></h6>`);
            rows.push('<div class="row g-3">');
            rows.push(procTable('Top by CPU',  h.top_cpu || []));
            rows.push(procTable('Top by RAM',  h.top_mem || []));
            rows.push('</div></div>');
        }
        rows.push('</div></div>');
        host.innerHTML = rows.join('');
    }

    function renderUnitLogReport(r) {
        // Same shape as tail.yml's report but per-host text is journalctl
        // -u <unit> output; existence flag means "the unit was loaded".
        const host = document.getElementById('report');
        const params = r.params || {};
        const headerLabel = `Unit log — <code>${escapeHtml(params.unit || '?')}</code> (${(params.lines || '?')} lines requested)`;
        const rows = ['<div class="card"><div class="card-header d-flex justify-content-between align-items-center"><strong>'+headerLabel+'</strong>',
            `<small class="text-muted">${escapeHtml(r.generated_at || '')}</small></div>`,
            '<div class="card-body p-0">'];
        for (const h of (r.hosts || [])) {
            rows.push('<div class="border-bottom px-3 py-2">');
            rows.push('<div class="d-flex align-items-center gap-2 mb-2 flex-wrap">');
            rows.push(`<h6 class="mb-0"><code>${escapeHtml(h.name)}</code></h6>`);
            rows.push(`<small class="text-muted">${h.n_returned}/${h.n_requested} lines</small>`);
            if (!h.exists) rows.push('<span class="ms-auto badge bg-secondary">unit not loaded</span>');
            rows.push('</div>');
            if (h.exists && (h.lines || []).length > 0) {
                rows.push('<pre style="background:#0b0e14;color:#e6e1cf;padding:0.75rem;border-radius:4px;font-size:11px;line-height:1.4;white-space:pre-wrap;word-break:break-word;max-height:50vh;overflow:auto;margin:0;">');
                rows.push((h.lines || []).map(escapeHtml).join('\n'));
                rows.push('</pre>');
            }
            rows.push('</div>');
        }
        rows.push('</div></div>');
        host.innerHTML = rows.join('');
    }

    function renderConfigTestReport(r) {
        const host = document.getElementById('report');
        const params = r.params || {};
        const headerLabel = `Config test — ${escapeHtml(params.what || '?')}`;
        const rows = ['<div class="card"><div class="card-header d-flex justify-content-between align-items-center"><strong>'+headerLabel+'</strong>',
            `<small class="text-muted">${escapeHtml(r.generated_at || '')}</small></div>`,
            '<div class="card-body p-0">'];
        for (const h of (r.hosts || [])) {
            let badge;
            if (!h.applicable)   badge = '<span class="badge bg-secondary">not applicable</span>';
            else if (h.ok)       badge = '<span class="badge bg-success">OK</span>';
            else                 badge = `<span class="badge bg-danger">FAILED rc=${h.exit_code}</span>`;
            rows.push('<div class="border-bottom px-3 py-2">');
            rows.push('<div class="d-flex align-items-center gap-2 mb-1 flex-wrap">');
            rows.push(`<h6 class="mb-0"><code>${escapeHtml(h.name)}</code></h6>`);
            rows.push(badge);
            rows.push('</div>');
            if (h.applicable && (h.output || '')) {
                rows.push('<pre style="background:#0b0e14;color:#e6e1cf;padding:0.5rem;border-radius:4px;font-size:11px;line-height:1.35;white-space:pre-wrap;word-break:break-word;max-height:30vh;overflow:auto;margin:0.25rem 0 0 0;">');
                rows.push(escapeHtml(h.output));
                rows.push('</pre>');
            }
            rows.push('</div>');
        }
        rows.push('</div></div>');
        host.innerHTML = rows.join('');
    }

    function renderGrepLogReport(r) {
        const host = document.getElementById('report');
        const params = r.params || {};
        const ptype = params.pattern_type || 'plain';
        const headerLabel = `Grep — ${escapeHtml(params.log || '?')} <code>${escapeHtml(params.pattern || '')}</code> <small class="text-muted">(${escapeHtml(ptype)}${params.context ? ', ±'+params.context : ''})</small>`;
        const rows = ['<div class="card"><div class="card-header d-flex justify-content-between align-items-center"><strong>'+headerLabel+'</strong>',
            `<small class="text-muted">${escapeHtml(r.generated_at || '')}</small></div>`,
            '<div class="card-body p-0">'];
        for (const h of (r.hosts || [])) {
            rows.push('<div class="border-bottom px-3 py-2">');
            rows.push('<div class="d-flex align-items-center gap-2 mb-2 flex-wrap">');
            rows.push(`<h6 class="mb-0"><code>${escapeHtml(h.name)}</code></h6>`);
            rows.push(`<small class="text-muted"><code>${escapeHtml(h.path || '')}</code></small>`);
            rows.push(`<small class="text-muted">${h.line_count} matching lines</small>`);
            if (!h.exists) rows.push('<span class="ms-auto badge bg-secondary">log not present</span>');
            rows.push('</div>');
            if (h.exists && (h.lines || []).length > 0) {
                rows.push('<pre style="background:#0b0e14;color:#e6e1cf;padding:0.75rem;border-radius:4px;font-size:11px;line-height:1.4;white-space:pre-wrap;word-break:break-word;max-height:50vh;overflow:auto;margin:0;">');
                rows.push((h.lines || []).map(escapeHtml).join('\n'));
                rows.push('</pre>');
            }
            rows.push('</div>');
        }
        rows.push('</div></div>');
        host.innerHTML = rows.join('');
    }

    function renderTailReport(r) {
        const host = document.getElementById('report');
        const params = r.params || {};
        const headerLabel = `Log tail — ${escapeHtml(params.log || '?')} (${(params.lines || '?')} lines requested)`;
        const rows = ['<div class="card"><div class="card-header d-flex justify-content-between align-items-center"><strong>'+headerLabel+'</strong>',
            `<small class="text-muted">${escapeHtml(r.generated_at || '')}</small></div>`,
            '<div class="card-body p-0">'];
        for (const h of (r.hosts || [])) {
            rows.push('<div class="border-bottom px-3 py-2">');
            rows.push('<div class="d-flex align-items-center gap-2 mb-2 flex-wrap">');
            rows.push(`<h6 class="mb-0"><code>${escapeHtml(h.name)}</code></h6>`);
            rows.push(`<small class="text-muted"><code>${escapeHtml(h.path || '')}</code></small>`);
            rows.push(`<small class="text-muted">${h.n_returned}/${h.n_requested} lines</small>`);
            if (!h.exists) {
                rows.push('<span class="ms-auto badge bg-secondary">not present</span>');
            }
            rows.push('</div>');
            if (h.exists && (h.lines || []).length > 0) {
                // Standalone scroll container per host so a noisy journal on
                // one host doesn't dominate the page.
                rows.push('<pre style="background:#0b0e14;color:#e6e1cf;padding:0.75rem;border-radius:4px;font-size:11px;line-height:1.4;white-space:pre-wrap;word-break:break-word;max-height:50vh;overflow:auto;margin:0;">');
                rows.push((h.lines || []).map(escapeHtml).join('\n'));
                rows.push('</pre>');
            }
            rows.push('</div>');
        }
        rows.push('</div></div>');
        host.innerHTML = rows.join('');
    }

    function renderDbReport(r) {
        const host = document.getElementById('report');
        const rows = ['<div class="card"><div class="card-header d-flex justify-content-between align-items-center"><strong>Database inventory</strong>',
            `<small class="text-muted">${escapeHtml(r.generated_at || '')}</small></div>`,
            '<div class="table-responsive"><table class="table table-sm mb-0"><thead><tr>',
            '<th>Host</th><th>Flavor</th><th>Package</th><th>Running</th><th>Service</th><th class="text-end">Datadir</th><th>Tunables</th></tr></thead><tbody>'];
        for (const h of (r.hosts || [])) {
            if (h.flavor === 'none') {
                rows.push(`<tr class="text-muted"><td><code>${escapeHtml(h.name)}</code></td><td colspan="6"><small>(no DB server installed)</small></td></tr>`);
                continue;
            }
            const flavorBadge = h.flavor === 'mariadb'
                ? '<span class="badge bg-primary">mariadb</span>'
                : '<span class="badge bg-warning text-dark">mysql</span>';
            const runningCell = h.running_version
                ? `<small><code>${escapeHtml(h.running_version)}</code></small>`
                : '<small class="text-warning">auth failed / down</small>';
            const svcCls = h.service_state === 'active' ? 'bg-success'
                         : h.service_state === 'failed' ? 'bg-danger'
                         : h.service_state === 'inactive' ? 'bg-secondary'
                         : 'bg-warning';
            const sizeCell = (h.datadir_size_gb !== null && h.datadir_size_gb !== undefined)
                ? `${h.datadir_size_gb} GB`
                : '<small class="text-muted">—</small>';
            const tun = h.tunables || {};
            const tunCell = '<small><code>max_conn=' + escapeHtml(tun.max_connections || '?') +
                            '</code><br><code>buffer=' + escapeHtml(tun.innodb_buffer_pool_size || '?') + '</code></small>';
            rows.push('<tr>');
            rows.push(`<td><code>${escapeHtml(h.name)}</code></td>`);
            rows.push(`<td>${flavorBadge}</td>`);
            rows.push(`<td><small><code>${escapeHtml(h.package_version || '?')}</code></small></td>`);
            rows.push(`<td>${runningCell}</td>`);
            rows.push(`<td><span class="badge ${svcCls}">${escapeHtml(h.service_state || '?')}</span></td>`);
            rows.push(`<td class="text-end">${sizeCell}</td>`);
            rows.push(`<td>${tunCell}</td>`);
            rows.push('</tr>');
        }
        rows.push('</tbody></table></div></div>');
        host.innerHTML = rows.join('');
    }

    function renderReport(r) {
        if (!r) return;
        if (r.report_type === 'disk')         renderDiskReport(r);
        if (r.report_type === 'memory')       renderMemoryReport(r);
        if (r.report_type === 'glance')       renderGlanceReport(r);
        if (r.report_type === 'fleet_health') renderFleetHealthReport(r);
        if (r.report_type === 'certs')        renderCertsReport(r);
        if (r.report_type === 'ports')        renderPortsReport(r);
        if (r.report_type === 'packages')     renderPackagesReport(r);
        if (r.report_type === 'services')     renderServicesReport(r);
        if (r.report_type === 'users')        renderUsersReport(r);
        if (r.report_type === 'webstack')     renderWebstackReport(r);
        if (r.report_type === 'db')           renderDbReport(r);
        if (r.report_type === 'tail')             renderTailReport(r);
        if (r.report_type === 'process_snapshot') renderProcessSnapshotReport(r);
        if (r.report_type === 'service')          renderServiceReport(r);
        if (r.report_type === 'cleanup')          renderCleanupReport(r);
        if (r.report_type === 'unit_log')         renderUnitLogReport(r);
        if (r.report_type === 'config_test')      renderConfigTestReport(r);
        if (r.report_type === 'grep_log')         renderGrepLogReport(r);
    }

    function loadReport() {
        return fetch('../parsers/run_report.php?id=' + encodeURIComponent(runId), { credentials: 'same-origin' })
            .then(r => r.ok ? r.json() : null)
            .then(renderReport)
            .catch(() => {});
    }

    if (isRunning) {
        const es = new EventSource('../parsers/run_stream.php?id=' + encodeURIComponent(runId));
        es.onmessage = ev => append(ev.data + '\n');
        es.addEventListener('end', ev => {
            es.close();
            try {
                const d = JSON.parse(ev.data);
                statusPill.className = 'badge ' + (d.exit_code === 0 ? 'bg-success' : 'bg-danger');
                statusPill.textContent = 'finished';
                exitInfo.textContent = 'exit code ' + d.exit_code;
            } catch (e) {}
            const cancel = document.getElementById('cancel-form');
            if (cancel) cancel.style.display = 'none';
            renderRecap();
            loadReport();
        });
        es.onerror = () => {
            // EventSource will auto-reconnect indefinitely if the run never
            // ended (e.g. server killed). Close after one error to avoid loops.
            if (es.readyState === EventSource.CLOSED) return;
        };

        const cancel = document.getElementById('cancel-form');
        if (cancel) cancel.addEventListener('submit', async function (e) {
            e.preventDefault();
            const fd = new FormData(this);
            const res = await fetch(this.action, { method: 'POST', body: fd, credentials: 'same-origin' });
            const d = await res.json().catch(() => ({}));
            if (d.error) alert(d.error);
        });
    } else {
        // Already finished — just dump the log file once.
        fetch('../parsers/run_log.php?id=' + encodeURIComponent(runId), { credentials: 'same-origin' })
            .then(r => r.text())
            .then(t => { append(t); renderRecap(); })
            .catch(() => {});
        statusPill.className = 'badge ' + (<?= (int)$r->exit_code ?> === 0 ? 'bg-success' : 'bg-danger');
        statusPill.textContent = 'finished';
        loadReport();
    }

    const rerun = document.getElementById('rerun-form');
    if (rerun) rerun.addEventListener('submit', async function (e) {
        e.preventDefault();
        const btn = this.querySelector('button[type=submit]');
        btn.disabled = true;
        try {
            const res = await fetch(this.action, { method: 'POST', body: new FormData(this), credentials: 'same-origin' });
            const ct = res.headers.get('content-type') || '';
            const data = ct.includes('application/json') ? await res.json() : {};
            if (data.run_id) {
                window.location.href = 'run.php?id=' + encodeURIComponent(data.run_id);
            } else {
                alert(data.error || 'Failed to start run.');
                btn.disabled = false;
            }
        } catch (err) {
            alert('Network error: ' + err.message);
            btn.disabled = false;
        }
    });
})();
</script>

<?php require_once $abs_us_root . $us_url_root . 'users/includes/html_footer.php'; ?>
