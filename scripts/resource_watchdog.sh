#!/usr/bin/env bash
# Resource pressure watchdog — prints NOTHING when healthy (silent cron),
# prints an alert block when a threshold is breached. Cooldown per alert kind
# so a sustained condition does not spam (default 3h).
set -uo pipefail

STATE="/home/ubuntu/ops/logs/watchdog_state"
mkdir -p "$STATE"
COOLDOWN=$(( ${WATCHDOG_COOLDOWN_H:-3} * 3600 ))

get() { awk -v k="$1" '$1==k":" {printf "%d", $2/1024}' /proc/meminfo; }
MEM_TOTAL=$(get MemTotal); MEM_AVAIL=$(get MemAvailable)
SWAP_TOTAL=$(get SwapTotal); SWAP_FREE=$(get SwapFree)
DISK_USE=$(df -P / | awk 'NR==2 {gsub("%","",$5); print $5}')
CORES=$(nproc)
LOAD1=$(awk '{printf "%.2f", $1}' /proc/loadavg)
CHROME_MB=$(ps -eo rss,comm 2>/dev/null | grep -iE 'chrom' | awk '{s+=$1} END {printf "%d", s/1024}')
ZRAM=$(swapon --show=NAME --noheadings 2>/dev/null | grep -c zram || true)

alerts=()
avail_pct=$(( MEM_AVAIL * 100 / (MEM_TOTAL>0?MEM_TOTAL:1) ))
if [ "$MEM_AVAIL" -lt 900 ] || [ "$avail_pct" -lt 8 ]; then
  alerts+=("mem")
fi
if [ "$SWAP_TOTAL" -gt 0 ]; then
  swap_used_pct=$(( (SWAP_TOTAL-SWAP_FREE) * 100 / SWAP_TOTAL ))
  if [ "$swap_used_pct" -gt 85 ]; then alerts+=("swap"); fi
fi
if [ "$DISK_USE" -gt 88 ]; then alerts+=("disk"); fi
load_int=${LOAD1%.*}
if [ "${load_int:-0}" -gt $((CORES*3)) ]; then alerts+=("load"); fi

fire=()
for a in "${alerts[@]:-}"; do
  [ -z "$a" ] && continue
  stamp="$STATE/$a.stamp"
  last=$(cat "$stamp" 2>/dev/null || echo 0)
  now=$(date +%s)
  if [ $((now-last)) -ge "$COOLDOWN" ]; then fire+=("$a"); echo "$now" > "$stamp"; fi
done

[ "${#fire[@]}" -eq 0 ] && exit 0

echo "⚠️ VM PRESSURE ALERT ($(hostname) $(date '+%d %b %H:%M') UTC) — triggered: ${fire[*]}"
echo "RAM: ${MEM_AVAIL}MB free / ${MEM_TOTAL}MB (${avail_pct}%) | Swap: $(( (SWAP_TOTAL-SWAP_FREE)/1024 ))MB used / $(( SWAP_TOTAL/1024 ))MB | zram: ${ZRAM} dev | Disk: ${DISK_USE}% | Load: ${LOAD1} on ${CORES} vCPU | Chrome: ${CHROME_MB}MB"
echo "Top RAM:"
ps -eo rss,comm --sort=-rss --no-headers 2>/dev/null | head -6 | awk '{printf "  %5dMB %s\n", $1/1024, $2}'
if [ "$ZRAM" -eq 0 ]; then
  echo "NOTE: no zram swap active — run: sudo systemctl restart zramswap"
fi
exit 0
