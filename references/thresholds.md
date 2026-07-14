# Threshold Reference / 阈值参考

Every status icon in the health check is driven by a threshold. This
file explains each one and why we picked it.

体检里每一个状态图标都来自一个阈值。本文件解释每个阈值与选它的理由。

## Resource thresholds / 资源阈值

| Metric / 指标 | Warn / 警告 | Critical / 严重 | Rationale / 理由 |
|---|---|---|---|
| CPU load (1-min avg) | ≥ cores | ≥ 2× cores | A system at 1× cores is busy but coping. At 2× it's saturated; processes are queueing. |
| Memory used % | ≥ 80% | ≥ 95% | At 80% the kernel starts reclaiming cache; at 95% OOM is imminent. |
| Swap used % | ≥ 50% | — | Heavy swapping is the classic "system feels slow" symptom. |
| Disk used % | ≥ 80% | ≥ 90% | Most sysadmins agree. Above 90% logs grow, /tmp fills, things break. |
| Inode used % | ≥ 70% | ≥ 90% | A disk with 5% space can still 100% fill inodes (mail spools, small files). |
| Disk I/O util | — | ≥ 80% sustained | Storage is the bottleneck; queues grow, latency spikes. |

## Thermal thresholds / 温度阈值

| Component | Warn | Critical | Note |
|---|---|---|---|
| CPU core temp | 70°C | 85°C | Most CPUs throttle 90-100°C. Warn early to clean fans. |
| GPU temp | 80°C | 90°C | NVIDIA throttles ~95°C. |
| NVMe SSD temp | 55°C | 70°C | Thermal throttle starts ~70°C on most consumer drives. |

## SMART thresholds / SMART 阈值

| Attribute | Action |
|---|---|
| Reallocated_Sector_Ct > 0 | ❌ CRITICAL — drive has bad blocks remapped. Back up data, replace soon. |
| Current_Pending_Sector > 0 | ❌ CRITICAL — sectors awaiting remap. Often pre-cursor to reallocated. |
| Reported_Uncorrect > 0 | ❌ CRITICAL — uncorrectable read errors. |
| Temperature_Celsius ≥ 55 | ⚠️ WARN — drive running hot. |
| Power_On_Hours > 30000 (~3.4yr) | ℹ️ INFO — getting old; monitor more closely. |

## Security thresholds / 安全阈值

| Check | Threshold |
|---|---|
| World-writable files in /etc | any = warn |
| SUID binaries | listed (informational) |
| Failed services | any = critical |
| Open ports (LISTEN) | listed (informational) |

## Why these numbers / 为什么选这些数字

We deliberately picked **conservative** thresholds — better to under-warn
than to spam the user with "everything is fine" false positives.

我们有意选择**保守**的阈值——少报警比乱报警更好。

- **Memory 80/95**: matches [Linux kernel `watermark_scale_factor`](https://www.kernel.org/doc/html/latest/admin-guide/sysctl/vm.html) behavior. Below 80% the kernel happily reclaims cache; above 80% it starts killing reclaimable workloads.
- **Disk 80/90**: industry standard. ext4 default reserved blocks is 5%, which kicks in around 95%.
- **CPU load = cores**: a load average equal to core count means zero idle time. Load = 2× cores means processes are waiting *more than one full scheduler quantum* on average.

If you disagree, the thresholds are easy to tweak in `scripts/lib.sh` —
search for `judge_pct` and the `case` blocks in `light.sh` / `deep.sh`.