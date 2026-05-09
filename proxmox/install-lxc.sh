#!/usr/bin/env bash
# ============================================================================
# UserSpice Ansible — Proxmox LXC Installer
#
# Creates an unprivileged Ubuntu 24.04 LXC on a Proxmox VE host, installs
# Apache + PHP + MariaDB + phpMyAdmin + Ansible, clones this repo, sets up
# the database, and configures an admin user.
#
# Run on a Proxmox host as root:
#
#   bash -c "$(wget -qO - https://raw.githubusercontent.com/mudmin/userspice-ansible/main/proxmox/install-lxc.sh)"
#
# Or locally:
#
#   wget -qO install-lxc.sh https://raw.githubusercontent.com/mudmin/userspice-ansible/main/proxmox/install-lxc.sh
#   bash install-lxc.sh
# ============================================================================

set -uo pipefail

REPO_URL="https://github.com/mudmin/userspice-ansible.git"
REPO_DIR_NAME="userspice-ansible"
APP_NAME="UserSpice Ansible"
DB_NAME="ansible-ui"

# Pin clone to the matching release tag. If the tag is missing on origin
# (rare — usually a fresh installer pulled from main before tags push),
# the clone falls back to main with a warning.
INSTALLER_VERSION="0.2.0"

DEFAULT_HOSTNAME="userspice-ansible"
DEFAULT_DISK="8"        # GB — LAMP + ansible needs ~3GB
DEFAULT_CORES="2"
DEFAULT_RAM="2048"      # MB
DEFAULT_SWAP="512"
DEFAULT_BRIDGE="vmbr0"
DEFAULT_TEMPLATE_STORAGE="local"
DEFAULT_CT_STORAGE="local-lvm"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
ok()   { echo -e "  ${GREEN}[OK]${NC} $*"; }
warn() { echo -e "  ${YELLOW}[!]${NC} $*"; }
fail() { echo -e "  ${RED}[X]${NC} $*" >&2; }
info() { echo -e "  ${BLUE}[i]${NC} $*"; }
ask()  { echo -en "  ${CYAN}[?]${NC} $* "; }
step() { echo -e "\n${BOLD}${CYAN}==>${NC} ${BOLD}$*${NC}"; }

# ---- Preconditions ----
if ! command -v pct &>/dev/null; then
    fail "This script must run on a Proxmox VE host (pct not found)."
    exit 1
fi
if [[ $EUID -ne 0 ]]; then
    fail "This script must run as root."
    exit 1
fi

clear
echo ""
echo -e "${BOLD}${CYAN}${APP_NAME}${NC}"
echo -e "${BOLD}${CYAN}Proxmox LXC Installer${NC}"
echo ""
echo "Creates an unprivileged Ubuntu 24.04 LXC with:"
echo "  - Apache + PHP 8.3 + MariaDB + phpMyAdmin"
echo "  - Ansible (control node)"
echo "  - The web UI cloned to /var/www/html/${REPO_DIR_NAME}"
echo "  - A dedicated SSH key for www-data so PHP can run ansible against your fleet"
echo ""

gen_pw() {
    if command -v openssl &>/dev/null; then
        openssl rand -base64 18 | tr -d '/+=' | cut -c1-16
    else
        tr -dc 'A-Za-z0-9' </dev/urandom | head -c 16
    fi
}
gen_token() {
    if command -v openssl &>/dev/null; then
        openssl rand -base64 24 | tr -d '/+=' | cut -c1-20
    else
        tr -dc 'A-Za-z0-9' </dev/urandom | head -c 20
    fi
}

# ---- Security / service prompts first ----
step "Configuration"

ask "LXC root password (leave empty to generate):"
read -rs ROOT_PW
echo ""
GENERATED_ROOT_PW=0
if [[ -z "$ROOT_PW" ]]; then
    ROOT_PW="$(gen_pw)"
    GENERATED_ROOT_PW=1
fi

ask "MariaDB root password (leave empty to generate):"
read -rs MYSQL_PW
echo ""
GENERATED_MYSQL_PW=0
if [[ -z "$MYSQL_PW" ]]; then
    MYSQL_PW="$(gen_pw)"
    GENERATED_MYSQL_PW=1
fi

# UserSpice admin user
ADMIN_EMAIL=""
while [[ -z "$ADMIN_EMAIL" || ! "$ADMIN_EMAIL" =~ ^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$ ]]; do
    ask "Admin email (for UserSpice login):"
    read -r ADMIN_EMAIL
    [[ -z "$ADMIN_EMAIL" ]] && fail "Email is required."
done

