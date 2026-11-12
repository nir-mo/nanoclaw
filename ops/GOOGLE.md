# Google integration (Calendar / Gmail / Sheets) via OneCLI

The bot reaches Google through **OneCLI's built-in managed connectors**, not a
separate MCP server. The agent calls Google APIs and OneCLI (the credential
gateway already running on the box) injects the OAuth token. This is the native
NanoClaw path — the agent prefers it automatically.

> A standalone Google MCP server (`taylorwilsdon/google_workspace_mcp`) was
> tried first and **removed** — it was redundant once we found the OneCLI
> connector. Don't re-add it; it just creates a second, competing Google
> integration.

## One-time setup

### 1. OAuth client (Google Cloud, bot account)
- A **Desktop** OAuth client in the bot account's Google Cloud project
  (named `Openclaw-google-helper`), marked **"Use this client for an AI-powered
  agent"** (agentic).
- APIs enabled: **Gmail, Calendar, Drive, Sheets**.
- The client id/secret live only in OneCLI's vault + its config on the box —
  **never commit them** (this repo is public).
- The app is in **Testing** publishing status → see *Weekly reconnect* below.

### 2. APP_URL must be loopback (the one non-obvious fix)
OneCLI defaults its public URL to the docker-bridge IP (`http://172.17.0.1:10254`).
**Google refuses OAuth callbacks to private IPs**, so connecting a Google account
fails with *"Access blocked … device_id and device_name are required for private
IP."* Loopback (`127.0.0.1`) is allowed for Desktop clients and still reaches
OneCLI through the SSH tunnel.

Fixed by setting `APP_URL=http://127.0.0.1:10254` in `~/.onecli/.env` and
restarting OneCLI. **This is automated** by [`onecli-app-url.sh`](onecli-app-url.sh),
which `bootstrap.sh` runs after setup — so a rebuilt box gets it automatically.

## Connecting an account (and reconnecting)

1. Open an SSH tunnel to OneCLI's portal (leave it open):
   ```bash
   ssh -i <key.pem> -L 10254:172.17.0.1:10254 ubuntu@<box>
   ```
2. Ask the bot in chat to connect the service (e.g. "connect my calendar"); it
   replies with a portal link. Open it in a browser on the tunneled machine,
   swapping `172.17.0.1` → `127.0.0.1` if needed:
   ```
   http://127.0.0.1:10254/p/<token>/connections?connect=google-calendar&source=agent&agent_name=Pharaoh
   ```
3. Click **connect**, sign in as the **bot account**, click through the
   "unverified app" warning → **Allow**. The redirect lands on `127.0.0.1:10254`
   via the tunnel and the connection saves.

Gmail and Sheets connect the same way (`connect=gmail`, `connect=google-sheets`).

## Weekly reconnect (the known limitation)

The OAuth app is in **Testing** mode, so Google **expires its refresh token
every 7 days**. When that happens the bot can't reach Google and will tell you,
with a fresh connect link. **Reconnecting is just re-authorizing** (the steps
above) — ~1 minute, no rebuild, no reconfiguration. You don't track the date;
the bot prompts you.

To eliminate the weekly reconnect (neither done — both have real costs):
- **Publish the OAuth app** → needs a domain you own + Google verification
  (the `gmail.readonly` scope is "restricted", triggering a review).
- **Service account** → never expires, but only works for Calendar/Sheets/Drive
  (shared with the service account), **not** consumer Gmail.

## Scopes granted
Gmail: read-only · Calendar: read/write · Sheets: read/write · Drive: file-level.
Everything runs on the **bot's own account**; your personal calendar is shared
*into* it, so the blast radius is a throwaway account.
