<?php
// Helper functions for the ansible-ui module.
// All ansible spawning goes through ansible_run(); never use exec/shell_exec/system.
// All user input passes through three whitelists: playbook, target, flags.

use Symfony\Component\Yaml\Yaml;

// ---------------------------------------------------------------------------
// Environment + paths
// ---------------------------------------------------------------------------

/**
 * Env passed to every spawn. Minimal — when we sudo into the `ansible` user,
 * ansible's own ~/.ansible.cfg + the repo's ansible.cfg (referenced via cwd)
 * provide every setting we used to override here, including the vault
 * password file location. PATH is what the wrapper script uses for curl.
 */
function ansible_env(): array {
    return [
        'PATH'                => ANSIBLE_BIN_DIR . ':/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin',
        'ANSIBLE_FORCE_COLOR' => '0',
        'LANG'                => 'C.UTF-8',
        'LC_ALL'              => 'C.UTF-8',
    ];
}

function ansible_bin(string $name): string {
    return ANSIBLE_BIN_DIR . '/' . $name;
}

/**
 * Wrap an ansible argv in `sudo -n -H -u ansible -- …` so it runs as the
 * `ansible` user. The /etc/sudoers.d/ansible-ui rule (installed by
 * ~/ansible/sudoers.sh) grants this passwordless. -H forces HOME to
 * /home/ansible so ~/.ansible/vault_pass.txt resolves correctly.
 */
function ansible_sudo_argv(string $bin, array $args): array {
    return array_merge(['sudo', '-n', '-H', '-u', 'ansible', '--', $bin], $args);
}

function ansible_runs_dir(): string {
    return dirname(__DIR__) . '/runs';
}

// ---------------------------------------------------------------------------
// Inventory
// ---------------------------------------------------------------------------

/**
 * `ansible-inventory --list` parsed into the canonical JSON shape.
 * Cached in a static for the request lifetime.
 *
 * Returns [] on failure (and writes the stderr to error_log).
 */
function ansible_load_inventory(): array {
    static $cache = null;
    if ($cache !== null) return $cache;

    $argv = ansible_sudo_argv(ansible_bin('ansible-inventory'), [
        '-i', ANSIBLE_REPO . '/inventory.ini',
        '--list',
    ]);
    $proc = proc_open(
        $argv,
        [1 => ['pipe', 'w'], 2 => ['pipe', 'w']],
        $pipes,
        ANSIBLE_REPO,
        ansible_env()
    );
    if (!is_resource($proc)) return $cache = [];

    $stdout = stream_get_contents($pipes[1]);
    $stderr = stream_get_contents($pipes[2]);
    fclose($pipes[1]); fclose($pipes[2]);
    $rc = proc_close($proc);

    if ($rc !== 0) {
        error_log("ansible-inventory --list failed (rc=$rc): " . substr($stderr, 0, 500));
        return $cache = [];
    }
    $json = json_decode($stdout, true);
    return $cache = is_array($json) ? $json : [];
}

/**
 * Flat list of every group name from the inventory.
 * 'all' and '_meta' are excluded — 'all' is a synthetic root, '_meta' is metadata.
 */
function ansible_groups(): array {
    $inv = ansible_load_inventory();
    $names = array_diff(array_keys($inv), ['_meta', 'all', 'ungrouped']);
    sort($names);
    return array_values($names);
}

/**
 * Flat list of every host name in the inventory.
 */
function ansible_hosts(): array {
    $inv = ansible_load_inventory();
    $hosts = array_keys($inv['_meta']['hostvars'] ?? []);
    sort($hosts);
    return $hosts;
}

/**
 * Recursively expand a group to its flat host list.
 * Walks `children` until each leaf yields `hosts`.
 */
function ansible_group_hosts(string $group): array {
    $inv = ansible_load_inventory();
    if (!isset($inv[$group])) return [];

    $out = [];
    $stack = [$group];
    $seen = [];
    while ($stack) {
        $g = array_pop($stack);
        if (isset($seen[$g])) continue;
        $seen[$g] = true;
        if (!empty($inv[$g]['hosts']))    $out = array_merge($out, $inv[$g]['hosts']);
        if (!empty($inv[$g]['children'])) $stack = array_merge($stack, $inv[$g]['children']);
    }
    $out = array_values(array_unique($out));
    sort($out);
    return $out;
}

