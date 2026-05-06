#!/bin/bash
#
# fixperms.sh — Ansible repo permission fixer
#
# This script lives in the ansible repo. The repo is read-only to www-data
# (which lives at /var/www/html/ansible-ui/) via the shared `ansible` group.
# The PHP UI reads inventory.ini, group_vars/*.yml, etc. via filesystem;
# it never writes to this tree.
#
# Permission model:
#   • Owner: <admin who runs this>      — full write, normal CLI/git workflow
#   • Group: ansible                    — www-data + future ansible-runner read here
#   • Files:  644                       — owner write, group/world read
#   • Dirs:   2755 (setgid)             — new files inherit `ansible` group
#   • Shell scripts (*.sh, *.py): 755   — preserve exec
#   • Sensitive (*.key, id_rsa*, *.pem, vault*.yml, *.vault): 600 owner-only
#
# Bootstraps the `ansible` group on first run (creates it, adds www-data and
# the calling user), so `git pull && ./fixperms.sh` works on a fresh box.
#
# .git/ is left alone — git manages its own perms (especially hook exec bits).

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ANSIBLE_ROOT="$SCRIPT_DIR"

ANSIBLE_GROUP="ansible"
WEB_USER="www-data"
CURRENT_USER="$(whoami)"

RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'; CYAN=$'\033[0;36m'; NC=$'\033[0m'
info() { printf '%s[INFO]%s %s\n' "$GREEN" "$NC" "$*"; }
warn() { printf '%s[WARN]%s %s\n' "$YELLOW" "$NC" "$*"; }
err()  { printf '%s[ERROR]%s %s\n' "$RED" "$NC" "$*" >&2; }
step() { printf '\n%s==> %s%s\n' "$CYAN" "$*" "$NC"; }

[[ $EUID -eq 0 ]] && { err "Don't run as root. Run as your regular user; sudo is invoked where needed."; exit 1; }

if [[ ! -f "$ANSIBLE_ROOT/inventory.ini" && ! -f "$ANSIBLE_ROOT/ansible.cfg" ]]; then
    err "$ANSIBLE_ROOT does not look like an Ansible repo (no inventory.ini or ansible.cfg). Refusing."
    exit 1
fi

step "Target: $ANSIBLE_ROOT"
sudo -v   # cache creds so we don't get prompted mid-run

# ---------------------------------------------------------------------------
# Bootstrap: ensure `ansible` group exists with the right members
# ---------------------------------------------------------------------------
step "Bootstrapping group '$ANSIBLE_GROUP'"

if getent group "$ANSIBLE_GROUP" >/dev/null 2>&1; then
    info "Group '$ANSIBLE_GROUP' exists"
else
    info "Creating group '$ANSIBLE_GROUP'"
    sudo groupadd "$ANSIBLE_GROUP"
fi

for u in "$WEB_USER" "$CURRENT_USER"; do
    if id -nG "$u" 2>/dev/null | tr ' ' '\n' | grep -qx "$ANSIBLE_GROUP"; then
        info "$u is in '$ANSIBLE_GROUP'"
    else
        info "Adding $u to '$ANSIBLE_GROUP'"
        sudo usermod -aG "$ANSIBLE_GROUP" "$u"
        if [[ "$u" == "$WEB_USER" ]]; then
            warn "$u picks up '$ANSIBLE_GROUP' on next service restart (systemctl restart php-fpm or apache2)"
        else
            warn "$u must log out and back in for the new group membership to take effect in your shell"
        fi
    fi
done

# ---------------------------------------------------------------------------
# Apply ownership and modes (whole repo except .git/)
# ---------------------------------------------------------------------------
step "Applying ownership: $CURRENT_USER:$ANSIBLE_GROUP"
sudo find "$ANSIBLE_ROOT" -path "$ANSIBLE_ROOT/.git" -prune -o -print0 \
    | sudo xargs -0 -r chown "$CURRENT_USER:$ANSIBLE_GROUP"

step "Applying directory perms: 2755 (setgid)"
sudo find "$ANSIBLE_ROOT" -path "$ANSIBLE_ROOT/.git" -prune -o -type d -print0 \
    | sudo xargs -0 -r chmod 2755

step "Applying file perms: 644"
sudo find "$ANSIBLE_ROOT" -path "$ANSIBLE_ROOT/.git" -prune -o -type f -print0 \
    | sudo xargs -0 -r chmod 644

step "Restoring exec bit on shell/python scripts: 755"
sudo find "$ANSIBLE_ROOT" -path "$ANSIBLE_ROOT/.git" -prune -o \
    -type f \( -name '*.sh' -o -name '*.py' \) -print0 \
    | sudo xargs -0 -r chmod 755

# ---------------------------------------------------------------------------
# Lock down sensitive files (defensive — they shouldn't be in the repo at all)
# ---------------------------------------------------------------------------
step "Locking down sensitive files (forced 600, owner-only)"
sensitive_count=0
while IFS= read -r -d '' f; do
    sensitive_count=$((sensitive_count + 1))
    warn "  found: $f"
    sudo chmod 600 "$f"
done < <(sudo find "$ANSIBLE_ROOT" \
    -path "$ANSIBLE_ROOT/.git" -prune -o \
    -type f \( -name '*.key' -o -name 'id_rsa*' -o -name '*.pem' \
            -o -name 'vault*.yml' -o -name '*.vault' \) -print0 2>/dev/null)
if [[ $sensitive_count -eq 0 ]]; then
    info "None found (good — keys and vaults belong outside the repo)"
else
    warn "$sensitive_count sensitive file(s) locked to 600. Consider moving them outside the repo entirely."
fi

# ---------------------------------------------------------------------------
# Verify www-data can read but not write
# ---------------------------------------------------------------------------
step "Verifying www-data access"

if sudo -u "$WEB_USER" test -r "$ANSIBLE_ROOT/inventory.ini" 2>/dev/null; then
    info "✓ $WEB_USER can read inventory.ini"
else
    warn "✗ $WEB_USER cannot read inventory.ini yet — group membership pending; restart php-fpm/apache2"
fi

if sudo -u "$WEB_USER" test -w "$ANSIBLE_ROOT/inventory.ini" 2>/dev/null; then
    err "✗ $WEB_USER CAN write to inventory.ini — that's wrong; ansible config must be read-only to www-data"
else
    info "✓ $WEB_USER cannot write to inventory.ini (correct)"
fi

step "Complete"
info "If '$ANSIBLE_GROUP' was just created or $WEB_USER was just added: sudo systemctl restart php-fpm (or apache2)."
info "If $CURRENT_USER was just added: log out and back in for your shell to see the new group."
