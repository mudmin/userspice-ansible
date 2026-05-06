<?php
require_once __DIR__ . '/../includes/bootstrap.php';
require_once $abs_us_root . $us_url_root . 'users/includes/template/prep.php';
?>

<style>
.help-toc { position: sticky; top: 1rem; }
.help-toc a { display: block; padding: .15rem .25rem; color: var(--bs-body-color); text-decoration: none; border-left: 2px solid transparent; }
.help-toc a:hover { background: var(--bs-tertiary-bg); }
.help-toc a.active { border-left-color: var(--bs-primary); font-weight: 600; }
.help-section { scroll-margin-top: 1rem; }
.help-section h2 { padding-bottom: .25rem; border-bottom: 1px solid var(--bs-border-color); margin-top: 2rem; }
.help-section h2:first-child { margin-top: 0; }
.help-section pre { background: var(--bs-tertiary-bg); padding: .75rem 1rem; border-radius: .375rem; font-size: .875rem; overflow-x: auto; }
.help-section code { color: var(--bs-code-color); }
.help-section pre code { color: inherit; }
.help-kbd { background: var(--bs-tertiary-bg); padding: .1rem .35rem; border-radius: .25rem; border: 1px solid var(--bs-border-color); font-family: var(--bs-font-monospace); font-size: .85em; }
</style>

<div class="container py-4">
    <p><a href="../">&larr; dashboard</a></p>
    <h1 class="mb-1">Getting started</h1>
    <p class="text-muted">An operator's guide to this Ansible UI and the repo behind it.</p>

    <div class="row g-4 mt-2">
        <div class="col-lg-3">
            <nav class="help-toc small">
                <a href="#overview">Overview</a>
                <a href="#running">Running a playbook</a>
                <a href="#readonly-vs-mutating">Read-only vs mutating</a>
                <a href="#groups">Groups &amp; inventory</a>
                <a href="#adding-server">Adding a server</a>
                <a href="#customization">Per-group customization</a>
                <a href="#vault">Vault basics</a>
                <a href="#troubleshooting">Troubleshooting</a>
                <a href="#more">Where to go next</a>
            </nav>
        </div>

        <div class="col-lg-9">
            <article class="help-section">

<h2 id="overview">Overview</h2>
<p>
    This UI is a thin web front-end over an Ansible repo on disk. The web app lives at
    <code><?= safeReturn(dirname(__DIR__, 2)) ?></code> and reads its playbooks, inventory,
    and group/host vars from <code><?= safeReturn(ANSIBLE_REPO) ?></code>.
</p>
<p>
    The trust model is single-tenant and offline-friendly: any UserSpice user with the
    required permission can run any playbook listed on the dashboard. There's no per-playbook
    ACL beyond the read-only badge. If you don't want a user running mutating playbooks,
    don't give them access to the UI.
</p>
<p>
    <strong>What lives where:</strong>
</p>
<ul>
    <li><code>inventory.ini</code> &mdash; groups and hosts</li>
    <li><code>group_vars/&lt;group&gt;.yml</code> &mdash; per-group settings (firewall rules, service whitelists, anything fleet-wide goes in <code>all.yml</code>)</li>
    <li><code>host_vars/&lt;host&gt;.yml</code> &mdash; per-host settings, including the vault-encrypted sudo password</li>
    <li><code>*.yml</code> at the repo root &mdash; playbooks. Anything with a <code># UI_PARAMS:</code> comment block is parameterized through this UI</li>
    <li><code>scripts/</code> &mdash; Python helpers shipped to remote hosts via <code>ansible.builtin.script</code></li>
</ul>

<h2 id="running">Running a playbook</h2>
<ol>
    <li>From the <a href="../">dashboard</a>, pick a playbook from the right-hand list.</li>
    <li>Pick a <strong>target</strong> &mdash; a group or a single host. Type to filter; the dropdown is searchable.</li>
    <li>Fill in any parameters the playbook exposes (defaults are pre-filled where the playbook supplies them).</li>
    <li>Click <strong>Run</strong>. You'll be taken to the run page, which shows three things, top to bottom:
        <ul>
            <li><strong>Pretty report</strong> &mdash; populated when the playbook finishes, if it emits a structured report (most do).</li>
            <li><strong>Recap</strong> &mdash; Ansible's built-in per-host ok/changed/failed summary.</li>
            <li><strong>Console log</strong> &mdash; the raw stdout from <code>ansible-playbook</code>, streamed live.</li>
        </ul>
    </li>
    <li>The run is locked per-target while it's in flight: starting a second run against the same target won't proceed until the first finishes. Different targets can run in parallel.</li>
