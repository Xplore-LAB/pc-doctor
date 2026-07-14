# Missing tools / 缺失工具

If the health check complains about a missing tool, here's what to
install. All packages are available in the standard repositories of
major Linux distributions.

如果体检脚本提示某个工具缺失，下面是安装方法。

## Debian / Ubuntu
```bash
sudo apt update
sudo apt install -y \
  procps        # ps, free, uptime, vmstat, sysctl
  lsof          # not used yet but handy
  iproute2      # ip, ss
  systemd       # systemctl, systemd-analyze, journalctl
  lm-sensors    # sensors
  smartmontools # smartctl
  sysstat       # iostat, mpstat
  dmidecode     # DMI/SMBIOS
  pciutils      # lspci
  usbutils      # lsusb
  util-linux    # lsblk, lsmem, etc.
  curl wget     # for connectivity
  nvidia-utils-<nvidia-driver-version>  # nvidia-smi (only on NVIDIA systems)
```

## RHEL / Fedora / CentOS
```bash
sudo dnf install -y \
  procps-ng lm_sensors smartmontools sysstat dmidecode \
  pciutils usbutils util-linux iproute nvidia-settings
```

## Arch / Manjaro
```bash
sudo pacman -S lm_sensors smartmontools sysstat dmidecode \
  pciutils usbutils util-linux iproute2 nvidia-utils
```

## macOS
Not officially supported — most commands differ (`vm_stat` vs `vmstat`,
`diskutil` vs `lsblk`, no SMART without `smartmontools` from Homebrew,
no `sensors`). For macOS use `Apple Diagnostics` (hold D at boot) or
`Hardware IO Tools for Xcode`.

If you'd like to add macOS support, PRs welcome — see `CONTRIBUTING.md`.

## Windows (WSL)
Works inside WSL2 with the caveat that:
- `sensors` returns nothing (no thermal access from WSL)
- `nvidia-smi` works if you have the Windows NVIDIA driver + WSL CUDA
- `smartctl` works for SMART but device paths differ (`/dev/sdX` vs `/dev/nvme0n1`)
- `systemd-analyze` requires systemd-as-WSL-init (Windows 11 22H2+)

## Sensors first-run / 第一次跑 sensors
`lm-sensors` needs a one-time hardware probe:
```bash
sudo sensors-detect   # answer 'yes' to all
sudo service kmod start   # or reboot
sensors                 # now shows temps
```

## smartctl permissions / smartctl 权限
To run smartctl without sudo, add yourself to the `disk` group:
```bash
sudo usermod -aG disk $USER
# log out and back in
```
Or run the script with sudo — it's safe (read-only).