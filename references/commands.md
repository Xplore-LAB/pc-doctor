# Command Reference / 命令参考

Each section of the health check uses one or more shell tools. This file
explains what each one does, in case you want to run them by hand.

体检脚本每一节都用到了一个或多个 shell 工具。本文件解释每个工具的
作用，方便你单独手动跑。

## System info / 系统信息

| Command | Purpose |
|---|---|
| `uname -a` | Kernel, architecture, hostname |
| `cat /etc/os-release` | Distribution name & version (Debian family) |
| `uptime -p` | Pretty uptime ("3 days, 4 hours") |
| `who -b` | Last boot time |
| `hostname` | Machine name |

## CPU / CPU

| Command | Purpose |
|---|---|
| `lscpu` | CPU model, cores, threads, cache |
| `nproc` | Number of logical CPUs |
| `cat /proc/loadavg` | 1/5/15-min load average + running/total procs |
| `mpstat -P ALL 1 1` | Per-CPU utilization snapshot |

## Memory / 内存

| Command | Purpose |
|---|---|
| `free -h` | Total/used/free RAM and swap, human-readable |
| `cat /sys/kernel/mm/hugepages/*/nr_hugepages` | Hugepage configuration |

## Disk / 磁盘

| Command | Purpose |
|---|---|
| `df -h` | Filesystem usage |
| `df -i` | Inode usage |
| `lsblk` | Block device tree (incl. rotation, model) |
| `iostat -dx 2 2` | Per-device I/O statistics (2 × 2s sample) |
| `vmstat 1 2` | System-wide I/O, CPU, memory snapshot |
| `smartctl -H -A -i /dev/sdX` | SMART health, attributes, device info |

## Processes / 进程

| Command | Purpose |
|---|---|
| `ps -eo pid,user,pcpu,pmem,comm --sort=-pcpu` | Top processes by CPU |
| `ps -eo pid,user,pcpu,pmem,comm --sort=-pmem` | Top processes by MEM |

## Network / 网络

| Command | Purpose |
|---|---|
| `ip -brief addr show` | IP addresses (brief) |
| `ip route show default` | Default gateway |
| `ping -c 2 -W 2 1.1.1.1` | Internet reachability (Cloudflare DNS) |
| `ss -tln` | TCP ports in LISTEN |
| `ss -tlnp` | Same, with process names |
| `ss -tnp state established` | Established TCP connections |

## Services & logs / 服务与日志

| Command | Purpose |
|---|---|
| `systemctl --failed` | Failed systemd units |
| `systemd-analyze` | Boot time breakdown |
| `systemd-analyze blame` | Slowest-starting services |
| `journalctl -p 3 -b` | Error+ priority messages since boot |
| `dmesg` | Kernel ring buffer (OOM, segfaults, panics) |
| `ls /var/crash` | Crash dump files |

## Security / 安全

| Command | Purpose |
|---|---|
| `find /etc -xdev -type f -perm -o=w` | World-writable files in /etc |
| `find /usr -xdev -type f -perm -4000` | SUID binaries |
| `ss -tlnp` | Listening ports with owning process |

## Updates / 更新

| Command | Purpose |
|---|---|
| `apt list --upgradable` | Debian/Ubuntu pending updates |
| `dnf check-update` | Fedora/RHEL pending updates |

## Hardware / 硬件

| Command | Purpose |
|---|---|
| `lspci` | PCI devices (network, GPU, etc.) |
| `lsusb` | USB devices |
| `dmidecode -t system` | System info (manufacturer, serial, BIOS) |
| `dmidecode -t memory` | RAM slots & speeds |

## Thermal / 温度

| Command | Purpose |
|---|---|
| `sensors` | CPU/motherboard temps (lm-sensors) |
| `nvidia-smi --query-gpu=...` | NVIDIA GPU temp, util, power |