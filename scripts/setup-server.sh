#!/usr/bin/env bash
# One-time setup for a fresh Ubuntu 22.04/24.04 VPS: deploy user, firewall,
# Node.js, PM2, Nginx, and Certbot.
#
# Usage (as root):
#   sudo bash setup-server.sh --deploy-user deploy --node-version 22 --ssh-key "ssh-ed25519 AAAA... ci"
#
# Options:
#   --deploy-user NAME   user that CI logs in as (default: deploy)
#   --node-version N     Node.js major version (default: 22)
#   --ssh-key "KEY"      public key to authorize for the deploy user (repeatable)
#   --harden-ssh         disable root login and password logins over SSH.
#                        Only use once you've confirmed key login works.
set -euo pipefail

DEPLOY_USER="deploy"
NODE_VERSION="22"
HARDEN_SSH=false
SSH_KEYS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --deploy-user) DEPLOY_USER="$2"; shift 2 ;;
    --node-version) NODE_VERSION="$2"; shift 2 ;;
    --ssh-key) SSH_KEYS+=("$2"); shift 2 ;;
    --harden-ssh) HARDEN_SSH=true; shift ;;
    -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [[ $EUID -ne 0 ]]; then
  echo "Run as root (sudo)." >&2
  exit 1
fi

log() { printf '\n==> %s\n' "$*"; }

log "Updating packages"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y
apt-get install -y curl ca-certificates gnupg git ufw nginx certbot python3-certbot-nginx

log "Installing Node.js ${NODE_VERSION}.x"
if ! command -v node >/dev/null || [[ "$(node -v)" != v${NODE_VERSION}.* ]]; then
  curl -fsSL "https://deb.nodesource.com/setup_${NODE_VERSION}.x" | bash -
  apt-get install -y nodejs
fi
node -v

log "Installing PM2"
npm install -g pm2

log "Creating deploy user '${DEPLOY_USER}'"
if ! id "$DEPLOY_USER" >/dev/null 2>&1; then
  adduser --disabled-password --gecos "" "$DEPLOY_USER"
fi
install -d -m 700 -o "$DEPLOY_USER" -g "$DEPLOY_USER" "/home/${DEPLOY_USER}/.ssh"
AUTH_KEYS="/home/${DEPLOY_USER}/.ssh/authorized_keys"
touch "$AUTH_KEYS"
for key in "${SSH_KEYS[@]}"; do
  grep -qxF "$key" "$AUTH_KEYS" || echo "$key" >> "$AUTH_KEYS"
done
chown "$DEPLOY_USER:$DEPLOY_USER" "$AUTH_KEYS"
chmod 600 "$AUTH_KEYS"

log "Creating /var/www owned by ${DEPLOY_USER}"
install -d -o "$DEPLOY_USER" -g "$DEPLOY_USER" /var/www

log "Installing deploy.sh and rollback.sh into /home/${DEPLOY_USER}/bin"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
install -d -o "$DEPLOY_USER" -g "$DEPLOY_USER" "/home/${DEPLOY_USER}/bin"
for script in deploy.sh rollback.sh; do
  install -m 755 -o "$DEPLOY_USER" -g "$DEPLOY_USER" "$SCRIPT_DIR/$script" "/home/${DEPLOY_USER}/bin/$script"
done

log "Allowing ${DEPLOY_USER} to test and reload Nginx without a password"
cat > "/etc/sudoers.d/${DEPLOY_USER}-nginx" <<EOF
${DEPLOY_USER} ALL=(root) NOPASSWD: /usr/sbin/nginx -t, /usr/bin/systemctl reload nginx
EOF
chmod 440 "/etc/sudoers.d/${DEPLOY_USER}-nginx"
visudo -cf "/etc/sudoers.d/${DEPLOY_USER}-nginx"

log "Starting PM2 on boot for ${DEPLOY_USER}"
env PATH="$PATH" pm2 startup systemd -u "$DEPLOY_USER" --hp "/home/${DEPLOY_USER}" >/dev/null

log "Configuring the firewall (SSH, HTTP, HTTPS)"
ufw allow OpenSSH
ufw allow 'Nginx Full'
ufw --force enable

systemctl enable --now nginx

if [[ "$HARDEN_SSH" == true ]]; then
  log "Hardening SSH (no root login, no passwords)"
  cat > /etc/ssh/sshd_config.d/99-hardening.conf <<'EOF'
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
EOF
  sshd -t
  systemctl reload ssh 2>/dev/null || systemctl reload sshd
fi

log "Done"
cat <<EOF

Next steps:
  1. Confirm you can log in:  ssh ${DEPLOY_USER}@<server-ip>
  2. Add an Nginx site from nginx/ and run:  sudo nginx -t && sudo systemctl reload nginx
  3. Get a certificate:  sudo certbot --nginx -d example.com -d www.example.com
  4. Re-run with --harden-ssh once key login works.
EOF
