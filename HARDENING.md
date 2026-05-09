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

ufw already permits port 443 from the operator IP, so no firewall edit
is needed for any of these.

### Option A — Tailscale serve (recommended if you're on a tailnet)

`tailscale serve` issues and renews a real cert via Tailscale's CA. Any
operator with Tailscale installed sees a clean padlock — no warning.
This is by far the lowest-friction path for the typical deployment.

```sh
# Inside the LXC, after `tailscale up`:
sudo tailscale serve --bg https / http://localhost:80
```

tailscaled terminates TLS on the tailnet IP and proxies to Apache on
loopback:80. The Apache vhost stays as-is.

### Option B — Let's Encrypt (real domain, port 80 reachable)

If the LXC has a public DNS name and port 80 is reachable from the
internet (or you can use DNS-01 with a supported provider), use certbot:

```sh
sudo apt install certbot python3-certbot-apache
sudo certbot --apache -d ansible.example.com
```

certbot adds an SSL vhost on 443, sets up auto-renewal, and (by default)
adds a redirect from 80 to 443. If you want to keep loopback traffic on
plain HTTP — required because helper.php's run-finish callback hits
`http://127.0.0.1/...` and run_wrapper.sh's curl doesn't follow
redirects — answer "No redirect" when certbot asks, or edit the
generated 80 vhost to add a `RewriteCond %{REMOTE_ADDR} !^127\.0\.0\.1$`
guard.

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
Same caveat as Option B: keep port 80 working without forcing redirect,
or guard the redirect with a loopback exemption, so the run-finish
callback isn't broken.

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
(it flips `settings.force_ssl` in the database to 1). **Leave it off**
even after you've enabled HTTPS via one of the options above.

`force_ssl` adds a redirect at the PHP layer (in
`users/includes/loader.php`) that fires on **every** request loading
`users/init.php` — including the loopback callback the run-wrapper
makes to `run_finish.php` after each playbook run. The wrapper's
`curl` doesn't follow redirects, so `finished_at` on your audit rows
stops getting stamped. Runs still complete, but the UI shows them as
"running" forever.

The right place to enforce HTTPS is the Apache layer (or your reverse
proxy / Tailscale serve). All three options above either don't redirect
loopback or let you exempt it. The PHP-layer toggle has no exemption
mechanism — it'll always break the callback.

If you absolutely need PHP-layer enforcement (say, you're running
behind something that already terminates TLS and forwards plain HTTP),
update `helper.php`'s `$finish_url` to use HTTPS and add `-k -L --post301`
to `run_wrapper.sh`'s curl call.

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
