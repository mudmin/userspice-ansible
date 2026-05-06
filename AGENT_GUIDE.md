# Customization Guide

This document tells you (and any AI agent helping you) how to extend this stack: add playbooks, add servers to your fleet, add web UI pages, and stay out of trouble. Read this once before you start hacking.

If you're new to Ansible, the [official intro](https://docs.ansible.com/ansible/latest/getting_started/index.html) is worth 30 minutes before you go further.

---

## 1. What you have

A web UI (UserSpice + custom PHP) that runs Ansible playbooks against a fleet of remote servers. The UI handles auth, audit logging, per-target locks, dry-run buttons, and parameter validation. Ansible itself does the actual work over SSH.

```
                                                    ┌──────────────────┐
 [ browser ]  ───►  [ Apache + PHP ]  ───►  exec  ──►  ansible-playbook │
                         │                          └────────┬─────────┘
                         │                                   │ SSH
                         ▼                                   ▼
                  audit log + run                     [ remote hosts ]
                  output streamed back
                  to browser via SSE
```

You — the operator — log in, click a playbook, pick a target group/host, and click Run. The UI spawns `ansible-playbook` in the background, streams output to your browser, and writes a row to the audit log.

---

## 2. Layout on disk (after install)

```
/var/www/html/userspice-ansible/      ← this whole repo, served by Apache
    index.php, ansible.php            ← entry points
    users/                            ← UserSpice framework (don't edit)
    usersc/                           ← UserSpice user customizations
    ansible/                          ← the web UI's PHP code
        pages/                        ← UI pages (group.php, playbook.php, run.php, …)
        parsers/                      ← AJAX/SSE endpoints (run_start.php, run_stream.php, …)
        includes/helper.php           ← shared helpers (inventory parsing, validation)
        runs/                         ← per-run log files (gitignored, owned by www-data)
    playbooks/                        ← ANSIBLE_PATH points here
        *.yml                         ← your playbooks
        ansible.cfg
        inventory.ini                 ← who exists, in what groups
        group_vars/<group>.yml        ← variables per group
        host_vars/<host>.yml          ← variables per host (often vault-encrypted)
        scripts/                      ← helper scripts the playbooks call
        templates/                    ← Jinja2 templates the playbooks render
    db/schema.sql                     ← initial UserSpice schema (used at install)
    proxmox/install-lxc.sh            ← the installer that put you here
```

The `playbooks/` directory is **denied by Apache** (`Require all denied`) so nobody can fetch your `inventory.ini` over HTTP. PHP's `exec()` still reads it fine — only HTTP serving is blocked.

The `ANSIBLE_PATH` constant is defined in `users/init.php`. If you move the playbooks elsewhere (e.g. `/opt/ansible-playbooks/`), update that one constant.

---

## 3. The three things you'll customize

| You want to … | You edit … |
|---|---|
| Add or change what the fleet does | `playbooks/*.yml` |
| Add a server, change groups, set per-host variables | `playbooks/inventory.ini`, `playbooks/host_vars/`, `playbooks/group_vars/` |
| Add a web UI page or change how a playbook is presented | `ansible/pages/`, `ansible/parsers/` |

Most days you'll only touch the first two. The web UI auto-discovers playbooks in `playbooks/*.yml` — you don't have to register them anywhere.

---

## 4. Add a playbook (worked example)

Goal: add a playbook called `restart_apache.yml` that restarts Apache on a target host.

**Step 1.** Create the file at `playbooks/restart_apache.yml`:

```yaml
---
# restart_apache.yml — restart Apache on the target host(s).
#
#   ansible-playbook restart_apache.yml --limit web-server-1

- name: Restart Apache
  hosts: all
  become: true
  gather_facts: false

  tasks:
    - name: Restart apache2 service
      ansible.builtin.systemd:
        name: apache2
        state: restarted
```

**Step 2.** Refresh the UI's playbook list. Open the dashboard — `restart_apache.yml` shows up automatically.

**Step 3.** Click it, pick a target, click **Check** first to dry-run, then **Run**.

That's it. The UI handles target selection, locking, output streaming, audit logging.

### Notes on writing playbooks

- **Idempotent.** Running the same playbook twice should produce the same end state. Use modules like `ansible.builtin.copy`, `ansible.builtin.systemd`, `ansible.builtin.apt` — they only act when something needs changing.
- **`become: true`** = sudo. Drop it if your task doesn't need root.
- **`gather_facts: false`** = skip the slow OS-detection step. Drop it if your tasks reference facts (`ansible_distribution`, etc.).
- **`hosts: all`** is fine — the UI always passes `--limit <target>` so this never runs against your whole fleet by accident.

---

## 5. Add a parameterized playbook (UI_PARAMS)

