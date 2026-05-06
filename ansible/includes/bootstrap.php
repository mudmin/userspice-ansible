<?php
// Common bootstrap for every ansible-ui page and parser.
// 1. Loads UserSpice (DB, $user, hasPerm).
// 2. Loads per-install config + composer autoload + helper functions.
// 3. Gates on hasPerm(ANSIBLE_UI_PERM); redirects to login otherwise.

// Resolve the UserSpice webroot from this file's path so the module is portable.
$ansible_ui_root = dirname(__DIR__);                  // /var/www/html/ansible
$webroot         = dirname($ansible_ui_root);          // /var/www/html

require_once $webroot . '/users/init.php';

require_once $ansible_ui_root . '/config.php';
require_once $ansible_ui_root . '/vendor/autoload.php';
require_once $ansible_ui_root . '/includes/helper.php';

// Auth gate. UserSpice's $user is populated by init.php.
if (!isset($user) || !$user->isLoggedIn() || !hasPerm(ANSIBLE_UI_PERM)) {
    Redirect::to($us_url_root . 'users/login.php');
    die();
}
