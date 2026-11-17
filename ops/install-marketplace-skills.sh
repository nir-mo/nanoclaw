#!/usr/bin/env bash
# Install the skills listed in my Claude plugin marketplace into
# container/skills/, where NanoClaw auto-discovers them (mounted at /app/skills).
# marketplace.json is the manifest: publish a skill there, re-run this (or
# bootstrap), and the bot carries it. Installed copies are kept out of git via
# .git/info/exclude. Idempotent; needs network.
set -euo pipefail
cd "$(dirname "$0")/.."

MP="${MARKETPLACE_REPO:-https://github.com/nir-mo/claude-marketplace}"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
mkdir -p container/skills

git clone -q --depth 1 "$MP" "$TMP/mp"

# One "name<TAB>owner/repo" line per plugin. Schema is fixed (Claude Code docs):
# {"name": ..., "source": {"source": "github", "repo": "owner/repo"}}
python3 -c '
import json, sys
for p in json.load(open(sys.argv[1]))["plugins"]:
    print(p["name"], p["source"]["repo"], sep="\t")
' "$TMP/mp/.claude-plugin/marketplace.json" |
while IFS=$'\t' read -r name repo; do
  # ponytail: assumes bare-skill repos (SKILL.md at root) and no version pins —
  # handle skills/ layouts and source.sha when a plugin actually uses them.
  echo "[marketplace] $name <- $repo"
  git clone -q --depth 1 "https://github.com/$repo" "$TMP/$name"
  rm -rf "$TMP/$name/.git" "container/skills/$name"
  cp -r "$TMP/$name" "container/skills/$name"
  grep -qxF "container/skills/$name/" .git/info/exclude 2>/dev/null \
    || echo "container/skills/$name/" >> .git/info/exclude
done

echo "[marketplace] done — skills load at next session spawn, no restart needed"
