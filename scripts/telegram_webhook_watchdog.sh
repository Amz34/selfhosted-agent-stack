#!/bin/bash
# Telegram webhook watchdog — daily check that no stale webhook blocks
# long-polling. Alerts once if a webhook URL appears (the classic "409
# storm" root cause — a laptop-side test or stray config can set one).
#
# crontab (daily):
#   0 6 * * * /path/to/telegram_webhook_watchdog.sh
#
# Requires: TELEGRAM_BOT_TOKEN env (or edit TOKEN_FILE below).

TOKEN_FILE="${TELEGRAM_TOKEN_FILE:-/home/ubuntu/.hermes/.env}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"
ALERT_FILE="/tmp/telegram_webhook_active.flag"

TOKEN=""
if [ -n "$TELEGRAM_BOT_TOKEN" ]; then
  TOKEN="$TELEGRAM_BOT_TOKEN"
elif [ -f "$TOKEN_FILE" ]; then
  TOKEN=$(grep -oP 'TELEGRAM_BOT_TOKEN=\K.*' "$TOKEN_FILE" 2>/dev/null | head -1)
fi

if [ -z "$TOKEN" ]; then
  echo "telegram_webhook_watchdog: TELEGRAM_BOT_TOKEN not found — skipping"
  exit 0
fi

WEBHOOK_URL=$(curl -s -m 10 "https://api.telegram.org/bot${TOKEN}/getWebhookInfo" 2>/dev/null \
  | python3 -c "import json,sys; print((json.load(sys.stdin).get('result') or {}).get('url',''))" 2>/dev/null)

if [ -z "$WEBHOOK_URL" ]; then
  # healthy — clear flag
  [ -f "$ALERT_FILE" ] && rm -f "$ALERT_FILE"
  echo "$(date -u '+%Y-%m-%d %H:%M') — webhook clean, long-poll OK"
  exit 0
fi

# webhook active — alert once per outage
if [ ! -f "$ALERT_FILE" ]; then
  touch "$ALERT_FILE"
  msg="⚠️ STALE WEBHOOK DETECTED on $(hostname) at $(date -u '+%Y-%m-%d %H:%M UTC'). URL: ${WEBHOOK_URL}
Long-poll 409s will follow. Fix: curl 'https://api.telegram.org/bot\$TOKEN/deleteWebhook?drop_pending_updates=true'"
  echo "$msg"
  if [ -n "$TELEGRAM_CHAT_ID" ] && [ -n "$TELEGRAM_BOT_TOKEN" ]; then
    curl -s -m 10 -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
      -d "chat_id=${TELEGRAM_CHAT_ID}" --data-urlencode "text=${msg}" >/dev/null 2>&1
  fi
fi
