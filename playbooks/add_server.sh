#!/usr/bin/env bash
# add_server.sh — onboard a new host into this Ansible control node.
#
# What it does:
#   1. Asks for hostname, address, SSH user/port/password (if needed), sudo
#      password, and which group(s) the host belongs to.
#   2. Vault-encrypts the secrets into host_vars/<name>.yml.
#   3. Appends the host to chosen groups in inventory.ini.
#   4. If the host is still on password auth, runs bootstrap.yml to push the
#      control node's SSH key, then strips the SSH password from host_vars.
#   5. Verifies key+sudo auth with a final ping.
#
# Run from ~/ansible:
#   ./add_server.sh
#
# Requirements: ansible-vault working (Vault is set up), and `sshpass` if
# bootstrapping a password-auth host. The script checks these.

set -uo pipefail
# Note: `set -e` is intentionally NOT used. Several intentional patterns here
# (e.g. `[[ test ]] && action` validation guards, ask_yn used in conditionals)
# return non-zero in normal flow and would terminate the script silently.
# Errors are checked explicitly. Run with DEBUG=1 ./add_server.sh to trace.

if [[ "${DEBUG:-}" == "1" ]]; then
    set -x
fi

# Diagnostic: if the script exits with a non-zero status from somewhere we
# didn't expect, surface the line number instead of dying silently.
trap '_rc=$?; if [[ $_rc -ne 0 ]]; then printf "\n[add_server.sh] exited with status %s near line %s\n" "$_rc" "$LINENO" >&2; fi' EXIT

# ---------- pretty output ----------
if [[ -t 1 ]]; then
    C_RED=$'\033[0;31m'; C_GREEN=$'\033[0;32m'; C_YELLOW=$'\033[0;33m'
    C_CYAN=$'\033[0;36m'; C_BOLD=$'\033[1m'; C_DIM=$'\033[2m'; C_RESET=$'\033[0m'
else
    C_RED=''; C_GREEN=''; C_YELLOW=''; C_CYAN=''; C_BOLD=''; C_DIM=''; C_RESET=''
