#!/usr/bin/env bash
# Point OneCLI's public URL (APP_URL) at loopback so Google OAuth callbacks work.
#
# OneCLI defaults APP_URL to the docker-bridge IP (e.g. http://172.17.0.1:10254).
# Google REFUSES OAuth redirect callbacks to private IPs, so connecting a Google
# account (Calendar/Gmail/Sheets via OneCLI) fails at consent with:
#   "Access blocked ... device_id and device_name are required for private IP".
# Loopback (127.0.0.1) is allowed for Desktop OAuth clients, and it still reaches
# OneCLI through the SSH tunnel used to open the connect portal. See ops/GOOGLE.md.
#
# Idempotent; safe to re-run. No-op if OneCLI isn't set up yet.
set -euo pipefail

ENV_FILE="$HOME/.onecli/.env"
WANT='APP_URL=http://127.0.0.1:10254'

if [ ! -f "$ENV_FILE" ]; then
  echo "[onecli-app-url] $ENV_FILE not found — OneCLI not set up yet, skipping"
  exit 0
fi

if grep -qx "$WANT" "$ENV_FILE"; then
  echo "[onecli-app-url] already set"
  exit 0
fi

if grep -q '^APP_URL=' "$ENV_FILE"; then
  sed -i "s|^APP_URL=.*|$WANT|" "$ENV_FILE"
else
  echo "$WANT" >> "$ENV_FILE"
fi

echo "[onecli-app-url] set $WANT — restarting OneCLI"
if ! ( cd "$HOME/.onecli" && docker compose up -d >/dev/null 2>&1 ); then
  echo "[onecli-app-url] restart failed — run manually: cd ~/.onecli && docker compose up -d"
fi
echo "[onecli-app-url] done"
