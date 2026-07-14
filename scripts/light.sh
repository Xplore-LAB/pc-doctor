#!/usr/bin/env bash
# light.sh - Lightweight computer health check (~30s)
# Usage: bash light.sh [zh|en]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
# shellcheck source=/etc/os-release
source "$SCRIPT_DIR/lib.sh"

# Force C locale for stable parsing of lscpu/df/etc output, regardless of user's LANG
LC_ALL=C
LANG=C
export LC_ALL LANG

HC_LANG="${1:-${HC_LANG:-auto}}"
_detect_lang

banner light

# ---------- OS info ----------
section section_cpu
echo "OS:      $(. /etc/os-release 2>/dev/null && echo "${PRETTY_NAME:-$(uname -s)}")  Kernel: $(uname -r)"
echo "Arch:    $(uname -m)   Uptime: $(uptime -p 2>/dev/null || uptime)"
echo "Hostname:$(hostname)"

if command -v lscpu >/dev/null 2>&1; then
  echo
  # On big.LITTLE ARM, lscpu lists multiple unique CPU models. Show them all, deduped.
  cpu_models=$(lscpu | awk -F: '/Model name/ {gsub(/^[ \t]+/, "", $2); print $2}' | sort -u | paste -sd' + ' -)
  echo "CPU:     ${cpu_models:-unknown}"
  cores_per_socket=$(lscpu | awk '/^Core\(s\) per socket/ {print $4; exit}')
  sockets=$(lscpu | awk '/^Socket\(s\)/ {print $2; exit}')
  phys=$(( ${cores_per_socket:-1} * ${sockets:-1} ))
  echo "Cores:   $(nproc) logical / $phys physical ($sockets socket × ${cores_per_socket:-?} cores)"
fi

# Load average
read -r l1 l5 l15 _ < <(cat /proc/loadavg)
cores=$(nproc)
load_status=$(awk -v l1="$l1" -v c="$cores" 'BEGIN{
  if (l1+0 >= c*2) {print "crit"; exit}
  if (l1+0 >= c)   {print "warn"; exit}
  print "ok"
}')
echo "Load:    1m=$l1  5m=$l5  15m=$l15   (cores=$cores)"
case "$load_status" in
  crit)
    crit "1-min load ($l1) ≥ 2× cores ($cores) — system is saturated"
    record crit "CPU load $l1 exceeds 2x core count $cores";;
  warn)
    warn "1-min load ($l1) ≥ cores ($cores) — system is busy"
    record warn "CPU load $l1 exceeds core count $cores";;
  *)
    ok "Load is normal";;
esac

# ---------- Memory ----------
section section_mem
if command -v free >/dev/null 2>&1; then
  free -h
  # Use raw (KB) for arithmetic; -h adds suffixes like 'Gi' that break math
  mem_pct=$(free | awk '/^Mem:/ {printf "%.0f", $3/$2*100}')
  swp_pct=$(free | awk '/^Swap:/ {if ($2+0>0) printf "%.0f", $3/$2*100; else print "0"}')
  judge_pct "$mem_pct" 80 95 >/dev/null
  case $? in
    2) crit "Memory usage ${mem_pct}% — critically high"; record crit "Memory usage ${mem_pct}% (>=95%)";;
    1) warn "Memory usage ${mem_pct}% — high";           record warn "Memory usage ${mem_pct}% (>=80%)";;
    *) ok "Memory usage ${mem_pct}%";;
  esac
  if (( swp_pct >= 50 )); then
    warn "Swap usage ${swp_pct}% — system is swapping heavily"
    record warn "Swap usage ${swp_pct}% (>=50%)"
  else
    info "Swap usage ${swp_pct}%"
  fi
fi

# ---------- Disks ----------
section section_disk
if command -v df >/dev/null 2>&1; then
  df -h --output=source,size,used,avail,pcent,target 2>/dev/null | grep -vE '^(tmpfs|devtmpfs|udev|overlay|shm)'
  echo
  while IFS= read -r line; do
    pct=$(echo "$line" | awk '{print $5}' | tr -d '%')
    mount=$(echo "$line" | awk '{print $6}')
    judge_pct "$pct" 80 90 >/dev/null
    case $? in
      2) crit "Mount $mount at ${pct}% — critically full"; record crit "Mount $mount ${pct}% full";;
      1) warn "Mount $mount at ${pct}% — getting full";    record warn "Mount $mount ${pct}% full";;
    esac
  done < <(df --output=pcent,target -x tmpfs -x devtmpfs -x overlay -x squashfs 2>/dev/null | tail -n +2 | awk '$1+0 > 0')

  # inode check
  if df -i >/dev/null 2>&1; then
    while IFS= read -r line; do
      pct=$(echo "$line" | awk '{print $5}' | tr -d '%')
      mount=$(echo "$line" | awk '{print $6}')
      judge_pct "$pct" 70 90 >/dev/null
      case $? in
        2) crit "Mount $mount inodes ${pct}% — near exhaustion"; record crit "Mount $mount inodes ${pct}%";;
        1) warn "Mount $mount inodes ${pct}% — high";            record warn "Mount $mount inodes ${pct}%";;
      esac
    done < <(df -i --output=pcent,target -x tmpfs -x devtmpfs -x overlay 2>/dev/null | tail -n +2 | awk '$1+0 > 50')
  fi
fi

# ---------- Top processes ----------
section section_proc
if command -v ps >/dev/null 2>&1; then
  echo "Top 5 by CPU:"
  ps -eo pid,user,pcpu,pmem,comm --sort=-pcpu | head -6
  echo
  echo "Top 5 by MEM:"
  ps -eo pid,user,pcpu,pmem,comm --sort=-pmem | head -6
fi

# ---------- Network ----------
section section_net
if command -v ip >/dev/null 2>&1; then
  echo "Interfaces:"
  ip -brief addr show 2>/dev/null
  echo
  echo "Routes:"
  ip route show default 2>/dev/null
fi
echo
echo "Connectivity:"
if command -v ping >/dev/null 2>&1; then
  if ping -c 2 -W 2 1.1.1.1 >/dev/null 2>&1; then
    ok "Internet reachable (1.1.1.1)"
  elif ping -c 2 -W 2 8.8.8.8 >/dev/null 2>&1; then
    ok "Internet reachable (8.8.8.8)"
  else
    crit "Internet unreachable"
    record crit "No internet connectivity"
  fi
fi
if command -v ss >/dev/null 2>&1; then
  listening=$(ss -tlnH 2>/dev/null | wc -l)
  info "$listening TCP ports in LISTEN state"
fi

# ---------- Failed services ----------
section section_svc
if command -v systemctl >/dev/null 2>&1; then
  failed=$(systemctl --failed --no-legend --no-pager 2>/dev/null | wc -l)
  if (( failed == 0 )); then
    ok "No failed systemd units"
  else
    crit "$failed failed systemd units:"
    systemctl --failed --no-pager --no-legend 2>/dev/null | head -10
    record crit "$failed failed systemd units"
  fi
else
  dim "(systemctl not available — skipping)"
fi

# ---------- Done ----------
print_summary
exit 0