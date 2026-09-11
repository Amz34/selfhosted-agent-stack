#!/usr/bin/env bash
# Enable zram compressed swap + memory-pressure sysctls on this VM.
# Idempotent. Usage: sudo bash zram_setup.sh [size_mb]
set -uo pipefail
SZ="${1:-6144}"

echo "== before =="
swapon --show 2>/dev/null | tail -5
free -m | head -3

export DEBIAN_FRONTEND=noninteractive
if ! dpkg -s zram-tools >/dev/null 2>&1; then
  echo "installing zram-tools..."
  apt-get update -qq >/dev/null 2>&1
  apt-get install -y -qq zram-tools >/dev/null 2>&1 || echo "APT-INSTALL-FAILED"
fi

cat > /etc/default/zramswap <<EOF
# Managed by Hermes infra tuning ($(date -u '+%Y-%m-%d'))
ALGO=zstd
PERCENT=0
SIZE=${SZ}
PRIORITY=100
EOF

# sysctls: prefer compressed swap, less read-ahead clustering for zram
cat > /etc/sysctl.d/99-hermes-memory.conf <<'EOF'
vm.swappiness=100
vm.page-cluster=0
vm.vfs_cache_pressure=150
vm.min_free_kbytes=131072
EOF
sysctl -q -p /etc/sysctl.d/99-hermes-memory.conf 2>/dev/null

systemctl enable --now zramswap >/dev/null 2>&1 || systemctl restart zramswap >/dev/null 2>&1
sleep 3

echo "== after =="
swapon --show 2>/dev/null | tail -6
free -m | head -3
sysctl -n vm.swappiness vm.page-cluster 2>/dev/null | tr '\n' ' '; echo
lszram=$(cat /sys/block/zram0/disksize 2>/dev/null || echo 0)
echo "zram0 size: $((lszram/1024/1024))MB  compression: $(cat /sys/block/zram0/comp_algorithm 2>/dev/null | grep -o '\[.*\]')"
