-- phpMyAdmin SQL Dump
-- version 5.1.1deb5ubuntu1
-- https://www.phpmyadmin.net/
--
-- Host: localhost:3306
-- Generation Time: May 06, 2026 at 01:31 PM
-- Server version: 8.0.45
-- PHP Version: 8.2.30

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `ansible-clean`
--

-- --------------------------------------------------------

--
-- Table structure for table `ansible_runs`
--

CREATE TABLE `ansible_runs` (
  `id` int NOT NULL,
  `run_id` varchar(64) COLLATE utf8mb4_general_ci NOT NULL,
  `user_id` int NOT NULL,
  `playbook` varchar(128) COLLATE utf8mb4_general_ci NOT NULL,
  `target` varchar(128) COLLATE utf8mb4_general_ci NOT NULL,
  `flags` varchar(255) COLLATE utf8mb4_general_ci NOT NULL DEFAULT '',
  `pid` int DEFAULT NULL,
  `started_at` datetime NOT NULL,
  `finished_at` datetime DEFAULT NULL,
  `exit_code` int DEFAULT NULL,
  `log_path` varchar(255) COLLATE utf8mb4_general_ci NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `audit`
--

CREATE TABLE `audit` (
  `id` int NOT NULL,
  `user` int NOT NULL,
  `page` varchar(255) COLLATE utf8mb4_general_ci NOT NULL,
  `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `ip` varchar(255) COLLATE utf8mb4_general_ci NOT NULL,
  `viewed` int NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `crons`
--

CREATE TABLE `crons` (
  `id` int NOT NULL,
  `active` int NOT NULL DEFAULT '1',
  `sort` int NOT NULL,
  `name` varchar(255) COLLATE utf8mb4_general_ci NOT NULL,
  `file` varchar(255) COLLATE utf8mb4_general_ci NOT NULL,
  `createdby` int NOT NULL,
  `created` datetime DEFAULT NULL,
  `modified` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `crons`
--

INSERT INTO `crons` (`id`, `active`, `sort`, `name`, `file`, `createdby`, `created`, `modified`) VALUES
(1, 0, 100, 'Auto-Backup', 'backup.php', 1, '2017-09-16 07:49:22', '2017-11-11 20:15:36');

-- --------------------------------------------------------

--
-- Table structure for table `crons_logs`
--

CREATE TABLE `crons_logs` (
  `id` int NOT NULL,
  `cron_id` int NOT NULL,
  `datetime` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `user_id` int NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `email`
--

CREATE TABLE `email` (
  `id` int NOT NULL,
  `website_name` varchar(100) COLLATE utf8mb4_general_ci NOT NULL,
  `smtp_server` varchar(100) COLLATE utf8mb4_general_ci NOT NULL,
  `smtp_port` int NOT NULL,
  `email_login` varchar(150) COLLATE utf8mb4_general_ci NOT NULL,
  `email_pass` varchar(100) COLLATE utf8mb4_general_ci NOT NULL,
  `from_name` varchar(100) COLLATE utf8mb4_general_ci NOT NULL,
  `from_email` varchar(150) COLLATE utf8mb4_general_ci NOT NULL,
  `transport` varchar(255) COLLATE utf8mb4_general_ci NOT NULL,
  `verify_url` varchar(255) COLLATE utf8mb4_general_ci NOT NULL,
  `email_act` int NOT NULL,
  `debug_level` int NOT NULL DEFAULT '0',
  `isSMTP` int NOT NULL DEFAULT '0',
  `isHTML` varchar(5) COLLATE utf8mb4_general_ci NOT NULL DEFAULT 'true',
  `useSMTPauth` varchar(6) COLLATE utf8mb4_general_ci NOT NULL DEFAULT 'true',
  `authtype` varchar(50) COLLATE utf8mb4_general_ci DEFAULT 'CRAM-MD5'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `email`
--

INSERT INTO `email` (`id`, `website_name`, `smtp_server`, `smtp_port`, `email_login`, `email_pass`, `from_name`, `from_email`, `transport`, `verify_url`, `email_act`, `debug_level`, `isSMTP`, `isHTML`, `useSMTPauth`, `authtype`) VALUES
(1, 'User Spice', 'smtp.gmail.com', 587, 'yourEmail@gmail.com', '1234', 'User Spice', 'yourEmail@gmail.com', 'tls', 'http://localhost/userspice', 0, 0, 1, 'true', 'true', 'CRAM-MD5');

-- --------------------------------------------------------

--
-- Table structure for table `groups_menus`
--

CREATE TABLE `groups_menus` (
  `id` int UNSIGNED NOT NULL,
  `group_id` int UNSIGNED NOT NULL,
  `menu_id` int UNSIGNED NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `groups_menus`
--

INSERT INTO `groups_menus` (`id`, `group_id`, `menu_id`) VALUES
(5, 0, 3),
(6, 0, 1),
(7, 0, 2),
(8, 0, 51),
(9, 0, 52),
(10, 0, 37),
(11, 0, 38),
(12, 2, 39),
(13, 2, 40),
(14, 2, 41),
(15, 2, 42),
(16, 2, 43),
(17, 2, 44),
(18, 2, 45),
(19, 0, 46),
(20, 0, 47),
(21, 0, 49),
(25, 0, 18),
(26, 0, 20),
(27, 0, 21),
(28, 0, 7),
(29, 0, 8),
(30, 2, 9),
(31, 2, 10),
(32, 2, 11),
(33, 2, 12),
(34, 2, 13),
(35, 2, 14),
(36, 2, 15),
(37, 0, 16),
(38, 1, 15);

-- --------------------------------------------------------

--
-- Table structure for table `keys`
--

CREATE TABLE `keys` (
  `id` int NOT NULL,
  `stripe_ts` varchar(255) COLLATE utf8mb4_general_ci NOT NULL,
  `stripe_tp` varchar(255) COLLATE utf8mb4_general_ci NOT NULL,
  `stripe_ls` varchar(255) COLLATE utf8mb4_general_ci NOT NULL,
  `stripe_lp` varchar(255) COLLATE utf8mb4_general_ci NOT NULL,
  `recap_pub` varchar(100) COLLATE utf8mb4_general_ci NOT NULL,
  `recap_pri` varchar(100) COLLATE utf8mb4_general_ci NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `logs`
--

CREATE TABLE `logs` (
  `id` int NOT NULL,
  `user_id` int NOT NULL DEFAULT '0',
  `cloak_from` int DEFAULT NULL,
  `logdate` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `logtype` varchar(25) COLLATE utf8mb4_general_ci NOT NULL,
  `lognote` mediumtext COLLATE utf8mb4_general_ci NOT NULL,
  `ip` varchar(75) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `metadata` blob
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `menus`
--

CREATE TABLE `menus` (
  `id` int NOT NULL,
  `menu_title` varchar(255) COLLATE utf8mb4_general_ci NOT NULL,
  `parent` int NOT NULL,
  `dropdown` int NOT NULL,
  `logged_in` int NOT NULL,
  `display_order` int NOT NULL,
  `label` varchar(255) COLLATE utf8mb4_general_ci NOT NULL,
  `link` varchar(255) COLLATE utf8mb4_general_ci NOT NULL,
  `icon_class` varchar(255) COLLATE utf8mb4_general_ci NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `menus`
--

INSERT INTO `menus` (`id`, `menu_title`, `parent`, `dropdown`, `logged_in`, `display_order`, `label`, `link`, `icon_class`) VALUES
(1, 'main', 2, 0, 1, 1, '{{home}}', '', 'fa fa-fw fa-home'),
(2, 'main', -1, 1, 1, 14, '', '', 'fa fa-fw fa-cogs'),
(3, 'main', -1, 0, 1, 11, '{{username}}', 'users/account.php', 'fa fa-fw fa-user'),
(4, 'main', -1, 1, 0, 3, '{{help}}', '', 'fa fa-fw fa-life-ring'),
(5, 'main', -1, 0, 0, 2, '{{register}}', 'users/join.php', 'fa fa-fw fa-plus-square'),
(6, 'main', -1, 0, 0, 1, '{{login}}', 'users/login.php', 'fa fa-fw fa-sign-in'),
(7, 'main', 2, 0, 1, 2, '{{account}}', 'users/account.php', 'fa fa-fw fa-user'),
(8, 'main', 2, 0, 1, 3, '{{hr}}', '', ''),
(9, 'main', 2, 0, 1, 4, '{{dashboard}}', 'users/admin.php', 'fa fa-fw fa-cogs'),
(10, 'main', 2, 0, 1, 5, '{{users}}', 'users/admin.php?view=users', 'fa fa-fw fa-user'),
(11, 'main', 2, 0, 1, 6, '{{perms}}', 'users/admin.php?view=permissions', 'fa fa-fw fa-lock'),
(12, 'main', 2, 0, 1, 7, '{{pages}}', 'users/admin.php?view=pages', 'fa fa-fw fa-wrench'),
(13, 'main', 2, 0, 1, 9, '{{logs}}', 'users/admin.php?view=logs', 'fa fa-fw fa-search'),
(14, 'main', 2, 0, 1, 10, '{{hr}}', '', ''),
(15, 'main', 2, 0, 1, 11, '{{logout}}', 'users/logout.php', 'fa fa-fw fa-sign-out'),
(16, 'main', -1, 0, 0, 0, '{{home}}', '', 'fa fa-fw fa-home'),
(17, 'main', -1, 0, 1, 10, '{{home}}', '', 'fa fa-fw fa-home'),
(18, 'main', 4, 0, 0, 1, '{{forgot}}', 'users/forgot_password.php', 'fa fa-fw fa-wrench'),
(20, 'main', 4, 0, 0, 99999, '{{resend}}', 'users/verify_resend.php', 'fa fa-exclamation-triangle');

-- --------------------------------------------------------

--
-- Table structure for table `messages`
--

CREATE TABLE `messages` (
  `id` int NOT NULL,
  `msg_from` int NOT NULL,
  `msg_to` int NOT NULL,
  `msg_body` mediumtext COLLATE utf8mb4_general_ci NOT NULL,
  `msg_read` int NOT NULL,
  `msg_thread` int NOT NULL,
  `deleted` int NOT NULL,
  `sent_on` datetime NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `message_threads`
--

CREATE TABLE `message_threads` (
  `id` int NOT NULL,
  `msg_to` int NOT NULL,
  `msg_from` int NOT NULL,
  `msg_subject` varchar(255) COLLATE utf8mb4_general_ci NOT NULL,
  `last_update` datetime NOT NULL,
  `last_update_by` int NOT NULL,
  `archive_from` int NOT NULL DEFAULT '0',
  `archive_to` int NOT NULL DEFAULT '0',
  `hidden_from` int NOT NULL DEFAULT '0',
  `hidden_to` int NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `notifications`
--

CREATE TABLE `notifications` (
  `id` int UNSIGNED NOT NULL,
  `user_id` int NOT NULL,
  `message` longtext COLLATE utf8mb4_general_ci NOT NULL,
  `is_read` tinyint NOT NULL,
  `is_archived` tinyint(1) DEFAULT '0',
  `date_created` datetime DEFAULT NULL,
  `date_read` datetime DEFAULT NULL,
  `last_updated` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `class` varchar(100) COLLATE utf8mb4_general_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `pages`
--

CREATE TABLE `pages` (
  `id` int NOT NULL,
  `page` varchar(255) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `title` varchar(255) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `private` int NOT NULL DEFAULT '0',
  `re_auth` int NOT NULL DEFAULT '0',
  `core` int DEFAULT '0',
  `lang_key` varchar(100) COLLATE utf8mb4_general_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `pages`
--

INSERT INTO `pages` (`id`, `page`, `title`, `private`, `re_auth`, `core`, `lang_key`) VALUES
(1, 'index.php', 'Home', 0, 0, 1, NULL),
(2, 'z_us_root.php', '', 0, 0, 1, NULL),
(3, 'users/account.php', 'Account Dashboard', 1, 0, 1, NULL),
(4, 'users/admin.php', 'Admin Dashboard', 1, 0, 1, NULL),
(14, 'users/forgot_password.php', 'Forgotten Password', 0, 0, 1, NULL),
(15, 'users/forgot_password_reset.php', 'Reset Forgotten Password', 0, 0, 1, NULL),
(16, 'users/index.php', 'Home', 0, 0, 1, NULL),
(17, 'users/init.php', '', 0, 0, 1, NULL),
(18, 'users/join.php', 'Join', 0, 0, 1, NULL),
(20, 'users/login.php', 'Login', 0, 0, 1, NULL),
(21, 'users/logout.php', 'Logout', 0, 0, 1, NULL),
(24, 'users/user_settings.php', 'User Settings', 1, 0, 1, NULL),
(25, 'users/verify.php', 'Account Verification', 0, 0, 1, NULL),
(26, 'users/verify_resend.php', 'Account Verification', 0, 0, 1, NULL),
(45, 'users/maintenance.php', 'Maintenance', 0, 0, 1, NULL),
(68, 'users/update.php', 'Update Manager', 1, 0, 1, NULL),
(81, 'users/admin_pin.php', 'Verification PIN Set', 1, 0, 1, NULL),
(90, 'users/complete.php', NULL, 1, 0, 0, NULL);

-- --------------------------------------------------------

--
-- Table structure for table `permissions`
--

CREATE TABLE `permissions` (
  `id` int NOT NULL,
  `name` varchar(150) COLLATE utf8mb4_general_ci NOT NULL,
  `descrip` varchar(255) COLLATE utf8mb4_general_ci DEFAULT ''
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `permissions`
--

INSERT INTO `permissions` (`id`, `name`, `descrip`) VALUES
(1, 'User', 'Standard User'),
(2, 'Administrator', 'UserSpice Administrator');

-- --------------------------------------------------------

--
-- Table structure for table `permission_page_matches`
--

CREATE TABLE `permission_page_matches` (
  `id` int NOT NULL,
  `permission_id` int DEFAULT NULL,
  `page_id` int DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `permission_page_matches`
--

INSERT INTO `permission_page_matches` (`id`, `permission_id`, `page_id`) VALUES
(3, 1, 24),
(14, 2, 4),
(15, 1, 3),
(38, 2, 68),
(54, 1, 81);

-- --------------------------------------------------------

--
-- Table structure for table `plg_social_logins`
--

CREATE TABLE `plg_social_logins` (
  `id` int NOT NULL,
  `plugin` varchar(50) COLLATE utf8mb4_general_ci NOT NULL,
  `provider` varchar(50) COLLATE utf8mb4_general_ci NOT NULL,
  `enabledsetting` varchar(50) COLLATE utf8mb4_general_ci NOT NULL,
  `image` varchar(255) COLLATE utf8mb4_general_ci NOT NULL,
  `link` varchar(255) COLLATE utf8mb4_general_ci NOT NULL,
  `built_in` tinyint(1) DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `plg_tags`
--

CREATE TABLE `plg_tags` (
  `id` int UNSIGNED NOT NULL,
  `tag` varchar(255) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `descrip` varchar(255) COLLATE utf8mb4_general_ci DEFAULT ''
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `plg_tags_matches`
--

CREATE TABLE `plg_tags_matches` (
  `id` int UNSIGNED NOT NULL,
  `tag_id` int UNSIGNED NOT NULL,
  `tag_name` varchar(255) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `user_id` int UNSIGNED NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `profiles`
--

CREATE TABLE `profiles` (
  `id` int NOT NULL,
  `user_id` int NOT NULL,
  `bio` mediumtext COLLATE utf8mb4_general_ci NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `profiles`
--

INSERT INTO `profiles` (`id`, `user_id`, `bio`) VALUES
(1, 1, '&lt;h1&gt;This is the Admin&#039;s bio.&lt;/h1&gt;'),
(2, 2, 'This is your bio');

-- --------------------------------------------------------

--
-- Table structure for table `settings`
--

CREATE TABLE `settings` (
  `id` int NOT NULL,
  `recaptcha` int NOT NULL DEFAULT '0',
  `force_ssl` int NOT NULL,
  `css_sample` int NOT NULL,
  `site_name` varchar(100) COLLATE utf8mb4_general_ci NOT NULL,
  `language` varchar(15) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `site_offline` int NOT NULL,
  `force_pr` int NOT NULL,
  `glogin` int NOT NULL DEFAULT '0',
  `fblogin` int NOT NULL,
  `gid` text COLLATE utf8mb4_general_ci,
  `gsecret` text COLLATE utf8mb4_general_ci,
  `gredirect` text COLLATE utf8mb4_general_ci,
  `ghome` text COLLATE utf8mb4_general_ci,
  `fbid` text COLLATE utf8mb4_general_ci,
  `fbsecret` text COLLATE utf8mb4_general_ci,
  `fbcallback` text COLLATE utf8mb4_general_ci,
  `graph_ver` text COLLATE utf8mb4_general_ci,
  `finalredir` text COLLATE utf8mb4_general_ci,
  `req_cap` int NOT NULL,
  `req_num` int NOT NULL,
  `min_pw` int NOT NULL,
  `max_pw` int NOT NULL,
  `min_un` int NOT NULL,
  `max_un` int NOT NULL,
  `messaging` int NOT NULL,
  `snooping` int NOT NULL,
  `echouser` int NOT NULL,
  `wys` int NOT NULL,
  `change_un` int NOT NULL,
  `backup_dest` text COLLATE utf8mb4_general_ci,
  `backup_source` text COLLATE utf8mb4_general_ci,
  `backup_table` text COLLATE utf8mb4_general_ci,
  `msg_notification` int NOT NULL,
  `permission_restriction` int NOT NULL,
  `auto_assign_un` int NOT NULL,
  `page_permission_restriction` int NOT NULL,
  `msg_blocked_users` int NOT NULL,
  `msg_default_to` int NOT NULL,
  `notifications` int NOT NULL,
  `notif_daylimit` int NOT NULL,
  `recap_public` text COLLATE utf8mb4_general_ci,
  `recap_private` text COLLATE utf8mb4_general_ci,
  `page_default_private` int NOT NULL,
  `navigation_type` tinyint(1) NOT NULL,
  `copyright` varchar(255) COLLATE utf8mb4_general_ci NOT NULL,
  `custom_settings` int NOT NULL,
  `system_announcement` varchar(255) COLLATE utf8mb4_general_ci NOT NULL,
  `twofa` int DEFAULT '0',
  `force_notif` tinyint(1) DEFAULT NULL,
  `cron_ip` varchar(255) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `registration` tinyint(1) DEFAULT NULL,
  `join_vericode_expiry` int UNSIGNED NOT NULL,
  `reset_vericode_expiry` int UNSIGNED NOT NULL,
  `admin_verify` tinyint(1) NOT NULL,
  `admin_verify_timeout` int NOT NULL,
  `session_manager` tinyint(1) NOT NULL,
  `template` varchar(255) COLLATE utf8mb4_general_ci DEFAULT 'standard',
  `saas` tinyint(1) DEFAULT NULL,
  `redirect_uri_after_login` mediumtext COLLATE utf8mb4_general_ci,
  `show_tos` tinyint(1) DEFAULT '1',
  `default_language` varchar(11) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `allow_language` tinyint(1) DEFAULT NULL,
  `spice_api` varchar(75) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `announce` datetime DEFAULT NULL,
  `bleeding_edge` tinyint(1) DEFAULT '0',
  `err_time` int DEFAULT '15',
  `container_open_class` text COLLATE utf8mb4_general_ci,
  `debug` tinyint(1) DEFAULT '0',
  `widgets` text COLLATE utf8mb4_general_ci,
  `no_passwords` tinyint(1) DEFAULT '0',
  `email_login` tinyint(1) DEFAULT '0',
  `pwl_length` int DEFAULT '5',
  `passkeys` tinyint(1) DEFAULT '0',
  `totp` tinyint(1) DEFAULT '0',
  `oauth_server` tinyint(1) DEFAULT '0',
  `oauth` tinyint(1) DEFAULT '0',
  `behind_reverse_proxy` tinyint(1) DEFAULT '0',
  `max_users_dt` int NOT NULL DEFAULT '2000',
  `social_login_location` tinyint(1) DEFAULT '1'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `settings`
--

INSERT INTO `settings` (`id`, `recaptcha`, `force_ssl`, `css_sample`, `site_name`, `language`, `site_offline`, `force_pr`, `glogin`, `fblogin`, `gid`, `gsecret`, `gredirect`, `ghome`, `fbid`, `fbsecret`, `fbcallback`, `graph_ver`, `finalredir`, `req_cap`, `req_num`, `min_pw`, `max_pw`, `min_un`, `max_un`, `messaging`, `snooping`, `echouser`, `wys`, `change_un`, `backup_dest`, `backup_source`, `backup_table`, `msg_notification`, `permission_restriction`, `auto_assign_un`, `page_permission_restriction`, `msg_blocked_users`, `msg_default_to`, `notifications`, `notif_daylimit`, `recap_public`, `recap_private`, `page_default_private`, `navigation_type`, `copyright`, `custom_settings`, `system_announcement`, `twofa`, `force_notif`, `cron_ip`, `registration`, `join_vericode_expiry`, `reset_vericode_expiry`, `admin_verify`, `admin_verify_timeout`, `session_manager`, `template`, `saas`, `redirect_uri_after_login`, `show_tos`, `default_language`, `allow_language`, `spice_api`, `announce`, `bleeding_edge`, `err_time`, `container_open_class`, `debug`, `widgets`, `no_passwords`, `email_login`, `pwl_length`, `passkeys`, `totp`, `oauth_server`, `oauth`, `behind_reverse_proxy`, `max_users_dt`, `social_login_location`) VALUES
(1, 0, 0, 0, 'UserSpice', 'en', 0, 0, 0, 0, '', '', '', '', '', '', '', '', '', 0, 0, 6, 150, 4, 150, 0, 1, 0, 1, 0, '/', 'everything', '', 0, 0, 0, 0, 0, 1, 0, 7, '6LeIxAcTAAAAAJcZVRqyHh71UMIEGNQ_MXjiZKhI', '6LeIxAcTAAAAAGG-vFI1TnRWxMZNFuojJ4WifJWe', 1, 1, 'UserSpice', 1, '', 0, 0, 'off', 1, 24, 15, 1, 120, 0, 'customizer', NULL, NULL, 1, 'en-US', 0, NULL, '2026-05-06 08:36:03', 0, 15, 'container-fluid', 0, 'settings,misc,tools,plugins,snapshot,active_users,active-users', 0, 0, 6, 0, 0, 0, 0, 0, 0, 1);

-- --------------------------------------------------------

--
-- Table structure for table `updates`
--

CREATE TABLE `updates` (
  `id` int NOT NULL,
  `migration` varchar(15) COLLATE utf8mb4_general_ci NOT NULL,
  `applied_on` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `update_skipped` tinyint(1) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `updates`
--

INSERT INTO `updates` (`id`, `migration`, `applied_on`, `update_skipped`) VALUES
(15, '1XdrInkjV86F', '2018-02-18 22:33:24', NULL),
(16, '3GJYaKcqUtw7', '2018-04-25 16:51:08', NULL),
(17, '3GJYaKcqUtz8', '2018-04-25 16:51:08', NULL),
(18, '69qa8h6E1bzG', '2018-04-25 16:51:08', NULL),
(19, '2XQjsKYJAfn1', '2018-04-25 16:51:08', NULL),
(20, '549DLFeHMNw7', '2018-04-25 16:51:08', NULL),
(21, '4Dgt2XVjgz2x', '2018-04-25 16:51:08', NULL),
(22, 'VLBp32gTWvEo', '2018-04-25 16:51:08', NULL),
(23, 'Q3KlhjdtxE5X', '2018-04-25 16:51:08', NULL),
(24, 'ug5D3pVrNvfS', '2018-04-25 16:51:08', NULL),
(25, '69FbVbv4Jtrz', '2018-04-25 16:51:09', NULL),
(26, '4A6BdJHyvP4a', '2018-04-25 16:51:09', NULL),
(27, '37wvsb5BzymK', '2018-04-25 16:51:09', NULL),
(28, 'c7tZQf926zKq', '2018-04-25 16:51:09', NULL),
(29, 'ockrg4eU33GP', '2018-04-25 16:51:09', NULL),
(30, 'XX4zArPs4tor', '2018-04-25 16:51:09', NULL),
(31, 'pv7r2EHbVvhD', '2018-04-26 00:00:00', NULL),
(32, 'uNT7NpgcBDFD', '2018-04-26 00:00:00', NULL),
(33, 'mS5VtQCZjyJs', '2018-12-11 14:19:16', NULL),
(34, '23rqAv5elJ3G', '2018-12-11 14:19:51', NULL),
(35, 'qPEARSh49fob', '2019-01-01 12:01:01', NULL),
(36, 'FyMYJ2oeGCTX', '2019-01-01 12:01:01', NULL),
(37, 'iit5tHSLatiS', '2019-01-01 12:01:01', NULL),
(38, 'hcA5B3PLhq6E', '2020-07-16 11:27:53', NULL),
(39, 'VNEno3E4zaNz', '2020-07-16 11:27:53', NULL),
(40, '2ZB9mg1l0JXe', '2020-07-16 11:27:53', NULL),
(41, 'B9t6He7qmFXa', '2020-07-16 11:27:53', NULL),
(42, '86FkFVV4TGRg', '2020-07-16 11:27:53', NULL),
(43, 'y4A1Y0u9n2Rt', '2020-07-16 11:27:53', NULL),
(44, 'Tm5xY22MM8eC', '2020-07-16 11:27:53', NULL),
(45, '0YXdrInkjV86F', '2020-07-16 11:27:53', NULL),
(46, '99plgnkjV86', '2020-07-16 11:27:53', NULL),
(47, '0DaShInkjV86', '2020-07-16 11:27:53', NULL),
(48, '0DaShInkjVz1', '2020-07-16 11:27:53', NULL),
(49, 'y4A1Y0u9n2SS', '2020-07-16 11:27:53', NULL),
(50, '0DaShInkjV87', '2020-07-16 11:27:53', NULL),
(51, '0DaShInkjV88', '2020-07-16 11:27:53', NULL),
(52, '2019-09-04a', '2020-07-16 11:27:53', NULL),
(53, '2019-09-05a', '2020-07-16 11:27:53', NULL),
(54, '2019-09-26a', '2020-07-16 11:27:53', NULL),
(55, '2019-11-19a', '2020-07-16 11:27:53', NULL),
(56, '2019-12-28a', '2020-07-16 11:27:53', NULL),
(57, '2020-01-21a', '2020-07-16 11:27:54', NULL),
(58, '2020-03-26a', '2020-07-16 11:27:54', NULL),
(59, '2020-04-17a', '2020-07-16 11:27:54', NULL),
(60, '2020-06-06a', '2020-07-16 11:27:54', NULL),
(61, '2020-06-30a', '2020-07-16 11:27:54', NULL),
(62, '2020-07-01a', '2020-07-16 11:27:54', NULL),
(63, '2020-07-16a', '2020-10-08 01:26:22', NULL),
(64, '2020-07-30a', '2020-10-08 01:26:22', NULL),
(65, '2020-10-06a', '2022-04-15 17:37:11', NULL),
(66, '2020-11-03a', '2022-04-15 17:37:11', NULL),
(67, '2020-11-08a', '2022-04-15 17:37:11', NULL),
(68, '2020-11-10a', '2022-04-15 17:37:11', NULL),
(69, '2020-11-10b', '2022-04-15 17:37:11', NULL),
(70, '2020-12-17a', '2022-04-15 17:37:11', NULL),
(71, '2020-12-28a', '2022-04-15 17:37:11', NULL),
(72, '2021-01-20a', '2022-04-15 17:37:11', NULL),
(73, '2021-02-16a', '2022-04-15 17:37:11', NULL),
(74, '2021-04-14a', '2022-04-15 17:37:11', NULL),
(75, '2021-04-15a', '2022-04-15 17:37:11', NULL),
(76, '2021-05-20a', '2022-04-15 17:37:11', NULL),
(77, '2021-07-11a', '2022-04-15 17:37:11', NULL),
(78, '2021-08-22a', '2022-04-15 17:37:11', NULL),
(79, '2021-08-24a', '2022-04-15 17:37:11', NULL),
(80, '2021-09-25a', '2022-04-15 17:37:11', NULL),
(81, '2021-12-26a', '2022-04-15 17:37:11', NULL),
(82, '2022-05-04a', '2022-12-23 12:05:38', NULL),
(83, '2022-11-06a', '2022-12-23 12:06:38', NULL),
(84, '2022-11-20a', '2022-12-23 12:06:38', NULL),
(85, '2022-12-04a', '2022-12-23 12:06:38', NULL),
(86, '2022-12-22a', '2022-12-23 12:06:38', NULL),
(87, '2022-12-23a', '2022-12-23 12:06:38', NULL),
(88, '2023-01-02a', '2024-09-25 09:30:55', NULL),
(89, '2023-01-03a', '2024-09-25 09:30:55', NULL),
(90, '2023-01-03b', '2024-09-25 09:30:55', NULL),
(91, '2023-01-05a', '2024-09-25 09:30:55', NULL),
(92, '2023-01-07a', '2024-09-25 09:30:55', NULL),
(93, '2023-02-10a', '2024-09-25 09:30:55', NULL),
(94, '2023-05-19a', '2024-09-25 09:30:56', NULL),
(95, '2023-06-29a', '2024-09-25 09:30:56', NULL),
(96, '2023-06-29b', '2024-09-25 09:30:56', NULL),
(97, '2023-11-15a', '2024-09-25 09:30:56', NULL),
(98, '2023-11-17a', '2024-09-25 09:30:56', NULL),
(99, '2024-03-12a', '2024-09-25 09:30:56', NULL),
(100, '2024-03-13a', '2024-09-25 09:30:56', NULL),
(101, '2024-03-14a', '2024-09-25 09:30:56', NULL),
(102, '2024-03-15a', '2024-09-25 09:30:56', NULL),
(103, '2024-03-17a', '2024-09-25 09:30:56', NULL),
(104, '2024-03-17b', '2024-09-25 09:30:56', NULL),
(105, '2024-03-18a', '2024-09-25 09:30:56', NULL),
(106, '2024-03-20a', '2024-09-25 09:30:56', NULL),
(107, '2024-03-22a', '2024-09-25 09:30:56', NULL),
(108, '2024-04-01a', '2024-09-25 09:30:56', NULL),
(109, '2024-04-13a', '2024-09-25 09:30:56', NULL),
(110, '2024-06-24a', '2024-09-25 09:30:56', NULL),
(111, '2024-09-25a', '2025-04-12 10:51:28', NULL),
(112, '2024-11-22a', '2025-04-12 10:51:28', NULL),
(113, '2024-12-16a', '2025-04-12 10:51:28', NULL),
(114, '2024-12-21a', '2025-04-12 10:51:28', NULL),
(115, '2025-02-23a', '2025-04-12 10:51:28', NULL),
(116, '2025-03-02a', '2025-04-12 10:51:28', NULL),
(117, '2025-03-03a', '2025-04-12 10:51:28', NULL),
(118, '2025-04-24a', '2026-05-05 16:44:04', NULL),
(119, '2025-05-27a', '2026-05-05 16:44:04', NULL),
(120, '2025-06-01a', '2026-05-05 16:44:04', NULL),
(121, '2025-06-03a', '2026-05-05 16:44:06', NULL),
(122, '2025-06-14a', '2026-05-05 16:44:06', NULL),
(123, '2025-06-15a', '2026-05-05 16:44:06', NULL),
(124, '2025-06-20a', '2026-05-05 16:44:07', NULL),
(125, '2025-06-21a', '2026-05-05 16:44:07', NULL),
(126, '2025-06-21b', '2026-05-05 16:44:07', NULL),
(127, '2025-06-22a', '2026-05-05 16:44:07', NULL),
(128, '2025-06-24a', '2026-05-05 16:44:08', NULL),
(129, '2025-06-28a', '2026-05-05 16:44:09', NULL),
(130, '2025-07-26a', '2026-05-05 16:44:09', NULL),
(131, '2025-07-30a', '2026-05-05 16:44:09', NULL),
(132, '2025-08-08a', '2026-05-05 16:44:10', NULL),
(133, '2025-08-15a', '2026-05-05 16:44:10', NULL),
(134, '2025-08-22a', '2026-05-05 16:44:10', NULL),
(135, '2025-11-09a', '2026-05-05 16:44:10', NULL),
(136, '2026-01-01a', '2026-05-05 16:44:10', NULL),
(137, '2026-01-04a', '2026-05-05 16:44:10', NULL),
(138, '2026-01-11a', '2026-05-05 16:44:10', NULL),
(139, '2026-01-24a', '2026-05-05 16:44:11', NULL),
(140, '2026-02-28a', '2026-05-05 16:44:11', NULL),
(141, '2026-03-17a', '2026-05-05 16:44:11', NULL);

-- --------------------------------------------------------

--
-- Table structure for table `users`
--

CREATE TABLE `users` (
  `id` int NOT NULL,
  `permissions` tinyint(1) NOT NULL,
  `email` varchar(155) COLLATE utf8mb4_general_ci NOT NULL,
  `email_new` varchar(155) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `username` varchar(255) COLLATE utf8mb4_general_ci NOT NULL,
  `password` varchar(255) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `pin` varchar(255) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `fname` varchar(255) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `lname` varchar(255) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `language` varchar(15) COLLATE utf8mb4_general_ci DEFAULT 'en-US',
  `email_verified` tinyint(1) NOT NULL DEFAULT '0',
  `vericode` text COLLATE utf8mb4_general_ci,
  `vericode_expiry` datetime DEFAULT NULL,
  `oauth_provider` text COLLATE utf8mb4_general_ci,
  `oauth_uid` text COLLATE utf8mb4_general_ci,
  `gender` varchar(10) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `locale` varchar(10) CHARACTER SET utf8mb3 COLLATE utf8mb3_unicode_ci DEFAULT NULL,
  `gpluslink` text COLLATE utf8mb4_general_ci,
  `account_owner` tinyint NOT NULL DEFAULT '1',
  `account_id` int NOT NULL DEFAULT '0',
  `account_mgr` int NOT NULL DEFAULT '0',
  `fb_uid` text COLLATE utf8mb4_general_ci,
  `picture` text COLLATE utf8mb4_general_ci,
  `created` datetime NOT NULL,
  `protected` tinyint(1) NOT NULL DEFAULT '0',
  `msg_exempt` tinyint(1) NOT NULL DEFAULT '0',
  `dev_user` tinyint(1) NOT NULL DEFAULT '0',
  `msg_notification` tinyint(1) NOT NULL DEFAULT '1',
  `cloak_allowed` tinyint(1) NOT NULL DEFAULT '0',
  `oauth_tos_accepted` tinyint(1) DEFAULT NULL,
  `un_changed` tinyint(1) NOT NULL DEFAULT '0',
  `force_pr` tinyint(1) NOT NULL DEFAULT '0',
  `logins` int UNSIGNED NOT NULL DEFAULT '0',
  `last_login` datetime DEFAULT NULL,
  `join_date` datetime DEFAULT NULL,
  `modified` datetime DEFAULT NULL,
  `active` tinyint(1) DEFAULT '1'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `users`
--

INSERT INTO `users` (`id`, `permissions`, `email`, `email_new`, `username`, `password`, `pin`, `fname`, `lname`, `language`, `email_verified`, `vericode`, `vericode_expiry`, `oauth_provider`, `oauth_uid`, `gender`, `locale`, `gpluslink`, `account_owner`, `account_id`, `account_mgr`, `fb_uid`, `picture`, `created`, `protected`, `msg_exempt`, `dev_user`, `msg_notification`, `cloak_allowed`, `oauth_tos_accepted`, `un_changed`, `force_pr`, `logins`, `last_login`, `join_date`, `modified`, `active`) VALUES
(1, 1, 'you@userspice.com', NULL, 'admin', '', NULL, 'Admin', 'User', 'en-US', 1, 's2GiSN9THd7V0Lb', '2022-11-25 05:32:17', '', '', '', '', '', 1, 0, 0, '', '', '0000-00-00 00:00:00', 1, 1, 0, 1, 1, NULL, 0, 0, 5, '2026-05-06 08:36:03', '2026-05-05 16:43:59', '2025-04-12 00:00:00', 1);

-- --------------------------------------------------------

--
-- Table structure for table `users_online`
--

CREATE TABLE `users_online` (
  `id` int NOT NULL,
  `ip` varchar(15) COLLATE utf8mb4_general_ci NOT NULL,
  `timestamp` varchar(15) COLLATE utf8mb4_general_ci NOT NULL,
  `user_id` int DEFAULT NULL,
  `session` varchar(50) COLLATE utf8mb4_general_ci NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `users_session`
--

CREATE TABLE `users_session` (
  `id` int NOT NULL,
  `user_id` int NOT NULL,
  `hash` varchar(255) COLLATE utf8mb4_general_ci NOT NULL,
  `uagent` mediumtext COLLATE utf8mb4_general_ci
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `user_permission_matches`
--

CREATE TABLE `user_permission_matches` (
  `id` int NOT NULL,
  `user_id` int NOT NULL,
  `permission_id` int NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `user_permission_matches`
--

INSERT INTO `user_permission_matches` (`id`, `user_id`, `permission_id`) VALUES
(100, 1, 1),
(101, 1, 2);

-- --------------------------------------------------------

--
-- Table structure for table `us_announcements`
--

CREATE TABLE `us_announcements` (
  `id` int NOT NULL,
  `dismissed` int NOT NULL,
  `link` varchar(255) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `title` varchar(255) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `message` text COLLATE utf8mb4_general_ci,
  `ignore` varchar(50) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `class` varchar(50) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `dismissed_by` int DEFAULT '0',
  `update_announcement` tinyint(1) DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `us_email_logins`
--

CREATE TABLE `us_email_logins` (
  `id` int NOT NULL,
  `user_id` int NOT NULL,
  `vericode` varchar(128) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `success` tinyint(1) DEFAULT '0',
  `login_ip` varchar(50) COLLATE utf8mb4_general_ci NOT NULL,
  `login_date` datetime NOT NULL,
  `expired` tinyint(1) DEFAULT '0',
  `expires` datetime DEFAULT NULL,
  `verification_code` varchar(128) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `invalid_attempts` int DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `us_fingerprints`
--

CREATE TABLE `us_fingerprints` (
  `kFingerprintID` int UNSIGNED NOT NULL,
  `fkUserID` int NOT NULL,
  `Fingerprint` varchar(32) COLLATE utf8mb4_general_ci NOT NULL,
  `Fingerprint_Expiry` datetime NOT NULL,
  `Fingerprint_Added` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `us_fingerprint_assets`
--

CREATE TABLE `us_fingerprint_assets` (
  `kFingerprintAssetID` int UNSIGNED NOT NULL,
  `fkFingerprintID` int NOT NULL,
  `IP_Address` varchar(255) COLLATE utf8mb4_general_ci NOT NULL,
  `User_Browser` varchar(255) COLLATE utf8mb4_general_ci NOT NULL,
  `User_OS` varchar(255) COLLATE utf8mb4_general_ci NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `us_forms`
--

CREATE TABLE `us_forms` (
  `id` int NOT NULL,
  `form` varchar(255) COLLATE utf8mb4_general_ci NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `us_form_validation`
--

CREATE TABLE `us_form_validation` (
  `id` int NOT NULL,
  `value` varchar(255) COLLATE utf8mb4_general_ci NOT NULL,
  `description` varchar(255) COLLATE utf8mb4_general_ci NOT NULL,
  `params` varchar(255) COLLATE utf8mb4_general_ci NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `us_form_validation`
--

INSERT INTO `us_form_validation` (`id`, `value`, `description`, `params`) VALUES
(1, 'min', 'Minimum # of Characters', 'number'),
(2, 'max', 'Maximum # of Characters', 'number'),
(3, 'is_numeric', 'Must be a number', 'true'),
(4, 'valid_email', 'Must be a valid email address', 'true'),
(5, '<', 'Must be a number less than', 'number'),
(6, '>', 'Must be a number greater than', 'number'),
(7, '<=', 'Must be a number less than or equal to', 'number'),
(8, '>=', 'Must be a number greater than or equal to', 'number'),
(9, '!=', 'Must not be equal to', 'text'),
(10, '==', 'Must be equal to', 'text'),
(11, 'is_integer', 'Must be an integer', 'true'),
(12, 'is_timezone', 'Must be a valid timezone name', 'true'),
(13, 'is_datetime', 'Must be a valid DateTime', 'true');

-- --------------------------------------------------------

--
-- Table structure for table `us_form_views`
--

CREATE TABLE `us_form_views` (
  `id` int NOT NULL,
  `form_name` varchar(255) COLLATE utf8mb4_general_ci NOT NULL,
  `view_name` varchar(255) COLLATE utf8mb4_general_ci NOT NULL,
  `fields` mediumtext COLLATE utf8mb4_general_ci NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `us_ip_blacklist`
--

CREATE TABLE `us_ip_blacklist` (
  `id` int NOT NULL,
  `ip` varchar(50) COLLATE utf8mb4_general_ci NOT NULL,
  `last_user` int NOT NULL DEFAULT '0',
  `reason` int NOT NULL DEFAULT '0',
  `expires` datetime DEFAULT NULL,
  `descrip` varchar(255) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `added_by` int DEFAULT NULL,
  `added_on` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `us_ip_list`
--

CREATE TABLE `us_ip_list` (
  `id` int NOT NULL,
  `ip` varchar(50) COLLATE utf8mb4_general_ci NOT NULL,
  `user_id` int NOT NULL,
  `timestamp` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `us_ip_list`
--

INSERT INTO `us_ip_list` (`id`, `ip`, `user_id`, `timestamp`) VALUES
(2, '::1', 1, '2026-05-05 14:02:43'),
(3, '', 1, '2026-05-06 08:36:03');

-- --------------------------------------------------------

--
-- Table structure for table `us_ip_whitelist`
--

CREATE TABLE `us_ip_whitelist` (
  `id` int NOT NULL,
  `ip` varchar(50) COLLATE utf8mb4_general_ci NOT NULL,
  `descrip` varchar(255) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `added_by` int DEFAULT NULL,
  `added_on` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `us_login_fails`
--

CREATE TABLE `us_login_fails` (
  `id` int NOT NULL,
  `login_method` varchar(50) COLLATE utf8mb4_general_ci NOT NULL,
  `ip` varchar(50) COLLATE utf8mb4_general_ci NOT NULL,
  `ts` datetime NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `us_management`
--

CREATE TABLE `us_management` (
  `id` int NOT NULL,
  `page` varchar(255) COLLATE utf8mb4_general_ci NOT NULL,
  `view` varchar(255) COLLATE utf8mb4_general_ci NOT NULL,
  `feature` varchar(255) COLLATE utf8mb4_general_ci NOT NULL,
  `access` varchar(255) COLLATE utf8mb4_general_ci NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `us_management`
--

INSERT INTO `us_management` (`id`, `page`, `view`, `feature`, `access`) VALUES
(1, '_admin_manage_ip.php', 'ip', 'IP Whitelist/Blacklist', ''),
(2, '_admin_nav.php', 'nav', 'Navigation [List/Add/Delete]', ''),
(3, '_admin_nav_item.php', 'nav_item', 'Navigation [View/Edit]', ''),
(4, '_admin_pages.php', 'pages', 'Page Management [List]', ''),
(5, '_admin_page.php', 'page', 'Page Management [View/Edit]', ''),
(6, '_admin_security_logs.php', 'security_logs', 'Security Logs', ''),
(7, '_admin_templates.php', 'templates', 'Templates', ''),
(8, '_admin_tools_check_updates.php', 'updates', 'Check Updates', ''),
(16, '_admin_menus.php', 'menus', 'Manage UltraMenu', ''),
(17, '_admin_logs.php', 'logs', 'System Logs', '');

-- --------------------------------------------------------

--
-- Table structure for table `us_menus`
--

CREATE TABLE `us_menus` (
  `id` int UNSIGNED NOT NULL,
  `menu_name` varchar(255) DEFAULT NULL,
  `type` varchar(75) DEFAULT NULL,
  `nav_class` varchar(255) DEFAULT NULL,
  `theme` varchar(25) DEFAULT NULL,
  `z_index` int DEFAULT NULL,
  `brand_html` text,
  `disabled` tinyint(1) DEFAULT '0',
  `justify` varchar(10) DEFAULT 'right',
  `show_active` tinyint(1) DEFAULT '0',
  `screen_reader_mode` tinyint(1) DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

--
-- Dumping data for table `us_menus`
--

INSERT INTO `us_menus` (`id`, `menu_name`, `type`, `nav_class`, `theme`, `z_index`, `brand_html`, `disabled`, `justify`, `show_active`, `screen_reader_mode`) VALUES
(1, 'Main Menu', 'horizontal', '', 'dark', 50, '&lt;a href=&quot;{{root}}&quot; &gt;\r\n&lt;img src=&quot;{{root}}users/images/logo.png&quot; /&gt;', 0, 'right', 0, 0),
(2, 'Dashboard Menu', 'horizontal', NULL, 'dark', 55, '&lt;a href=&quot;{{root}}&quot; title=&quot;Home Page&quot;&gt;\r\n&lt;img src=&quot;{{root}}users/images/logo.png&quot; alt=&quot;Main logo&quot; /&gt;&lt;/a&gt;', 0, 'right', 0, 0);

-- --------------------------------------------------------

--
-- Table structure for table `us_menu_items`
--

CREATE TABLE `us_menu_items` (
  `id` int UNSIGNED NOT NULL,
  `menu` int UNSIGNED NOT NULL,
  `type` varchar(50) DEFAULT NULL,
  `label` varchar(255) DEFAULT NULL,
  `link` text,
  `icon_class` varchar(255) DEFAULT NULL,
  `li_class` varchar(255) DEFAULT NULL,
  `a_class` varchar(255) DEFAULT NULL,
  `link_target` varchar(50) DEFAULT NULL,
  `parent` int DEFAULT NULL,
  `display_order` int DEFAULT NULL,
  `disabled` tinyint(1) DEFAULT '0',
  `permissions` varchar(1000) DEFAULT NULL,
  `tags` varchar(1000) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

--
-- Dumping data for table `us_menu_items`
--

INSERT INTO `us_menu_items` (`id`, `menu`, `type`, `label`, `link`, `icon_class`, `li_class`, `a_class`, `link_target`, `parent`, `display_order`, `disabled`, `permissions`, `tags`) VALUES
(1, 1, 'dropdown', '', '', 'fa fa-cogs', NULL, NULL, '_self', 0, 14, 0, '[1]', NULL),
(2, 1, 'link', '{{LOGGED_IN_USERNAME}}', 'users/account.php', 'fa fa-user', NULL, NULL, '_self', 0, 11, 0, '[1]', NULL),
(3, 1, 'dropdown', '{{MENU_HELP}}', '', 'fa fa-life-ring', NULL, NULL, '_self', 0, 3, 0, '[0]', NULL),
(4, 1, 'link', '{{SIGNUP_TEXT}}', 'users/join.php', 'fa fa-plus-square', NULL, NULL, '_self', 0, 2, 0, '[0]', NULL),
(5, 1, 'link', '{{SIGNIN_BUTTONTEXT}}', 'users/login.php', 'fa fa-sign-in', NULL, NULL, '_self', 0, 1, 0, '[0]', NULL),
(6, 1, 'link', '{{MENU_HOME}}', '', 'fa fa-home', NULL, NULL, '_self', 0, 0, 0, '[0]', NULL),
(7, 1, 'link', '{{MENU_HOME}}', '', 'fa fa-home', NULL, NULL, '_self', 0, 10, 0, '[]', NULL),
(8, 1, 'link', '{{MENU_HOME}}', '', 'fa fa-home', NULL, NULL, '_self', 1, 1, 0, '[1]', NULL),
(9, 1, 'link', '{{MENU_ACCOUNT}}', 'users/account.php', 'fa fa-user', NULL, NULL, '_self', 1, 2, 0, '[1]', NULL),
(10, 1, 'separator', '', '', '', NULL, NULL, '_self', 1, 3, 0, '[1]', NULL),
(11, 1, 'link', '{{MENU_DASH}}', 'users/admin.php', 'fa fa-cogs', NULL, NULL, '_self', 1, 4, 0, '[2]', NULL),
(12, 1, 'link', '{{MENU_USER_MGR}}', 'users/admin.php?view=users', 'fa fa-user', NULL, NULL, '_self', 1, 5, 0, '[2]', NULL),
(13, 1, 'link', '{{MENU_PERM_MGR}}', 'users/admin.php?view=permissions', 'fa fa-lock', NULL, NULL, '_self', 1, 6, 0, '[2]', NULL),
(14, 1, 'link', '{{MENU_PAGE_MGR}}', 'users/admin.php?view=pages', 'fa fa-wrench', NULL, NULL, '_self', 1, 7, 0, '[2]', NULL),
(15, 1, 'link', '{{MENU_LOGS_MGR}}', 'users/admin.php?view=logs', 'fa fa-search', NULL, NULL, '_self', 1, 9, 0, '[2]', NULL),
(16, 1, 'separator', '', '', '', NULL, NULL, '_self', 1, 10, 0, '[2]', NULL),
(17, 1, 'link', '{{MENU_LOGOUT}}', 'users/logout.php', 'fa fa-sign-out', NULL, NULL, '_self', 1, 11, 0, '[2,1]', NULL),
(18, 1, 'link', '{{SIGNIN_FORGOTPASS}}', 'users/forgot_password.php', 'fa fa-wrench', NULL, NULL, '_self', 3, 1, 0, '[0]', NULL),
(19, 1, 'link', '{{VER_RESEND}}', 'users/verify_resend.php', 'fa fa-exclamation-triangle', NULL, NULL, '_self', 3, 99999, 0, '[0]', NULL),
(45, 2, 'dropdown', 'Tools', '', 'fa fa-wrench', '', '', '_self', 0, 3, 0, '[2]', NULL),
(46, 2, 'link', 'User Manager', 'users/admin.php?view=users', 'fa fa-user', NULL, NULL, NULL, 45, 15, 0, '[2]', NULL),
(47, 2, 'link', 'Bug Report', 'users/admin.php?view=bugs', 'fa fa-bug', NULL, NULL, NULL, 45, 1, 0, '[2]', NULL),
(48, 2, 'link', 'IP Manager', 'users/admin.php?view=ip', 'fa fa-warning', NULL, NULL, NULL, 45, 3, 0, '[0]', NULL),
(49, 2, 'link', 'Cron Jobs', 'users/admin.php?view=cron', 'fa fa-terminal', NULL, NULL, NULL, 45, 2, 0, '[2]', NULL),
(50, 2, 'link', 'Security Logs', 'users/admin.php?view=security_logs', 'fa fa-lock', NULL, NULL, NULL, 45, 9, 0, '[2]', NULL),
(51, 2, 'link', 'System Logs', 'users/admin.php?view=logs', 'fa fa-list-ol', NULL, NULL, NULL, 45, 10, 0, '[2]', NULL),
(52, 2, 'link', 'Templates', 'users/admin.php?view=templates', 'fa fa-eye', NULL, NULL, NULL, 45, 11, 0, '[2]', NULL),
(53, 2, 'link', 'Updates', 'users/admin.php?view=updates', 'fa fa-arrow-circle-o-up', NULL, NULL, NULL, 45, 12, 0, '[2]', NULL),
(54, 2, 'link', 'Page Manager', 'users/admin.php?view=pages', 'fa fa-file', NULL, NULL, NULL, 45, 7, 0, '[2]', NULL),
(55, 2, 'link', 'Permissions', 'users/admin.php?view=permissions', 'fa fa-unlock-alt', NULL, NULL, NULL, 45, 8, 0, '[2]', NULL),
(56, 2, 'dropdown', 'Settings', '', 'fa fa-gear', '', '', '_self', 0, 4, 0, '[2]', NULL),
(57, 2, 'link', 'General', 'users/admin.php?view=general', 'fa fa-check', NULL, NULL, NULL, 56, 1, 0, '[2]', NULL),
(58, 2, 'link', 'Registration', 'users/admin.php?view=reg', 'fa fa-users', NULL, NULL, NULL, 56, 2, 0, '[2]', NULL),
(59, 2, 'link', 'Email', 'users/admin.php?view=email', 'fa fa-envelope', NULL, NULL, NULL, 56, 3, 0, '[0]', NULL),
(60, 2, 'link', 'Navigation (Classic)', 'users/admin.php?view=nav', 'fa fa-rocket', NULL, NULL, NULL, 56, 4, 0, '[2]', NULL),
(61, 2, 'link', 'UltraMenu', 'users/admin.php?view=menus', 'fa fa-lock', NULL, NULL, NULL, 56, 5, 0, '[2]', NULL),
(62, 2, 'link', 'Dashboard Access', 'users/admin.php?view=access', 'fa fa-file-code-o', NULL, NULL, NULL, 56, 5, 0, '[2]', NULL),
(63, 2, 'dropdown', 'Plugins', '#', 'fa fa-plug', '', '', '_self', 0, 5, 0, '[2]', NULL),
(64, 2, 'snippet', 'All Plugins', 'users/includes/menu_hooks/plugins.php', '', NULL, NULL, NULL, 63, 2, 0, '[2]', NULL),
(65, 2, 'link', 'Plugin Manager', 'users/admin.php?view=plugins', 'fa fa-puzzle-piece', NULL, NULL, NULL, 63, 1, 0, '[2]', NULL),
(66, 2, 'link', 'Spice Shaker', 'users/admin.php?view=spice', 'fa fa-user-secret', '', '', '_self', 0, 2, 0, '[2]', NULL),
(67, 2, 'link', 'Home', '#', 'fa fa-home', '', '', '_self', 0, 1, 0, '[2]', NULL),
(68, 2, 'link', 'Dashboard', 'users/admin.php', 'fa-solid fa-desktop', '', '', '_self', 0, 1, 0, '[2]', NULL);

-- --------------------------------------------------------

--
-- Table structure for table `us_oauth_client_logins`
--

CREATE TABLE `us_oauth_client_logins` (
  `id` int NOT NULL,
  `user_id` int DEFAULT NULL,
  `new_user` tinyint(1) DEFAULT '0',
  `ts` datetime DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `us_oauth_client_login_options`
--

CREATE TABLE `us_oauth_client_login_options` (
  `id` int NOT NULL,
  `oauth` tinyint(1) DEFAULT '0',
  `client_name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT 'UserSpice Login',
  `client_icon` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT 'oauth.png',
  `client_id` varchar(80) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `client_secret` varchar(80) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `redirect_uri` varchar(200) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `server_url` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `server_target` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT 'users/auth/',
  `login_title` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT 'UserSpice',
  `login_script` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT 'default_script.php',
  `response_secret` varchar(64) COLLATE utf8mb4_unicode_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `us_oauth_client_login_tokens`
--

CREATE TABLE `us_oauth_client_login_tokens` (
  `id` int NOT NULL,
  `user_id` int DEFAULT NULL,
  `access_token` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `refresh_token` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `expires_at` datetime NOT NULL,
  `scope` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `us_oauth_server_clients`
--

CREATE TABLE `us_oauth_server_clients` (
  `id` int NOT NULL,
  `client_name` varchar(80) COLLATE utf8mb4_unicode_ci NOT NULL,
  `client_description` varchar(200) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `client_enabled` tinyint(1) DEFAULT '1',
  `client_id` varchar(80) COLLATE utf8mb4_unicode_ci NOT NULL,
  `client_secret` varchar(80) COLLATE utf8mb4_unicode_ci NOT NULL,
  `redirect_uri` varchar(200) COLLATE utf8mb4_unicode_ci NOT NULL,
  `ip_restrict` varchar(200) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `login_title` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT 'Login with UserSpice',
  `login_form` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT 'default_login.php',
  `login_script` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT 'default_script.php',
  `response_secret` varchar(64) COLLATE utf8mb4_unicode_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `us_oauth_server_codes`
--

CREATE TABLE `us_oauth_server_codes` (
  `id` int NOT NULL,
  `client_id` int DEFAULT NULL,
  `user_id` int DEFAULT NULL,
  `auth_code` varchar(80) COLLATE utf8mb4_unicode_ci NOT NULL,
  `expires_at` datetime NOT NULL,
  `used` tinyint(1) DEFAULT '0',
  `redirect_uri` tinyint(1) DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `us_oauth_server_settings`
--

CREATE TABLE `us_oauth_server_settings` (
  `id` int NOT NULL,
  `other_columns` text COLLATE utf8mb4_unicode_ci,
  `include_tags` tinyint(1) DEFAULT '1'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `us_oauth_server_settings`
--

INSERT INTO `us_oauth_server_settings` (`id`, `other_columns`, `include_tags`) VALUES
(1, 'language,created', 1);

-- --------------------------------------------------------

--
-- Table structure for table `us_oauth_server_tokens`
--

CREATE TABLE `us_oauth_server_tokens` (
  `id` int NOT NULL,
  `client_id` int DEFAULT NULL,
  `user_id` int DEFAULT NULL,
  `access_token` varchar(80) COLLATE utf8mb4_unicode_ci NOT NULL,
  `refresh_token` varchar(80) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `expires_at` datetime NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `us_passkeys`
--

CREATE TABLE `us_passkeys` (
  `id` int UNSIGNED NOT NULL,
  `user_id` int DEFAULT '0',
  `credential_id` varbinary(255) DEFAULT NULL,
  `credential_public_key` blob,
  `created` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `times_used` int DEFAULT '0',
  `last_used` timestamp NULL DEFAULT NULL,
  `last_ip` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `passkey_note` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `user_handle` varbinary(64) DEFAULT NULL,
  `transports` text COLLATE utf8mb4_unicode_ci,
  `attestation_type` varchar(32) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `trust_path` text COLLATE utf8mb4_unicode_ci,
  `aaguid` varchar(36) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `signature_counter` bigint UNSIGNED DEFAULT '0',
  `other_ui_data` text COLLATE utf8mb4_unicode_ci
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `us_password_strength`
--

CREATE TABLE `us_password_strength` (
  `id` int NOT NULL,
  `enforce_rules` tinyint(1) DEFAULT '0',
  `meter_active` tinyint(1) DEFAULT '0',
  `min_length` int DEFAULT '8',
  `max_length` int DEFAULT '24',
  `require_lowercase` tinyint(1) DEFAULT '1',
  `require_uppercase` tinyint(1) DEFAULT '1',
  `require_numbers` tinyint(1) DEFAULT '1',
  `require_symbols` tinyint(1) DEFAULT '1',
  `min_score` int DEFAULT '5',
  `uppercase_score` int NOT NULL DEFAULT '6',
  `lowercase_score` int NOT NULL DEFAULT '6',
  `number_score` int NOT NULL DEFAULT '6',
  `symbol_score` int NOT NULL DEFAULT '11',
  `greater_eight` int NOT NULL DEFAULT '15',
  `greater_twelve` int NOT NULL DEFAULT '28',
  `greater_sixteen` int NOT NULL DEFAULT '40'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `us_password_strength`
--

INSERT INTO `us_password_strength` (`id`, `enforce_rules`, `meter_active`, `min_length`, `max_length`, `require_lowercase`, `require_uppercase`, `require_numbers`, `require_symbols`, `min_score`, `uppercase_score`, `lowercase_score`, `number_score`, `symbol_score`, `greater_eight`, `greater_twelve`, `greater_sixteen`) VALUES
(1, 0, 1, 10, 150, 1, 1, 1, 1, 75, 6, 6, 6, 11, 15, 28, 40);

-- --------------------------------------------------------

--
-- Table structure for table `us_php_eol`
--

CREATE TABLE `us_php_eol` (
  `id` int NOT NULL,
  `release_version` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL,
  `eol_date` date NOT NULL,
  `last_checked` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `us_php_eol`
--

INSERT INTO `us_php_eol` (`id`, `release_version`, `eol_date`, `last_checked`) VALUES
(1, '8.4', '2028-12-31', '2026-05-06 12:36:04'),
(2, '8.3', '2027-12-31', '2026-05-06 12:36:04'),
(3, '8.2', '2026-12-31', '2026-05-06 12:36:04'),
(4, '8.1', '2025-12-31', '2026-05-06 12:36:04'),
(5, '8.0', '2023-11-26', '2026-05-06 12:36:04'),
(6, '7.4', '2022-11-28', '2026-05-06 12:36:04'),
(7, '7.3', '2021-12-06', '2026-05-06 12:36:04'),
(8, '7.2', '2020-11-30', '2026-05-06 12:36:04'),
(9, '7.1', '2019-12-01', '2026-05-06 12:36:04'),
(10, '7.0', '2019-01-10', '2026-05-06 12:36:04'),
(11, '5.6', '2018-12-31', '2026-05-06 12:36:04');

-- --------------------------------------------------------

--
-- Table structure for table `us_php_known_bad`
--

CREATE TABLE `us_php_known_bad` (
  `id` int NOT NULL,
  `version` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL,
  `last_checked` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `us_php_known_bad`
--

INSERT INTO `us_php_known_bad` (`id`, `version`, `last_checked`) VALUES
(1, '5.6.1', '2026-05-06 12:36:04');

-- --------------------------------------------------------

--
-- Table structure for table `us_plugins`
--

CREATE TABLE `us_plugins` (
  `id` int NOT NULL,
  `plugin` varchar(255) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `status` varchar(255) COLLATE utf8mb4_general_ci DEFAULT NULL,
  `updates` mediumtext COLLATE utf8mb4_general_ci,
  `last_check` datetime DEFAULT '2020-01-01 00:00:00'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `us_plugin_hooks`
--

CREATE TABLE `us_plugin_hooks` (
  `id` int UNSIGNED NOT NULL,
  `page` varchar(255) COLLATE utf8mb4_general_ci NOT NULL,
  `folder` varchar(255) COLLATE utf8mb4_general_ci NOT NULL,
  `position` varchar(255) COLLATE utf8mb4_general_ci NOT NULL,
  `hook` varchar(255) COLLATE utf8mb4_general_ci NOT NULL,
  `disabled` tinyint(1) DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data for table `us_plugin_hooks`
--

INSERT INTO `us_plugin_hooks` (`id`, `page`, `folder`, `position`, `hook`, `disabled`) VALUES
(1, 'admin.php?view=user', 'userspice_core', 'form', 'hooks/tags_admin_user_form.php', 0),
(2, 'admin.php?view=user', 'userspice_core', 'post', 'hooks/tags_admin_user_post.php', 0);

-- --------------------------------------------------------

--
-- Table structure for table `us_rate_limits`
--

CREATE TABLE `us_rate_limits` (
  `id` int NOT NULL,
  `identifier_key` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `action` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `success` tinyint(1) DEFAULT '0',
  `attempt_time` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `metadata` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin
) ;

-- --------------------------------------------------------

--
-- Table structure for table `us_rate_limit_proxy_settings`
--

CREATE TABLE `us_rate_limit_proxy_settings` (
  `id` int NOT NULL,
  `proxy_ip` varchar(45) COLLATE utf8mb4_unicode_ci NOT NULL,
  `header_name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `header` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `priority` int DEFAULT '0',
  `enabled` tinyint(1) DEFAULT '1',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `us_saas_levels`
--

CREATE TABLE `us_saas_levels` (
  `id` int NOT NULL,
  `level` varchar(255) COLLATE utf8mb4_general_ci NOT NULL,
  `users` int NOT NULL,
  `details` mediumtext COLLATE utf8mb4_general_ci NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `us_saas_orgs`
--

CREATE TABLE `us_saas_orgs` (
  `id` int NOT NULL,
  `org` varchar(255) COLLATE utf8mb4_general_ci NOT NULL,
  `owner` int NOT NULL,
  `level` int NOT NULL,
  `active` int NOT NULL DEFAULT '1'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `us_totp_secrets`
--

CREATE TABLE `us_totp_secrets` (
  `id` int NOT NULL,
  `user_id` int NOT NULL,
  `secret_enc` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `backup_codes_h` text COLLATE utf8mb4_unicode_ci,
  `verified` tinyint(1) NOT NULL DEFAULT '0',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `us_user_sessions`
--

CREATE TABLE `us_user_sessions` (
  `kUserSessionID` int UNSIGNED NOT NULL,
  `fkUserID` int UNSIGNED NOT NULL,
  `UserFingerprint` varchar(255) COLLATE utf8mb4_general_ci NOT NULL,
  `UserSessionIP` varchar(255) COLLATE utf8mb4_general_ci NOT NULL,
  `UserSessionOS` varchar(255) COLLATE utf8mb4_general_ci NOT NULL,
  `UserSessionBrowser` varchar(255) COLLATE utf8mb4_general_ci NOT NULL,
  `UserSessionStarted` datetime NOT NULL,
  `UserSessionLastUsed` datetime DEFAULT NULL,
  `UserSessionLastPage` varchar(255) COLLATE utf8mb4_general_ci NOT NULL,
  `UserSessionEnded` tinyint(1) NOT NULL DEFAULT '0',
  `UserSessionEnded_Time` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `us_versions`
--

CREATE TABLE `us_versions` (
  `id` int NOT NULL,
  `release_version` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `bleeding_edge` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `experimental` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `us_versions`
--

INSERT INTO `us_versions` (`id`, `release_version`, `bleeding_edge`, `experimental`) VALUES
(1, '6.0.8', '6.0.8', '6.0.8');

--
-- Indexes for dumped tables
--

--
-- Indexes for table `ansible_runs`
--
ALTER TABLE `ansible_runs`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `run_id` (`run_id`),
  ADD KEY `user_id` (`user_id`),
  ADD KEY `started_at` (`started_at`);

--
-- Indexes for table `audit`
--
ALTER TABLE `audit`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `crons`
--
ALTER TABLE `crons`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `crons_logs`
--
ALTER TABLE `crons_logs`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `email`
--
ALTER TABLE `email`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `groups_menus`
--
ALTER TABLE `groups_menus`
  ADD PRIMARY KEY (`id`),
  ADD KEY `group_id` (`group_id`),
  ADD KEY `menu_id` (`menu_id`);

--
-- Indexes for table `keys`
--
ALTER TABLE `keys`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `logs`
--
ALTER TABLE `logs`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `menus`
--
ALTER TABLE `menus`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `messages`
--
ALTER TABLE `messages`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `message_threads`
--
ALTER TABLE `message_threads`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `notifications`
--
ALTER TABLE `notifications`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `pages`
--
ALTER TABLE `pages`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_page` (`page`);

--
-- Indexes for table `permissions`
--
ALTER TABLE `permissions`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `permission_page_matches`
--
ALTER TABLE `permission_page_matches`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `plg_social_logins`
--
ALTER TABLE `plg_social_logins`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `plg_tags`
--
ALTER TABLE `plg_tags`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `plg_tags_matches`
--
ALTER TABLE `plg_tags_matches`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `profiles`
--
ALTER TABLE `profiles`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `settings`
--
ALTER TABLE `settings`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `updates`
--
ALTER TABLE `updates`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`id`),
  ADD KEY `EMAIL` (`email`) USING BTREE;

--
-- Indexes for table `users_online`
--
ALTER TABLE `users_online`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `users_session`
--
ALTER TABLE `users_session`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `user_permission_matches`
--
ALTER TABLE `user_permission_matches`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_user_id` (`user_id`);

--
-- Indexes for table `us_announcements`
--
ALTER TABLE `us_announcements`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `us_email_logins`
--
ALTER TABLE `us_email_logins`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `us_fingerprints`
--
ALTER TABLE `us_fingerprints`
  ADD PRIMARY KEY (`kFingerprintID`);

--
-- Indexes for table `us_fingerprint_assets`
--
ALTER TABLE `us_fingerprint_assets`
  ADD PRIMARY KEY (`kFingerprintAssetID`);

--
-- Indexes for table `us_forms`
--
ALTER TABLE `us_forms`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `us_form_validation`
--
ALTER TABLE `us_form_validation`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `us_form_views`
--
ALTER TABLE `us_form_views`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `us_ip_blacklist`
--
ALTER TABLE `us_ip_blacklist`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_ip` (`ip`);

--
-- Indexes for table `us_ip_list`
--
ALTER TABLE `us_ip_list`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `us_ip_whitelist`
--
ALTER TABLE `us_ip_whitelist`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `us_login_fails`
--
ALTER TABLE `us_login_fails`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `us_management`
--
ALTER TABLE `us_management`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `us_menus`
--
ALTER TABLE `us_menus`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `us_menu_items`
--
ALTER TABLE `us_menu_items`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `us_oauth_client_logins`
--
ALTER TABLE `us_oauth_client_logins`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `us_oauth_client_login_options`
--
ALTER TABLE `us_oauth_client_login_options`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `client_id` (`client_id`),
  ADD UNIQUE KEY `client_secret` (`client_secret`);

--
-- Indexes for table `us_oauth_client_login_tokens`
--
ALTER TABLE `us_oauth_client_login_tokens`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `us_oauth_server_clients`
--
ALTER TABLE `us_oauth_server_clients`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `client_id` (`client_id`),
  ADD UNIQUE KEY `client_secret` (`client_secret`);

--
-- Indexes for table `us_oauth_server_codes`
--
ALTER TABLE `us_oauth_server_codes`
  ADD PRIMARY KEY (`id`),
  ADD KEY `auth_code` (`auth_code`);

--
-- Indexes for table `us_oauth_server_settings`
--
ALTER TABLE `us_oauth_server_settings`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `us_oauth_server_tokens`
--
ALTER TABLE `us_oauth_server_tokens`
  ADD PRIMARY KEY (`id`),
  ADD KEY `access_token` (`access_token`);

--
-- Indexes for table `us_passkeys`
--
ALTER TABLE `us_passkeys`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uidx_credential_id` (`credential_id`),
  ADD KEY `idx_user_id` (`user_id`);

--
-- Indexes for table `us_password_strength`
--
ALTER TABLE `us_password_strength`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `us_php_eol`
--
ALTER TABLE `us_php_eol`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `idx_release_version` (`release_version`);

--
-- Indexes for table `us_php_known_bad`
--
ALTER TABLE `us_php_known_bad`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `idx_version` (`version`);

--
-- Indexes for table `us_plugins`
--
ALTER TABLE `us_plugins`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `us_plugin_hooks`
--
ALTER TABLE `us_plugin_hooks`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `us_rate_limits`
--
ALTER TABLE `us_rate_limits`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_identifier_action` (`identifier_key`,`action`),
  ADD KEY `idx_attempt_time` (`attempt_time`),
  ADD KEY `idx_cleanup` (`attempt_time`,`success`);

--
-- Indexes for table `us_rate_limit_proxy_settings`
--
ALTER TABLE `us_rate_limit_proxy_settings`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_proxy_ip` (`proxy_ip`),
  ADD KEY `idx_header_name` (`header_name`),
  ADD KEY `idx_enabled_priority` (`enabled`,`priority`);

--
-- Indexes for table `us_saas_levels`
--
ALTER TABLE `us_saas_levels`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `us_saas_orgs`
--
ALTER TABLE `us_saas_orgs`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `us_totp_secrets`
--
ALTER TABLE `us_totp_secrets`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `user_id` (`user_id`);

--
-- Indexes for table `us_user_sessions`
--
ALTER TABLE `us_user_sessions`
  ADD PRIMARY KEY (`kUserSessionID`);

--
-- Indexes for table `us_versions`
--
ALTER TABLE `us_versions`
  ADD PRIMARY KEY (`id`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `ansible_runs`
--
ALTER TABLE `ansible_runs`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `audit`
--
ALTER TABLE `audit`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `crons`
--
ALTER TABLE `crons`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `crons_logs`
--
ALTER TABLE `crons_logs`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `email`
--
ALTER TABLE `email`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `groups_menus`
--
ALTER TABLE `groups_menus`
  MODIFY `id` int UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=39;

--
-- AUTO_INCREMENT for table `keys`
--
ALTER TABLE `keys`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `logs`
--
ALTER TABLE `logs`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=84;

--
-- AUTO_INCREMENT for table `menus`
--
ALTER TABLE `menus`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=23;

--
-- AUTO_INCREMENT for table `messages`
--
ALTER TABLE `messages`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `message_threads`
--
ALTER TABLE `message_threads`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `notifications`
--
ALTER TABLE `notifications`
  MODIFY `id` int UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `pages`
--
ALTER TABLE `pages`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=91;

--
-- AUTO_INCREMENT for table `permissions`
--
ALTER TABLE `permissions`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `permission_page_matches`
--
ALTER TABLE `permission_page_matches`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=58;

--
-- AUTO_INCREMENT for table `plg_social_logins`
--
ALTER TABLE `plg_social_logins`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `plg_tags`
--
ALTER TABLE `plg_tags`
  MODIFY `id` int UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `plg_tags_matches`
--
ALTER TABLE `plg_tags_matches`
  MODIFY `id` int UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `profiles`
--
ALTER TABLE `profiles`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=11;

--
-- AUTO_INCREMENT for table `settings`
--
ALTER TABLE `settings`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `updates`
--
ALTER TABLE `updates`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=142;

--
-- AUTO_INCREMENT for table `users`
--
ALTER TABLE `users`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `users_session`
--
ALTER TABLE `users_session`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `user_permission_matches`
--
ALTER TABLE `user_permission_matches`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=111;

--
-- AUTO_INCREMENT for table `us_announcements`
--
ALTER TABLE `us_announcements`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `us_email_logins`
--
ALTER TABLE `us_email_logins`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `us_fingerprints`
--
ALTER TABLE `us_fingerprints`
  MODIFY `kFingerprintID` int UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `us_fingerprint_assets`
--
ALTER TABLE `us_fingerprint_assets`
  MODIFY `kFingerprintAssetID` int UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `us_forms`
--
ALTER TABLE `us_forms`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `us_form_validation`
--
ALTER TABLE `us_form_validation`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=14;

--
-- AUTO_INCREMENT for table `us_form_views`
--
ALTER TABLE `us_form_views`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `us_ip_blacklist`
--
ALTER TABLE `us_ip_blacklist`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=11;

--
-- AUTO_INCREMENT for table `us_ip_list`
--
ALTER TABLE `us_ip_list`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT for table `us_ip_whitelist`
--
ALTER TABLE `us_ip_whitelist`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- AUTO_INCREMENT for table `us_login_fails`
--
ALTER TABLE `us_login_fails`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `us_management`
--
ALTER TABLE `us_management`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=18;

--
-- AUTO_INCREMENT for table `us_menus`
--
ALTER TABLE `us_menus`
  MODIFY `id` int UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `us_menu_items`
--
ALTER TABLE `us_menu_items`
  MODIFY `id` int UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=69;

--
-- AUTO_INCREMENT for table `us_oauth_client_logins`
--
ALTER TABLE `us_oauth_client_logins`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `us_oauth_client_login_options`
--
ALTER TABLE `us_oauth_client_login_options`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `us_oauth_client_login_tokens`
--
ALTER TABLE `us_oauth_client_login_tokens`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `us_oauth_server_clients`
--
ALTER TABLE `us_oauth_server_clients`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `us_oauth_server_codes`
--
ALTER TABLE `us_oauth_server_codes`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `us_oauth_server_settings`
--
ALTER TABLE `us_oauth_server_settings`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `us_oauth_server_tokens`
--
ALTER TABLE `us_oauth_server_tokens`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `us_passkeys`
--
ALTER TABLE `us_passkeys`
  MODIFY `id` int UNSIGNED NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `us_password_strength`
--
ALTER TABLE `us_password_strength`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `us_php_eol`
--
ALTER TABLE `us_php_eol`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=34;

--
-- AUTO_INCREMENT for table `us_php_known_bad`
--
ALTER TABLE `us_php_known_bad`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT for table `us_plugins`
--
ALTER TABLE `us_plugins`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `us_plugin_hooks`
--
ALTER TABLE `us_plugin_hooks`
  MODIFY `id` int UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `us_rate_limits`
--
ALTER TABLE `us_rate_limits`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `us_rate_limit_proxy_settings`
--
ALTER TABLE `us_rate_limit_proxy_settings`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `us_saas_levels`
--
ALTER TABLE `us_saas_levels`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `us_saas_orgs`
--
ALTER TABLE `us_saas_orgs`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `us_totp_secrets`
--
ALTER TABLE `us_totp_secrets`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `us_user_sessions`
--
ALTER TABLE `us_user_sessions`
  MODIFY `kUserSessionID` int UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `us_versions`
--
ALTER TABLE `us_versions`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
