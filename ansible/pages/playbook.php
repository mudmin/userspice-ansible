<?php
require_once __DIR__ . '/../includes/bootstrap.php';
require_once $abs_us_root . $us_url_root . 'users/includes/template/prep.php';

$file = $_GET['name'] ?? '';
if (!ansible_validate_playbook($file)) {
    echo '<div class="container py-4"><div class="alert alert-danger">Unknown playbook.</div></div>';
    require_once $abs_us_root . $us_url_root . 'users/includes/html_footer.php';
    die();
}
$pb = ansible_find_playbook($file);

$preselect = $_GET['target'] ?? '';
if ($preselect !== '' && !ansible_validate_target($preselect)) $preselect = '';

$groups = ansible_groups();
$hosts  = ansible_hosts();

// Per-playbook parameter schema parsed from the UI_PARAMS comment block.
// Each entry: ['name','type','values','required','default','min','max'].
// The form below renders one field per entry; run_start.php validates
// values against the same schema before invoking ansible.
$pb_params = ansible_playbook_params($pb['file']);
?>

<div class="container py-4">
    <p><a href="../">&larr; dashboard</a></p>
    <h1>Playbook: <code><?= safeReturn($pb['file']) ?></code></h1>
    <p class="lead"><?= safeReturn($pb['name']) ?></p>
    <p class="text-muted">
        Default <code>hosts:</code> <code><?= safeReturn(is_array($pb['targets']) ? json_encode($pb['targets']) : (string)$pb['targets']) ?></code>
        <?php if ($pb['readonly']): ?>
            <span class="badge bg-info">read-only</span>
        <?php endif; ?>
    </p>

    <div class="card">
        <div class="card-header"><strong>Run</strong></div>
        <div class="card-body">
            <form method="post" action="../parsers/run_start.php" id="run-form">
                <?php tokenHere(); ?>
                <input type="hidden" name="playbook" value="<?= safeReturn($pb['file']) ?>">

                <div class="mb-3">
                    <label class="form-label" for="target-select"><strong>Target</strong> <small class="text-muted">(--limit)</small></label>
                    <select class="form-select" name="target" id="target-select" required placeholder="Type to search groups and hosts&hellip;">
                        <option value=""></option>
                        <optgroup label="Groups">
                            <?php foreach ($groups as $g): ?>
                                <option value="<?= safeReturn($g) ?>" <?= $preselect === $g ? 'selected' : '' ?>><?= safeReturn($g) ?></option>
                            <?php endforeach; ?>
                        </optgroup>
                        <optgroup label="Hosts">
                            <?php foreach ($hosts as $h): ?>
                                <option value="<?= safeReturn($h) ?>" <?= $preselect === $h ? 'selected' : '' ?>><?= safeReturn($h) ?></option>
                            <?php endforeach; ?>
                        </optgroup>
                    </select>
                </div>

                <?php foreach ($pb_params as $p):
                    $field_name = 'param_' . $p['name'];
                    $field_id   = 'param-' . $p['name'];
                    $required   = !empty($p['required']);
                    $default    = $_GET['param_' . $p['name']] ?? ($p['default'] ?? '');
                    // For enum-with-extras, use the per-target resolved
                    // list when a target is preselected; otherwise show
                    // the static defaults until the user picks a target
                    // (JS then refreshes the dropdown via AJAX).
                    $enum_values = $p['values'] ?? [];
                    if ($p['type'] === 'enum' && !empty($p['extra_var']) && $preselect !== '') {
                        $enum_values = ansible_resolve_param_enum($p, $preselect);
                    }
                ?>
                    <div class="mb-3">
                        <label class="form-label" for="<?= safeReturn($field_id) ?>">
                            <strong><?= safeReturn($p['name']) ?></strong>
                            <small class="text-muted">(<?= safeReturn($p['type']) ?><?php
                                if (isset($p['min']) || isset($p['max'])) {
                                    echo ' ' . safeReturn(($p['min'] ?? '?') . '..' . ($p['max'] ?? '?'));
                                }
                            ?>)</small>
                            <?php if ($required): ?><span class="text-danger small">required</span><?php endif; ?>
                            <?php if (!empty($p['extra_var'])): ?>
                                <small class="text-muted">— extras from <code><?= safeReturn($p['extra_var']) ?></code></small>
                            <?php endif; ?>
                        </label>
                        <?php if ($p['type'] === 'enum'): ?>
                            <select class="form-select playbook-param-enum"
                                    name="<?= safeReturn($field_name) ?>"
                                    id="<?= safeReturn($field_id) ?>"
                                    data-param="<?= safeReturn($p['name']) ?>"
                                    <?php if (!empty($p['extra_var'])): ?>data-extra-var="<?= safeReturn($p['extra_var']) ?>"<?php endif; ?>
                                    <?= $required ? 'required' : '' ?>>
                                <option value=""></option>
                                <?php foreach ($enum_values as $v): ?>
                                    <option value="<?= safeReturn($v) ?>" <?= $default === $v ? 'selected' : '' ?>><?= safeReturn($v) ?></option>
                                <?php endforeach; ?>
                            </select>
                        <?php elseif ($p['type'] === 'int'): ?>
                            <input type="number"
                                   class="form-control"
                                   name="<?= safeReturn($field_name) ?>"
                                   id="<?= safeReturn($field_id) ?>"
                                   value="<?= safeReturn((string)$default) ?>"
                                   <?php if (isset($p['min'])): ?>min="<?= safeReturn((string)$p['min']) ?>"<?php endif; ?>
                                   <?php if (isset($p['max'])): ?>max="<?= safeReturn((string)$p['max']) ?>"<?php endif; ?>
                                   <?= $required ? 'required' : '' ?>>
                        <?php elseif ($p['type'] === 'bool'): ?>
                            <select class="form-select"
                                    name="<?= safeReturn($field_name) ?>"
                                    id="<?= safeReturn($field_id) ?>"
                                    <?= $required ? 'required' : '' ?>>
                                <option value="false" <?= $default === 'false' ? 'selected' : '' ?>>false</option>
                                <option value="true"  <?= $default === 'true'  ? 'selected' : '' ?>>true</option>
                            </select>
                        <?php elseif ($p['type'] === 'string'): ?>
                            <input type="text"
                                   class="form-control"
                                   name="<?= safeReturn($field_name) ?>"
                                   id="<?= safeReturn($field_id) ?>"
                                   value="<?= safeReturn((string)$default) ?>"
                                   <?php if (isset($p['max_length'])): ?>maxlength="<?= safeReturn((string)$p['max_length']) ?>"<?php endif; ?>
                                   <?php if (isset($p['min_length'])): ?>minlength="<?= safeReturn((string)$p['min_length']) ?>"<?php endif; ?>
                                   <?= $required ? 'required' : '' ?>
                                   autocomplete="off"
                                   spellcheck="false">
                        <?php endif; ?>
                    </div>
                <?php endforeach; ?>

                <div class="mb-3">
                    <label class="form-label"><strong>Verbosity</strong></label>
                    <select class="form-select" name="verbosity">
                        <option value="">default</option>
                        <option value="-v">-v</option>
                        <option value="-vv">-vv</option>
                    </select>
                </div>

                <div class="d-flex gap-2 flex-wrap">
                    <button type="submit" name="mode" value="check" class="btn btn-secondary">
                        Check (dry run)
                    </button>
                    <button type="submit" name="mode" value="diff" class="btn btn-warning">
                        Diff
                    </button>
                    <button type="submit" name="mode" value="run" class="btn btn-danger" onclick="return confirm('Run <?= safeReturn($pb['file']) ?> for real?');">
                        Run (apply)
                    </button>
                </div>
            </form>
        </div>
    </div>
