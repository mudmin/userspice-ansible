# Hardening guide

Defaults the installer ships with are tuned for an internal control
appliance — single operator, isolated LXC, trusted network. This file is
for operators who want to deviate from those defaults. Read
[README.md](README.md) first; the threat model section explains *why*
the defaults are what they are.

## Replace the self-signed certificate

The installer generates `/etc/ssl/certs/userspice-ansible.crt` (10-year
self-signed, `CN = <lxc-hostname>`). Browsers warn on first visit. Three
ways to replace it.

### Option A — Tailscale serve (recommended if you're on a tailnet)

`tailscale serve` issues and renews a real cert via Tailscale's CA. Any
operator already trusting Tailscale's CA sees no warning.

```sh
# Inside the LXC, after `tailscale up`:
sudo tailscale serve --bg https / http://localhost:80
```

That terminates TLS in tailscaled and proxies to Apache on 80. With
that in place, you can disable our 80→443 redirect so Apache serves
plain HTTP on the loopback:

```sh
# /etc/apache2/sites-available/000-default.conf — replace the rewrite
# block with a normal vhost (DocumentRoot, Directory, etc.) and:
sudo a2dissite default-ssl
sudo systemctl reload apache2
```

### Option B — Let's Encrypt (real domain, port 80 reachable)

If the LXC has a public DNS name and port 80 is reachable from the
internet (or you can use DNS-01 with a supported provider), use certbot:

```sh
sudo apt install certbot python3-certbot-apache
sudo certbot --apache -d ansible.example.com
```

certbot rewrites the Apache vhosts and sets up auto-renewal.

### Option C — Bring your own cert

Drop in your cert + key:

```
/etc/ssl/certs/userspice-ansible.crt
/etc/ssl/private/userspice-ansible.key
```

then `sudo systemctl reload apache2`. The install-time vhost references
those exact paths; no Apache config edits needed.

## Multiple operator IPs

The installer prompts for *one* IP. To add more after install, the
restriction lives in two layers:

**Network layer (ufw):**
```sh
sudo ufw allow from 192.168.1.51 to any port 22 proto tcp
sudo ufw allow from 192.168.1.51 to any port 80 proto tcp
sudo ufw allow from 192.168.1.51 to any port 443 proto tcp
sudo ufw status numbered
```

**HTTP layer (Apache `Require ip`):**
edit `/etc/apache2/conf-available/99-userspice-ansible-restrict.conf` and
add lines:

```apache
<Directory /var/www/html>
    Require ip 192.168.1.50
    Require ip 192.168.1.51
</Directory>
```

then `sudo systemctl reload apache2`.

Both layers must be updated — ufw is the real boundary; Apache is
defense-in-depth.

## Disable SSH entirely

If you'd rather use `pct enter` from the Proxmox host instead of SSH:

```sh
sudo systemctl disable --now ssh
sudo ufw deny 22       # belt-and-suspenders even after sshd is off
```

`pct enter <CTID>` from the Proxmox host then becomes your only console.

## Don't enable UserSpice's `force_ssl` setting

The UserSpice admin → Security dashboard has a "Force HTTPS" toggle
(it flips `settings.force_ssl` in the database to 1). **Leave it off.**

The Apache layer already redirects external HTTP to HTTPS. Toggling
`force_ssl` adds a *second* redirect at the PHP layer (in
`users/includes/loader.php`), and that one fires on **every** request
that loads `users/init.php` — including the loopback callback the
run-wrapper makes to `run_finish.php` after each playbook run. The
wrapper's `curl` doesn't follow redirects, so finished_at on your
audit rows stops getting stamped. Runs still complete, but the UI
shows them as "running" forever.

If you absolutely need PHP-layer SSL enforcement (e.g., you've
disabled the Apache redirect because you're running behind something
that already terminates TLS), update `helper.php`'s `$finish_url` to
use HTTPS and add `-k -L --post301` to `run_wrapper.sh`'s curl call.

## Vault password backup

The vault password is generated at install and printed *once*. Every
`host_vars/*.yml` file the `add-server` wizard creates is encrypted with
it. Lose the password and those files are unreadable forever — there is
no recovery.

Right after the installer finishes, copy
`/home/ansible/.ansible/vault_pass.txt` into a password manager,
encrypted USB stick, or your preferred secrets store. Don't put it on
the same LXC's filesystem as your only copy.

## Tightening the sudoers rule

The installer ships:

```
www-data ALL=(ansible) NOPASSWD: /usr/bin/ansible, /usr/bin/ansible-playbook, /usr/bin/ansible-inventory, /usr/bin/ansible-vault
```

`NOPASSWD` is what makes the web UI work — PHP can't supply a sudo
password interactively. If you want a stricter posture (e.g., audit-only
runs, or a separate review user), the boundary you'd change is here, in
`/etc/sudoers.d/ansible-ui`.

A common stricter variant: drop `ansible-vault` from the allow list
once your fleet is fully onboarded, so the web tier can no longer
encrypt or decrypt vault files. The downside: `add-server` (run from
the console) still works, but the web UI loses the ability to run
playbooks that reference vaulted host_vars.