Some playbooks need user input beyond "which target." The UI reads a comment block at the top of the YAML and renders form fields automatically.

```yaml
---
# service.yml — restart, reload, or check the status of a service.
#
# UI_PARAMS:
#   service: enum(apache2|mariadb|nginx|ssh|ufw) required
#   action:  enum(restart|reload|status) required
#   apply:   bool default=false

- name: Manage a service
  hosts: all
  become: true
  gather_facts: false

  tasks:
    - name: Validate parameters (defense in depth)
      ansible.builtin.assert:
        that:
          - service in ['apache2', 'mariadb', 'nginx', 'ssh', 'ufw']
          - action in ['restart', 'reload', 'status']
        fail_msg: "Invalid service or action"
        run_once: true
        delegate_to: localhost
        become: false

    - name: Run the action
      ansible.builtin.systemd:
        name: "{{ service }}"
        state: "{{ 'restarted' if action == 'restart' else action }}"
      when: apply | bool
```

### UI_PARAMS syntax

- Block starts with `# UI_PARAMS:` on its own line. Ends at the first non-comment line.
- One param per line: `# <name>: <type>(<values>)? <attrs...>`
- Types:
  - `enum(a|b|c)` — dropdown, only the listed values are accepted
  - `int min=N max=N` — number input with bounds
  - `bool` — true/false dropdown
  - `string max_length=N min_length=N` — free-form text, length-bounded
- Attrs: `required`, `default=X`, `min=N`, `max=N`, `max_length=N`, `min_length=N`

### Always validate inside the playbook too