fi
say()   { printf '%s\n' "$*"; }
info()  { printf '%s==>%s %s\n' "$C_CYAN" "$C_RESET" "$*"; }
ok()    { printf '%s✓%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn()  { printf '%s⚠%s %s\n' "$C_YELLOW" "$C_RESET" "$*"; }
err()   { printf '%s✗%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; }
hint()  { printf '   %s%s%s\n' "$C_DIM" "$*" "$C_RESET"; }
hr()    { printf '%s%s%s\n' "$C_DIM" "────────────────────────────────────────────────────────────" "$C_RESET"; }

# ---------- locate project ----------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

INVENTORY="$SCRIPT_DIR/inventory.ini"
HOST_VARS_DIR="$SCRIPT_DIR/host_vars"
BOOTSTRAP="$SCRIPT_DIR/bootstrap.yml"

# ---------- pre-flight ----------
preflight() {
    info "Pre-flight checks"
    [[ -f "$INVENTORY" ]]   || { err "inventory.ini not found at $INVENTORY"; exit 1; }
    [[ -f "$BOOTSTRAP" ]]   || { err "bootstrap.yml not found at $BOOTSTRAP"; exit 1; }
    [[ -d "$HOST_VARS_DIR" ]] || mkdir -p "$HOST_VARS_DIR"
    command -v ansible-vault     >/dev/null || { err "ansible-vault not in PATH"; exit 1; }
    command -v ansible-playbook  >/dev/null || { err "ansible-playbook not in PATH"; exit 1; }
    command -v ansible           >/dev/null || { err "ansible not in PATH"; exit 1; }
    [[ -f "$HOME/.ansible/vault_pass.txt" ]] || { err "Vault password file missing: ~/.ansible/vault_pass.txt"; exit 1; }
    [[ -f "$HOME/.ssh/id_ed25519.pub" ]]     || { err "Public key missing: ~/.ssh/id_ed25519.pub"; exit 1; }
    detect_control_ips
    ok "Project files OK; ansible + vault available"
}

# ---------- inventory helpers ----------
host_exists() {
    grep -qE "^[[:space:]]*$1([[:space:]]|$)" "$INVENTORY"
}
group_exists() {
    grep -qE "^\[$1\]$" "$INVENTORY"
}
list_leaf_groups() {
    # Leaf groups only (skip :children and :vars sections).
    grep -oE '^\[[a-zA-Z0-9_]+\]$' "$INVENTORY" | tr -d '[]'
}
add_host_to_group() {
    # Inserts a line right after [group] in inventory.ini.
    # Fails loudly if the section doesn't exist (instead of silently doing nothing).
    local group="$1" line="$2"
    local tmp; tmp="$(mktemp)"
    awk -v g="$group" -v l="$line" '
        $0 == "[" g "]" { print; print l; found=1; next }
        { print }
        END { if (!found) exit 2 }
    ' "$INVENTORY" > "$tmp"
    local rc=$?
    if [[ $rc -ne 0 ]]; then
        rm -f "$tmp"
        err "add_host_to_group: section [$group] not found in inventory.ini"
        return 1
    fi
    mv "$tmp" "$INVENTORY"
    return 0
}
remove_host_from_inventory() {
    # Strip every line whose first non-whitespace token equals the given name.
    # Group headers ([name]) and comments (# name) are preserved because their
    # first token is "[name]" / "#", not the bare name.
    local name="$1"
    local tmp; tmp="$(mktemp)"
    awk -v n="$name" '
        {
            line=$0
            sub(/^[[:space:]]+/, "", line)
            split(line, parts, /[[:space:]]+/)
            if (parts[1] == n) next
            print
        }
    ' "$INVENTORY" > "$tmp"
    mv "$tmp" "$INVENTORY"
}

# ---------- control node IP detection ----------
# Surfaced to the user so they can pre-allow us through any UFW on the new host
# before we try to reach it.
detect_control_ips() {
    CTRL_TS_IP=""
    CTRL_LAN_IP=""
    if command -v tailscale >/dev/null 2>&1; then
        CTRL_TS_IP="$(tailscale ip -4 2>/dev/null | head -1 || true)"
    fi
    # First non-loopback, non-tailscale IPv4 — i.e. the LAN address.
    CTRL_LAN_IP="$(ip -4 -o addr show 2>/dev/null \
        | awk '$2 != "lo" && $2 !~ /^tailscale/ { sub(/\/.*/, "", $4); print $4; exit }')"
}

# ---------- prompt helpers ----------
ask() {
    # ask "Question" "default" -> echoes answer
    local q="$1" def="${2:-}" ans
    if [[ -n "$def" ]]; then
        read -rp "$(printf '%s? %s%s [%s]: ' "$C_BOLD" "$q" "$C_RESET" "$def")" ans
        echo "${ans:-$def}"
    else
        read -rp "$(printf '%s? %s%s: ' "$C_BOLD" "$q" "$C_RESET")" ans
        echo "$ans"
    fi
}
ask_secret() {
    local q="$1" ans
    read -rsp "$(printf '%s? %s%s (input hidden): ' "$C_BOLD" "$q" "$C_RESET")" ans
    echo >&2
    echo "$ans"
}
ask_yn() {
    # Re-prompt on anything other than y/yes/n/no (or empty -> default).
    # Used in conditionals all over this script, so a stray keystroke shouldn't
    # collapse to "no" and end the run.
    local q="$1" def="${2:-y}" ans choices
    [[ "$def" == "y" ]] && choices="Y/n" || choices="y/N"
    while :; do
        read -rp "$(printf '%s? %s%s [%s]: ' "$C_BOLD" "$q" "$C_RESET" "$choices")" ans
        ans="${ans:-$def}"
        case "${ans,,}" in
            y|yes) return 0 ;;
            n|no)  return 1 ;;
            *)     err "Please answer y or n (or press Enter for the default)." ;;
        esac
    done
}
ask_ynr() {
    # y/n/r prompt. Returns 0 (yes), 1 (no), or 2 (retry). Re-prompts on garbage.
    local q="$1" def="${2:-r}" ans choices
    case "$def" in
        y) choices="Y/n/r" ;;
        n) choices="y/N/r" ;;
        r|*) choices="y/n/R" ;;
    esac
    while :; do
        read -rp "$(printf '%s? %s%s [%s]: ' "$C_BOLD" "$q" "$C_RESET" "$choices")" ans
        ans="${ans:-$def}"
        case "${ans,,}" in
            y|yes)   return 0 ;;
            n|no)    return 1 ;;
            r|retry) return 2 ;;
            *)       err "Please answer y, n, or r (or press Enter for the default)." ;;
        esac
    done
}