/**
 * Groups that a host belongs to (direct memberships only — does not walk
 * `children` upward, but returns every group that lists this host in `hosts`).
 */
function ansible_host_groups(string $host): array {
    $inv = ansible_load_inventory();
    $out = [];
    foreach ($inv as $g => $data) {
        if ($g === '_meta' || $g === 'all') continue;
        if (!empty($data['hosts']) && in_array($host, $data['hosts'], true)) $out[] = $g;
    }
    sort($out);
    return $out;
}

/**
 * Merged variables for a single host via `ansible-inventory --host`.
 * Returns the raw vars hash; caller should pretty-print.
 */
function ansible_host_vars(string $host): array {
    if (!ansible_validate_target($host)) return [];

    $proc = proc_open(
        ansible_sudo_argv(ansible_bin('ansible-inventory'), ['-i', ANSIBLE_REPO . '/inventory.ini', '--host', $host]),
        [1 => ['pipe', 'w'], 2 => ['pipe', 'w']],
        $pipes,
        ANSIBLE_REPO,
        ansible_env()
    );
    if (!is_resource($proc)) return [];
    $out = stream_get_contents($pipes[1]);
    fclose($pipes[1]); fclose($pipes[2]);
    proc_close($proc);
    $json = json_decode($out, true);
    return is_array($json) ? $json : [];
}

// ---------------------------------------------------------------------------
// Playbooks
// ---------------------------------------------------------------------------

/**
 * Discover playbooks in the repo root (top-level *.yml).
 * Returns [['file' => 'firewall.yml', 'name' => 'Configure firewall',
 *          'targets' => 'all', 'readonly' => false], ...]
 * Files that don't parse as a play list are skipped.
 */
function ansible_list_playbooks(): array {
    static $cache = null;
    if ($cache !== null) return $cache;

    $readonly_set = [
        // Original quick-look set
        'disk.yml' => 1, 'memory.yml' => 1, 'glance.yml' => 1, 'fleet_health.yml' => 1,
        // Theme 1 fleet-observability reports
        'certs.yml' => 1, 'ports.yml' => 1, 'packages.yml' => 1,
        'services.yml' => 1, 'users.yml' => 1,
        // Theme 2 v1 apache-stack inventory
        'webstack.yml' => 1, 'db.yml' => 1,
        // Theme 3 v1 operational toolkit (read-only first)
        'tail.yml' => 1, 'process_snapshot.yml' => 1,
        // Theme 3 v3 read-only complements
        'unit_log.yml' => 1, 'config_test.yml' => 1, 'grep_log.yml' => 1,
    ];

    $files = glob(ANSIBLE_REPO . '/*.yml') ?: [];
    $playbooks = [];
    foreach ($files as $path) {
        $base = basename($path);
        if ($base[0] === '_') continue;
        try {
            $doc = Yaml::parseFile($path);
        } catch (\Throwable $e) {
            continue;
        }
        if (!is_array($doc) || !isset($doc[0]) || !is_array($doc[0]) || !isset($doc[0]['hosts'])) continue;
        $playbooks[] = [
            'file'     => $base,
            'name'     => $doc[0]['name'] ?? pathinfo($base, PATHINFO_FILENAME),
            'targets'  => $doc[0]['hosts'],
            'readonly' => isset($readonly_set[$base]),
        ];
    }
    usort($playbooks, fn($a, $b) => strcmp($a['file'], $b['file']));
    return $cache = $playbooks;
}

function ansible_find_playbook(string $file): ?array {
    foreach (ansible_list_playbooks() as $p) {
        if ($p['file'] === $file) return $p;
    }
    return null;
}

