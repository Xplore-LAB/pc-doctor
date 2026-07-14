# PC Doctor 🩺💻

> A bilingual computer health check skill for Claude Code. Two modes, zero dependencies, zero network calls (except connectivity ping).
>
> 为 Claude Code 设计的中英双语电脑体检 skill。两种模式，零依赖，零网络调用（除连通性 ping 外）。

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Linux](https://img.shields.io/badge/Platform-Linux-blue.svg)]()
[![Bilingual](https://img.shields.io/badge/i18n-EN%20%2B%20中文-green.svg)]()

## What it does / 功能

Inspects your Linux machine across **CPU, memory, disk, processes, network,
services, temperatures, SMART disk health, security, and pending updates**.
Two modes:

| Mode | Command | Time | What it checks |
|---|---|---|---|
| Light  | `bash scripts/light.sh` | ~30s | OS, CPU, mem, disk, top procs, network, failed services |
| Deep   | `bash scripts/deep.sh`  | ~3–5min | Everything in light + SMART, thermal, I/O, boot, logs, security, updates, hardware |

It produces a structured report with ✅ ⚠️ ❌ icons and a **final summary
listing every actionable finding**. The thresholds are conservative — we
would rather under-warn than cry wolf.

## Installation / 安装

### Option 1: As a Claude Code skill (recommended)

```bash
git clone https://github.com/xplore-lab/pc-doctor.git \
  ~/.claude/skills/pc-doctor
```

Then in Claude Code just type:

```
/pc-doctor         # light mode
/pc-doctor --deep  # deep mode
/pc-doctor deep    # also works
```

Claude will pick the right script and summarize the output for you in your
preferred language.

### Option 2: Standalone CLI

```bash
git clone https://github.com/xplore-lab/pc-doctor.git
cd pc-doctor
bash scripts/light.sh       # or deep.sh
bash scripts/light.sh zh    # force Chinese output
bash scripts/deep.sh  en    # force English output
```

## Requirements / 系统要求

Linux (any distro). The scripts use only standard GNU coreutils + these
common packages:

```bash
sudo apt install -y procps iproute2 systemd lm-sensors smartmontools \
  sysstat dmidecode pciutils usbutils util-linux
```

`nvidia-smi` is optional — only needed if you have an NVIDIA GPU.

The scripts **degrade gracefully** when tools are missing: they print a
warning and skip the relevant section rather than failing.

## Example output / 样例输出

```
╔════════════════════════════════════════════════════════════╗
║  Computer Health Check Report                              ║
║  Mode: LIGHT                                               ║
║  Host: spark-44a8                                          ║
║  Time: 2026-07-14 09:49:13 CST                             ║
╚════════════════════════════════════════════════════════════╝

━━━ CPU & Load ━━━
OS:      Ubuntu 24.04.4 LTS  Kernel: 6.17.0-1021-nvidia
Arch:    aarch64   Uptime: up 1 day, 9 hours, 41 minutes
CPU:     Cortex-A725 + Cortex-X925  (big.LITTLE)
Cores:   20 logical / 10 physical (1 socket × 10 cores)
Load:    1m=0.33  5m=0.35  15m=0.48   (cores=20)
✅ Load is normal

━━━ Memory & Swap ━━━
              total        used        free      shared  buff/cache   available
Mem:          121Gi       113Gi       4.5Gi       117Mi       5.7Gi       8.5Gi
Swap:          15Gi       5.2Gi        10Gi
⚠️  Memory usage 93% — high
ℹ️  Swap usage 32%

━━━ Summary ━━━
❌ Overall: CRITICAL  (1 critical, 1 warnings)

❌ Recommendation (CRITICAL):
  • 2 failed systemd units

⚠️  Recommendation (WARNING):
  • Memory usage 93% (>=80%)
```

See [`examples/sample-output-light.txt`](examples/sample-output-light.txt) and
[`examples/sample-output-deep.txt`](examples/sample-output-deep.txt) for full real
runs.

## Thresholds / 阈值

| Metric | WARN | CRITICAL |
|---|---|---|
| CPU load (1-min) | ≥ cores | ≥ 2× cores |
| Memory % | ≥ 80% | ≥ 95% |
| Swap % | ≥ 50% | — |
| Disk % | ≥ 80% | ≥ 90% |
| Inode % | ≥ 70% | ≥ 90% |
| CPU temp | ≥ 70°C | ≥ 85°C |
| GPU temp | ≥ 80°C | ≥ 90°C |
| SMART reallocated | > 0 | — |
| Pending apt updates | > 50 | — |

See [`references/thresholds.md`](references/thresholds.md) for the rationale
behind every number.

## Safety / 安全

- **Read-only.** The scripts never modify your system.
- `sudo` is requested **only** for `smartctl` and `dmidecode` (both
  read-only). If you decline sudo, those sections print a notice and
  continue.
- **No network calls** except `ping` to `1.1.1.1` and `8.8.8.8` for
  reachability. Easy to comment out if you want zero network activity.
- No files written outside stdout.

## Platform support / 平台支持

| OS | Status |
|---|---|
| Ubuntu / Debian | ✅ Tested |
| Fedora / RHEL / CentOS | ✅ Works (use `dnf install` instead of `apt`) |
| Arch / Manjaro | ✅ Works |
| macOS | ❌ Not supported (different tool names) — PRs welcome |
| Windows (native) | ❌ Not supported |
| Windows (WSL2) | ⚠️ Partial — sensors/SMART unavailable |

## Project structure / 项目结构

```
pc-doctor/
├── SKILL.md                          ← main skill entrypoint (bilingual)
├── README.md                         ← this file (English)
├── README.zh-CN.md                   ← 中文版说明
├── LICENSE                           ← MIT
├── CONTRIBUTING.md                   ← how to contribute
├── scripts/
│   ├── lib.sh                        ← shared helpers (colors, thresholds, summary)
│   ├── light.sh                      ← ~30s check
│   └── deep.sh                       ← ~5min check
├── references/
│   ├── commands.md                   ← what each command does
│   ├── thresholds.md                 ← why each threshold was chosen
│   └── tools.md                      ← how to install missing tools
└── examples/
    ├── sample-output-light.txt       ← example light run
    └── sample-output-deep.txt        ← example deep run
```

## Contributing / 贡献

See [CONTRIBUTING.md](CONTRIBUTING.md). Top contributions we're hoping for:

- macOS / Windows (WSL) support
- More languages (Spanish, Japanese, French, …)
- Additional check categories (Docker, Kubernetes, GPU workloads)
- Smarter thresholds (e.g. swap pressure relative to RAM size)

## Inspiration / 灵感

Created because [anthropics/claude-code#1234](https://github.com/anthropics/claude-code/issues/1234)
asked for it and nobody had shipped one yet. Also inspired by
[Microsoft PC Health Check](https://www.microsoft.com/en-us/windows/pc-health-check-app),
[HWiNFO](https://www.hwinfo.com/), and [Neofetch](https://github.com/dylanaraps/neofetch).

## License / 许可证

MIT — see [LICENSE](LICENSE).