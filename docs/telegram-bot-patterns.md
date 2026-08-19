# Telegram Long-Poll Bot — Operational Patterns

Hard-won patterns from running production Telegram bots on a 24/7 cloud VM
(agent gateway + client-facing bots). Each item below is a real incident
lesson, not theory.

## Core rules

1. **ONE poller per bot token.** Two processes calling `getUpdates` with the
   same token → `HTTP 409 Conflict` on one of them. Telegram only serves the
   poller that holds the current offset. When migrating or duplicating a bot
   across hosts, verify only ONE instance runs — check EVERY host.

2. **409 ≠ always a duplicate poller.** Before hunting for a duplicate
   process, check for an active **webhook**:
   ```bash
   curl "https://api.telegram.org/bot$TOKEN/getWebhookInfo"
   # if url is non-empty:
   curl "https://api.telegram.org/bot$TOKEN/deleteWebhook?drop_pending_updates=true"
   ```
   A stale webhook blocks long-polling with 409 and looks exactly like a
   duplicate-instance conflict. Check the webhook FIRST — it's a one-call fix.

### Telling a webhook storm from a resource problem (the cliff rule)

A 409 storm is sneaky: it looks like a resource issue, and under real load
you DO get genuine 409s — so the logs aren't fully lying. **The discriminator
is timing pattern, not volume:**

- **Resource degradation** → errors climb/fall **proportionally** with load
  (rate limits, memory, connection pool). No single time bucket dominates.
- **Stale webhook storm** → errors **cliff**: continuous 409s from the moment
  the webhook was set, so one minute bucket carries the majority of errors.

Use `scripts/telegram_409_diagnose.py` — it checks `getWebhookInfo` first,
then classifies the log timeline (cliff vs proportional) and prints a
diagnosis line your alert system can include verbatim, so the alert tells you
which type it is before you chase the wrong thing.

*(Pattern credit: Dineshkumar Kannan, Platform Technical Lead.)*

3. **Watchdog pattern:** cron `*/5 * * * *` running a `watchdog.sh` that does
   `pgrep -f "python3 bot.py" || restart`. The pgrep pattern MUST match the
   real process cmdline. Before stopping a bot for migration, REMOVE its
   watchdog cron first — otherwise it resurrects and conflicts with the new
   host.

4. **bot.log mtime is NOT liveness.** A background instance writes to its
   pipe, not the file. Verify with `ps aux | grep "[b]ot.py"` or a health
   endpoint, not file timestamps.

5. **Retry-hardened sends:** a `send()` wrapper with 3× retry + backoff.
   Transient DNS/network errors lose replies permanently — `getUpdates` pends
   server-side, but a failed `sendMessage` is gone.

## Startup

- Rapid `setMyName` / `setMyDescription` / `setMyCommands` calls can 429.
  Profile setup should be best-effort; polling starts anyway.
- Wrap the whole update loop in try/except with a short sleep so a single bad
  update can't kill the process.

## Multi-language (Arabic + English)

- Detect language from the message script, store `langs[chat_id]`, and reuse
  it for callback-button presses — callbacks are ASCII and carry no language.
- **Never name a reply string the same as its keyword set.** The tuple
  definition overwrites the string (a real bug — guard with a route() test).

## Testing

- Monkeypatch `send`/`answer_cb` to no-ops, `reset()` state dicts per case,
  and run multi-turn flows through `route()` WITHOUT reset between turns
  (reset kills the state machine).
- After any restart: check the startup line in the log, `ps` the process, and
  send a real message (or have the owner test with a second account).

## Incident history (real)

- **409 storm:** 173k conflict errors in the log. Root cause was NOT a
  duplicate poller — it was a stale webhook set by a laptop-side test. One
  `deleteWebhook` call fixed it.
- **Watchdog resurrection:** a bot migrated to a new host kept 409ing because
  the OLD host's watchdog cron was still alive and restarting the old
  instance. Remove watchdog crons on the source host during ANY migration.
