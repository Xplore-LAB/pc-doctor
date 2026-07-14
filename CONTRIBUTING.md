# Contributing to PC Doctor / 贡献指南

Thanks for helping make computer diagnostics easier for everyone.
感谢你帮大家把电脑诊断变得更容易。

## Quick start / 快速上手

```bash
git clone https://github.com/YOUR_USER/pc-doctor.git
cd pc-doctor
bash scripts/light.sh       # ~30s
bash scripts/deep.sh        # ~3-5min
```

## Where to add what / 在哪里加什么

| You want to... | Edit |
|---|---|
| Add a new check section | `scripts/light.sh` or `scripts/deep.sh` |
| Change a threshold | `scripts/light.sh` / `scripts/deep.sh` (the `case` blocks) or `scripts/lib.sh` |
| Change output colors | `scripts/lib.sh` (`C_OK` etc.) |
| Add a new language | `scripts/lib.sh` (the `t()` function) |
| Add a new tool fallback | `references/tools.md` |
| Document a new command | `references/commands.md` |

## Coding style / 代码风格

- **Bash 5+** compatible. Use `#!/usr/bin/env bash`.
- Source `lib.sh` for all shared helpers (colors, thresholds, summary).
- Use `LC_ALL=C LANG=C` at the top to ensure parsing is locale-independent.
- Use `judge_pct` for percentage thresholds (returns 0/1/2).
- Use `ok` / `warn` / `crit` / `info` / `dim` for status lines.
- Use `record warn "..."` / `record crit "..."` to add to the final summary.
- Keep each section under `section <key>` so it gets a heading.
- New translatable strings go through `t "key"` (defined in `lib.sh`).
- Don't use `set -e` — we want the script to keep going even when one
  tool fails.

## Testing / 测试

Before submitting a PR:

```bash
# 1. Run both modes, check the summary block makes sense
bash scripts/light.sh | tail -20
bash scripts/deep.sh | tail -30

# 2. Check shellcheck (if you have it)
shellcheck scripts/*.sh

# 3. Check formatting with shfmt (optional, our format is shfmt default)
shfmt -d scripts/*.sh
```

If you have a weird platform (ARM big.LITTLE, weird disk, etc.) please
include the relevant `lscpu`, `df`, and `lsblk` output in the PR
description — it helps us add platform-specific handling.

## Translation workflow / 翻译流程

To add a new language (e.g. Japanese):

1. In `lib.sh`, add a new branch in `t()`:
   ```bash
   ja:title)        echo "パソコン健康診断レポート";;
   ja:section_cpu)  echo "CPUと負荷";;
   # ... etc
   ```
2. Set `HC_LANG=ja` to test, or pass `bash light.sh ja`.
3. Update `SKILL.md` to mention the new language.
4. Optionally add a `README.ja.md`.

## Adding a new check / 添加新检查项

Example: add a Docker container health check.

```bash
section docker_containers  # add the key to t() first
if command -v docker >/dev/null 2>&1; then
  running=$(docker ps -q 2>/dev/null | wc -l)
  info "$running containers running"
  # Maybe check for restart counts:
  high_restart=$(docker ps --format '{{.Names}}\t{{.Status}}' 2>/dev/null \
    | grep -c "Restarting")
  if (( high_restart > 0 )); then
    warn "$high_restart containers in restart loop"
    record warn "$high_restart Docker containers restarting"
  fi
else
  dim "(docker not installed — skipping)"
fi
```

## Versioning / 版本

We don't tag releases often — when we do, it's the date:
`v2026.07.14`. The scripts themselves are versionless and self-contained.

## Code of conduct / 行为准则

Be kind. We're all here because our computers broke at some point.
对人友善。我们都在电脑坏掉时聚到这里。