# ---------- vault helpers ----------
vault_encrypt() {
    # Echoes a YAML block: "<name>: !vault | ..."
    # Plaintext is piped via stdin (not argv) so it never appears in
    # `ps`/`/proc/<pid>/cmdline` for the duration of the subprocess.
    # `printf '%s'` (not `echo`) avoids appending a newline that would
    # change the encrypted value.
    local name="$1" plaintext="$2"
    printf '%s' "$plaintext" | ansible-vault encrypt_string --stdin-name "$name" 2>/dev/null
}

# ---------- main flow ----------
preflight
hr
say "${C_BOLD}Add a server to the Ansible fleet${C_RESET}"
hr
say "${C_BOLD}What you need before starting:${C_RESET}"
echo
say "  ${C_CYAN}1.${C_RESET} ${C_BOLD}Short name${C_RESET} for the host (e.g. portal-prod-1)"
hint "letters / numbers / dash / underscore only; must be unique in inventory.ini"
echo
say "  ${C_CYAN}2.${C_RESET} ${C_BOLD}Reachable address${C_RESET} — one of:"
hint "Tailscale IP   (e.g. 100.x.y.z from your tailnet)"
hint "MagicDNS name  (e.g. portal1.tail-xxxx.ts.net)"
hint "LAN IP         (e.g. 192.168.1.50)"
hint "must be reachable from THIS control node before you start"
echo
say "  ${C_CYAN}3.${C_RESET} ${C_BOLD}SSH username${C_RESET} on the remote host (default: root)"
echo
say "  ${C_CYAN}4.${C_RESET} ${C_BOLD}SSH port${C_RESET} (default: 22)"
echo
say "  ${C_CYAN}5.${C_RESET} ${C_BOLD}Whether this host already has our SSH key${C_RESET}"
hint "If NO: you'll need the SSH password (used once, then discarded)"
hint "If YES: skip straight to sudo"
echo
say "  ${C_CYAN}6.${C_RESET} ${C_BOLD}Sudo password${C_RESET} for that SSH user on the remote host"
hint "vault-encrypted into host_vars; you won't type it again after this"
echo
say "  ${C_CYAN}7.${C_RESET} ${C_BOLD}Group(s)${C_RESET} the host belongs to (the script will show the list)"
hint "you can pick more than one (space-separated)"
hint "leaf-group membership inherits parents automatically"
echo
say "${C_BOLD}On the NEW host (if its firewall blocks SSH from us):${C_RESET}"
if [[ -n "$CTRL_TS_IP" ]]; then
    hint "sudo ufw allow from $CTRL_TS_IP to any port 22 comment 'ansible (tailscale)'"
fi
if [[ -n "$CTRL_LAN_IP" ]]; then
    hint "sudo ufw allow from $CTRL_LAN_IP to any port 22 comment 'ansible (lan)'"
fi
if [[ -z "$CTRL_TS_IP" && -z "$CTRL_LAN_IP" ]]; then
    hint "(could not auto-detect this control node's IPs — check 'ip -4 addr' and allow port 22 from it)"
fi
hint "Skip if the new host has no firewall, or already allows the control node."
echo
say "${C_BOLD}Control-node pre-reqs:${C_RESET}"
hint "sshpass installed (only if pushing the SSH key for the first time):"
hint "  sudo apt install -y sshpass"
hint "ansible can already reach the host on $C_BOLD${C_RESET}port (verify with: nc -zv <addr> <port>)"
echo
hint "Ctrl-C at any time to abort. Nothing is written until you confirm at the summary."
echo
ask_yn "Ready to begin?" "y" || { warn "Aborted."; exit 0; }
echo