</ol>
<p>
    <strong>Past runs</strong> are listed under <a href="runs.php">history</a>. Each one keeps the full log and structured report so you can re-read it later or compare.
</p>

<h2 id="readonly-vs-mutating">Read-only vs mutating</h2>
<p>
    Playbooks marked <span class="badge bg-info">read-only</span> are safe to run any time
    against any target &mdash; they only read state. Examples: <code>fleet_health.yml</code>,
    <code>disk.yml</code>, <code>tail.yml</code>, <code>grep_log.yml</code>,
    <code>process_snapshot.yml</code>, <code>config_test.yml</code>.
</p>
<p>
    Playbooks <em>without</em> the badge change something on the remote host: install
    packages, restart services, edit config files, prune logs, etc. They still go through the
    same UI, but you should know what they do before clicking Run. Read the comment block at
    the top of the playbook file when in doubt.
</p>
<p class="text-muted small">
    The badge isn't a permission gate &mdash; it's a label. The real safety boundary is who
    you let into the UI in the first place.
</p>

<h2 id="groups">Groups &amp; inventory</h2>
<p>
    <code>inventory.ini</code> is the source of truth for what hosts exist and how they're
    grouped. A host can belong to multiple groups; groups can have parents via
    <code>:children</code>. Variables inherit down the tree.
</p>

<p><strong>Example structure</strong>:</p>
<pre><code>[apache]
web1 ansible_host=10.0.0.10
web2 ansible_host=web2.example.com

[db]
db1 ansible_host=10.0.0.20

[nonprod]
sandbox1 ansible_host=10.0.0.50

# Parent group: anything in apache or db is also in `production`
[production:children]
apache
db

