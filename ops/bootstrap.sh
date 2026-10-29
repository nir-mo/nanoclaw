#!/usr/bin/env bash
# One-command deploy for this fork. Run this on the host instead of a pile of
# manual steps — it does everything:
#
#   1. sets the box timezone (so cron + logs are local, DST-safe)
#   2. runs upstream setup (deps, Docker, WhatsApp pairing, ...)
#   3. turns on continuous auto-compaction (keeps the session small on its own —
#      replaces any "nightly compact"; NanoClaw compacts whenever context fills)
#   4. installs the ops cron jobs (security updates, file cleanup, update check)
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

# 2. Upstream setup (interactive on first run).
bash ./nanoclaw.sh "$@"

# 3. Continuous auto-compaction. NanoClaw's agent-runner reads this from .env.
if [ -f .env ] && ! grep -q '^CLAUDE_CODE_AUTO_COMPACT_WINDOW=' .env; then
  echo "[bootstrap] enabling auto-compaction at ${COMPACT_WINDOW} tokens"
  printf '\n# Auto-compact the session when it reaches this many tokens.\nCLAUDE_CODE_AUTO_COMPACT_WINDOW=%s\n' "$COMPACT_WINDOW" >> .env
fi

# 4. Ops cron jobs.
bash ./ops/install-cron.sh

echo ""
echo "[bootstrap] done — everything wired in one run:"
echo "  timezone        : $TZ_NAME"
echo "  auto-compaction : ~${COMPACT_WINDOW} tokens (continuous — no nightly compact needed)"
echo "  cron            : security updates + session file cleanup + update check"
echo ""
echo "Instant hard reset of the conversation: send /new to the bot in chat."
