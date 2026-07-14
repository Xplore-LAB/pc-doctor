#!/usr/bin/env bash
# lib.sh - Shared helpers for healthcheck skill
# Source this file from light.sh / deep.sh
#
# Provides:
#   - colored output (info/ok/warn/crit)
#   - threshold-based section judges (cpu/mem/disk/temp/smart)
#   - portable section printing
#   - language detection (zh/en)
#
# shellcheck shell=bash

set -u

# ---------- Colors & glyphs (no color when not a TTY) ----------
if [[ -t 1 ]]; then
  C_RESET=$'\033[0m'
  C_BOLD=$'\033[1m'
  C_DIM=$'\033[2m'
  C_OK=$'\033[32m'
  C_WARN=$'\033[33m'
  C_CRIT=$'\033[31m'
  C_INFO=$'\033[36m'
  C_HEAD=$'\033[1;36m'
else
  C_RESET=""; C_BOLD=""; C_DIM=""; C_OK=""; C_WARN=""; C_CRIT=""; C_INFO=""; C_HEAD=""
fi

G_OK="✅"
G_WARN="⚠️ "
G_CRIT="❌"
G_INFO="ℹ️ "

# ---------- Language ----------
HC_LANG="${HC_LANG:-auto}"
_detect_lang() {
  if [[ "$HC_LANG" == "auto" ]]; then
    if [[ "${LANG:-}" == zh* || "${LC_ALL:-}" == zh* ]]; then
      HC_LANG="zh"
    else
      HC_LANG="en"
    fi
  fi
}
_detect_lang

# ---------- Translators ----------
# Return translated string. Usage: t "key"
t() {
  local key="$1"
  case "$HC_LANG:$key" in
    zh:title)        echo "电脑体检报告";;
    en:title)        echo "Computer Health Check Report";;
    zh:section_cpu)  echo "CPU 与负载";;
    en:section_cpu)  echo "CPU & Load";;
    zh:section_mem)  echo "内存与交换";;
    en:section_mem)  echo "Memory & Swap";;
    zh:section_disk) echo "磁盘与文件系统";;
    en:section_disk) echo "Disks & Filesystems";;
    zh:section_proc) echo "高占用进程";;
    en:section_proc) echo "Top Processes";;
    zh:section_net)  echo "网络";;
    en:section_net)  echo "Network";;
    zh:section_svc)  echo "失败的服务";;
    en:section_svc)  echo "Failed Services";;
    zh:section_temp) echo "温度与散热";;
    en:section_temp) echo "Thermal & Cooling";;
    zh:section_smart)echo "磁盘健康 (SMART)";;
    en:section_smart)echo "Disk Health (SMART)";;
    zh:section_io)   echo "磁盘 I/O";;
    en:section_io)   echo "Disk I/O";;
    zh:section_boot) echo "启动与日志";;
    en:section_boot) echo "Boot & Logs";;
    zh:section_sec)  echo "安全与端口";;
    en:section_sec)  echo "Security & Ports";;
    zh:section_pkg)  echo "系统更新";;
    en:section_pkg)  echo "Pending Updates";;
    zh:section_hw)   echo "硬件清单";;
    en:section_hw)   echo "Hardware Inventory";;
    zh:section_crash)echo "近期崩溃/OOM";;
    en:section_crash)echo "Recent Crashes/OOM";;
    zh:summary)      echo "汇总";;
    en:summary)      echo "Summary";;
    zh:overall_ok)   echo "整体状态";;
    en:overall_ok)   echo "Overall";;
    zh:tool_missing) echo "工具缺失：";;
    en:tool_missing) echo "Missing tool: ";;
    zh:tool_install) echo "可使用以下命令安装";;
    en:tool_install) echo "You can install it with";;
    zh:recommend)    echo "建议";;
    en:recommend)    echo "Recommendations";;
    zh:action)       echo "操作";;
    en:action)       echo "Action";;
    zh:need_root)    echo "（需 sudo 才能完整检测）";;
    en:need_root)    echo "(requires sudo for full results)";;
    *)               echo "$key";;
  esac
}

# ---------- Section header ----------
section() {
  local title_key="$1"
  printf "\n${C_HEAD}${C_BOLD}━━━ %s ━━━${C_RESET}\n" "$(t "$title_key")"
}

