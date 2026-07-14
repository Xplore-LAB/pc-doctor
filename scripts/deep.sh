#!/usr/bin/env bash
# deep.sh - Comprehensive computer health check (~2-5 min)
# Usage: bash deep.sh [zh|en]

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

banner deep

# ---------- 1. OS / CPU / Memory (same as light, plus extras) ----------
section section_cpu
echo "OS:      $(. /etc/os-release 2>/dev/null && echo "${PRETTY_NAME:-$(uname -s)}")  Kernel: $(uname -r)"
echo "Arch:    $(uname -m)   Uptime: $(uptime -p 2>/dev/null || uptime)"
echo "Hostname:$(hostname)"
echo "Booted:  $(who -b 2>/dev/null | awk '{print $3, $4}')"
echo

if command -v lscpu >/dev/null 2>&1; then
  lscpu | grep -E '^(Model name|Architecture|CPU\(s\)|Thread|Core|Socket|Vendor ID|CPU max MHz|CPU MHz|Cache|Flags)' | sed 's/^/  /'
fi

read -r l1 l5 l15 _ < <(cat /proc/loadavg)
cores=$(nproc)
echo
echo "Load:    1m=$l1  5m=$l5  15m=$l15   (cores=$cores)"
if awk -v v="$l1" -v c="$cores" 'BEGIN{exit !(v+0 >= c*2)}'; then
  crit "1-min load $l1 ≥ 2× cores ($cores)"; record crit "Load $l1 >= 2x cores"
elif awk -v v="$l1" -v c="$cores" 'BEGIN{exit !(v+0 >= c)}'; then
  warn "1-min load $l1 ≥ cores ($cores)"; record warn "Load $l1 >= cores"
else
  ok "Load normal"
fi

# Per-CPU utilization snapshot (1 second sample)
if command -v mpstat >/dev/null 2>&1; then
  echo
  echo "mpstat (1s sample):"
  mpstat -P ALL 1 1 2>/dev/null | tail -n +4
fi

# ---------- 2. Memory ----------
section section_mem
free -h
# Use raw (KB) output for arithmetic; -h appends units like 'Gi' that break math
mem_pct=$(free | awk '/^Mem:/ {printf "%.0f", $3/$2*100}')
swp_pct=$(free | awk '/^Swap:/ {if ($2+0>0) printf "%.0f", $3/$2*100; else print "0"}')
judge_pct "$mem_pct" 80 95 >/dev/null
case $? in
  2) crit "Memory ${mem_pct}%"; record crit "Memory ${mem_pct}% (>=95%)";;
  1) warn "Memory ${mem_pct}%"; record warn "Memory ${mem_pct}% (>=80%)";;
  *) ok "Memory ${mem_pct}%";;
esac
if (( swp_pct >= 50 )); then
  warn "Swap ${swp_pct}%"; record warn "Swap ${swp_pct}% (>=50%)"
else
  info "Swap ${swp_pct}%"
fi

# Hugepages
if [[ -d /sys/kernel/mm/hugepages ]]; then
  echo
  echo "Hugepages:"
  for hp in /sys/kernel/mm/hugepages/hugepages-*; do
    size=$(basename "$hp" | sed 's/hugepages-//')
    total=$(cat "$hp/nr_hugepages")
    free=$(cat "$hp/free_hugepages")
    echo "  $size: total=$total free=$free"
  done
fi

# ---------- 3. Disks ----------
section section_disk
df -h --output=source,size,used,avail,pcent,target 2>/dev/null | grep -vE '^(tmpfs|devtmpfs|udev|overlay|shm)' | head -20
echo
echo "Block devices:"
if command -v lsblk >/dev/null 2>&1; then
  lsblk -o NAME,SIZE,ROTA,TYPE,MODEL,MOUNTPOINT,FSTYPE 2>/dev/null | head -30
fi
echo
while IFS= read -r line; do
  pct=$(echo "$line" | awk '{print $5}' | tr -d '%')
  mount=$(echo "$line" | awk '{print $6}')
  judge_pct "$pct" 80 90 >/dev/null
  case $? in
    2) crit "Mount $mount ${pct}%"; record crit "Mount $mount ${pct}%";;
    1) warn "Mount $mount ${pct}%"; record warn "Mount $mount ${pct}%";;
  esac
done < <(df --output=pcent,target -x tmpfs -x devtmpfs -x overlay -x squashfs 2>/dev/null | tail -n +2 | awk '$1+0 > 0')

# ---------- 4. Disk I/O ----------
section section_io
if command -v iostat >/dev/null 2>&1; then
  echo "iostat (2s sample):"
  iostat -dx 2 2 2>/dev/null | tail -n +9
  # Flag high utilization
  iostat -dx 1 2 2>/dev/null | awk 'NR>6 && $NF+0 >= 80 {print "  High util on " $1 ": " $NF "%"}' | head -5