/**
 * Parse the UI_PARAMS schema block from the top of a playbook.
 *
 * Format expected at the top of the file (one block, in comments):
 *
 *   # UI_PARAMS:
 *   #   log:   enum(apache_error|apache_access|...) required
 *   #   lines: int default=200 min=1 max=10000
 *   #   apply: bool default=false
 *
 * Types: enum (with parens of pipe-separated values), int, bool.
 * Attrs:
 *   required          marks the param as required (else optional)
 *   default=X         default value
 *   min=N max=N       int bounds
 *
 * Returns [] if no UI_PARAMS block. Otherwise an ordered list of
 * [['name'=>..., 'type'=>..., 'values'=>[...], 'required'=>true,
 *   'default'=>..., 'min'=>..., 'max'=>...], ...].
 *
 * The block ends at the first non-comment, non-blank line. The comment
 * prefix is stripped before parsing each param line.
 */
function ansible_playbook_params(string $file): array {
    static $cache = [];
    if (isset($cache[$file])) return $cache[$file];
    $path = ANSIBLE_REPO . '/' . $file;
    if (!is_file($path)) return $cache[$file] = [];
    $content = @file_get_contents($path);
    if ($content === false) return $cache[$file] = [];

    if (!preg_match('/^# UI_PARAMS:\s*\n((?:^#.*(?:\n|$))+)/m', $content, $m)) {
        return $cache[$file] = [];
    }
    $params = [];
    foreach (explode("\n", $m[1]) as $line) {
        // "#   name: type(values) attrs..."
        if (!preg_match('/^#\s+(\w+):\s+(\w+)(?:\(([^)]+)\))?(?:\s+(.*?))?\s*$/', $line, $pm)) {
            continue;
        }
        $param = ['name' => $pm[1], 'type' => $pm[2]];
        if (!empty($pm[3])) {
            $param['values'] = array_map('trim', explode('|', $pm[3]));
        }
        if (!empty($pm[4])) {
            foreach (preg_split('/\s+/', trim($pm[4])) as $attr) {
                if ($attr === 'required') {
                    $param['required'] = true;
                } elseif (str_contains($attr, '=')) {
                    [$k, $v] = explode('=', $attr, 2);
                    $param[$k] = $v;
                }
            }
        }
        $params[] = $param;
    }
    return $cache[$file] = $params;
}

/**
 * Validate a single parameter value against its schema entry.
 * Returns true on valid, false on invalid. Type-specific:
 *   enum   - value must be in $effective_values (which is the schema's
 *            static `values`, plus any per-target extras when the schema
 *            declares `extra_var=NAME` and a target is supplied)
 *   int    - value must be an integer literal within optional min/max
 *   bool   - value must be the string 'true' or 'false'
 *
 * Pass $target when validating an enum-with-extras to compose the
 * effective whitelist for that host/group. Without a target, validation
 * falls back to the static values (matches what the UI form would
 * default to for an unselected target).
 */
function ansible_validate_param_value(array $schema, $val, ?string $target = null): bool {
    if (!is_string($val)) return false;
    switch ($schema['type'] ?? '') {
        case 'enum':
            $effective = ($target !== null && !empty($schema['extra_var']))
                ? ansible_resolve_param_enum($schema, $target)
                : ($schema['values'] ?? []);
            return in_array($val, $effective, true);
        case 'int':
            if (!preg_match('/^-?\d+$/', $val)) return false;
            $n = (int)$val;
            if (isset($schema['min']) && $n < (int)$schema['min']) return false;
            if (isset($schema['max']) && $n > (int)$schema['max']) return false;
            return true;
        case 'bool':
            return in_array($val, ['true', 'false'], true);
        case 'string':
            // Free-form text. Bounded by max_length (mandatory in schema) and
            // optional min_length. Reject any control character (incl. NUL)
            // so the value survives JSON encoding + argv handoff cleanly;
            // common printable Unicode passes through. Specific patterns
            // (e.g. "must look like a regex") are the playbook's job to
            // validate — ours is to keep the bytes safe.
            $max = isset($schema['max_length']) ? (int)$schema['max_length'] : 1024;
            $min = isset($schema['min_length']) ? (int)$schema['min_length'] : 1;
            $len = strlen($val);
            if ($len < $min || $len > $max) return false;
            if (preg_match('/[\x00-\x08\x0b-\x1f\x7f]/', $val)) return false;
            return true;
        default:
            return false;
    }
}

