# UserSpice Ansible

A web UI for running Ansible playbooks against your fleet, with auth, audit
logging, dry-run buttons, and parameter validation. Built on UserSpice (PHP).

## Quick install (Proxmox)

On a Proxmox VE host, as root:

```
bash -c "$(wget -qO - https://raw.githubusercontent.com/mudmin/userspice-ansible/main/proxmox/install-lxc.sh)"
```

Creates an unprivileged Ubuntu 24.04 LXC with Apache, MariaDB, phpMyAdmin,
and Ansible pre-installed; clones this repo; sets up the database; and
prompts you for an admin email + password.

## What's in here

- `index.php`, `users/`, `usersc/`, `ansible/` — the web UI (UserSpice + custom PHP)
- `playbooks/` — Ansible playbooks, inventory, host/group vars
- `db/schema.sql` — initial database schema (used by the installer)
- `proxmox/install-lxc.sh` — the LXC installer
- `AGENT_GUIDE.md` — **read this first** — how to customize, add playbooks, add servers

## After install

1. Open the UI at `http://<lxc-ip>/` and log in with the admin credentials you
   set during install.
2. Copy `playbooks/inventory.example.ini` → `playbooks/inventory.ini` and add
   your servers.
3. (Optional) add per-host overrides in `playbooks/host_vars/<hostname>.yml`.
   Encrypt the file with `ansible-vault` if it contains secrets.
4. Click any playbook in the dashboard, pick a target, click **Check** for a
   dry run, then **Run** to apply.

See [AGENT_GUIDE.md](AGENT_GUIDE.md) for the full customization guide
(adding playbooks, the UI_PARAMS schema for parameterized playbooks, the
permissions model, and what NOT to do).

## Security

This stack runs `ansible-playbook` from PHP via `proc_open` with argv arrays
(no shell injection vector). Targets and playbook names are whitelisted.
Every run is audit-logged. See [AGENT_GUIDE.md](AGENT_GUIDE.md) §9 for the
full safety rules.

The `playbooks/` directory is denied by Apache (`Require all denied`) so
inventory and vault files cannot be served over HTTP. PHP's `exec()` still
reads them fine — only HTTP serving is blocked.

## License

MIT. Use at your own risk.
