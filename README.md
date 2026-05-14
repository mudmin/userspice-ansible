# UserSpice Ansible

A web UI for running Ansible playbooks against your fleet, with auth, audit
logging, dry-run buttons, and parameter validation. Built on UserSpice (PHP).

## What this is

An **internal control appliance** — a single-LXC web UI for trusted
operators on a trusted network. The intended deployment is an isolated
Proxmox LXC reached over Tailscale, a VPN, or your local LAN.

## What this is *not*

- A hardened public web app. Don't expose it directly to the internet.
- A multi-tenant SaaS. The sudoers rule lets `www-data` invoke ansible as
  the dedicated `ansible` user with no password — fine for a single
  operator, problematic if the web tier is shared.
- A robust job queue. The run-start lock prevents double-clicks; it isn't
  a scheduler. Concurrent operators may step on each other.

## Quick install (Proxmox)

On a Proxmox VE host, as root:

```
bash -c "$(wget -qO - https://raw.githubusercontent.com/mudmin/userspice-ansible/main/proxmox/install-lxc.sh)"
```

Creates an unprivileged Ubuntu 24.04 LXC with Apache, MariaDB, and Ansible
pre-installed; clones this repo; sets up the database; and prompts you for
an admin email + password.

The installer asks: *"Restrict access to a single IP?"* — answer with the
operator workstation's IP if you want the LXC firewalled to that one
source. Skipping it leaves the LXC reachable from anywhere on its network.

## What's in here

- `index.php`, `users/`, `usersc/`, `ansible/` — the web UI (UserSpice + custom PHP)
- `playbooks/` — Ansible playbooks, inventory, host/group vars
- `db/schema.sql` — initial database schema (used by the installer)
- `proxmox/install-lxc.sh` — the LXC installer
- `AGENT_GUIDE.md` — **read this first** — how to customize, add playbooks, add servers

## After install

1. Open the UI at the URL printed by the installer and log in with the
   admin credentials you set during install. The installer ships plain
   HTTP — appropriate for an internal LXC reached over LAN, Tailscale,
   or VPN. To enable HTTPS with a real cert, see
   [HARDENING.md](HARDENING.md).
2. Run `add-server` on the LXC console to onboard your first remote host.
   The wizard handles SSH keys, sudo passwords, vault encryption, and
   inventory grouping. **The dashboard is empty until at least one host
   is onboarded** — by design, the LXC itself is not pre-registered (see
   [HARDENING.md](HARDENING.md) if you want self-management anyway).
3. Click any playbook in the dashboard, pick a target, click **Check**
   for a dry run, then **Run** to apply.

See [AGENT_GUIDE.md](AGENT_GUIDE.md) for the full customization guide
(adding playbooks, the UI_PARAMS schema for parameterized playbooks, the
permissions model, and what NOT to do).

## Threat model

The boundaries this stack actually enforces:

- **No shell injection.** `ansible-playbook` runs via `proc_open` with
  argv arrays — never `exec` with concatenated strings. Targets and
  playbook names are whitelisted at the PHP layer.
- **Web tier can't write playbooks.** Apache + PHP run as `www-data`;
  the playbook tree, SSH key, and vault password live under a separate
  `ansible` user. The web reaches ansible only through
  `sudo -n -H -u ansible -- ansible-*` with a sudoers rule that
  whitelists those four binaries.
- **Playbook tree isn't web-served.** Apache denies `playbooks/`, `db/`,
  and `proxmox/` (`Require all denied`). PHP can still read those paths;
  only direct HTTP fetches are blocked.
- **Self-management is read-only.** The LXC pre-registers itself in the
  inventory with `ansible_connection=local`. Tasks needing `become: true`
  fail intentionally, so a new operator can't lock themselves out by
  running `firewall.yml` against the control node.
- **Every run is audit-logged** with the operator's UserSpice user ID,
  command, exit code, target host, and full output.

What this stack does **not** do for you:

- **The vault password is on disk.** It's generated at install and stored
  at `/home/ansible/.ansible/vault_pass.txt`. Anything running as the
  `ansible` user — including the web UI through the sudoers rule —
  decrypts vaulted host_vars transparently. The boundary is "only ansible
  binaries" (via the sudoers whitelist), not "PHP can never touch vault
  data." If the web tier is compromised, vaulted host_vars are
  compromised.
- **No internet hardening.** SSH ships with `PermitRootLogin yes` and
  `PasswordAuthentication yes`. That posture is acceptable *because* the
  IP-restrict prompt configures `ufw` to only allow the operator IP — the
  firewall is the boundary, not sshd. Skipping the IP-restrict prompt
  leaves SSH wide open. Don't.
- **Single-operator.** The sudoers rule grants password-less
  `www-data → ansible`. Fine for one trusted operator on an isolated
  appliance. If you put this in front of multiple users with mixed trust
  levels, you've outgrown this design.

## Known limitations

- **Cancel-run button is a no-op.** `run_cancel.php` errors with
  "Undefined constant SIGTERM" because Apache's mod_php doesn't load
  `pcntl`. A run started from the UI will complete on its own; the button
  doesn't kill it. Tracked for a fix.
- **`init.php` path detection is fragile.** It works because Apache's
  `DocumentRoot` matches the app directory. Changing `DocumentRoot`
  (e.g., to a parent dir + alias) breaks the wrapper-callback URL in
  non-obvious ways. Don't reconfigure Apache without reading
  [AGENT_GUIDE.md](AGENT_GUIDE.md) first.
- **Vault password loss is unrecoverable.** Every host_vars/*.yml the
  `add-server` wizard creates is encrypted with the install-time vault
  password. There is no recovery — back it up the moment the installer
  prints it.

## Hardening

See [HARDENING.md](HARDENING.md) for adding HTTPS (Let's Encrypt for a
real domain, Tailscale serve for a tailnet, or BYO cert), adding
multiple operator IPs, disabling SSH entirely, backing up the vault
password, and tightening the sudoers rule.

## License

MIT. Use at your own risk.
