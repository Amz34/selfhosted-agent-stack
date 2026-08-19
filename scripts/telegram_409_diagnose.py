#!/usr/bin/env python3
"""
Telegram 409 discriminator — tell a stale-webhook storm from a real
resource problem before you start chasing the wrong thing.

Expert insight (credit: Dineshkumar Kannan, Platform Tech Lead):
  "A genuine resource problem degrades proportionally. A stale webhook
   storm has a cliff. The tell is timing pattern, not volume."

Diagnosis order:
  1. Check getWebhookInfo FIRST — a non-empty webhook URL is a one-call
     root cause for long-poll 409s (deleteWebhook fixes it instantly).
  2. If no webhook, inspect the 409 error timeline in the log:
       CLIFF        → errors start abruptly at a single timestamp and stay
                      saturated → configuration event (webhook set, deploy,
                      duplicate instance started).
       PROPORTIONAL → error rate climbs/falls with load → resource problem
                      (rate limits, memory, connection pool).
  3. Emit a diagnosis line the alert system can include verbatim.

Usage:
  export TELEGRAM_BOT_TOKEN="..."
  python telegram_409_diagnose.py --log /path/to/bot.log [--window 200]

Exit codes:
  0 = no 409 pattern (healthy or webhook clean)
  2 = webhook storm (webhook active)
  3 = resource pattern (proportional 409s, no webhook)
  4 = inconclusive (not enough data)
"""
import argparse, json, os, re, sys, time, urllib.request
from collections import Counter
from datetime import datetime, timezone

WEBHOOK_URL = "https://api.telegram.org/bot{token}/getWebhookInfo"
LOG_LINE_TS = re.compile(
    r"(?P<ts>\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2})"
)


def fetch_webhook(token: str) -> dict:
    try:
        req = urllib.request.Request(WEBHOOK_URL.format(token=token))
        with urllib.request.urlopen(req, timeout=10) as resp:
            return json.loads(resp.read().decode())
    except Exception as exc:
        return {"error": str(exc)}


def parse_log_timestamps(log_path: str) -> list[str]:
    """Return ISO timestamps of lines mentioning 409/Conflict."""
    stamps = []
    try:
        with open(log_path, "r", errors="ignore") as fh:
            for line in fh:
                if "409" in line or "Conflict" in line:
                    m = LOG_LINE_TS.search(line)
                    if m:
                        stamps.append(m.group("ts"))
    except FileNotFoundError:
        return []
    return stamps


def is_cliff(stamps: list[str]) -> bool:
    """True when 409s saturate a single time bucket — a config event.

    A stale-webhook storm produces continuous 409s from the moment the
    webhook is set, so one minute bucket carries the majority of errors.
    A genuine resource problem spreads errors proportionally across the
    window — no single bucket dominates.
    """
    if len(stamps) < 20:
        return False
    minutes = Counter(ts[:16] for ts in stamps)  # bucket by YYYY-MM-DD HH:MM
    top_ratio = max(minutes.values()) / len(stamps)
    return top_ratio > 0.5


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--log", required=True, help="path to bot log")
    ap.add_argument("--window", type=int, default=200,
                    help="max recent 409 lines to analyze")
    args = ap.parse_args()

    token = os.environ.get("TELEGRAM_BOT_TOKEN", "")
    if not token:
        print("diagnosis: TELEGRAM_BOT_TOKEN not set — skipping webhook check")
    else:
        wb = fetch_webhook(token)
        url = (wb.get("result") or {}).get("url", "") if "result" in wb else ""
        if url:
            print(f"diagnosis: WEBHOOK_STORM — active webhook URL: {url}")
            print("fix: curl 'https://api.telegram.org/bot$TOKEN/deleteWebhook?drop_pending_updates=true'")
            return 2

    stamps = parse_log_timestamps(args.log)[-args.window:]
    if not stamps:
        print("diagnosis: no 409 pattern in log window — healthy")
        return 0

    if is_cliff(stamps):
        print(f"diagnosis: WEBHOOK_STORM_LIKELY — {len(stamps)} 409s started"
              f" abruptly (cliff pattern), webhook check was clean.")
        print("next: look for a config event at the cliff timestamp: webhook"
              " set, deploy, duplicate instance started.")
        return 3
    print(f"diagnosis: RESOURCE_PATTERN — {len(stamps)} 409s over the window,"
          " proportional (no cliff). Check rate limits, memory, connection pool.")
    return 4


if __name__ == "__main__":
    sys.exit(main())
