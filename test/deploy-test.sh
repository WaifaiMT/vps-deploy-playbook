#!/usr/bin/env bash
# End-to-end test of deploy.sh and rollback.sh for a static site, in a temp
# directory (no server, PM2, or Nginx needed). Run: bash test/deploy-test.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEPLOY="$ROOT/scripts/deploy.sh"
ROLLBACK="$ROOT/scripts/rollback.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
BASE="$WORK/www"
APP_DIR="$BASE/site"

pass=0
check() {
  local name="$1"; shift
  if "$@"; then
    echo "  ok   $name"; pass=$((pass + 1))
  else
    echo "  FAIL $name" >&2; exit 1
  fi
}

# Builds a fake site archive whose index.html says which version it is
make_archive() {
  local version="$1" dir="$WORK/build-$1"
  mkdir -p "$dir"
  echo "<h1>version $version</h1>" > "$dir/index.html"
  tar -czf "$WORK/v$version.tar.gz" -C "$dir" .
}

live_version() { cat "$APP_DIR/current/index.html"; }
release_count() { find "$APP_DIR/releases" -mindepth 1 -maxdepth 1 -type d | wc -l; }

for v in 1 2 3 4; do make_archive "$v"; done
mkdir -p "$APP_DIR/shared"
echo "SECRET=1" > "$APP_DIR/shared/.env"

echo "deploy.sh"
bash "$DEPLOY" --app site --archive "$WORK/v1.tar.gz" --base "$BASE" --keep 2 >/dev/null
check "first deploy goes live" grep -q "version 1" "$APP_DIR/current/index.html"
check "current is a symlink" test -L "$APP_DIR/current"
check "shared .env is linked into the release" test -L "$APP_DIR/current/.env"

sleep 1
bash "$DEPLOY" --app site --archive "$WORK/v2.tar.gz" --base "$BASE" --keep 2 >/dev/null
check "second deploy goes live" grep -q "version 2" "$APP_DIR/current/index.html"

sleep 1
if bash "$DEPLOY" --app site --archive "$WORK/v3.tar.gz" --base "$BASE" --keep 2 \
     --health-url "http://127.0.0.1:9/unreachable" >/dev/null 2>&1; then
  echo "  FAIL failed health check should exit non-zero" >&2; exit 1
fi
check "failed health check rolls back to version 2" grep -q "version 2" "$APP_DIR/current/index.html"
check "failed release is removed" test "$(release_count)" -eq 2

sleep 1
bash "$DEPLOY" --app site --archive "$WORK/v4.tar.gz" --base "$BASE" --keep 2 >/dev/null
check "third successful deploy goes live" grep -q "version 4" "$APP_DIR/current/index.html"
check "old releases are pruned to --keep 2" test "$(release_count)" -eq 2

echo "rollback.sh"
bash "$ROLLBACK" --app site --base "$BASE" >/dev/null
check "rollback restores version 2" grep -q "version 2" "$APP_DIR/current/index.html"
if bash "$ROLLBACK" --app site --base "$BASE" >/dev/null 2>&1; then
  echo "  FAIL rollback past the oldest kept release should fail" >&2; exit 1
fi
check "rollback stops at the oldest kept release" grep -q "version 2" "$APP_DIR/current/index.html"

echo "first-deploy failure"
FRESH="$WORK/fresh"
if bash "$DEPLOY" --app new --archive "$WORK/v1.tar.gz" --base "$FRESH" \
     --health-url "http://127.0.0.1:9/unreachable" >/dev/null 2>&1; then
  echo "  FAIL failed first deploy should exit non-zero" >&2; exit 1
fi
check "no dangling current link after a failed first deploy" test ! -e "$FRESH/new/current" -a ! -L "$FRESH/new/current"

echo "All $pass checks passed."
