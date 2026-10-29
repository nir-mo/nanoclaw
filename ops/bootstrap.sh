#!/usr/bin/env bash
# One-command deploy for this fork: upstream setup + local ops cron jobs.
#
# Run this INSTEAD of `bash nanoclaw.sh` so a fresh box (or a rebuild) installs
# everything in one go. It leaves upstream's nanoclaw.sh untouched — no edits to
# tracked upstream files, so `/update-nanoclaw` and upstream syncs never conflict.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

bash ./nanoclaw.sh "$@"        # upstream interactive setup (installs deps, pairs WhatsApp, ...)
bash ./ops/install-cron.sh     # our system-cron jobs (idempotent)

echo ""
echo "Bootstrap complete: NanoClaw setup + ops cron installed."
