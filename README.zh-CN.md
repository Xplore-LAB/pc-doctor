# PC Doctor 🩺💻

> 为 Claude Code 设计的中英双语电脑体检 skill。两种模式，零依赖，零网络调用（除连通性 ping 外）。
>
> A bilingual computer health check skill for Claude Code. Two modes, zero dependencies, zero network calls (except connectivity ping).

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Linux](https://img.shields.io/badge/Platform-Linux-blue.svg)]()
[![Bilingual](https://img.shields.io/badge/i18n-EN%20%2B%20中文-green.svg)]()

## 功能

全面检查你的 Linux 机器，覆盖 **CPU、内存、磁盘、进程、网络、服务、温度、SMART 硬盘健康、安全与待更新包**。两种模式：

| 模式 | 命令 | 耗时 | 检查项 |
|---|---|---|---|
| 轻量  | `bash scripts/light.sh` | ~30 秒 | 系统、CPU、内存、磁盘、Top 进程、网络、失败服务 |
| 深度  | `bash scripts/deep.sh`  | ~3–5 分钟 | 轻量全部 + SMART、温度、I/O、启动、日志、安全、更新、硬件清单 |

输出结构化报告，带 ✅ ⚠️ ❌ 图标，**末尾汇总每一条可操作的发现**。阈值设得保守——宁可不报，也不乱报。

## 安装

### 方式一：作为 Claude Code skill（推荐）

```bash
git clone https://github.com/xplore-lab/pc-doctor.git \
  ~/.claude/skills/pc-doctor
```

然后在 Claude Code 里直接说：

```
/pc-doctor         # 轻量
/pc-doctor --deep  # 深度
/pc-doctor deep    # 也行
```

Claude 会自动选对应脚本并用你偏好的语言汇总结果。

### 方式二：独立 CLI

```bash
git clone https://github.com/xplore-lab/pc-doctor.git
cd pc-doctor
bash scripts/light.sh       # 或 deep.sh
bash scripts/light.sh zh    # 强制中文
bash scripts/deep.sh  en    # 强制英文
```

## 系统要求

任意 Linux 发行版。脚本只用 GNU coreutils + 这些常见包：

```bash
sudo apt install -y procps iproute2 systemd lm-sensors smartmontools \
  sysstat dmidecode pciutils usbutils util-linux
```

`nvidia-smi` 可选——只有 NVIDIA 显卡才需要。

脚本**优雅降级**：缺工具时会打印警告并跳过对应小节，不会直接报错退出。

## 样例输出

```
╔════════════════════════════════════════════════════════════╗
║  电脑体检报告                                              ║
║  Mode: LIGHT                                               ║
║  Host: spark-44a8                                          ║
║  Time: 2026-07-14 09:49:13 CST                             ║
╚════════════════════════════════════════════════════════════╝

━━━ CPU 与负载 ━━━
OS:      Ubuntu 24.04.4 LTS  Kernel: 6.17.0-1021-nvidia
Arch:    aarch64   Uptime: up 1 day, 9 hours, 41 minutes
CPU:     Cortex-A725 + Cortex-X925  (big.LITTLE)
Cores:   20 logical / 10 physical (1 socket × 10 cores)
Load:    1m=0.33  5m=0.35  15m=0.48   (cores=20)
✅ Load is normal

━━━ 内存与交换 ━━━
              total        used        free      shared  buff/cache   available
Mem:          121Gi       113Gi       4.5Gi       117Mi       5.7Gi       8.5Gi
Swap:          15Gi       5.2Gi        10Gi
⚠️  Memory usage 93% — high
ℹ️  Swap usage 32%

━━━ 汇总 ━━━
❌ 整体状态: CRITICAL  (1 critical, 1 warnings)

❌ 建议 (CRITICAL):
  • 2 failed systemd units

⚠️  建议 (WARNING):
  • Memory usage 93% (>=80%)
```

完整样例见 [`examples/sample-output-light.txt`](examples/sample-output-light.txt) 和
[`examples/sample-output-deep.txt`](examples/sample-output-deep.txt)。

## 阈值

| 指标 | 警告 | 严重 |
|---|---|---|
| CPU 负载（1 分钟） | ≥ 核心数 | ≥ 2× 核心数 |
| 内存 % | ≥ 80% | ≥ 95% |
| 交换 % | ≥ 50% | — |
| 磁盘 % | ≥ 80% | ≥ 90% |
| inode % | ≥ 70% | ≥ 90% |
| CPU 温度 | ≥ 70°C | ≥ 85°C |
| GPU 温度 | ≥ 80°C | ≥ 90°C |
| SMART 重映射扇区 | > 0 | — |
| 待更新包 | > 50 | — |

每个数字的取舍逻辑见 [`references/thresholds.md`](references/thresholds.md)。

## 安全

- **只读。** 脚本从不修改你的系统。
- `sudo` **只用于** `smartctl` 和 `dmidecode`（都只读）。拒绝 sudo 就跳过对应小节。
- **无网络调用**（除 ping `1.1.1.1` 和 `8.8.8.8` 测连通性外）。要彻底离线把 ping 那段注释掉。
- 不在 stdout 外写任何文件。

## 平台支持

| 系统 | 状态 |
|---|---|
| Ubuntu / Debian | ✅ 已测 |
| Fedora / RHEL / CentOS | ✅ 可用（用 `dnf install`） |
| Arch / Manjaro | ✅ 可用 |
| macOS | ❌ 不支持（命令名差异大）——欢迎 PR |
| Windows（原生） | ❌ 不支持 |
| Windows（WSL2） | ⚠️ 部分可用——sensors/SMART 不可用 |

## 项目结构

```
pc-doctor/
├── SKILL.md                          ← skill 入口（中英双语）
├── README.md                         ← 英文说明
├── README.zh-CN.md                   ← 本文件
├── LICENSE                           ← MIT
├── CONTRIBUTING.md                   ← 贡献指南
├── scripts/
│   ├── lib.sh                        ← 共享工具（颜色、阈值、汇总）
│   ├── light.sh                      ← 30 秒版
│   └── deep.sh                       ← 5 分钟版
├── references/
│   ├── commands.md                   ← 每条命令的作用
│   ├── thresholds.md                 ← 为什么选这个阈值
│   └── tools.md                      ← 缺工具怎么装
└── examples/
    ├── sample-output-light.txt       ← 轻量样例
    └── sample-output-deep.txt        ← 深度样例
```

## 贡献

见 [CONTRIBUTING.md](CONTRIBUTING.md)。最希望得到的贡献：

- macOS / Windows (WSL) 支持
- 更多语言（西班牙语、日语、法语……）
- 更多检查类别（Docker、Kubernetes、GPU 负载）
- 更智能的阈值（如根据内存大小动态调整 swap 阈值）

## 灵感

起因是 [anthropics/claude-code#1234](https://github.com/anthropics/claude-code/issues/1234)
有需求但没人做。同时也参考了
[Microsoft PC Health Check](https://www.microsoft.com/en-us/windows/pc-health-check-app)、
[HWiNFO](https://www.hwinfo.com/) 和 [Neofetch](https://github.com/dylanaraps/neofetch)。

## 许可证

MIT —— 见 [LICENSE](LICENSE)。