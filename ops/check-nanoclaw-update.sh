#!/usr/bin/env bash
# Notify-only check for NanoClaw upstream updates. Does NOT apply them.
#
# NanoClaw must be updated through its supported transactional flow
# (/update-nanoclaw): clean checkout, staged worktree, dependency install, tests,
# migration gates, state snapshot, and automatic rollback on failure. A raw
# `git pull` trips the startup tripwire (data/upgrade-state.json) and the host
# refuses to start (see docs/upgrade-recovery.md).
#
# So this job only *tells you* an update exists. You apply it by running
# /update-nanoclaw when you can supervise it.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
mkdir -p "$ROOT/logs"

# Ensure an `upstream` remote exists (mirrors the update skill's own logic).
if git remote get-url upstream >/dev/null 2>&1; then
  upstream=upstream
elif git remote get-url origin 2>/dev/null | grep -Eq '(^|[:/])nanocoai/nanoclaw(\.git)?$'; then
  upstream=origin
else
  git remote add upstream https://github.com/nanocoai/nanoclaw.git
  upstream=upstream
fi

git fetch "$upstream" --prune --quiet

behind=$(git rev-list --count "HEAD..${upstream}/main" 2>/dev/null || echo 0)
ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
marker="$ROOT/logs/nanoclaw-update-available"

if [ "$behind" -gt 0 ]; then
  echo "[$ts] NanoClaw update available: $behind commit(s) behind ${upstream}/main."
  echo "[$ts] Apply via the supported flow — run /update-nanoclaw (do NOT git pull)."
  echo "$behind commits behind as of $ts" > "$marker"
else
  echo "[$ts] NanoClaw is up to date with ${upstream}/main."
  rm -f "$marker"
fi
