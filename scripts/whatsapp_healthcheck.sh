#!/bin/bash
# WhatsApp Baileys bridge health check — run via cron for 24/7 uptime alerts.
# Usage: */5 * * * * /path/to/whatsapp_healthcheck.sh
# Sends a Telegram alert if the bridge or gateway is down.

BRIDGE_PORT="${BRIDGE_PORT:-3000}"
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"
ALERT_FILE="/tmp/whatsapp_bridge_down.flag"

health=$(curl -s -m 5 "http://127.0.0.1:${BRIDGE_PORT}/health" 2>/dev/null)
bridge_up=$(echo "$health" | grep -c '"status":"connected"')

if [ "$bridge_up" -eq 1 ]; then
  # recovered — clear alert flag
  [ -f "$ALERT_FILE" ] && rm -f "$ALERT_FILE"
  exit 0
fi

# bridge down — alert (once per outage, not every 5 min)
if [ ! -f "$ALERT_FILE" ]; then
  touch "$ALERT_FILE"
  msg="⚠️ WhatsApp bridge DOWN on $(hostname) at $(date -u '+%Y-%m-%d %H:%M UTC'). Bridge port ${BRIDGE_PORT} not responding."
  echo "$msg"
  if [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
    curl -s -m 10 -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
      -d "chat_id=${TELEGRAM_CHAT_ID}" --data-urlencode "text=${msg}" >/dev/null 2>&1
  fi
fi