</div>

<!-- Tom Select for the target picker: typeahead + scrollable dropdown that
     doesn't get clipped by short viewports. -->
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/tom-select@2.4.3/dist/css/tom-select.bootstrap5.min.css">
<script src="https://cdn.jsdelivr.net/npm/tom-select@2.4.3/dist/js/tom-select.complete.min.js"></script>

<script>
// Same treatment for any enum-type playbook parameter so a long whitelist
// (e.g. service.yml's unit list, tail.yml's log keys) is searchable and
// the dropdown can scroll out of the card. Initialised first so the
// target picker's onChange can grab their TomSelect instances.
const paramEnumTomSelects = {};
document.querySelectorAll('select.playbook-param-enum').forEach(function (el) {
    paramEnumTomSelects[el.dataset.param] = new TomSelect(el, {
        maxOptions:     500,
        dropdownParent: 'body',
        placeholder:    'Choose…',
    });
});

// When target changes, refresh any enum field that declares extra_var.
// The AJAX endpoint composes the static defaults with the host's
// (or group's union of) `extra_var` list and returns the merged values.
const playbookFile = document.querySelector('input[name="playbook"]').value;
function refreshDependentEnums(target) {
    if (!target) return;
    document.querySelectorAll('select.playbook-param-enum[data-extra-var]').forEach(function (el) {
        const ts = paramEnumTomSelects[el.dataset.param];
        if (!ts) return;
        const url = '../parsers/resolve_enum.php?'
            + 'playbook=' + encodeURIComponent(playbookFile)
            + '&param='   + encodeURIComponent(el.dataset.param)
            + '&target='  + encodeURIComponent(target);
        fetch(url, { credentials: 'same-origin' })
            .then(function (r) { return r.ok ? r.json() : null; })
            .then(function (data) {
                if (!data || !Array.isArray(data.values)) return;
                // Preserve current selection if still valid, else clear.
                const current = ts.getValue();
                ts.clearOptions();
                data.values.forEach(function (v) {
                    ts.addOption({ value: v, text: v });
                });
                ts.refreshOptions(false);
                if (current && data.values.indexOf(current) !== -1) {
                    ts.setValue(current, /*silent=*/true);
                } else {
                    ts.clear(/*silent=*/true);
                }
            })
            .catch(function () { /* leave existing options in place */ });
    });
}

// Type-ahead target picker. dropdownParent on body avoids clipping by the
// card / container; maxOptions=500 disables truncation for our fleet size.
const targetTomSelect = new TomSelect('#target-select', {
    sortField:      { field: 'text', direction: 'asc' },
    maxOptions:     500,
    dropdownParent: 'body',
    placeholder:    'Type to search groups and hosts…',
    onChange:       function (value) { refreshDependentEnums(value); },
});

document.getElementById('run-form').addEventListener('submit', async function(e) {
    e.preventDefault();
    const fd = new FormData(this);
    const btn = e.submitter;
    if (btn) fd.set('mode', btn.value);
    btn.disabled = true;
    try {
        const res = await fetch(this.action, { method: 'POST', body: fd, credentials: 'same-origin' });
        const ct = res.headers.get('content-type') || '';
        if (!ct.includes('application/json')) {
            alert('Unexpected response from server. HTTP ' + res.status);
            btn.disabled = false;
            return;
        }
        const data = await res.json();
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
</script>

<?php require_once $abs_us_root . $us_url_root . 'users/includes/html_footer.php'; ?>
