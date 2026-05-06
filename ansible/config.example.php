<?php
// Per-install configuration for the ansible-ui module.
// Copy to config.php and edit. config.php is gitignored so each deployment
// keeps its own values.

// Filesystem path to the ansible repo (inventory.ini, playbooks, group_vars, host_vars).
// www-data must have read access to everything inside.
define('ANSIBLE_REPO', '/home/ansible/ansible');

// Absolute path to the ansible-playbook / ansible-inventory binaries.
// `which ansible-playbook` from a shell that has the same PATH as PHP-FPM.
define('ANSIBLE_BIN_DIR', '/home/ansible/.local/bin');

// UserSpice permission ID required to use the UI. 2 = admin in stock UserSpice.
define('ANSIBLE_UI_PERM', 2);

// Lock dir for per-target run serialization.
define('ANSIBLE_LOCK_DIR', '/var/lock');

// Optional: shared secret used by run_finish.php to mark runs done.
// Generate once: php -r "echo bin2hex(random_bytes(32)).PHP_EOL;"
define('ANSIBLE_FINISH_SECRET', 'CHANGE_ME_LONG_RANDOM_HEX');
