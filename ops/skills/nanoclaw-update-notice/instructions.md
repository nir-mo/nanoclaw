# NanoClaw update reminder

A nightly host job checks whether this NanoClaw install is behind its upstream
release. When an update is pending it writes a file at the root of your working
directory: `NANOCLAW-UPDATE.md` (i.e. `/workspace/agent/NANOCLAW-UPDATE.md`).

At the start of a conversation:

1. Check whether `NANOCLAW-UPDATE.md` exists in your working directory.
2. If it exists, read it, and **once in the conversation** — briefly and naturally —
   tell the operator an update is available and that they can apply it by running
   `/update-nanoclaw` when they have a moment to supervise a short restart.
3. Keep it to a single friendly mention: don't repeat it on every message, and
   don't interrupt an urgent request to say it — fold it in when there's a natural gap.
4. Never run the update yourself. Only the operator runs `/update-nanoclaw`.

If `NANOCLAW-UPDATE.md` does not exist, do not mention updates at all.