# 1. Short name
RETRY=0
while :; do
    NAME="$(ask "Short name for this host (e.g. portal-prod-1)")"
    if [[ -z "$NAME" ]]; then
        err "Name can't be empty."; continue
    fi
    if [[ ! "$NAME" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*$ ]]; then
        err "Use letters, numbers, dash, underscore only. No spaces."; continue
    fi
    if host_exists "$NAME"; then
        warn "Host '$NAME' already exists in inventory.ini."
        if [[ -f "$HOST_VARS_DIR/${NAME}.yml" ]]; then
            hint "host_vars/${NAME}.yml also exists."
        fi
        say "  Options:"
        say "    y = clear existing and re-add fresh (asks for everything again)"
        say "    n = pick a different name"
        say "    r = retry with the existing inventory + host_vars (rerun bootstrap/ping)"
        ask_ynr "Action" "r"
        case $? in
            0)  remove_host_from_inventory "$NAME"
                rm -f "$HOST_VARS_DIR/${NAME}.yml"
                ok "Cleared $NAME from inventory.ini and host_vars/"
                break
                ;;
            1)  continue ;;
            2)  RETRY=1; break ;;
        esac
    fi
    break
done

HV="$HOST_VARS_DIR/${NAME}.yml"

if [[ $RETRY -eq 1 ]]; then
    # Retry path: pull the bits we need for messaging out of the existing files.
    # The vault-encrypted SSH/sudo passwords stay where they are — ansible reads
    # them straight from host_vars during bootstrap/ping.
    [[ -f "$HV" ]] || { err "Retry needs $HV but it doesn't exist."; exit 1; }
    SSH_USER="$(awk '/^ansible_user:/ {print $2; exit}' "$HV")"
    SSH_PORT="$(awk '/^ansible_port:/ {print $2; exit}' "$HV")"
    SSH_PORT="${SSH_PORT:-22}"
    ADDR="$(grep -E "^[[:space:]]*${NAME}[[:space:]]" "$INVENTORY" | head -1 \
            | grep -oE 'ansible_host=[^[:space:]]+' | head -1 | sed 's/^ansible_host=//')"
    ADDR="${ADDR:-(unknown)}"
    if grep -qE '^ansible_password:' "$HV"; then
        NEEDS_BOOTSTRAP=1
    else
        NEEDS_BOOTSTRAP=0
    fi
    PICKED_GROUPS=()

    echo
    hr
    say "${C_BOLD}Retry summary${C_RESET}"
    hr
    printf '  %-12s %s\n' "Name:"      "$NAME"
    printf '  %-12s %s\n' "Address:"   "$ADDR"
    printf '  %-12s %s\n' "SSH user:"  "$SSH_USER"
    printf '  %-12s %s\n' "SSH port:"  "$SSH_PORT"
    if [[ $NEEDS_BOOTSTRAP -eq 1 ]]; then
        printf '  %-12s %s\n' "Action:" "rerun bootstrap.yml + verify (existing host_vars + inventory unchanged)"
    else
        printf '  %-12s %s\n' "Action:" "rerun verify only (existing host_vars + inventory unchanged)"
    fi
    echo
    if ! ask_yn "Proceed?" "y"; then warn "Aborted."; exit 0; fi
else

# 2. Address
while :; do
    ADDR="$(ask "Reachable address (Tailscale IP / MagicDNS hostname / LAN IP)")"
    if [[ -z "$ADDR" ]]; then err "Address can't be empty."; continue; fi
    break
done

# 3. SSH user
SSH_USER="$(ask "SSH username on the remote host" "root")"

# 4. SSH port
SSH_PORT="$(ask "SSH port" "22")"
if [[ ! "$SSH_PORT" =~ ^[0-9]+$ ]] || (( SSH_PORT < 1 || SSH_PORT > 65535 )); then
    err "Port must be a number 1-65535."
    exit 1
