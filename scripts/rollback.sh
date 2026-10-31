#!/usr/bin/env bash
# Switches an app back to the release before the current one.
#
# Usage (on the server, as the deploy user):
#   rollback.sh --app my-app [--type static|node] [--pm2-name NAME] [--base /var/www]
set -euo pipefail

APP=""; TYPE="static"; PM2_NAME=""; BASE="/var/www"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app) APP="$2"; shift 2 ;;
    --type) TYPE="$2"; shift 2 ;;
    --pm2-name) PM2_NAME="$2"; shift 2 ;;
    --base) BASE="$2"; shift 2 ;;
    -h|--help) sed -n '2,5p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

[[ -n "$APP" ]] || { echo "--app is required" >&2; exit 1; }
PM2_NAME="${PM2_NAME:-$APP}"
APP_DIR="$BASE/$APP"

CURRENT="$(basename "$(readlink "$APP_DIR/current")")"
mapfile -t RELEASES < <(find "$APP_DIR/releases" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)

TARGET=""
for release in "${RELEASES[@]}"; do
  [[ "$release" < "$CURRENT" ]] && TARGET="$release"
done

if [[ -z "$TARGET" ]]; then
  echo "No release older than $CURRENT to roll back to." >&2
  exit 1
fi

ln -sfn "$APP_DIR/releases/$TARGET" "$APP_DIR/current.next"
mv -Tf "$APP_DIR/current.next" "$APP_DIR/current"
echo "==> Rolled back $APP: $CURRENT -> $TARGET"

if [[ "$TYPE" == "node" ]]; then
  pm2 reload "$PM2_NAME" --update-env
  pm2 save >/dev/null
fi
