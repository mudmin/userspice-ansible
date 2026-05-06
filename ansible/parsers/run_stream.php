<?php
require_once __DIR__ . '/../includes/bootstrap.php';

$run_id = $_GET['id'] ?? '';
if (!preg_match('/^[0-9]{8}-[0-9]{6}-[a-f0-9]{8}$/', $run_id)) {
    http_response_code(400);
    echo "bad run id";
    exit;
}

global $db;
$row = $db->query("SELECT log_path FROM ansible_runs WHERE run_id = ? LIMIT 1", [$run_id])->first();
if (!$row) {
    http_response_code(404);
    echo "no such run";
    exit;
}
$log_path = $row->log_path;

// SSE setup.
header('Content-Type: text/event-stream');
header('Cache-Control: no-cache');
header('X-Accel-Buffering: no');     // tell nginx to not buffer
while (ob_get_level() > 0) ob_end_flush();
@ini_set('zlib.output_compression', '0');
@ini_set('output_buffering', '0');
@ini_set('implicit_flush', '1');
ob_implicit_flush(true);

// Hard ceiling so a stuck client doesn't hold a worker forever.
@set_time_limit(0);
$max_seconds = 1800;     // 30 min
$started     = time();

/**
 * Emit a single log line as one SSE message. SSE doesn't allow embedded
 * newlines inside a `data:` field, but a logical newline at the end of the
 * line maps to "this event ends here", which is fine. CR is stripped to
 * avoid garbled rendering.
 */
function ansible_sse_emit(string $line): void {
    $line = rtrim($line, "\r\n");
    echo "data: " . $line . "\n\n";
    @flush();
}

$fp = null;
$wait = 0;
while (time() - $started < $max_seconds) {
    if (connection_aborted()) break;

    if ($fp === null) {
        if (is_file($log_path)) $fp = @fopen($log_path, 'r');
        if (!$fp) { sleep(1); continue; }
    }

    $line = fgets($fp);
    if ($line === false) {
        // PHP's fgets latches EOF; an fseek to the current position clears the
        // EOF flag so the next fgets sees bytes appended since we hit EOF.
        clearstatcache(true, $log_path);
        fseek($fp, 0, SEEK_CUR);

        // Check if the run finished. If so, emit the final event and stop.
        $r = $db->query(
            "SELECT finished_at, exit_code FROM ansible_runs WHERE run_id = ? LIMIT 1",
            [$run_id]
        )->first();
        if ($r && $r->finished_at !== null) {
            // Drain anything written between the last fgets and the finish row.
            while (($extra = fgets($fp)) !== false) {
                ansible_sse_emit($extra);
            }
            echo "event: end\n";
            echo "data: " . json_encode(['exit_code' => (int) $r->exit_code]) . "\n\n";
            @flush();
            break;
        }
        // Heartbeat every 15s so proxies don't drop the conn.
        if ($wait++ % 15 === 0) {
            echo ": heartbeat\n\n";
            @flush();
        }
        sleep(1);
        continue;
    }
    $wait = 0;
    ansible_sse_emit($line);
}

if ($fp) fclose($fp);