The UI is the primary gate, but a CLI run (you SSH'd in and typed `ansible-playbook` directly) bypasses it. The `ansible.builtin.assert` block at the top of the playbook is your backstop. Copy the whitelist values literally — don't try to share them between the UI schema and the assert. The cost of duplication is low; the cost of one drifting away from the other is high.

---

## 6. Add a server to your fleet

**Step 1.** Make sure the new server has SSH access from the LXC. The simplest path:

```bash
# On the LXC, as the user that runs ansible:
ssh-copy-id -i ~/.ssh/id_ed25519.pub user@new-server.example.com
```

**Step 2.** Add the host to `playbooks/inventory.ini`:

```ini
[apache]
existing-server-1 ansible_host=10.0.0.10
new-server        ansible_host=new-server.example.com
```

**Step 3.** (Optional) Per-host variables go in `playbooks/host_vars/new-server.yml`:

```yaml
ansible_user: ubuntu
ansible_become_password: "{{ vault_become_password }}"
some_app_port: 8080
```

If the file contains secrets, encrypt it with ansible-vault:

```bash
cd /var/www/html/userspice-ansible/playbooks
ansible-vault encrypt host_vars/new-server.yml
# You'll be prompted for a password. Save it somewhere safe.
```

**Step 4.** Smoke-test from CLI:

```bash
cd /var/www/html/userspice-ansible/playbooks
ansible -i inventory.ini new-server -m ping
# Expected: new-server | SUCCESS => { "ping": "pong" }
```

**Step 5.** Refresh the UI — the host appears in the dashboard under whatever groups you put it in.

### Inventory shapes the UI understands

```ini
[apache]                                          ← leaf group
web-server-1 ansible_host=10.0.0.10
web-server-2 ansible_host=10.0.0.11

[db]
db-server-1 ansible_host=10.0.0.20

[production:children]                             ← group-of-groups
apache
db

[production:vars]                                 ← group-level vars
ansible_ssh_private_key_file=~/.ssh/id_ed25519
```

A host in `apache` is automatically also in `production`. Targeting `--limit production` hits both `apache` and `db` hosts.

**Don't parse inventory.ini yourself with PHP.** The format looks INI-shaped but per-host vars on the same line aren't valid INI. The UI uses `ansible-inventory --list` (which returns canonical JSON) instead, via `ansible/includes/helper.php`. Stick to that pattern if you write new pages.

---

## 7. Add a UI page (advanced)

You usually don't need to. The dashboard, group view, host view, playbook view, and run view are all generic — they discover playbooks, groups, and hosts dynamically.

If you want a custom page (e.g. a one-click "deploy production" button that runs three playbooks in sequence), the pattern lives in `ansible/pages/`. Read [ansible/pages/playbook.php](ansible/pages/playbook.php) and [ansible/parsers/run_start.php](ansible/parsers/run_start.php) — they're the reference.

The shape is always:
1. **Page** in `ansible/pages/foo.php` — calls `securePage($hooks_array)` first to enforce auth, then renders HTML/forms.
2. **Parser** in `ansible/parsers/foo.php` — handles AJAX POSTs, validates input, calls `run_ansible($argv, $log_path)` from the helper, returns JSON.

The two non-negotiables, repeated for emphasis:
- **Always `securePage` at the top.** Never ship a page that runs anything without an auth check.
- **Always pass arguments to ansible as an argv array, never as a shell string.** The helper already does this — use it. Don't introduce `exec()` or `shell_exec()` with concatenated strings.

---

## 8. Permissions model

| What | Owner | Group | Mode |
|---|---|---|---|
| Web UI files (`/var/www/html/userspice-ansible/`) | www-data | www-data | 755 dirs, 644 files |
| Playbooks (`playbooks/`) | (your admin user) | ansible | 755 dirs, 644 files |
| `playbooks/scripts/*.sh`, `*.py` | (your admin user) | ansible | 755 |
| Sensitive files (`*.key`, `vault*.yml`, `*.pem`) | (your admin user) | ansible | 600 |
| `ansible/runs/` (run logs) | www-data | www-data | 775 |

`www-data` is in the `ansible` group, so it can **read** everything in `playbooks/` and **execute** the scripts there. It cannot write anything in `playbooks/`. That's intentional: the UI runs playbooks but never edits them. Edits go through your CLI/git workflow on the LXC, not through the web.

---

## 9. Safety rules (don't break these)

1. **Argv arrays only.** Never build an ansible command as a string and pass it to `exec()` / `shell_exec()` / `system()`. Always pass an array to `proc_open()`. The helper does this for you.
2. **Whitelist playbooks.** The UI knows about a fixed list (auto-discovered from `playbooks/*.yml`). User-supplied playbook names from `$_POST` are matched against that list before exec.
3. **Whitelist target patterns.** Targets must match `^[a-zA-Z0-9_.-]+$` and resolve to a known host or group from `ansible-inventory --list`.
4. **Whitelist flags.** Allow exactly `--check`, `--diff`, `-v`, `-vv`. Reject everything else (no `-e`, no `--vault-password-file`, no `-i`).
5. **Lock per target.** Two simultaneous runs against the same host stomp each other. The helper uses `flock` on `/var/lock/ansible-ui-<target>`.
6. **Audit every run.** A row in the DB: `run_id, user, playbook, target, flags, started_at, finished_at, exit_code, log_path`.
7. **Auth in front.** `securePage` at the top of every UI page that runs anything.
8. **No vault password in PHP.** If a host_var is encrypted and the playbook needs it, the run will fail because there's no TTY for the prompt. That's correct behavior — playbooks that need vault decryption should be run from CLI. Surface a clear error in the UI; don't try to work around it.
9. **No file modifications under `playbooks/`.** The UI is read-execute-only. Edits go through your CLI/git workflow.

---

## 10. Things that look like good ideas but aren't

- **Don't let the UI edit `inventory.ini` or `group_vars/`.** It's tempting to add a "manage hosts" page. Resist. Files in `playbooks/` are read-only to www-data on purpose. If you really need UI-driven edits later, that's a separate write-side service with a separate auth path.
- **Don't shell out to `git pull`** to update the playbooks from the UI. Same reason — write side, separate concern.
- **Don't aggregate runs across hosts in PHP.** A "run firewall.yml on all production" button should fire ONE `ansible-playbook ... --limit production` and let ansible parallelize, not N PHP processes each running per-host.
- **Don't try to live-render `--diff` colors.** Set `ANSIBLE_FORCE_COLOR=0`, present plain text, re-colorize in the browser if you care.

---

## 11. Common gotchas

- **`become_password` errors.** If a host needs `sudo` but your SSH user can't sudo without a password, set `ansible_become_password` in `host_vars/<name>.yml` (vault-encrypt the file).
- **Host key prompts hang the UI.** First time you connect to a new host, ansible wants to confirm the SSH host key. Either pre-populate `~/.ssh/known_hosts` for the user that runs ansible, or set `ANSIBLE_HOST_KEY_CHECKING=False` in the UI's exec environment (only safe over a trusted network like Tailscale).
- **PHP can't find `ansible-playbook`.** Apache's PATH may not include `/usr/bin`. The helper sets `PATH` explicitly in the env passed to `proc_open`.
- **Runs hang forever.** Check `ansible/runs/<run_id>.log` for the actual ansible output. Common cause: SSH connection timed out, or sudo prompted for a password.

---

## 12. Going further

- [Ansible documentation](https://docs.ansible.com/) — the canonical reference
- [UserSpice documentation](https://userspice.com/getting-started/) — the auth/user framework this UI is built on
- The web UI's full architecture decisions live in this repo's git history — read commit messages for the "why."

When you change something significant, document the why in a commit message. Future you (or future AI) will thank you.