# Per-group defaults (override per-host in host_vars/&lt;host&gt;.yml)
[apache:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=~/.ssh/id_ed25519
</code></pre>

<p>
    <strong>When to make a new group:</strong> when a set of hosts needs different settings
    from the rest of its current group &mdash; different firewall rules, a different service
    whitelist, a different baseline config. Groups are how this repo expresses
    &ldquo;these hosts are configured the same.&rdquo;
</p>
<p>
    <strong>How to make one:</strong>
</p>
<ol>
    <li>Add a section to <code>inventory.ini</code>: <code>[my_new_group]</code> followed by host names.</li>
    <li>If the new group should inherit from an existing parent, add a <code>:children</code> entry: e.g. <code>[apache:children]</code> with <code>my_new_group</code> on its own line.</li>
    <li>Create <code>group_vars/my_new_group.yml</code> for any settings that differ.</li>
    <li>Reload this UI &mdash; the new group will show up in the target dropdown automatically.</li>
</ol>
<p>
    Inventory edits happen on the control node (filesystem on the box this UI runs on); this
    UI does not write to <code>inventory.ini</code>.
</p>

<h2 id="adding-server">Adding a server</h2>
<p>
    Onboarding a new host is a CLI operation, not a UI one &mdash; it's deliberately kept on
    the terminal so SSH and sudo passwords never transit the web tier.
</p>
<p>
    On the control node:
</p>
<pre><code>cd ~/ansible
./add_server.sh
</code></pre>
<p>
    The script walks you through:
</p>
<ol>
    <li>Short name (must be unique in <code>inventory.ini</code>).</li>
    <li>Reachable address &mdash; Tailscale IP, MagicDNS name, or LAN IP. Must be reachable from the control node before you start.</li>
    <li>SSH user (defaults to <code>root</code>) and port (defaults to 22).</li>
    <li>Whether the host already has the control node's SSH key pushed. If not, you'll be asked for the SSH password once; the script uses <code>sshpass</code> + <code>bootstrap.yml</code> to push the key, then strips the password from <code>host_vars</code>.</li>
    <li>Sudo password (vault-encrypted into <code>host_vars/&lt;name&gt;.yml</code>).</li>
    <li>Group(s) the host belongs to (space-separated; the script lists what's available).</li>
</ol>
<p>
    After you confirm the summary, the script writes <code>host_vars/&lt;name&gt;.yml</code>,
    edits <code>inventory.ini</code>, runs <code>bootstrap.yml</code> if needed, and verifies
    both <code>ping</code> and privileged <code>ping -b</code>. If anything fails, it tells
    you exactly what files to look at.
</p>
<p>
    <strong>Pre-reqs to have ready:</strong>
</p>
<ul>
    <li><code>ansible-vault</code> is set up (vault password file exists at <code>~/.ansible/vault_pass.txt</code>).</li>
    <li><code>~/.ssh/id_ed25519.pub</code> exists on the control node.</li>
    <li><code>sshpass</code> is installed if you'll be doing the password-bootstrap step: <code>sudo apt install -y sshpass</code>.</li>
    <li>The new host's firewall (if any) allows SSH from the control node. The script prints the exact <code>ufw allow</code> commands you need.</li>
</ul>

<h2 id="customization">Per-group customization</h2>
<p>
    Some playbooks let each group extend a hardcoded default list. Two patterns to know:
</p>

<h5 class="mt-3">Firewall rules (additive per group)</h5>
<p>
    <code>firewall.yml</code> composes the effective rule list from a host's groups. Each
    group can declare a <code>&lt;group&gt;_firewall_rules</code> list in its
    <code>group_vars/</code> file; rules from every group the host belongs to are merged.
</p>
<pre><code># group_vars/apache.yml
apache_firewall_rules:
  - { rule: allow, port: "80",  proto: tcp, comment: "HTTP" }
  - { rule: allow, port: "443", proto: tcp, comment: "HTTPS" }
</code></pre>
<p>
    To open a port for one group, drop a rule into that group's file. To open it
    fleet-wide, put it in <code>group_vars/all.yml</code> as
    <code>all_firewall_rules</code>.
</p>

<h5 class="mt-3">Service whitelist (extra services per group)</h5>
<p>
    <code>service.yml</code> and <code>unit_log.yml</code> only let you target a hardcoded
    set of services through the UI (<code>apache2</code>, <code>fail2ban</code>,
    <code>mariadb</code>, etc). To allow extra service names on a specific group, add a
    <code>ui_safe_services_extra</code> list:
</p>
<pre><code># group_vars/omt_streaming.yml
ui_safe_services_extra:
  - rtmp-relay
  - my-streaming-app
</code></pre>
<p>
    Reload the UI; the service dropdown will show the extras when you target a host in that
    group. Defense-in-depth check: the playbook also asserts the service is in the
    effective whitelist, so the UI dropdown isn't the only gate.
</p>

<h2 id="vault">Vault basics</h2>
<p>
    Secrets in this repo are encrypted with <code>ansible-vault</code>. The vault password
    lives on the control node at <code>~/.ansible/vault_pass.txt</code> (referenced from
    <code>ansible.cfg</code>). The web user has read access to it via the <code>ansible</code>
    group.
</p>
<p>
    <strong>To encrypt a single value</strong> (the most common case &mdash; e.g. a password
    you want to drop into <code>host_vars/</code>):
</p>
<pre><code>cd ~/ansible
ansible-vault encrypt_string --stdin-name 'my_secret_var'
# (paste the value, then Ctrl-D)
</code></pre>
<p>
    Copy the resulting <code>!vault | ...</code> block into the YAML file.
</p>
<p>
    <strong>To edit an existing encrypted file</strong> (e.g. a whole vault file):
</p>
<pre><code>ansible-vault edit group_vars/secrets.yml
</code></pre>
<p>
    Don't commit plaintext secrets. <code>add_server.sh</code> handles encryption for you
    when you onboard a host; you only need these commands when adding ad-hoc secrets.
</p>

<h2 id="troubleshooting">Troubleshooting</h2>

<h5 class="mt-3">A run fails with &ldquo;Permission denied (publickey)&rdquo;</h5>
<p>
    The control node's SSH key isn't authorized on the target. Either the host was added
    without bootstrap, the key was rotated, or the host's <code>~/.ssh/authorized_keys</code>
    was overwritten. Re-run <code>add_server.sh</code>; if the host is already in the
    inventory it'll offer a &ldquo;retry&rdquo; option that just reruns bootstrap.
</p>

<h5 class="mt-3">A mutating playbook fails with a sudo password prompt</h5>
<p>
    The vault-encrypted <code>ansible_become_password</code> in <code>host_vars/&lt;host&gt;.yml</code>
    is wrong, missing, or the vault password file isn't readable. Check:
</p>
<pre><code>cat ~/.ansible/vault_pass.txt           # exists and readable?
ansible &lt;host&gt; -m ping -b               # privileged ping from CLI
</code></pre>
<p>
    If the privileged ping fails, re-encrypt the sudo password:
</p>
<pre><code>ansible-vault encrypt_string --stdin-name 'ansible_become_password'
</code></pre>
<p>
    Then replace the existing block in <code>host_vars/&lt;host&gt;.yml</code>.
</p>

<h5 class="mt-3">A run is stuck and won't start (target locked)</h5>
<p>
    Each target has a lock file in <code><?= safeReturn(defined('ANSIBLE_LOCK_DIR') ? ANSIBLE_LOCK_DIR : '/var/lock') ?></code>
    while a run is in flight. If a previous run died without releasing it (web process
    killed, machine rebooted mid-run), remove the stale lock:
</p>
<pre><code>ls <?= safeReturn(defined('ANSIBLE_LOCK_DIR') ? ANSIBLE_LOCK_DIR : '/var/lock') ?>/ansible-ui-*
sudo rm <?= safeReturn(defined('ANSIBLE_LOCK_DIR') ? ANSIBLE_LOCK_DIR : '/var/lock') ?>/ansible-ui-&lt;target&gt;.lock
</code></pre>

<h5 class="mt-3">A new playbook I added doesn't show up in the UI</h5>
<p>
    The UI lists every <code>*.yml</code> at the root of the ansible repo. If yours is
    missing, check it's at the top level (not inside a subdir) and that it parses as YAML.
    For parameterized playbooks, the parameter form only renders if the file has a
    <code># UI_PARAMS:</code> comment block at the top &mdash; see
    <code>AGENT_GUIDE.md</code> for the schema.
</p>

<h5 class="mt-3">Reports don't render &ldquo;pretty&rdquo; &mdash; only the console log shows</h5>
<p>
    The structured report is only written when the playbook supports it. Built-in playbooks
    all do. If you're running a custom playbook that doesn't emit one, you'll only see the
    console + recap; that's normal. Adding a structured report is a small change &mdash; see
    <code>AGENT_GUIDE.md</code> &sect; on JSON sidecars.
</p>

<h2 id="more">Where to go next</h2>
<ul>
    <li><strong>Adding a new playbook to the UI</strong> &mdash; see
        <code>AGENT_GUIDE.md</code> in the <code>ansible-ui</code> repo. It documents the
        <code># UI_PARAMS:</code> schema, the JSON sidecar pattern, and how to add a custom
        report renderer.
    </li>
    <li><strong>Ansible itself</strong> &mdash; the
        <a href="https://docs.ansible.com/ansible/latest/" target="_blank" rel="noopener">official Ansible documentation</a>
        is the canonical reference for inventory, modules, and playbook syntax.
    </li>
    <li><strong>Tweaking this UI</strong> &mdash; <code>config.php</code> in the
        <code>ansible-ui</code> repo holds the per-install settings (repo path, lock dir,
        permission ID).
    </li>
</ul>

            </article>
        </div>
    </div>
</div>

<script>
(function () {
    var links = document.querySelectorAll('.help-toc a');
    var sections = Array.from(links).map(function (a) {
        return document.querySelector(a.getAttribute('href'));
    }).filter(Boolean);
    function onScroll() {
        var pos = window.scrollY + 80;
        var current = sections[0];
        for (var i = 0; i < sections.length; i++) {
            if (sections[i].offsetTop <= pos) current = sections[i];
        }
        links.forEach(function (a) {
            a.classList.toggle('active', a.getAttribute('href') === '#' + current.id);
        });
    }
    window.addEventListener('scroll', onScroll, { passive: true });
    onScroll();
})();
</script>

<?php require_once $abs_us_root . $us_url_root . 'users/includes/html_footer.php'; ?>