fi

# 5. Bootstrap needed?
if ask_yn "Does this host still need our SSH public key pushed?" "y"; then
    NEEDS_BOOTSTRAP=1
    SSH_PASS="$(ask_secret "SSH password for $SSH_USER@$ADDR")"
    if [[ -z "$SSH_PASS" ]]; then
        err "SSH password can't be empty."
        exit 1
    fi
    if ! command -v sshpass >/dev/null; then
        err "sshpass is required for password-auth bootstrap but isn't installed."
        say "  Install it with:  sudo apt install -y sshpass"
        say "  Then re-run this script."
        exit 1
    fi
else
    NEEDS_BOOTSTRAP=0
    SSH_PASS=""
fi

# 6. Sudo password
SUDO_PASS="$(ask_secret "Sudo password for $SSH_USER on $NAME")"
if [[ -z "$SUDO_PASS" ]]; then
    err "Sudo password can't be empty."
    exit 1
fi

# 7. Groups
echo
info "Available leaf groups in inventory.ini:"
list_leaf_groups | sed 's/^/   - /'
hint "Pick one or more, separated by spaces. Hosts in a leaf group automatically"
hint "inherit any parent groups (e.g. omt_portals -> omt_servers; managed_vps -> apache)."
while :; do
    GROUPS_RAW="$(ask "Groups to add this host to (space-separated)")"
    if [[ -z "$GROUPS_RAW" ]]; then
        err "Pick at least one group."
        continue
    fi
    BAD=0
    for g in $GROUPS_RAW; do
        if ! group_exists "$g"; then
            err "Group '$g' doesn't exist in inventory.ini."
            BAD=1
        fi
    done
    if [[ $BAD -eq 0 ]]; then
        break
    fi
done
# IMPORTANT: do NOT name this array "GROUPS" — that's a read-only bash built-in
# array containing the current user's Linux group IDs. Assignments are silently
# ignored, and ${GROUPS[@]} returns your /etc/group memberships, not what you typed.
# shellcheck disable=SC2206
PICKED_GROUPS=($GROUPS_RAW)

# ---------- summary ----------
if [[ $NEEDS_BOOTSTRAP -eq 1 ]]; then
    BOOT_STATUS="YES (push SSH key, then strip password)"
else
    BOOT_STATUS="no (host already on key auth)"
fi

echo
hr
say "${C_BOLD}Summary${C_RESET}"
hr
printf '  %-12s %s\n' "Name:"       "$NAME"
printf '  %-12s %s\n' "Address:"    "$ADDR"
printf '  %-12s %s\n' "SSH user:"   "$SSH_USER"
printf '  %-12s %s\n' "SSH port:"   "$SSH_PORT"
printf '  %-12s %s\n' "Bootstrap:"  "$BOOT_STATUS"
printf '  %-12s %s\n' "Groups:"     "${PICKED_GROUPS[*]}"
printf '  %-12s %s\n' "Files:"      "host_vars/${NAME}.yml + inventory.ini edits"
echo
if ! ask_yn "Proceed?" "y"; then
    warn "Aborted."
    exit 0
fi

# ---------- write host_vars ----------
HV="$HOST_VARS_DIR/${NAME}.yml"
info "Writing $HV"

ENC_BECOME="$(vault_encrypt 'ansible_become_password' "$SUDO_PASS")"
if [[ $NEEDS_BOOTSTRAP -eq 1 ]]; then
    ENC_SSH="$(vault_encrypt 'ansible_password' "$SSH_PASS")"
fi

{
    echo "---"
    echo "# Per-host vars for $NAME"
    echo "# Managed by add_server.sh; hand-edits are fine."
    echo
    echo "ansible_user: $SSH_USER"
    if [[ "$SSH_PORT" != "22" ]]; then echo "ansible_port: $SSH_PORT"; fi
    echo
    if [[ $NEEDS_BOOTSTRAP -eq 1 ]]; then
        echo "# ansible_password is used only during bootstrap and is removed"
        echo "# automatically once SSH key auth is confirmed."
        echo "$ENC_SSH"
        echo
    fi
    echo "$ENC_BECOME"
} > "$HV"
chmod 640 "$HV"
ok "host_vars written and chmod 640"

