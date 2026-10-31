#!/usr/bin/env bash
# Deploys a release archive with an atomic symlink switch, then health-checks
# it and rolls back automatically if the check fails.
#
# Layout on the server:
#   /var/www/<app>/
#     releases/<timestamp>/   one folder per deploy
#     shared/.env             kept across deploys, linked into each release
#     current -> releases/<timestamp>
#
# Usage (on the server, as the deploy user):
#   deploy.sh --app my-app --archive /tmp/release.tar.gz [options]
#
# Options:
#   --app NAME          app folder name under --base (required)
#   --archive PATH      .tar.gz of the build to deploy (required)
#   --type TYPE         static | node (default: static)
#   --pm2-name NAME     PM2 process to start/reload (node apps; default: --app)
#   --health-url URL    URL that must return 2xx after the switch
#   --keep N            releases to keep (default: 5)
#   --base DIR          apps root (default: /var/www)
set -euo pipefail

APP=""; ARCHIVE=""; TYPE="static"; PM2_NAME=""; HEALTH_URL=""; KEEP=5; BASE="/var/www"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app) APP="$2"; shift 2 ;;
    --archive) ARCHIVE="$2"; shift 2 ;;
    --type) TYPE="$2"; shift 2 ;;
    --pm2-name) PM2_NAME="$2"; shift 2 ;;
    --health-url) HEALTH_URL="$2"; shift 2 ;;
    --keep) KEEP="$2"; shift 2 ;;
    --base) BASE="$2"; shift 2 ;;
    -h|--help) sed -n '2,24p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

[[ -n "$APP" && -n "$ARCHIVE" ]] || { echo "--app and --archive are required" >&2; exit 1; }
[[ "$TYPE" == "static" || "$TYPE" == "node" ]] || { echo "--type must be static or node" >&2; exit 1; }
[[ -f "$ARCHIVE" ]] || { echo "Archive not found: $ARCHIVE" >&2; exit 1; }
PM2_NAME="${PM2_NAME:-$APP}"

APP_DIR="$BASE/$APP"
RELEASES="$APP_DIR/releases"
SHARED="$APP_DIR/shared"
RELEASE_ID="$(date -u +%Y%m%d%H%M%S)"
RELEASE="$RELEASES/$RELEASE_ID"

log() { printf '==> %s\n' "$*"; }

# Points `current` at a release in one atomic rename, so visitors never see a half-switched app
switch_to() {
  ln -sfn "$1" "$APP_DIR/current.next"
  mv -Tf "$APP_DIR/current.next" "$APP_DIR/current"
}

reload_app() {
  [[ "$TYPE" == "node" ]] || return 0
  if pm2 describe "$PM2_NAME" >/dev/null 2>&1; then
    pm2 reload "$PM2_NAME" --update-env
  elif [[ -f "$APP_DIR/current/ecosystem.config.cjs" ]]; then
    (cd "$APP_DIR/current" && pm2 start ecosystem.config.cjs)
  else
    pm2 start npm --name "$PM2_NAME" --cwd "$APP_DIR/current" -- start
  fi
  pm2 save >/dev/null
}

healthy() {
  [[ -n "$HEALTH_URL" ]] || return 0
  for attempt in $(seq 1 10); do
    if curl -fsS -o /dev/null --max-time 5 "$HEALTH_URL"; then
      log "Health check passed ($HEALTH_URL)"
      return 0
    fi
    log "Health check attempt $attempt/10 failed; retrying in 3s"
    sleep 3
  done
  return 1
}

mkdir -p "$RELEASES" "$SHARED"

if [[ -e "$RELEASE" ]]; then
  echo "Release $RELEASE_ID already exists; wait a second and deploy again." >&2
  exit 1
fi

log "Unpacking release $RELEASE_ID"
mkdir "$RELEASE"
tar -xzf "$ARCHIVE" -C "$RELEASE"

if [[ -f "$SHARED/.env" ]]; then
  ln -sfn "$SHARED/.env" "$RELEASE/.env"
fi

if [[ "$TYPE" == "node" ]]; then
  log "Installing production dependencies"
  (cd "$RELEASE" && npm ci --omit=dev --no-audit --no-fund)
fi

PREVIOUS="$(readlink "$APP_DIR/current" 2>/dev/null || true)"

log "Switching current -> releases/$RELEASE_ID"
switch_to "$RELEASE"
reload_app

if ! healthy; then
  echo "Health check failed for release $RELEASE_ID" >&2
  if [[ -n "$PREVIOUS" && -d "$PREVIOUS" ]]; then
    log "Rolling back to $(basename "$PREVIOUS")"
    switch_to "$PREVIOUS"
    reload_app
  else
    # First deploy: nothing to roll back to, so don't leave `current` pointing at a removed release
    rm -f "$APP_DIR/current"
  fi
  rm -rf "$RELEASE"
  exit 1
fi

log "Pruning old releases (keeping $KEEP)"
# Release folder names are UTC timestamps, so a name sort is a time sort
mapfile -t ALL < <(find "$RELEASES" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort -r)
for old in "${ALL[@]:$KEEP}"; do
  rm -rf "${RELEASES:?}/$old"
done

log "Deployed $APP release $RELEASE_ID"
