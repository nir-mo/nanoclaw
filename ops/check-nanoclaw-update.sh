#!/usr/bin/env bash
# Notify-only check for NanoClaw upstream updates. Does NOT apply them.
#
# NanoClaw must be updated through its supported transactional flow
# (/update-nanoclaw): clean checkout, staged worktree, dependency install, tests,
# migration gates, state snapshot, and automatic rollback on failure. A raw
# `git pull` trips the startup tripwire (data/upgrade-state.json) and the host
# refuses to start (see docs/upgrade-recovery.md).
#
# So this job only *tells you* an update exists — two ways:
#   1. writes logs/nanoclaw-update-available (operator-facing marker file), and
#   2. drops NANOCLAW-UPDATE.md into each group folder. That folder is mounted
#      into the agent at /workspace/agent, and the `nanoclaw-update-notice` skill
#      tells the agent to surface it to you in chat next time you message the bot
#      — reactive and during the day, not a 3am ping. Removed again once current.
# You apply it by running /update-nanoclaw when you can supervise it.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
mkdir -p "$ROOT/logs"

NOTICE="NANOCLAW-UPDATE.md"
GROUPS_DIR="$ROOT/groups"

# Write (arg given) or clear (no arg) the in-chat notice in every group folder.
# Plain file in a mounted data dir — no DB/mailbox writes, so none of the
# container-ownership fragility that rules out sending messages from here.
sync_group_notice() {
  [ -d "$GROUPS_DIR" ] || return 0
  local g
  for g in "$GROUPS_DIR"/*/; do
    [ -d "$g" ] || continue
    if [ "$#" -gt 0 ] && [ -n "$1" ]; then
      printf '%s\n' "$1" > "$g$NOTICE"
    else
      rm -f "$g$NOTICE"
    fi
  done
}

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
  sync_group_notice "# NanoClaw update available

- Behind upstream by: **$behind commit(s)**
- As of: $ts
- Action: the operator can apply it by running \`/update-nanoclaw\` in this chat,
  when they can supervise a brief restart. Do not git pull."
else
  echo "[$ts] NanoClaw is up to date with ${upstream}/main."
  rm -f "$marker"
  sync_group_notice
fi
