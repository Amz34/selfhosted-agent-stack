# Self-Hosted AI Agent Stack

**Run a 24/7 AI agent on FREE cloud — Hermes + Telegram + WhatsApp, production-tested.**
Your own AI ops center for ~$0-5/month. Built from real incidents, not tutorials.

![Python](https://img.shields.io/badge/Python-3.9%2B-blue) ![License](https://img.shields.io/badge/License-MIT-green) ![Stack](https://img.shields.io/badge/Stack-Hermes%20%2B%20Telegram%20%2B%20WhatsApp-orange) ![Status](https://img.shields.io/badge/Status-Production--tested-success)

Production-tested recipes, scripts, and patterns for running a **24/7 AI
agent stack on free infrastructure** — Hermes Agent gateway + Telegram +
WhatsApp bridge + cron watchdogs, all on an Oracle Cloud Always-Free VM for
~$3-5/month total.

Built from real incidents: every pitfall documented here is one we actually
hit and fixed (409 webhook storms, Baileys multi-device message loss, gateway
restart deadlocks, watchdog resurrection).

## Why this exists

Most "AI agent" tutorials show a demo that stops at a notebook. This repo is
the opposite: the boring, hard-won operational layer — what breaks when you
run agents 24/7, how to detect it, how to fix it, and how to keep the whole
thing alive on free hardware.

## What's inside

```
├── scripts/
│   ├── gmail_toolbox.py          # IMAP email search/extract (newsletter monitoring)
│   ├── whatsapp_healthcheck.sh   # bridge health check + Telegram alert (cron)
│   ├── telegram_409_diagnose.py  # 409 storm vs resource issue — cliff discriminator
│   ├── telegram_webhook_watchdog.sh # daily stale-webhook check + alert
│   └── gateway_restart_cron.sh   # restart systemd gateway from cron (outside process tree)
├── docs/
│   ├── selfhosted-agent-stack.md # full architecture + VM sizing + services
│   └── telegram-bot-patterns.md  # long-poll bot ops: 409s, watchdogs, i18n, testing
└── LICENSE                       # MIT
```

## Quick start (30 min to a live agent)

1. **Get a free VM** — Oracle Cloud Always-Free (ARM Ampere A1, 2+ vCPU,
   11-24 GB RAM). Sign up at oracle.com/cloud/free.
2. **Install Hermes Agent** on it:
   ```bash
   curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
   hermes setup
   ```
3. **Wire Telegram** — create a bot via @BotFather, add the token, enable the
   gateway. See `docs/selfhosted-agent-stack.md` for the systemd unit.
4. **Add WhatsApp (optional)** — Baileys bridge; see the doc for the
   multi-device primary-device limitation — read this BEFORE deploying.
5. **Set up watchdogs** — cron every 5 min: `whatsapp_healthcheck.sh` +
   bot watchdog. Alert on outage, recover automatically.

## Scripts

### gmail_toolbox.py
Dependency-free IMAP search/extract for newsletter monitoring and email
analysis workflows.
```bash
export GMAIL_ADDRESS="you@gmail.com"
export GMAIL_APP_PASSWORD="your-app-password"   # Google App Password

python gmail_toolbox.py search "from:newsletter@x.com" --limit 10
python gmail_toolbox.py get 12345
python gmail_toolbox.py list --recent 15
```

### whatsapp_healthcheck.sh
Cron watchdog that alerts on Telegram when the Baileys bridge dies (alerts
once per outage, auto-recovers silently).
```bash
# crontab:
*/5 * * * * /path/to/whatsapp_healthcheck.sh
```

### gateway_restart_cron.sh
One-shot systemd restart from cron — needed because restarting the gateway
from inside itself is blocked (SIGTERM propagation). Self-removes after
running. See header comment for setup.

## Cost

| Component | Cost |
|---|---|
| Oracle Always-Free VM | $0 |
| LLM API (DeepSeek etc.) | ~$3-5/mo light use |
| WhatsApp + Telegram | $0 |
| **Total** | **~$3-5/mo** |

## License

MIT — use it, fork it, ship it. Attribution appreciated but not required.