/**
 * Resolve an enum parameter's effective value list for a given target.
 *
 * For schemas that declare `extra_var=NAME`, this composes the static
 * `values` with each host's resolved `NAME` variable (drawn from
 * group_vars / host_vars composition). The host vars come from
 * ansible-inventory --list's _meta.hostvars block, so per-group
 * inheritance is already applied — no per-host shell-out.
 *
 * Behaviour by target:
 *   host name   → values + that host's NAME (if a list)
 *   group name  → values + UNION of NAME across all hosts in the group
 *   no extra_var → values unchanged
 *
 * Returns the merged, deduplicated, sorted list.
 */
function ansible_resolve_param_enum(array $schema, string $target): array {
    $values = $schema['values'] ?? [];
    if (empty($schema['extra_var']))    return $values;
    if (!ansible_validate_target($target)) return $values;

    $extra_var = $schema['extra_var'];
    $hosts     = ansible_target_hosts($target);
    $inv       = ansible_load_inventory();
    $hostvars  = $inv['_meta']['hostvars'] ?? [];

    $extras = [];
    foreach ($hosts as $host) {
        $vars = $hostvars[$host] ?? [];
        if (isset($vars[$extra_var]) && is_array($vars[$extra_var])) {
            foreach ($vars[$extra_var] as $v) {
                if (is_string($v)) $extras[] = $v;
            }
        }
    }
    $merged = array_values(array_unique(array_merge($values, $extras)));
    sort($merged);
    return $merged;
}

/**
 * Flat list of host names a target resolves to.
 *
 *  - host name → [host]
 *  - group name → recursive expansion via ansible_group_hosts()
 *  - unknown → []
 */
function ansible_target_hosts(string $target): array {
    $inv = ansible_load_inventory();
    if (isset($inv['_meta']['hostvars'][$target])) return [$target];
    if (isset($inv[$target])) return ansible_group_hosts($target);
    return [];
}

// ---------------------------------------------------------------------------
// Vars files (group_vars, host_vars)
// ---------------------------------------------------------------------------

/**
 * True if the file starts with the ansible-vault header.
 * Whole-file vault encryption — distinct from inline `!vault |` blocks
 * inside an otherwise plaintext YAML file.
 */
function ansible_is_vault_encrypted(string $path): bool {
    if (!is_file($path) || !is_readable($path)) return false;
    $fp = fopen($path, 'r');
    if (!$fp) return false;
    $first = fgets($fp, 32) ?: '';
    fclose($fp);
    return str_starts_with($first, '$ANSIBLE_VAULT;');
}

/**
 * Read group_vars/<name>.yml if present. Returns:
 *   ['exists' => bool, 'encrypted' => bool, 'vars' => array, 'error' => string|null]
 */
function ansible_read_group_vars(string $group): array {
    $path = ANSIBLE_REPO . '/group_vars/' . $group . '.yml';
    return ansible_read_vars_file($path);
}

function ansible_read_host_vars(string $host): array {
    $path = ANSIBLE_REPO . '/host_vars/' . $host . '.yml';
    return ansible_read_vars_file($path);
}

function ansible_read_vars_file(string $path): array {
    if (!is_file($path)) {
        return ['exists' => false, 'encrypted' => false, 'vars' => [], 'error' => null];
    }
    if (ansible_is_vault_encrypted($path)) {
        return ['exists' => true, 'encrypted' => true, 'vars' => [], 'error' => null];
    }
    try {
        // Symfony Yaml parses `!vault |` blocks as a tagged value object; we
        // surface them as the literal string '(vault encrypted)' for display.
        $vars = Yaml::parseFile($path, Yaml::PARSE_CUSTOM_TAGS);
        return ['exists' => true, 'encrypted' => false, 'vars' => is_array($vars) ? $vars : [], 'error' => null];
    } catch (\Throwable $e) {
        return ['exists' => true, 'encrypted' => false, 'vars' => [], 'error' => $e->getMessage()];
    }
}

// ---------------------------------------------------------------------------
// Validation (the three whitelists)
// ---------------------------------------------------------------------------

