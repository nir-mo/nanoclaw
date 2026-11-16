---
name: nanoclaw-update-notice
description: Standing reminder to tell the operator, in chat, when a NanoClaw update is pending so they can apply it with /update-nanoclaw. Rule-bearing — its instructions.md is always inlined into the project document, so it needs no explicit trigger.
---

# NanoClaw update notice

Carries a standing rule (see `instructions.md`): when the host has flagged that a
NanoClaw update is available, mention it to the operator in chat so they can apply
it with `/update-nanoclaw` during the day, when they can supervise a short restart.

The flag is a file the nightly `ops/check-nanoclaw-update.sh` cron writes into the
group folder (`NANOCLAW-UPDATE.md`) when the install is behind upstream, and removes
once it is current. The agent never applies updates itself — it only relays.