else
  dim "(iostat missing — install sysstat)"
fi
if command -v vmstat >/dev/null 2>&1; then
  echo
  echo "vmstat (1s sample):"
  vmstat 1 2 2>/dev/null | tail -n +4
fi

# ---------- 5. Thermal ----------
section section_temp
if command -v sensors >/dev/null 2>&1; then
  sensors 2>/dev/null
  # Threshold checks on CPU temps
  sensors 2>/dev/null | awk '
    /°C/ {
      for (i=1; i<=NF; i++) {
        if ($i ~ /°C/) {
          t = $i; gsub(/[^0-9.\-]/, "", t);
          if (t+0 != 0 && t+0 >= 85) { print "CRIT: " $0; crit_flag=1 }
          else if (t+0 != 0 && t+0 >= 70) { print "WARN: " $0; warn_flag=1 }
        }
      }
    }
    END {
      if (crit_flag) exit 2
      if (warn_flag) exit 1
      exit 0
    }
  '
  case $? in
    2) record crit "CPU/GPU temperature >= 85°C";;
    1) record warn "CPU/GPU temperature >= 70°C";;
  esac
else
  dim "(lm-sensors missing — sudo apt install lm-sensors && sudo sensors-detect)"
fi
if command -v nvidia-smi >/dev/null 2>&1; then
  echo
  echo "GPU (nvidia-smi):"
  nvidia-smi --query-gpu=index,name,temperature.gpu,utilization.gpu,utilization.memory,memory.used,memory.total,power.draw --format=table 2>/dev/null || dim "(no NVIDIA GPU)"
  gpu_temp=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader 2>/dev/null | head -1)
  if [[ -n "$gpu_temp" ]]; then
    if (( gpu_temp >= 90 )); then
      crit "GPU temperature ${gpu_temp}°C"
      record crit "GPU temperature ${gpu_temp}°C (>=90°C)"
    elif (( gpu_temp >= 80 )); then
      warn "GPU temperature ${gpu_temp}°C"
      record warn "GPU temperature ${gpu_temp}°C (>=80°C)"
    else
      ok "GPU temperature ${gpu_temp}°C"
    fi
  fi
fi

# ---------- 6. SMART disk health ----------
section section_smart
need_tool smartctl smartmontools || true
disks=$(lsblk -dno NAME 2>/dev/null | grep -vE '^(loop|ram)')
for d in $disks; do
  dev="/dev/$d"
  echo "── $dev ──"
  if has_sudo; then
    out=$(sudo smartctl -H -A -i "$dev" 2>&1)
  else
    out=$(smartctl -H -A -i "$dev" 2>&1)
  fi
  # Skip devices that smartctl can't probe (USB bridges, etc.)
  if echo "$out" | grep -qiE 'unknown usb|please specify device type|permission denied|open device.*failed'; then
    dim "  (smartctl cannot access this device — likely needs '-d' flag or sudo)"
    echo
    continue
  fi
  echo "$out" | head -25
  # Critical SMART attributes
  if echo "$out" | grep -q "SMART overall-health self-assessment test result: PASSED"; then
    ok "$dev: SMART PASSED"
  elif echo "$out" | grep -q "SMART overall-health self-assessment test result"; then
    warn "$dev: SMART NOT PASSED — back up data"
    record warn "$dev: SMART health NOT PASSED"
  fi
  realloc=$(echo "$out" | awk '/Reallocated_Sector_Ct/ {print $10}')
  pending=$(echo "$out" | awk '/Current_Pending_Sector/ {print $10}')
  if [[ -n "$realloc" && "$realloc" != "0" ]]; then
    crit "$dev: $realloc reallocated sectors"
    record crit "$dev has $realloc reallocated sectors"
  fi
  if [[ -n "$pending" && "$pending" != "0" ]]; then
    crit "$dev: $pending pending sectors"
    record crit "$dev has $pending pending sectors"
  fi
  echo
done
dim "$(t need_root)"

# ---------- 7. Boot / logs ----------
section section_boot
if command -v systemd-analyze >/dev/null 2>&1; then
  echo "Boot performance:"
  systemd-analyze 2>/dev/null | head -10
  echo
  echo "Slowest 5 services:"
  systemd-analyze blame 2>/dev/null | head -5
else
  dim "(systemd-analyze not available)"