# ---------- update inventory ----------
info "Adding $NAME to inventory.ini"
# First listed group gets the ansible_host=<addr>; subsequent groups just get the name.
FIRST=1
for g in "${PICKED_GROUPS[@]}"; do
    if [[ $FIRST -eq 1 ]]; then
        if ! add_host_to_group "$g" "$NAME ansible_host=$ADDR"; then
            err "Failed to add $NAME to [$g]. inventory.ini left unchanged."
            err "host_vars/$NAME.yml was written and should be removed if you abort:"
            say "  rm $HV"
            exit 1
        fi
        FIRST=0
    else
        if ! add_host_to_group "$g" "$NAME"; then
            err "Failed to add $NAME to [$g]. inventory.ini may be partially updated."
            err "Review inventory.ini and host_vars/$NAME.yml manually."
            exit 1
        fi
    fi
done
ok "inventory.ini updated"

info "Verifying $NAME is visible to ansible-inventory"
if ! ansible-inventory --host "$NAME" >/dev/null 2>&1; then
    err "ansible-inventory can't find $NAME. Inventory edits did NOT take effect."
    err "Files to review:"
    say "  $INVENTORY"
    say "  $HV"
    exit 1
fi
ok "ansible-inventory sees $NAME in: $(ansible-inventory --host "$NAME" 2>/dev/null | grep -oE '"group_names":[^]]*\]' || echo "(unknown)")"

fi  # end of !RETRY data-collection block

# ---------- bootstrap (if needed) ----------
if [[ $NEEDS_BOOTSTRAP -eq 1 ]]; then
    info "Running bootstrap.yml --limit $NAME (pushing SSH key over password auth)"
    if ! ansible-playbook "$BOOTSTRAP" --limit "$NAME"; then
        err "bootstrap.yml failed. Inventory and host_vars have NOT been rolled back."
        say "  Investigate, fix the issue, then either:"
        say "    - re-run: ansible-playbook bootstrap.yml --limit $NAME"
        say "    - or revert: rm $HV  and  remove $NAME lines from inventory.ini"
        exit 1
    fi
    ok "SSH key installed on $NAME"

    info "Stripping ansible_password from $HV (key auth from now on)"
    # Surgical awk removal: drops the 'ansible_password:' line plus the indented
    # vault continuation lines that follow it. Preserves any hand-edits the user
    # made to the file. Works in both fresh-add and retry modes.
    _tmp="$(mktemp)"
    awk '
        /^ansible_password:/      { skip=1; next }
        skip && /^[[:space:]]/    { next }
        skip                      { skip=0 }
        { print }
    ' "$HV" > "$_tmp"
    mv "$_tmp" "$HV"
    chmod 640 "$HV"
    ok "ansible_password removed; host_vars now contains only ansible_become_password"
fi

# ---------- final verification ----------
info "Verifying connectivity ($NAME via SSH key)"
if ansible "$NAME" -m ping; then
    ok "Ping OK"
else
    err "Ping failed. Check ~/.ssh/id_ed25519 is authorized on $ADDR and that"
    err "sudo access works with the supplied password."
    exit 1
fi

info "Verifying sudo access (privileged ping)"
if ansible "$NAME" -m ping -b; then
    ok "Sudo OK"
else
    err "Privileged ping failed. The vault-encrypted sudo password may be wrong."
    err "Re-run encrypt_string for ansible_become_password and update $HV."
    exit 1
fi

echo
hr
ok "${C_BOLD}$NAME${C_RESET} is onboarded."
hr
hint "Try it:"
hint "  ansible $NAME -a 'uptime'"
hint "  ansible-playbook update.yml --limit $NAME"
hint "Or run against the whole group:"
hint "  ansible-playbook update.yml --limit ${PICKED_GROUPS[0]}"
