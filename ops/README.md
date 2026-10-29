# ops/

Operational cron jobs for this NanoClaw install. **Local customization**, kept
in its own directory so upstream merges never touch it (nothing in `nanocoai/
nanoclaw` lives under `ops/`).

## Two layers — put each job in the right one

| Layer | For | Cost |
|---|---|---|
| **System cron** (this dir) | Machine ops — OS updates, file cleanup, update checks | No model call, **no tokens** |
| **`ncl tasks`** (NanoClaw) | Agent work — briefings, triage, anything needing the LLM | **Burns tokens per run** (has a 4/24h cap + script gates) |

Rule: if the work is "run a shell command / manage the box," it's system cron
(here). If it's "have the agent think," it's an `ncl task` (see
`docs/scheduled-tasks.md`). Never manage machine lifecycle from an `ncl task`.

## The jobs

| Script | Schedule | Mode | What it does |
|---|---|---|---|
| `nightly-security-updates.sh` | 03:17 daily | **auto-apply** | OS security updates via `unattended-upgrades`. Flags (never forces) a reboot. Needs passwordless sudo. |
| `../scripts/cleanup-sessions.sh` | 03:42 daily | **auto** | Prunes stale session JSONLs/logs/todos/telemetry (>3–7d). Never deletes the active session. |
| `check-nanoclaw-update.sh` | 04:07 daily | **notify-only** | Reports if upstream NanoClaw is ahead. Does **not** apply — see below. |

## Why NanoClaw updates are notify-only

NanoClaw must be updated through its supported transactional flow
(`/update-nanoclaw`): clean checkout, staged worktree, dependency install, tests,
migration gates, state snapshot, auto-rollback. A raw `git pull` trips the
startup tripwire and the host refuses to start (`docs/upgrade-recovery.md`). So
cron only *tells you* an update exists; you apply it by running
`/update-nanoclaw` when you can supervise it. When an update is waiting, the
check writes `logs/nanoclaw-update-available`.

## Install

One command deploys the whole box (timezone + upstream setup + auto-compaction + cron):

```bash
bash ops/bootstrap.sh
```

Override defaults if needed: `TZ_NAME=UTC COMPACT_WINDOW=60000 bash ops/bootstrap.sh`.

Just the cron jobs (idempotent; re-run anytime):

```bash
bash ops/install-cron.sh
```

## Notes

- **Timezone:** cron times are the box's local time. EC2 defaults to **UTC**
  (03:17 UTC ≈ early morning in most of the world). Either adjust the hours in
  `install-cron.sh`, or set the box once: `sudo timedatectl set-timezone <TZ>`.
- **Context stays small automatically — no nightly compact.** NanoClaw
  auto-compacts the live session via `CLAUDE_CODE_AUTO_COMPACT_WINDOW` (set in
  `.env` by `bootstrap.sh`), so it never balloons the way OpenClaw did. The
  nightly `cleanup-sessions.sh` is *disk* hygiene only — it prunes old artifacts,
  it does not touch the active conversation.
- **No host-side session reset.** `/new`, `/reset`, `/compact` are chat commands
  — send `/new` to the bot for an instant fresh start. There is deliberately no
  cron that force-resets the live session (that would mean poking the session
  SQLite — fragile, and unnecessary given auto-compaction).
- **Logs** land in `logs/` (gitignored). Check `logs/ops-*.log`.
- **Secrets:** never put credentials in these scripts. The security job uses
  sudo; the update check uses only git. Nothing here should hold a secret.
