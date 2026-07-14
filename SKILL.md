---
name: pc-doctor
description: |
  Computer health check for Linux systems. Inspects CPU, memory, disks,
  filesystem, processes, network, services, temperatures, SMART, security,
  and pending updates. Two modes: --light (≈30s) and --deep (≈3-5min).
  Use when user asks to "check my computer", "run a health check",
  "diagnose my machine", "why is my computer slow", "体检", "电脑体检", "跑个 pc-doctor",
  "跑个健康检查", or any computer-diagnostics request.
metadata:
  language: en | zh
  platforms: linux
  modes:
    - light
    - deep
---

# pc-doctor / 电脑体检

A bilingual (English / 中文) computer health check skill for Claude Code.
One skill, two modes — invoked by the user as `/pc-doctor` (light) or
`/pc-doctor --deep` (thorough).

为 Claude Code 设计的中英双语电脑体检 skill。一个 skill、两种模式：
`/pc-doctor`（轻量，约 30 秒）和 `/pc-doctor --deep`（深度，约 3-5 分钟）。

---

## When to use this skill / 何时使用

Invoke when the user asks ANY of:
- "check my computer health" / "run a health check" / "diagnose my machine"
- "why is my computer slow" / "what's wrong with my laptop"
- "体检" / "电脑体检" / "健康检查" / "诊断一下" / "跑个 pc-doctor" / "看看电脑"
- "看一下内存/CPU/磁盘" / "帮我查一下电脑"
- "free up disk space" (use light first to find what's full)

**Do NOT use** for:
- Software development debugging (use `verify` skill instead)
- Code review (use `code-review` skill instead)
- Pure data/chart generation (use `dataviz` skill instead)

---

## How to run / 如何运行

### Light mode (default, ~30 seconds)
```bash
bash ~/.claude/skills/pc-doctor/scripts/light.sh
```
Or, when running from the repo:
```bash
bash ./scripts/light.sh
```
Optionally pass a language: `bash ./scripts/light.sh zh` or `... en`.
Auto-detects from `$LANG` if not provided.

### Deep mode (~3-5 minutes)
```bash
bash ~/.claude/skills/pc-doctor/scripts/deep.sh
```
Some checks (SMART details, DMI) may need `sudo` for full output — the
script will print a notice and skip what it can't access.

### From a Claude Code conversation
The user can simply say:
- `/pc-doctor` → runs light mode
- `/pc-doctor deep` → runs deep mode
- `/pc-doctor --deep` → also runs deep mode

You (Claude) should:
1. Confirm the mode: light or deep
2. Execute the appropriate script via Bash tool
3. Read the output
4. Summarize in the user's language (auto-detect or ask)
5. Highlight any ⚠️ / ❌ items with **actionable** recommendations

---

## What the scripts check / 检查项

### Light mode / 轻量版
| Section / 项目 | Tool | Threshold |
|---|---|---|
| OS info / 系统信息 | `uname`, `/etc/os-release` | — |
| CPU & load / CPU 与负载 | `lscpu`, `/proc/loadavg` | warn ≥ cores, crit ≥ 2× cores |
| Memory & swap / 内存 | `free` | warn ≥ 80%, crit ≥ 95% |
| Disks & mounts / 磁盘 | `df` | warn ≥ 80%, crit ≥ 90% |
| Inodes / inode | `df -i` | warn ≥ 70%, crit ≥ 90% |
| Top processes / 高占用进程 | `ps` | top 5 by CPU & MEM |
| Network / 网络 | `ip`, `ping` | reachability check |
| Listening ports / 监听端口 | `ss -tln` | count |
| Failed services / 失败服务 | `systemctl --failed` | any failure = crit |

### Deep mode additions / 深度版额外检查
| Section / 项目 | Tool | Threshold |
|---|---|---|
| Per-CPU util / 每核 CPU | `mpstat` | 1-second sample |
| Hugepages / 大页 | `/sys/kernel/mm/hugepages` | informational |
| Block devices / 块设备 | `lsblk` | list |
| Disk I/O / 磁盘 I/O | `iostat -dx`, `vmstat` | high util flagged |
| Temperatures / 温度 | `sensors`, `nvidia-smi` | warn ≥ 70°C, crit ≥ 85°C |
| GPU / 显卡 | `nvidia-smi` | temp + utilization |
| SMART disk health / 硬盘健康 | `smartctl -H -A` | reallocated/pending > 0 = crit |
| Boot performance / 启动耗时 | `systemd-analyze` | blame top 5 |
| Boot-time errors / 启动期错误 | `journalctl -p 3 -b` | > 20 = warn |
| OOM events / OOM 事件 | `dmesg` | any = info |
| Crashes / 崩溃 | `/var/crash`, `dmesg` | any dump = warn |
| Listening services / 监听端口 | `ss -tlnp` | top 20 |
| External connections / 外连 | `ss -tnp` | top 10 |
| World-writable files / 弱权限 | `find -perm -o=w` | any in /etc = warn |
| SUID binaries / SUID 文件 | `find -perm -4000` | top 10 |
| Pending updates / 待更新包 | `apt list --upgradable` | > 50 = warn |
| PCI/USB inventory / 硬件清单 | `lspci`, `lsusb` | list |
| DMI/SMBIOS / 主板信息 | `dmidecode` | system + memory |

---

## Output format / 输出格式

The script prints structured sections with colored status icons:
- ✅ **OK** — within normal range
- ⚠️  **WARN** — above warn threshold, attention needed
- ❌ **CRIT** — above crit threshold, action required
- ℹ️  **INFO** — informational only

At the end, a **Summary** block lists all WARN/CRIT findings with
recommendations. When summarizing back to the user:
- Use the same icon style for visual continuity
- Group by severity: CRIT first, then WARN
- Provide one concrete next action per finding (e.g. "run `sudo apt upgrade`")
- Don't speculate — only report what the script found
- Translate section titles if the user prefers Chinese

---

## Threshold philosophy / 阈值哲学

We pick conservative thresholds that err on the side of *not* crying wolf:
- **CPU load**: warn at 1× cores, crit at 2× cores. A modern system with
  8 cores can sustain load 8 without complaint; we only flag it once it
  crosses into "truly busy" territory.
- **Disk**: 80/90% (warn/crit). Most Linux sysadmins agree on this.
- **Temperature**: 70/85°C. CPUs throttle at 90-100°C, so we warn earlier
  to give time to clean fans / re-paste.
- **SMART**: ANY reallocated or pending sector is critical — these are
  early signs of drive failure.

See `references/thresholds.md` for the full table.

---

## Safety / 安全说明

- The scripts are **read-only** — they do not modify the system.
- `sudo` is requested only for: `smartctl`, `dmidecode`. Both are
  read-only commands. You can run without sudo and skip those sections.
- No network calls except `ping` for connectivity check.
- No files are written outside of stdout.

---

## References / 参考文档

- `references/commands.md` — what each command does
- `references/thresholds.md` — full threshold table with rationale
- `references/tools.md` — how to install missing tools
- `examples/sample-output-light.txt` — example light run
- `examples/sample-output-deep.txt` — example deep run

---

## License / 许可证

MIT — see `LICENSE`. Contributions welcome.

## 作者 / Author

Created for the community. Open a GitHub issue or PR at the repo URL.