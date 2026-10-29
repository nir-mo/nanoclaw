#!/usr/bin/env bash
# Install the NanoClaw ops cron jobs (system-cron layer: no agent, no tokens).
# Idempotent — re-running replaces the '# nanoclaw-ops' lines and keeps any
# other crontab entries you have.
#
#   OS security updates      -> ops/nightly-security-updates.sh  (auto-applies)
#   Context/session cleanup  -> scripts/cleanup-sessions.sh      (prunes stale files)
#   NanoClaw update check     -> ops/check-nanoclaw-update.sh      (NOTIFY ONLY)
#
# Times are LOCAL to the box. EC2 defaults to UTC — see ops/README.md.
set -euo pipefail

OPS_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$OPS_DIR")"
mkdir -p "$ROOT/logs"
chmod +x "$OPS_DIR"/*.sh 2>/dev/null || true
chmod +x "$ROOT/scripts/cleanup-sessions.sh" 2>/dev/null || true

TMP="$(mktemp)"
# Preserve existing crontab lines that aren't ours.
crontab -l 2>/dev/null | grep -v '# nanoclaw-ops' > "$TMP" || true
cat >> "$TMP" <<EOF
17 3 * * * $OPS_DIR/nightly-security-updates.sh >> $ROOT/logs/ops-security.log 2>&1 # nanoclaw-ops
42 3 * * * $ROOT/scripts/cleanup-sessions.sh >> $ROOT/logs/ops-cleanup.log 2>&1 # nanoclaw-ops
7 4 * * * $OPS_DIR/check-nanoclaw-update.sh >> $ROOT/logs/ops-update-check.log 2>&1 # nanoclaw-ops
EOF
crontab "$TMP"
rm -f "$TMP"

echo "Installed nanoclaw ops cron jobs:"
crontab -l | grep '# nanoclaw-ops' || true
echo ""
echo "Times are in this box's timezone ($(date +%Z)). EC2 defaults to UTC."
