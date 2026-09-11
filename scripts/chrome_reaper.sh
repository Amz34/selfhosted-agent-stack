#!/usr/bin/env bash
# Stale Chrome reaper — reclaims RAM from leaked headless Chrome trees.
# Safe by default: only kills headless/remote-debug Chrome whose CDP port has
# NO live ESTABLISHED client and whose age exceeds MAX_AGE_H, plus orphans.
#
# Usage: chrome_reaper.sh [--dry-run] [--max-age-h 6]
set -uo pipefail

DRY=0; MAX_AGE_H=6
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1 ;;
    --max-age-h) MAX_AGE_H="${2:-6}"; shift ;;
  esac
  shift
done

LOG="/home/ubuntu/ops/logs/chrome_reaper.log"
mkdir -p "$(dirname "$LOG")"
now=$(date '+%Y-%m-%d %H:%M:%S')
killed=0; reclaimed_kb=0; report=""

# --- 1. Remote-debug / headless chrome mains that are old AND unattached ---
while read -r pid age rss port; do
  [ -z "${pid:-}" ] && continue
  # live client attached to the CDP port?
  if [ -n "$port" ] && ss -tnp 2>/dev/null | grep -q ":${port} .*ESTAB"; then
    continue
  fi
  # does the process have any established TCP connection at all? (active browsing)
  if ss -tnp 2>/dev/null | grep -q "pid=${pid}," ; then
    continue
  fi
  report="${report}  pid=${pid} age=$((age/3600))h rss=$((rss/1024))MB port=${port:-none}\n"
  if [ "$DRY" -eq 0 ]; then
    pkill -TERM -P "$pid" 2>/dev/null
    kill -TERM "$pid" 2>/dev/null
    sleep 1
    pkill -KILL -P "$pid" 2>/dev/null
    kill -KILL "$pid" 2>/dev/null
    killed=$((killed+1)); reclaimed_kb=$((reclaimed_kb+rss))
  fi
done < <(ps -eo pid,etimes,rss,cmd --no-headers 2>/dev/null \
  | grep -E 'chrom(e|ium)' \
  | grep -vE 'grep|chrome_reaper' \
  | grep -vE 'dp_profile|/\.chrome-notion' \
  | grep -E '\-\-remote-debugging-port|\-\-headless' \
  | awk -v max="$((MAX_AGE_H*3600))" '$2>max {
      port="";
      for(i=4;i<=NF;i++){ if($i ~ /^--remote-debugging-port=/){ split($i,a,"="); port=a[2] } }
      print $1, $2, $3, port
    }')

# --- 2. Orphaned chrome children (reparented to init, older than 1h) ---
while read -r pid age rss; do
  [ -z "${pid:-}" ] && continue
  report="${report}  ORPHAN pid=${pid} age=$((age/3600))h rss=$((rss/1024))MB\n"
  if [ "$DRY" -eq 0 ]; then
    kill -TERM "$pid" 2>/dev/null; sleep 1; kill -KILL "$pid" 2>/dev/null
    killed=$((killed+1)); reclaimed_kb=$((reclaimed_kb+rss))
  fi
done < <(ps -eo pid,ppid,etimes,rss,cmd --no-headers 2>/dev/null \
  | grep -E 'chrom(e|ium)' | grep -vE 'grep|chrome_reaper' \
  | awk '$2==1 && $3>3600 {print $1, $3, $4}')

tot_mb=$(ps -eo rss,comm 2>/dev/null | grep -iE 'chrom' | awk '{s+=$1} END {printf "%d", s/1024}')
avail_mb=$(awk '/MemAvailable/{printf "%d", $2/1024}' /proc/meminfo)

if [ "$killed" -gt 0 ] || [ "$DRY" -eq 1 ]; then
  {
    echo "[$now] ${DRY:+DRY-RUN }killed=$killed reclaimed=$((reclaimed_kb/1024))MB chrome_now=${tot_mb}MB mem_avail=${avail_mb}MB"
    [ -n "$report" ] && printf "%b" "$report"
  } >> "$LOG"
fi

if [ "$DRY" -eq 1 ]; then
  echo "DRY-RUN: would reap ${killed:-0} tree(s); chrome total=${tot_mb}MB mem_avail=${avail_mb}MB"
  [ -n "$report" ] && printf "%b" "$report"
elif [ "$killed" -gt 0 ]; then
  echo "Chrome reaper: freed $((reclaimed_kb/1024))MB from ${killed} stale tree(s) — chrome now ${tot_mb}MB, RAM avail ${avail_mb}MB"
fi
exit 0