/**
 * Target must be alphanumeric/underscore/dot/dash AND resolve to a known
 * group or host in the current inventory.
 */
function ansible_validate_target(string $t): bool {
    if ($t === '' || strlen($t) > 128) return false;
    if (!preg_match('/^[a-zA-Z0-9_.-]+$/', $t)) return false;
    $inv = ansible_load_inventory();
    if (isset($inv[$t]) && $t !== '_meta') return true;          // group
    if (isset($inv['_meta']['hostvars'][$t])) return true;       // host
    return false;
}

/**
 * Playbook must be in the discovered list. No path components allowed.
 */
function ansible_validate_playbook(string $p): bool {
    if ($p === '' || strpos($p, '/') !== false || strpos($p, '..') !== false) return false;
    return ansible_find_playbook($p) !== null;
}

/**
 * Flags: every element must be in the allowed set.
 */
function ansible_validate_flags(array $flags): bool {
    $allowed = ['--check', '--diff', '-v', '-vv'];
    foreach ($flags as $f) {
        if (!is_string($f) || !in_array($f, $allowed, true)) return false;
    }
    return true;
}

// ---------------------------------------------------------------------------
// Run lifecycle
// ---------------------------------------------------------------------------

/**
 * Generate a unique run id: timestamp + short hex.
 */
function ansible_new_run_id(): string {
    return date('Ymd-His') . '-' . bin2hex(random_bytes(4));
}

/**
 * Path to a run's log file. The wrapper writes ansible's stdout+stderr here.
 */
function ansible_run_log_path(string $run_id): string {
    return ansible_runs_dir() . '/' . $run_id . '.log';
}

/**
 * Spawn ansible-playbook detached, output → $log_path.
 *
 * Wraps the real ansible call in a shell wrapper that, on exit, curls
 * run_finish.php with the exit code. That endpoint updates the audit row.
 * This avoids polling /proc and the race of who writes finished_at.
 *
 * Returns the wrapper's pid (NOT ansible's pid — the wrapper is the parent).
 * We store it so cancel can SIGTERM the whole process group.
 *
 * Caller must have already acquired the per-target flock.
 */
function ansible_run_spawn(array $argv, string $run_id, string $log_path): int {
    $wrapper = dirname(__DIR__) . '/includes/run_wrapper.sh';
    $finish_url = 'http://127.0.0.1/ansible/parsers/run_finish.php';

    // Build the wrapped command line: argv passed via env-quoted positional args.
    $full = array_merge(
        ['/bin/bash', $wrapper, $run_id, $log_path, $finish_url, ANSIBLE_FINISH_SECRET, '--'],
        $argv
    );

    $proc = proc_open(
        $full,
        [
            0 => ['file', '/dev/null', 'r'],
            1 => ['file', $log_path, 'a'],
            2 => ['file', $log_path, 'a'],
        ],
        $pipes,
        ANSIBLE_REPO,
        ansible_env()
    );
    if (!is_resource($proc)) return 0;

    $status = proc_get_status($proc);
    $pid = $status['pid'] ?? 0;

    // Don't proc_close — that waits. We want to abandon the handle and let
    // the wrapper finish in the background.
    foreach ($pipes as $p) { if (is_resource($p)) fclose($p); }

    return (int) $pid;
}

/**
 * Acquire a non-blocking lock on the per-target file.
 * Returns the file handle (caller must keep it open for the life of the run)
 * or null if another run already holds the lock.
 *
 * NB: we open in /var/www/html/ansible/runs/.locks rather than /var/lock to
 * avoid sudo dependencies — the runs dir is already group-writable.
 */
function ansible_lock_target(string $target) {
    $dir = ansible_runs_dir() . '/.locks';
    if (!is_dir($dir)) @mkdir($dir, 02775, true);
    $path = $dir . '/' . preg_replace('/[^a-zA-Z0-9_.-]/', '_', $target) . '.lock';
    $fp = fopen($path, 'c');
    if (!$fp) return null;
    if (!flock($fp, LOCK_EX | LOCK_NB)) {
        fclose($fp);
        return null;
    }
    return $fp;
}
