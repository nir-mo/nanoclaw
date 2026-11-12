#!/usr/bin/env bash
# One-command deploy for this fork. Run this on the host instead of a pile of
# manual steps — it does everything:
#
#   1. sets the box timezone (so cron + logs are local, DST-safe)
#   2. makes Docker usable by this user (prevents the first-start docker.sock crash)
#   3. runs upstream setup (deps, WhatsApp pairing, ...)
#   4. points OneCLI's APP_URL at loopback (so Google OAuth callbacks work — see ops/GOOGLE.md)
#   5. turns on continuous auto-compaction (keeps the session small on its own —
#      replaces any "nightly compact"; NanoClaw compacts whenever context fills)
#   6. installs the ops cron jobs (security updates, file cleanup, update check)
#
# Re-runnable. Override the defaults with env vars, e.g.:
#   TZ_NAME=UTC COMPACT_WINDOW=60000 bash ops/bootstrap.sh
#
# It does NOT force a nightly "new session" — that isn't cleanly supported from
# the host (the reset commands are chat-side). Auto-compaction keeps context
# bounded; send /new to the bot in chat for an instant hard reset.
set -euo pipefail

TZ_NAME="${TZ_NAME:-Asia/Jerusalem}"        # box timezone
COMPACT_WINDOW="${COMPACT_WINDOW:-80000}"   # auto-compact threshold (tokens).
                                            # Lower = compact sooner = smaller,
                                            # cheaper context per message. Tune.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# 1. Timezone.
if command -v timedatectl >/dev/null 2>&1; then
  echo "[bootstrap] timezone -> $TZ_NAME"
  sudo timedatectl set-timezone "$TZ_NAME"
  sudo systemctl restart cron 2>/dev/null || true
fi

# 2. Docker preflight. NanoClaw needs Docker usable by THIS user before its
#    first start, or it crash-loops on "permission denied ... /var/run/docker.sock"
#    and setup aborts at the WhatsApp restart step. install-docker.sh is
#    idempotent (nanoclaw.sh skips its own install when Docker is already here).
#    usermod is the durable fix (active after next login/boot); setfacl —
#    upstream's own remediation (setup/service.ts, setup/auto.ts) — grants access
#    THIS session so setup finishes in one pass, no reboot.
if ! command -v docker >/dev/null 2>&1; then
  echo "[bootstrap] installing Docker..."
  bash ./setup/install-docker.sh || { echo "[bootstrap] Docker install failed — see output above"; exit 1; }
fi
sudo systemctl enable --now docker 2>/dev/null || true
sudo usermod -aG docker "$USER" 2>/dev/null || true
if ! docker info >/dev/null 2>&1; then
  command -v setfacl >/dev/null 2>&1 || sudo apt-get install -y acl >/dev/null 2>&1 || true
  sudo setfacl -m "u:$USER:rw" /var/run/docker.sock 2>/dev/null || true
fi
if docker info >/dev/null 2>&1; then
  echo "[bootstrap] docker: usable"
else
  echo "[bootstrap] docker is installed but not usable by $USER this session."
  echo "[bootstrap] reboot, then re-run:  sudo reboot  then  cd ~/nanoclaw && bash ops/bootstrap.sh"
  exit 1
fi

# 3. Upstream setup (interactive on first run).
bash ./nanoclaw.sh "$@"

# 4. OneCLI public URL -> loopback, so Google OAuth callbacks work (Google blocks
#    callbacks to the docker-bridge private IP OneCLI uses by default). See ops/GOOGLE.md.
bash ./ops/onecli-app-url.sh || true

# 5. Continuous auto-compaction. NanoClaw's agent-runner reads this from .env.
if [ -f .env ] && ! grep -q '^CLAUDE_CODE_AUTO_COMPACT_WINDOW=' .env; then
  echo "[bootstrap] enabling auto-compaction at ${COMPACT_WINDOW} tokens"
  printf '\n# Auto-compact the session when it reaches this many tokens.\nCLAUDE_CODE_AUTO_COMPACT_WINDOW=%s\n' "$COMPACT_WINDOW" >> .env
fi

# 6. Ops cron jobs.
bash ./ops/install-cron.sh

echo ""
echo "[bootstrap] done — everything wired in one run:"
echo "  timezone        : $TZ_NAME"
echo "  docker          : usable by $USER"
echo "  onecli APP_URL  : loopback (Google OAuth callbacks work)"
echo "  auto-compaction : ~${COMPACT_WINDOW} tokens (continuous — no nightly compact needed)"
echo "  cron            : security updates + session file cleanup + update check"
echo ""
echo "Google setup + weekly reconnect: see ops/GOOGLE.md"
echo "Instant hard reset of the conversation: send /new to the bot in chat."
