# Hardening guide

Defaults the installer ships with are tuned for an internal control
appliance — single operator, isolated LXC, trusted network. This file is
for operators who want to deviate from those defaults. Read
[README.md](README.md) first; the threat model section explains *why*
the defaults are what they are.

## Enable HTTPS

The installer ships **plain HTTP**. For an internal LXC reached over
LAN, Tailscale, or VPN that's deliberate: a self-signed cert produces a
permanent "Not Secure" warning that trains operators to ignore browser
warnings without protecting against a same-network attacker. Operators
who want real HTTPS have three good paths — pick the one that matches
your network model.

The installer doesn't open port 443 in `ufw` by default. After enabling
HTTPS via any option below, open it:

```sh
# If you set an operator IP restriction:
sudo ufw allow from <operator-ip> to any port 443 proto tcp
# Or, for unrestricted 443 (uncommon — only if your operator IP is dynamic):
sudo ufw allow 443/tcp
```

Once HTTPS is working, see [Enable `force_ssl` in UserSpice](#enable-force_ssl-in-userspice-after-https-is-up) below.

### Option A — Let's Encrypt (public domain)

If the LXC has a public DNS name and port 80 is reachable from the
internet, or you can do DNS-01 with a supported provider, use certbot:

```sh
sudo apt install certbot python3-certbot-apache
sudo certbot --apache -d ansible.example.com
```

certbot adds an SSL vhost on 443, sets up auto-renewal, and adds an
80→443 redirect. The run-finish callback in `run_wrapper.sh` follows
redirects and replays the POST body, so the certbot defaults work
without further config.

**DNS-01 with dynamic DNS:** providers like Cloudflare, deSEC, or Hurricane
Electric work with `certbot --dns-cloudflare` / `--dns-rfc2136` and let
you issue a cert without exposing port 80. Useful for home labs behind
CGNAT.

### Option B — Tailscale serve (tailnet)

**Heads-up: the installer can do this for you.** If you answered yes to
the *"Install Tailscale + serve the web UI on your tailnet over HTTPS?"*
prompt during install, this section is already in place — skip ahead to
[Enable `force_ssl`](#enable-force_ssl-in-userspice-after-https-is-up).
The rest of this section is for operators who skipped that prompt and
want to add Tailscale serve manually.

`tailscale serve` issues and renews a cert via **Tailscale's CA** (not
Let's Encrypt — different ACME workflow, same end result of a real
padlock for clients on your tailnet). The clean MagicDNS name
(`<machine>.<tailnet>.ts.net`) just works.

```sh
# Inside the LXC:
curl -fsSL https://tailscale.com/install.sh | sh

# Unprivileged LXCs need userspace networking (no /dev/net/tun passthrough).
sudo tee /etc/default/tailscaled > /dev/null <<'EOF'
PORT="41641"
FLAGS="--tun=userspace-networking"
EOF
sudo systemctl restart tailscaled

sudo tailscale up --hostname="$(hostname)" --accept-routes=false --accept-dns=false
sudo tailscale serve --bg https / http://localhost:80
```

tailscaled terminates TLS on the tailnet IP and proxies to Apache on
loopback:80. The Apache vhost stays as-is; you don't need to open 443
in ufw because traffic arrives via the tailnet interface.

### Option C — Bring your own cert

Enable mod_ssl, drop your cert + key in place, and write a 443 vhost:

```sh
sudo a2enmod ssl
```

Then write `/etc/apache2/sites-available/userspice-ansible-ssl.conf`:

```apache
<VirtualHost *:443>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/html/userspice-ansible

    SSLEngine on
    SSLCertificateFile /etc/ssl/certs/your-cert.crt
    SSLCertificateKeyFile /etc/ssl/private/your-key.key

    <Directory /var/www/html/userspice-ansible>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
```

Then `sudo a2ensite userspice-ansible-ssl && sudo systemctl reload apache2`.

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

## Enable `force_ssl` in UserSpice (after HTTPS is up)

Once you've added HTTPS via one of the options above, flip on
UserSpice's belt-and-suspenders HTTPS enforcement:

1. Log in as the admin user.
2. **Admin Panel → Settings → Security** (or wherever your UserSpice
   version exposes it).
3. Toggle **Force HTTPS** on. (This flips `settings.force_ssl` in the
   database to `1`.)

That adds a PHP-layer redirect in `users/includes/loader.php` so any
request that somehow lands on plain HTTP — bookmark, hardcoded link,
operator typing `http://` — gets bumped to HTTPS even if Apache misses
it.

**Redundant with certbot's redirect?** Mostly yes. Certbot writes an
Apache-layer 80→443 redirect that fires before PHP, so `force_ssl`
mainly matters when something terminates TLS in front of Apache and
forwards plain HTTP (e.g., a reverse proxy on the same LXC).
Enabling it doesn't hurt — the second redirect never fires when the
first already did its job.

**Loopback callback:** `run_wrapper.sh`'s curl uses
`-L --post301 --post302 --post303 -k`, so the run-finish callback at
`http://127.0.0.1/...` correctly follows any redirect (Apache's or
`force_ssl`'s) and replays the POST body. No further config needed.
If you've forked `run_wrapper.sh` and removed those flags, expect
audit rows stuck at "running" — re-add the flags.

## Self-managing the control node

The installer deliberately does **not** add the LXC itself to the
inventory. Two reasons:

1. The local connection runs as the `ansible` user with no passwordless
   sudo (the boundary that keeps the web UI from rooting its own
   container — see the threat model in the README). Anything with
   `become: true` would fail with a cryptic *"sudo: a password is
   required"*. Earlier versions papered over this by leaving the LXC
   in inventory and treating it as "read-only" — the failures just
   moved from explicit to confusing.
2. A misclick on `firewall.yml` or `update.yml` against the control
   node could lock you out of your own appliance. Excluding it from
   the dashboard removes that footgun.

If you genuinely want to manage the LXC from its own UI (homelab use,
single-operator who'll never confuse targets), add it explicitly. SSH
to localhost as root, with the `ansible` user's pubkey installed:

```sh
# On the LXC, as root:
sudo -u ansible cat /home/ansible/.ssh/id_ed25519.pub >> /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys

# Append to /var/www/html/userspice-ansible/playbooks/inventory.ini:
cat >> /var/www/html/userspice-ansible/playbooks/inventory.ini <<'EOF'

[control]
this-lxc ansible_host=localhost ansible_user=root ansible_ssh_private_key_file=~/.ssh/id_ed25519
EOF
chown ansible:ansible /var/www/html/userspice-ansible/playbooks/inventory.ini
```

Now `become: true` works (you're already root over SSH), and the LXC
shows up in the dashboard. **Don't run `firewall.yml` against it.**

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