GENERATED_ADMIN_PW=0
while true; do
    ask "Admin password (min 8 chars, leave empty to generate):"
    read -rs ADMIN_PW
    echo ""
    if [[ -z "$ADMIN_PW" ]]; then
        ADMIN_PW="$(gen_pw)"
        GENERATED_ADMIN_PW=1
        break
    fi
    if [[ ${#ADMIN_PW} -lt 8 ]]; then
        fail "Password must be at least 8 characters."
        continue
    fi
    ask "Confirm admin password:"
    read -rs ADMIN_PW2
    echo ""
    if [[ "$ADMIN_PW" != "$ADMIN_PW2" ]]; then
        fail "Passwords don't match."
        continue
    fi
    break
done

while true; do
    ask "Restrict access to a single IP (web + SSH via ufw)? Enter IP, or leave blank for unrestricted:"
    read -r RESTRICT_IP
    if [[ -z "$RESTRICT_IP" ]]; then
        break
    fi
    if [[ "$RESTRICT_IP" =~ ^[0-9a-fA-F:.]+$ ]]; then
        break
    fi
    warn "\"$RESTRICT_IP\" does not look like an IP address — try again or leave blank for unrestricted"
done

ask "Install phpMyAdmin? (recommended for development only) [y/N]:"
read -r INSTALL_PMA_ANSWER
INSTALL_PMA=0
if [[ "${INSTALL_PMA_ANSWER,,}" == "y" || "${INSTALL_PMA_ANSWER,,}" == "yes" ]]; then
    INSTALL_PMA=1
fi

# Generate cookie/session names now so they're consistent across the install
COOKIE_NAME="$(gen_token)"
SESSION_NAME="$(gen_token)"

# Vault password — encrypts host_vars/*.yml on every `add-server` invocation.
# Generated once at install; user must back this up because losing it means
# every encrypted host_vars file becomes unreadable forever.
VAULT_PW="$(openssl rand -base64 32 | tr -d '\n')"

# ---- Container resource prompts ----
echo ""
echo -e "${BOLD}Container resources${NC}"
echo -e "  ${YELLOW}You can hit Enter through the rest — defaults work for most hosts.${NC}"
echo ""

NEXT_ID=$(pvesh get /cluster/nextid 2>/dev/null || echo "200")
ask "Container ID [${NEXT_ID}]:"
read -r CTID
CTID="${CTID:-$NEXT_ID}"

if pct status "$CTID" &>/dev/null; then
    fail "Container ${CTID} already exists. Pick a different ID or destroy it first."
    exit 1
fi

ask "Hostname [${DEFAULT_HOSTNAME}]:"
read -r HOSTNAME
HOSTNAME="${HOSTNAME:-$DEFAULT_HOSTNAME}"

ask "Disk size in GB [${DEFAULT_DISK}]:"
read -r DISK
DISK="${DISK:-$DEFAULT_DISK}"

ask "CPU cores [${DEFAULT_CORES}]:"
read -r CORES
CORES="${CORES:-$DEFAULT_CORES}"

ask "RAM in MB [${DEFAULT_RAM}]:"
read -r RAM
RAM="${RAM:-$DEFAULT_RAM}"

ask "Network bridge [${DEFAULT_BRIDGE}]:"
read -r BRIDGE
BRIDGE="${BRIDGE:-$DEFAULT_BRIDGE}"

ask "Template storage [${DEFAULT_TEMPLATE_STORAGE}]:"
read -r TEMPLATE_STORAGE
TEMPLATE_STORAGE="${TEMPLATE_STORAGE:-$DEFAULT_TEMPLATE_STORAGE}"

ask "Container storage [${DEFAULT_CT_STORAGE}]:"
read -r CT_STORAGE
CT_STORAGE="${CT_STORAGE:-$DEFAULT_CT_STORAGE}"

echo ""
echo -e "${BOLD}Review:${NC}"
echo "  CTID:            ${CTID}"
echo "  Hostname:        ${HOSTNAME}"
echo "  Disk:            ${DISK} GB on ${CT_STORAGE}"
echo "  CPU / RAM:       ${CORES} cores / ${RAM} MB"
echo "  Bridge:          ${BRIDGE}"
echo "  Admin email:     ${ADMIN_EMAIL}"
echo "  IP lock (web+SSH): ${RESTRICT_IP:-<none — unrestricted>}"
echo "  phpMyAdmin:      $([[ $INSTALL_PMA -eq 1 ]] && echo "yes" || echo "no")"
echo ""
ask "Proceed? [Y/n]:"
read -r CONFIRM
if [[ "${CONFIRM,,}" == "n" ]]; then
    info "Cancelled."
    exit 0
fi

# ---- Find Ubuntu template ----
step "Finding Ubuntu 24.04 template"
pveam update >/dev/null 2>&1 || warn "pveam update failed (continuing)"

LATEST_TEMPLATE=$(pveam available --section system 2>/dev/null \
    | awk '/ubuntu-24\.04-standard/ {print $2}' \
    | sort -V | tail -1)

if [[ -z "$LATEST_TEMPLATE" ]]; then
    fail "No Ubuntu 24.04 template available via pveam."
    fail "Check: pveam available --section system | grep ubuntu-24"
    exit 1
fi
info "Latest available: ${LATEST_TEMPLATE}"

if ! pveam list "$TEMPLATE_STORAGE" 2>/dev/null | grep -q "${LATEST_TEMPLATE}"; then
    info "Not in storage — downloading..."
    if ! pveam download "$TEMPLATE_STORAGE" "$LATEST_TEMPLATE"; then
        fail "Template download failed."
        exit 1
    fi
fi
TEMPLATE_PATH="${TEMPLATE_STORAGE}:vztmpl/${LATEST_TEMPLATE}"
ok "Template: ${LATEST_TEMPLATE}"

# ---- Create container ----
step "Creating LXC ${CTID}"
if ! pct create "$CTID" "$TEMPLATE_PATH" \
        --hostname "$HOSTNAME" \
        --cores "$CORES" \
        --memory "$RAM" \
        --swap "$DEFAULT_SWAP" \
        --rootfs "${CT_STORAGE}:${DISK}" \
        --net0 "name=eth0,bridge=${BRIDGE},firewall=1,ip=dhcp,ip6=auto" \
        --features "nesting=1,keyctl=1" \
        --unprivileged 1 \
        --onboot 1 \
        --password "$ROOT_PW" \
        --ostype ubuntu \
        --description "${APP_NAME}"; then
    fail "pct create failed."
    exit 1
fi
ok "Container ${CTID} created"

cleanup_on_fail() {
    warn "Install failed — cleaning up container ${CTID}"
    pct stop "$CTID" &>/dev/null || true
    pct destroy "$CTID" &>/dev/null || true
}

# ---- Start + wait for network ----
step "Starting container"
pct start "$CTID"

NETWORK_READY=0
for i in {1..30}; do
    if pct exec "$CTID" -- bash -c 'getent hosts github.com &>/dev/null' 2>/dev/null; then
        NETWORK_READY=1
        break
    fi
    sleep 1
done
if [[ $NETWORK_READY -eq 0 ]]; then
    cleanup_on_fail
    fail "Container has no DNS/network after 30s. Check ${BRIDGE} and DHCP."
    exit 1
fi
ok "Network up"

# ---- Install LAMP + Ansible + system config ----
step "Installing LAMP, Ansible, phpMyAdmin (several minutes)"
warn "You'll see harmless 'Cannot set LC_CTYPE' / 'LC_ALL' warnings during apt install."
echo ""

# Heredoc-on-stdin (not bash -c '...') so user-quoted strings flow verbatim.
INSTALL_RC=0
pct exec "$CTID" -- env \
    MYSQL_PW="$MYSQL_PW" \
    RESTRICT_IP="$RESTRICT_IP" \
    VAULT_PW="$VAULT_PW" \
    INSTALL_PMA="$INSTALL_PMA" \
    bash <<'CONTAINER_SCRIPT' || INSTALL_RC=$?
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update -q
apt-get upgrade -yq

# LAMP + Ansible + tooling. Composer is required for the ansible-ui PHP
# module's dependencies (vendor/autoload.php).
apt-get install -yq --no-install-recommends \
    apache2 mariadb-server \
    php php-cli php-mysql php-xml php-mbstring php-curl php-zip php-gd php-intl \
    libapache2-mod-php \
    ansible \
    git curl wget unzip openssh-server openssh-client sudo ca-certificates openssl \
    composer

systemctl enable --now apache2
systemctl enable --now mariadb
systemctl enable --now ssh

# Allow root password login over SSH so SFTP/SCP work for transferring files in.
mkdir -p /etc/ssh/sshd_config.d
cat > /etc/ssh/sshd_config.d/99-userspice-ansible.conf <<SSHCFG
PermitRootLogin yes
PasswordAuthentication yes
SSHCFG
systemctl restart ssh

# Groups: ansible (for /playbooks ownership), webdev (general).
groupadd -f ansible
groupadd -f webdev

# Dedicated `ansible` system user owns the playbook tree and runs ansible
# binaries via sudo from the web UI. Sudoers rule (below) restricts which
# binaries www-data can invoke as ansible — keeps a vault password file (if
# set up later) out of www-data's reach. Use existing 'ansible' group as the
# user's primary group (-g) so we don't get a duplicate-group error.
useradd -m -d /home/ansible -s /bin/bash -g ansible ansible 2>/dev/null || true

usermod -aG ansible www-data
usermod -aG webdev www-data

# Sudoers rule: www-data can run ansible binaries as the ansible user with
# no password. The dev codebase's includes/helper.php hardcodes this pattern
# (sudo -n -H -u ansible -- ansible-inventory ...) so the rule is required
# for the web UI to invoke ansible at all.
cat > /etc/sudoers.d/ansible-ui <<'SUDOERS'
www-data ALL=(ansible) NOPASSWD: /usr/bin/ansible, /usr/bin/ansible-playbook, /usr/bin/ansible-inventory, /usr/bin/ansible-vault
SUDOERS
chmod 0440 /etc/sudoers.d/ansible-ui
visudo -cf /etc/sudoers.d/ansible-ui >/dev/null

# MariaDB root password (chained auth: socket-as-root + password-as-mysql_native)
mariadb <<SQL
ALTER USER "root"@"localhost" IDENTIFIED VIA unix_socket OR mysql_native_password USING PASSWORD("$MYSQL_PW");
FLUSH PRIVILEGES;
SQL

cat > /root/.my.cnf <<CNF
[client]
user=root
password=$MYSQL_PW
CNF
chmod 600 /root/.my.cnf

# phpMyAdmin (optional — recommended for development only). When opted in,
# debconf preseeds the passwords so the install is non-interactive.
if [[ "$INSTALL_PMA" == "1" ]]; then
    debconf-set-selections <<DEBCONF
phpmyadmin phpmyadmin/dbconfig-install boolean true
phpmyadmin phpmyadmin/app-password-confirm password $MYSQL_PW
phpmyadmin phpmyadmin/mysql/admin-pass password $MYSQL_PW
phpmyadmin phpmyadmin/mysql/app-pass password $MYSQL_PW
phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2
DEBCONF
    apt-get install -yq phpmyadmin
fi

# PHP tuning for long ansible runs and UserSpice form posts
PHP_VER=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')
for CTX in apache2 cli; do
    INI_DIR="/etc/php/${PHP_VER}/${CTX}/conf.d"
    if [[ -d "$INI_DIR" ]]; then
        cat > "$INI_DIR/99-userspice-ansible.ini" <<PHPINI
max_execution_time = 600
max_input_time = 600
memory_limit = 512M
max_input_vars = 10000
post_max_size = 64M
upload_max_filesize = 64M
PHPINI
    fi
done

# SSH key for fleet access lives in the ansible user's home — that's the
# user that actually runs ansible-playbook (via sudo from www-data). Keep
# it at /home/ansible/.ssh/id_ed25519 so ansible_ssh_private_key_file=
# ~/.ssh/id_ed25519 in the inventory resolves correctly.
#
# Do the whole setup as the ansible user so .ssh and its contents are
# created with the right ownership from the start (avoids a chicken-and-egg
# where root-owned ~/.ssh blocks ssh-keygen running as ansible).
HN=$(hostname)
sudo -u ansible bash -c "
    set -e
    mkdir -p /home/ansible/.ssh
    chmod 700 /home/ansible/.ssh
    if [[ ! -f /home/ansible/.ssh/id_ed25519 ]]; then
        ssh-keygen -t ed25519 -f /home/ansible/.ssh/id_ed25519 -N '' -C 'userspice-ansible@$HN'
    fi
    touch /home/ansible/.ssh/known_hosts
    chmod 644 /home/ansible/.ssh/known_hosts /home/ansible/.ssh/id_ed25519.pub
    chmod 600 /home/ansible/.ssh/id_ed25519
"

# Vault password file — written as root (avoids the password ever appearing
# in process argv), then chowned to ansible. ansible.cfg's vault_password_file
# line points at this path so ansible-vault auto-uses it.
mkdir -p /home/ansible/.ansible
echo "$VAULT_PW" > /home/ansible/.ansible/vault_pass.txt
chown -R ansible:ansible /home/ansible/.ansible
chmod 700 /home/ansible/.ansible
chmod 600 /home/ansible/.ansible/vault_pass.txt

# Optional: restrict all access to a single IP. Two layers in concert:
#   1. Apache Require ip on the app's filesystem path (and on phpMyAdmin's
#      separate path when it's installed) — defense in depth at the HTTP layer.
#   2. ufw rules — the real boundary. Locks ports 22 / 80 / 443 to the operator
#      IP at the network layer, which is what actually keeps SSH and
#      phpMyAdmin contained.
if [[ -n "$RESTRICT_IP" ]]; then
    cat > /etc/apache2/conf-available/99-userspice-ansible-restrict.conf <<APACHERESTRICT
<Directory /var/www/html>
    Require ip $RESTRICT_IP
</Directory>
APACHERESTRICT

    # phpMyAdmin's Apache alias points at /usr/share/phpmyadmin, outside the
    # /var/www/html scope above. Add a parallel Require ip block so it stays
    # restricted even if someone hits its URL via 127.0.0.1 or hostname tricks.
    if [[ -d /usr/share/phpmyadmin ]]; then
        cat >> /etc/apache2/conf-available/99-userspice-ansible-restrict.conf <<APACHEPMA
<Directory /usr/share/phpmyadmin>
    Require ip $RESTRICT_IP
</Directory>
APACHEPMA
    fi
    a2enconf 99-userspice-ansible-restrict >/dev/null 2>&1 || true

    apt-get install -yq ufw
    ufw default deny incoming >/dev/null
    ufw default allow outgoing >/dev/null
    ufw allow from "$RESTRICT_IP" to any port 22 proto tcp >/dev/null
    ufw allow from "$RESTRICT_IP" to any port 80 proto tcp >/dev/null
    ufw allow from "$RESTRICT_IP" to any port 443 proto tcp >/dev/null
    if ! ufw --force enable >/dev/null 2>&1; then
        echo "WARNING: ufw enable failed inside the LXC. Apache Require ip is" >&2
        echo "still active for HTTP/HTTPS, but SSH is NOT firewalled. Lock SSH" >&2
        echo "manually (Proxmox firewall on the bridge, or sshd ListenAddress)." >&2
    fi
fi

# Apache DocumentRoot points directly at the app (set below in the apache
# config step) so URLs like /ansible/parsers/run_finish.php resolve to the
# UserSpice install without symlink gymnastics. Just remove Ubuntu's
# default landing page.
rm -f /var/www/html/index.html

# Wrapper so users can just type `add-server` instead of remembering the
# sudo invocation. Re-execs as the ansible user since add_server.sh uses
# $HOME/.ssh/id_ed25519 and writes inventory.ini / host_vars/, all of
# which live under the ansible user.
cat > /usr/local/bin/add-server <<'WRAPPER'
#!/bin/bash
# Onboard a new host into the Ansible fleet (interactive wizard).
# Runs add_server.sh as the ansible user so SSH keys + inventory ownership
# stay consistent with what the web UI uses.
exec sudo -u ansible --preserve-env=DEBUG \
    /var/www/html/userspice-ansible/playbooks/add_server.sh "$@"
WRAPPER
chmod +x /usr/local/bin/add-server

# Login banner — shown on every SSH login via /etc/update-motd.d/.
# Quiet down Ubuntu's noisy default MOTD ads while we're here.
[[ -f /etc/default/motd-news ]] && sed -i 's/^ENABLED=1/ENABLED=0/' /etc/default/motd-news

cat > /etc/update-motd.d/99-userspice-ansible <<'MOTDSCRIPT'
#!/bin/bash
IP=$(hostname -I 2>/dev/null | awk '{print $1}')
cat <<EOF

==============================================================
  UserSpice Ansible
==============================================================

  Web UI:        http://${IP}/
EOF

# phpMyAdmin is optional — only show its URL when it's actually installed.
# Self-detects so the MOTD stays correct if it's added or removed later.
if [[ -d /usr/share/phpmyadmin ]]; then
    echo "  phpMyAdmin:    http://${IP}/phpmyadmin/"
fi

cat <<EOF

  Add a server (interactive wizard):
      add-server

  Ping all hosts in your inventory:
      sudo -n -H -u ansible ansible \\
          -i /var/www/html/userspice-ansible/playbooks/inventory.ini \\
          all -m ping

  Playbook directory:
      /var/www/html/userspice-ansible/playbooks/

  Customization guide:
      /var/www/html/userspice-ansible/AGENT_GUIDE.md

==============================================================
EOF
MOTDSCRIPT
chmod +x /etc/update-motd.d/99-userspice-ansible

systemctl restart apache2
CONTAINER_SCRIPT

if [[ $INSTALL_RC -ne 0 ]]; then
    cleanup_on_fail
    fail "Package install failed."
    exit 1
fi
ok "Packages installed, MariaDB configured, SSH key generated"

# ---- Clone repo + permissions ----
step "Cloning ${REPO_DIR_NAME} repo"
if ! pct exec "$CTID" -- bash -c "
set -e
cd /var/www/html
# Pin to the matching release tag. Falls back to main if the tag isn't
# pushed yet (a dev-time race where the installer reaches GitHub before
# the tag does); operators see a clear warning when that happens.
if ! git clone --branch 'v$INSTALLER_VERSION' --depth 1 '$REPO_URL' '$REPO_DIR_NAME' 2>/dev/null; then
    echo 'WARNING: tag v$INSTALLER_VERSION not found on origin, falling back to main' >&2
    git clone --depth 1 '$REPO_URL' '$REPO_DIR_NAME'
fi

# Ownership model:
#   - Web UI files (PHP, users/, usersc/, ansible/): www-data:www-data
#   - Playbook tree: ansible:ansible (the ansible user is who runs them)
#   - Runs directory: www-data:ansible 2775 — both users write to it.
#     www-data writes the run header + log; ansible writes structured
#     reports via delegate_to: localhost in the playbooks.
chown -R www-data:www-data '/var/www/html/${REPO_DIR_NAME}'

chown -R ansible:ansible   '/var/www/html/${REPO_DIR_NAME}/playbooks'
find '/var/www/html/${REPO_DIR_NAME}/playbooks' -type d -exec chmod 2775 {} \;
find '/var/www/html/${REPO_DIR_NAME}/playbooks' -type f -exec chmod 664 {} \;
find '/var/www/html/${REPO_DIR_NAME}/playbooks' -name '*.sh' -exec chmod 775 {} \;
find '/var/www/html/${REPO_DIR_NAME}/playbooks' -name '*.py' -exec chmod 775 {} \;

mkdir -p '/var/www/html/${REPO_DIR_NAME}/ansible/runs'
chown www-data:ansible '/var/www/html/${REPO_DIR_NAME}/ansible/runs'
chmod 2775 '/var/www/html/${REPO_DIR_NAME}/ansible/runs'
"; then
    cleanup_on_fail
    fail "Clone failed."
    exit 1
fi
ok "Repo cloned, permissions set"

# ---- Composer install + render ansible/config.php ----
# The ansible-ui PHP module uses Composer dependencies (vendor/autoload.php)
# and a per-install config.php that's gitignored. Both must be created at
# install time or the dashboard 500s on first load.
step "Installing composer dependencies and rendering ansible/config.php"
pct exec "$CTID" -- bash <<'COMPOSERSCRIPT'
set -e

cd /var/www/html/userspice-ansible/ansible

# Ensure www-data has a writable composer cache dir under its home.
# (On a fresh install, /var/www/.cache doesn't exist yet — composer warns
# and proceeds without cache, but it's cleaner to create it up front.)
mkdir -p /var/www/.cache /var/www/.config/composer
chown -R www-data:www-data /var/www/.cache /var/www/.config

# -H so HOME is www-data's home (/var/www) — composer's cache lands there.
# composer.lock SHIPS in the repo, so this runs `install` (reproducible)
# rather than `update` (latest-version resolve).
sudo -H -u www-data composer install --no-dev --no-interaction --quiet

# Render config.php from config.example.php
SECRET=$(php -r 'echo bin2hex(random_bytes(32));')
cp config.example.php config.php
sed -i \
    -e "s|/home/ansible/ansible|/var/www/html/userspice-ansible/playbooks|" \
    -e "s|/home/ansible/.local/bin|/usr/bin|" \
    -e "s|CHANGE_ME_LONG_RANDOM_HEX|${SECRET}|" \
    config.php
chown www-data:www-data config.php vendor
chown -R www-data:www-data vendor
chmod 640 config.php
COMPOSERSCRIPT
ok "Composer dependencies installed, ansible/config.php rendered"

# ---- Apache: TLS, DocumentRoot, mod_rewrite, AllowOverride, playbook deny ----
step "Configuring Apache (HTTPS + DocumentRoot + mod_rewrite + deny)"
pct exec "$CTID" -- bash <<'APACHECONFIG'
set -e

# UserSpice ships .htaccess files with rewrite rules — both must be on.
a2enmod rewrite >/dev/null 2>&1
a2enmod ssl >/dev/null 2>&1

# Generate a self-signed cert at install. Browsers warn on first visit
# (no chain of trust) — acceptable for an internal appliance. CN = LXC
# hostname; SAN omitted because the IP isn't reliably known here. To
# replace with a real cert (Tailscale serve, Let's Encrypt), see
# HARDENING.md — the vhost references these two paths so a swap is just
# overwriting the files.
HOSTNAME_CN=$(hostname)
mkdir -p /etc/ssl/private
if [[ ! -f /etc/ssl/certs/userspice-ansible.crt ]]; then
    openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
        -keyout /etc/ssl/private/userspice-ansible.key \
        -out /etc/ssl/certs/userspice-ansible.crt \
        -subj "/CN=${HOSTNAME_CN}" 2>/dev/null
fi
chmod 600 /etc/ssl/private/userspice-ansible.key
chmod 644 /etc/ssl/certs/userspice-ansible.crt

# Port 80 = redirect EXTERNAL traffic to HTTPS, preserving Host + path.
# Loopback stays on plain HTTP so the run-wrapper callback works:
# helper.php hardcodes http://127.0.0.1/ansible/parsers/run_finish.php
# and run_wrapper.sh's curl has no -L/-k. Exempting 127.0.0.1 / ::1 from
# the redirect keeps that flow simple. Don't enable UserSpice's
# `force_ssl` setting in the admin UI — its PHP-level redirect would
# fire on the loopback request and break this. Apache handles HTTPS
# enforcement for external traffic; UserSpice's setting is redundant
# here and actively harmful.
cat > /etc/apache2/sites-available/000-default.conf <<'VHOST'
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/html/userspice-ansible

    <Directory /var/www/html/userspice-ansible>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    RewriteEngine On
    RewriteCond %{REMOTE_ADDR} !^127\.0\.0\.1$
    RewriteCond %{REMOTE_ADDR} !^::1$
    RewriteRule ^(.*)$ https://%{HTTP_HOST}$1 [R=301,L]

    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
VHOST

# Port 443 = real app vhost. UserSpice expects to live at the webroot
# (its init.php walks up from PHP_SELF looking for z_us_root.php in
# DOCUMENT_ROOT). With DocumentRoot=/var/www/html the wrapper-callback
# URL /ansible/parsers/run_finish.php 500s. This DocumentRoot lines up.
cat > /etc/apache2/sites-available/default-ssl.conf <<'VHOST_SSL'
<VirtualHost *:443>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/html/userspice-ansible

    SSLEngine on
    SSLCertificateFile /etc/ssl/certs/userspice-ansible.crt
    SSLCertificateKeyFile /etc/ssl/private/userspice-ansible.key

    <Directory /var/www/html/userspice-ansible>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog ${APACHE_LOG_DIR}/error-ssl.log
    CustomLog ${APACHE_LOG_DIR}/access-ssl.log combined
</VirtualHost>
VHOST_SSL
a2ensite default-ssl >/dev/null 2>&1

# Block direct HTTP access to the playbooks tree, db schema, and installer.
# Filesystem-scoped so it covers both vhosts. PHP exec still reads
# playbooks fine — only HTTP serving is denied.
cat > /etc/apache2/conf-available/99-userspice-ansible-app.conf <<'CONF'
<Directory /var/www/html/userspice-ansible/playbooks>
    Require all denied
</Directory>
<Directory /var/www/html/userspice-ansible/db>
    Require all denied
</Directory>
<Directory /var/www/html/userspice-ansible/proxmox>
    Require all denied
</Directory>
CONF
a2enconf 99-userspice-ansible-app >/dev/null 2>&1 || true
apache2ctl configtest >/dev/null
systemctl reload apache2
APACHECONFIG
ok "HTTPS on (self-signed); 80 redirects to 443; playbooks/db/proxmox denied"

# ---- Database setup, schema import, admin user, init.php render ----
step "Setting up database, importing schema, configuring admin user"
pct exec "$CTID" -- env \
    MYSQL_PW="$MYSQL_PW" \
    DB_NAME="$DB_NAME" \
    ADMIN_EMAIL="$ADMIN_EMAIL" \
    ADMIN_PW="$ADMIN_PW" \
    COOKIE_NAME="$COOKIE_NAME" \
    SESSION_NAME="$SESSION_NAME" \
    LXC_HOSTNAME="$HOSTNAME" \
    bash <<'DBSCRIPT'
set -e

# Create database (utf8mb4 to match what UserSpice expects)
mariadb -e "CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

# Import schema
mariadb "$DB_NAME" < /var/www/html/userspice-ansible/db/schema.sql

# Set admin email + bcrypted (cost 14) password.
# Cost 14 takes ~1.5s on container hardware — acceptable for one-time setup.
php -r '
$pdo = new PDO("mysql:host=localhost;dbname=" . getenv("DB_NAME") . ";charset=utf8mb4",
               "root", getenv("MYSQL_PW"));
$pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
$hash = password_hash(getenv("ADMIN_PW"), PASSWORD_BCRYPT, ["cost" => 14]);
$stmt = $pdo->prepare("UPDATE users SET email = ?, password = ?, email_verified = 1 WHERE username = ?");
$stmt->execute([getenv("ADMIN_EMAIL"), $hash, "admin"]);
fwrite(STDOUT, "Admin user updated: " . $stmt->rowCount() . " row(s)\n");
'

# Render init.php from init.template.php — strtr handles arbitrary content
# without escaping pitfalls.
php -r '
$tmpl = file_get_contents("/var/www/html/userspice-ansible/proxmox/init.template.php");
$replacements = [
    "__MYSQL_PASSWORD__" => getenv("MYSQL_PW"),
    "__DB_NAME__"        => getenv("DB_NAME"),
    "__COOKIE_NAME__"    => getenv("COOKIE_NAME"),
    "__SESSION_NAME__"   => getenv("SESSION_NAME"),
    "__ANSIBLE_PATH__"   => "/var/www/html/userspice-ansible/playbooks",
];
file_put_contents("/var/www/html/userspice-ansible/users/init.php", strtr($tmpl, $replacements));
'

# init.php contains the DB password — tighten perms
chown www-data:www-data /var/www/html/userspice-ansible/users/init.php
chmod 640 /var/www/html/userspice-ansible/users/init.php

# Bootstrap an inventory.ini if none exists
INVENTORY=/var/www/html/userspice-ansible/playbooks/inventory.ini
if [[ ! -f "$INVENTORY" ]]; then
    cp /var/www/html/userspice-ansible/playbooks/inventory.example.ini "$INVENTORY"
fi
chown ansible:ansible "$INVENTORY"

# Pre-register the LXC itself as a read-only managed host. Uses the
# `local` connection (no SSH, runs as www-data) so playbooks that don't
# need root work immediately — disk.yml, memory.yml, glance.yml, etc.
# Playbooks with `become: true` (firewall, services, certs) will fail
# with "cannot escalate" — that's intentional. Mutating the control
# node from the UI would risk locking the user out, so it's blocked
# by design. Configure a remote host for those playbooks.
if ! grep -q '^\[local\]' "$INVENTORY"; then
    cat >> "$INVENTORY" <<INVENTORY_LOCAL

# --- The control node itself (this LXC) ---
# Pre-registered at install time as READ-ONLY. The local connection
# runs as www-data with no sudo, so mutating playbooks (anything with
# become: true) will fail — that's intentional. To enable full
# management of the LXC from the UI, replace this block with:
#   $LXC_HOSTNAME ansible_host=localhost ansible_user=root
# and add www-data's pubkey to /root/.ssh/authorized_keys.
[local]
$LXC_HOSTNAME ansible_connection=local
INVENTORY_LOCAL
fi
chown ansible:ansible "$INVENTORY"
chmod 664 "$INVENTORY"
DBSCRIPT
ok "Database imported, admin user set, init.php rendered"

# ---- Final restart + summary ----
pct exec "$CTID" -- systemctl restart apache2 >/dev/null 2>&1 || true

CT_IP=$(pct exec "$CTID" -- bash -c "hostname -I | awk '{print \$1}'" 2>/dev/null | tr -d '[:space:]')
SSH_PUBKEY=$(pct exec "$CTID" -- cat /home/ansible/.ssh/id_ed25519.pub 2>/dev/null || echo "<failed-to-read>")

echo ""
echo -e "${BOLD}${GREEN}========================================${NC}"
echo -e "${BOLD}${GREEN}  Installation complete${NC}"
echo -e "${BOLD}${GREEN}========================================${NC}"
echo ""
echo -e "  Container ID:   ${BOLD}${CTID}${NC}"
echo -e "  Hostname:       ${BOLD}${HOSTNAME}${NC}"
echo -e "  IP:             ${BOLD}${CT_IP:-<not-detected>}${NC}"
echo ""

ROOT_PW_LABEL=$([[ $GENERATED_ROOT_PW -eq 1 ]] && echo "generated" || echo "as entered")
MYSQL_PW_LABEL=$([[ $GENERATED_MYSQL_PW -eq 1 ]] && echo "generated" || echo "as entered")
ADMIN_PW_LABEL=$([[ $GENERATED_ADMIN_PW -eq 1 ]] && echo "generated" || echo "as entered")

echo -e "  ${BOLD}Credentials${NC} ${YELLOW}(save now — not shown again)${NC}"
echo -e "  LXC root:       ${BOLD}${ROOT_PW}${NC}   (${ROOT_PW_LABEL})"
echo -e "  MariaDB root:   ${BOLD}${MYSQL_PW}${NC}   (${MYSQL_PW_LABEL})"
echo -e "  Admin email:    ${BOLD}${ADMIN_EMAIL}${NC}"
echo -e "  Admin password: ${BOLD}${ADMIN_PW}${NC}   (${ADMIN_PW_LABEL})"
echo -e "  Vault password: ${BOLD}${VAULT_PW}${NC}"
echo ""
echo -e "${RED}${BOLD}=================================================================${NC}"
echo -e "${RED}${BOLD}  *** BACK UP THE VAULT PASSWORD ***${NC}"
echo -e "${RED}${BOLD}=================================================================${NC}"
echo -e "  ${YELLOW}It encrypts every host_vars/*.yml file you create with${NC}"
echo -e "  ${YELLOW}add-server (sudo passwords, per-host secrets).${NC}"
echo -e "  ${YELLOW}Without it, those files cannot be decrypted. There is no${NC}"
echo -e "  ${YELLOW}recovery — losing it bricks every host you have onboarded.${NC}"
echo -e "  ${YELLOW}Stored on the LXC at: /home/ansible/.ansible/vault_pass.txt${NC}"
echo -e "${RED}${BOLD}=================================================================${NC}"
echo ""
echo -e "  Web UI:      ${BOLD}https://${CT_IP:-<ip>}/${NC}"
if [[ $INSTALL_PMA -eq 1 ]]; then
    echo -e "  phpMyAdmin:  ${BOLD}https://${CT_IP:-<ip>}/phpmyadmin/${NC}   (root / MariaDB password)"
fi
echo -e "  SSH:         ${BOLD}ssh root@${CT_IP:-<ip>}${NC}"
echo -e "  Console:     ${BOLD}pct enter ${CTID}${NC}"
echo ""
echo -e "  ${YELLOW}HTTPS uses a self-signed cert — your browser will warn on first${NC}"
echo -e "  ${YELLOW}visit. Click through; it's expected. See HARDENING.md to swap${NC}"
echo -e "  ${YELLOW}in a real cert (Tailscale serve, Let's Encrypt, your own).${NC}"
if [[ -n "$RESTRICT_IP" ]]; then
    echo ""
    echo -e "  ${YELLOW}Access (web + SSH) restricted to IP: ${BOLD}${RESTRICT_IP}${NC}"
    echo -e "  ${YELLOW}ufw is active with allow rules for ports 22, 80, 443 from that IP.${NC}"
    echo -e "  ${YELLOW}To add another operator IP: see HARDENING.md.${NC}"
else
    echo ""
    echo -e "  ${YELLOW}No IP restriction set — anyone on the bridge network can reach${NC}"
    echo -e "  ${YELLOW}this LXC's web UI and SSH. Lock it down via the installer's${NC}"
    echo -e "  ${YELLOW}\"Restrict access\" prompt or with ufw. See HARDENING.md.${NC}"
fi
echo ""
echo -e "  ${BOLD}SSH public key for fleet access${NC} (copy this to each managed host):"
echo "    ${SSH_PUBKEY}"
echo ""
echo -e "  ${BOLD}Next steps:${NC}"
echo "    1. SSH into the LXC. The login banner repeats these instructions —"
echo "       no need to memorize anything."
echo "         ssh root@${CT_IP:-<ip>}"
echo ""
echo "    2. Onboard your fleet hosts with the interactive wizard. It handles"
echo "       SSH keys, sudo passwords, vault encryption, and inventory grouping:"
echo "         add-server"
echo ""
echo -e "    3. Visit ${BOLD}http://${CT_IP:-<ip>}/${NC} and log in with the admin"
echo "       credentials above. Click any playbook to run it."
echo ""
echo -e "  ${BOLD}Customization guide:${NC} /var/www/html/userspice-ansible/AGENT_GUIDE.md"
echo "                            (also viewable in the repo on GitHub)"
echo ""