fi
echo
echo "Kernel errors since boot:"
err_total=$(journalctl -p 3 -b --no-pager -q 2>/dev/null | wc -l)
# Count distinct error patterns (strip PIDs/timestamps) to detect spam vs diversity
err_distinct=$(journalctl -p 3 -b --no-pager -q 2>/dev/null \
  | sed -E 's/[0-9]+/N/g; s/^[^ ]+ //; s/ [0-9]{2}:[0-9]{2}:[0-9]{2} / TIME /' \
  | sort -u | wc -l)
echo "  $err_total error/crit messages ($err_distinct unique patterns)"
if (( err_total > 0 )); then
  journalctl -p 3 -b --no-pager -q 2>/dev/null | tail -10
  # Only flag as warning if errors are diverse (more than just one service spamming).
  # If there are <5 distinct patterns but thousands of messages, it's a service retry loop.
  if (( err_distinct > 20 )); then
    record warn "$err_distinct distinct boot-time errors in journal"
  elif (( err_distinct > 5 && err_total > 100 )); then
    record warn "$err_distinct distinct error patterns (${err_total} total) since boot"
  elif (( err_distinct <= 5 && err_total > 50 )); then
    info "Errors dominated by $err_distinct retry pattern(s) — investigate the specific service"
  fi
fi

# ---------- 8. Recent crashes / OOM ----------
section section_crash
echo "Last 5 OOM events:"
dmesg 2>/dev/null | grep -iE 'out of memory|oom' | tail -5 || dim "(no dmesg access)"
echo
echo "Last 5 segfaults / kernel panics:"
dmesg 2>/dev/null | grep -iE 'segfault|kernel panic|hardware error' | tail -5 || true
echo
if command -v journalctl >/dev/null 2>&1; then
  echo "Crash dump files:"
  crash_count=$(find /var/crash -maxdepth 1 -name '*.crash' 2>/dev/null | wc -l)
  if (( crash_count > 0 )); then
    find /var/crash -maxdepth 1 -name '*.crash' -printf '%p %s\n' 2>/dev/null \
      | head -5 | while read -r f s; do
        printf '  %s  %s\n' "$(numfmt --to=iec "$s" 2>/dev/null || echo "${s}B")" "$(basename "$f")"
      done
    warn "$crash_count crash dump(s) in /var/crash"
    record warn "$crash_count crash dumps present in /var/crash"
  else
    info "No crash dumps in /var/crash"
  fi
fi

# ---------- 9. Security & ports ----------
section section_sec
if command -v ss >/dev/null 2>&1; then
  echo "Listening TCP ports:"
  ss -tlnp 2>/dev/null | head -20
  echo
  echo "Established external connections (top 10):"
  ss -tnp state established 2>/dev/null | grep -v "127.0.0.1\|::1" | head -10
fi
echo
echo "World-writable sensitive files (heuristic):"
find /etc /usr/local/etc -xdev -type f -perm -o=w 2>/dev/null | head -5 || true
echo
echo "Files with SUID bit (top 10):"
find /usr -xdev -type f -perm -4000 2>/dev/null | head -10 || true

# ---------- 10. Pending updates ----------
section section_pkg
if command -v apt >/dev/null 2>&1; then
  upgradable=$(apt list --upgradable 2>/dev/null | grep -vc '^Listing')
  echo "Pending apt updates: $upgradable"
  if (( upgradable > 0 )); then
    apt list --upgradable 2>/dev/null | head -10
    if (( upgradable > 50 )); then
      warn "$upgradable packages need updating — consider 'sudo apt update && sudo apt upgrade'"
      record warn "$upgradable pending apt updates"
    elif (( upgradable > 0 )); then
      info "$upgradable pending updates"
    fi
  else
    ok "All packages up-to-date"
  fi
elif command -v dnf >/dev/null 2>&1; then
  dnf check-update -q 2>/dev/null | head -10
elif command -v yum >/dev/null 2>&1; then
  yum check-update -q 2>/dev/null | head -10
else
  dim "(no apt/dnf/yum found)"
fi

# ---------- 11. Hardware inventory ----------
section section_hw
echo "PCI devices:"
if command -v lspci >/dev/null 2>&1; then
  lspci 2>/dev/null | head -30
fi
echo
echo "USB devices:"
if command -v lsusb >/dev/null 2>&1; then
  lsusb 2>/dev/null | head -10
fi
echo
echo "DMI / SMBIOS:"
if command -v dmidecode >/dev/null 2>&1; then
  if has_sudo; then
    sudo dmidecode -t system 2>/dev/null | head -15
    echo
    sudo dmidecode -t memory 2>/dev/null | grep -E 'Size|Speed|Manufacturer|Configured' | head -10
  else
    dim "$(t need_root) — try: sudo dmidecode -t system"
  fi
fi

# ---------- Final summary ----------
print_summary
exit 0