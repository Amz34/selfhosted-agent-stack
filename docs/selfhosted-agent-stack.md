# Self-Hosted AI Agent Stack on Oracle Always-Free

A complete, production-tested recipe for running a 24/7 AI agent stack on a
free Oracle Cloud Always-Free ARM VM: Hermes agent gateway + Telegram +
WhatsApp bridge + cron watchdogs. Everything below was built and debugged on
real hardware — the pitfalls are documented because we hit every one.

## Architecture

```
Oracle Always-Free ARM VM (24/7)
├── Hermes Agent (gateway)          — the AI brain (any LLM provider)
│   ├── Telegram gateway            — chat via Telegram bot
│   ├── WhatsApp gateway (Baileys)  — chat via WhatsApp (bridged)
│   ├── cron scheduler              — recurring jobs
│   └── skills / memory             — cross-session learning
├── WhatsApp bridge (node)          — Baileys multi-device session
└── systemd user services           — auto-restart everything
```

## VM sizing (Oracle Always-Free)

| Resource | Allocated | Notes |
|---|---|---|
| vCPU | 2 (ARM Ampere A1) | plenty for agent loops |
| RAM | 11-24 GB | 2-4 GB used in practice |
| Disk | 50+ GB boot | ~20 GB used |
| Cost | $0 | Always-Free tier |

## Service layout (systemd user units)

```ini
# ~/.config/systemd/user/hermes-gateway.service
[Unit]
Description=Hermes Agent Gateway
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/opt/hermes/venv/bin/python -m hermes_cli.main gateway run
Restart=always
RestartSec=5
Environment=HERMES_HOME=/home/user/.hermes

[Install]
WantedBy=default.target
```

Enable lingering so user units run without a login session:

```bash
sudo loginctl enable-linger ubuntu
systemctl --user enable --now hermes-gateway.service
```

## WhatsApp bridge (Baileys)

- Runs as a child process spawned by the gateway (port 3000).
- Session lives in `~/.hermes/profiles/<profile>/whatsapp/session/`.
- Health check: `curl http://127.0.0.1:3000/health` → `{"status":"connected"}`.
- Send API needs JID format: `POST /send` with
  `{"chatId":"<number>@s.whatsapp.net","message":"..."}` — a bare number
  fails with `jidDecode undefined`.

### WhatsApp multi-device limitation (IMPORTANT)

A Baileys session is a **linked device**. WhatsApp's protocol delivers
messages to linked devices only while the **primary device** (the phone/laptop
where the number is installed) is online. If the primary device is off, the
bot silently misses messages — this looks like a "bot is down" bug but is
actually WhatsApp's design.

**Fixes, in order of preference:**
1. **WhatsApp Cloud API (Meta official)** — server-side, no device dependency.
   Free tier: 1,000 service conversations/month; beyond ~$0.01-0.03/conversation.
2. **Dedicated always-on device** — a cheap phone/tablet on a charger as the
   primary device.
3. **Keep the primary device online** — acceptable for testing only.

## Gateway restart from inside the agent

`systemctl --user restart hermes-gateway*` is BLOCKED when run from inside the
gateway process (SIGTERM propagates to children and kills your command).
Workaround: schedule the restart via cron (cron daemon is outside the gateway
process tree):

```bash
# ~/scripts/gateway_restart_cron.sh  — see scripts/
* * * * * /home/user/scripts/gateway_restart_cron.sh hermes-gateway.service && crontab -l | grep -v gateway_restart_cron | crontab -
```

`XDG_RUNTIME_DIR=/run/user/$(id -u)` is required in cron for `systemctl --user`.

## Security checklist

- Secrets ONLY in `.env` (never config.yaml, never committed).
- `chmod 600` on `.env` and session directories.
- SSH: key-only auth, no password.
- Never commit session files (`creds.json`), tokens, or `.env`.
- Keep the VM private — only expose what must be public (webhooks).

## Cost summary

| Component | Cost |
|---|---|
| Oracle Always-Free VM | $0 |
| LLM API (DeepSeek etc.) | usage-based, ~$3-5/mo for light use |
| WhatsApp bridge | $0 (personal number) |
| Telegram | $0 |
| Total | **~$3-5/mo** |