# ---------- Status line ----------
# status 1/2/3 = ok/warn/crit
ok()    { printf "${C_OK}${G_OK}${C_RESET} %s\n" "$*"; }
warn()  { printf "${C_WARN}${G_WARN}${C_RESET} %s\n" "$*"; }
crit()  { printf "${C_CRIT}${G_CRIT}${C_RESET} %s\n" "$*"; }
info()  { printf "${C_INFO}${G_INFO}${C_RESET} %s\n" "$*"; }
dim()   { printf "${C_DIM}%s${C_RESET}\n" "$*"; }

# ---------- Tool check ----------
# need_tool <cmd> <apt-package>
# Returns 0 if available. Warns & suggests install if missing.
declare -ga HC_MISSING_TOOLS=()
need_tool() {
  local cmd="$1"
  local pkg="${2:-$1}"
  if command -v "$cmd" >/dev/null 2>&1; then
    return 0
  fi
  HC_MISSING_TOOLS+=("$cmd")
  warn "$(t tool_missing) $cmd  —  $(t tool_install): sudo apt install -y $pkg"
  return 1
}

# ---------- Threshold judges ----------
# Returns 0=ok, 1=warn, 2=crit. Sets HC_LAST_STATUS.
declare -i HC_LAST_STATUS=0
declare -ga HC_WARNINGS=()
declare -ga HC_CRITICALS=()

record() {
  local lvl="$1" msg="$2"
  case "$lvl" in
    warn) HC_WARNINGS+=("$msg");;
    crit) HC_CRITICALS+=("$msg");;
  esac
}

# judge <value%> <warn%> <crit%> — compare percentage values
judge_pct() {
  local val="$1" warn_at="$2" crit_at="$3"
  # Use awk for float compare
  awk -v v="$val" -v w="$warn_at" -v c="$crit_at" 'BEGIN{
    if (v+0 >= c+0) exit 2;
    else if (v+0 >= w+0) exit 1;
    else exit 0;
  }'
}

# ---------- Final summary ----------
print_summary() {
  section summary
  local n_warn=${#HC_WARNINGS[@]}
  local n_crit=${#HC_CRITICALS[@]}
  if (( n_crit == 0 && n_warn == 0 )); then
    printf "${C_OK}${C_BOLD}✅ %s: HEALTHY${C_RESET}\n" "$(t overall_ok)"
    if [[ "$HC_LANG" == "zh" ]]; then
      echo "各项指标在正常范围内，无需处理。"
    else
      echo "All indicators are within normal ranges. No action required."
    fi
  else
    if (( n_crit > 0 )); then
      printf "${C_CRIT}${C_BOLD}❌ %s: CRITICAL${C_RESET}  " "$(t overall_ok)"
    else
      printf "${C_WARN}${C_BOLD}⚠️  %s: NEEDS ATTENTION${C_RESET}  " "$(t overall_ok)"
    fi
    echo "(${n_crit} critical, ${n_warn} warnings)"
    if (( n_crit > 0 )); then
      echo
      crit "$(t recommend) (CRITICAL):"
      printf '  • %s\n' "${HC_CRITICALS[@]}"
    fi
    if (( n_warn > 0 )); then
      echo
      warn "$(t recommend) (WARNING):"
      printf '  • %s\n' "${HC_WARNINGS[@]}"
    fi
  fi
  if (( ${#HC_MISSING_TOOLS[@]} > 0 )); then
    echo
    dim "$(t tool_install) (missing): sudo apt install -y ${HC_MISSING_TOOLS[*]}"
  fi
}

# ---------- Utility ----------
has_sudo() { sudo -n true 2>/dev/null; }
bytes_to_human() {
  awk 'BEGIN{
    split("B KB MB GB TB PB", units, " ");
    i=1; v=$1;
    while (v >= 1024 && i < 6) { v/=1024; i++ }
    printf "%.1f %s", v, units[i]
  }' <<< "$1"
}

# ---------- Entry banner ----------
banner() {
  local mode="$1"   # light | deep
  printf "${C_HEAD}${C_BOLD}"
  printf "╔════════════════════════════════════════════════════════════╗\n"
  printf "║  %-58s ║\n" "$(t title)"
  printf "║  Mode: %-52s ║\n" "${mode^^}"
  printf "║  Host: %-52s ║\n" "$(hostname 2>/dev/null || echo unknown)"
  printf "║  Time: %-52s ║\n" "$(date '+%Y-%m-%d %H:%M:%S %Z')"
  printf "╚════════════════════════════════════════════════════════════╝\n"
  printf "${C_RESET}\n"
}