<?php
// Legacy redirect: the dashboard now lives at /ansible/.
require_once 'users/init.php';
Redirect::to($us_url_root . 'ansible/');
