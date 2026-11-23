# Sakura 的 NixOS 桌面

一台主机名为 `laurel` 的 i5-12400 台式机，Plasma 6 + Wayland + Fcitx5。仓库放在 `~/nixos-config`，由 `sakura` 用户维护。网络由 NetworkManager 管理，代理由 mihomo 提供。

## 目录

| 路径 | 内容 |
| --- | --- |
| `hosts/laurel/default.nix` | 引导、NetworkManager、SSH、Intel 核显、磁盘维护、系统包 |
| `hosts/laurel/hardware-configuration.nix` | 磁盘 UUID、文件系统、内核模块 |
| `hosts/laurel/users.nix` | 账户、密码哈希、sudo |
| `hosts/laurel/home.nix` | 用户包、Plasma、Ghostty、Bash 别名 |
| `modules/nixos/desktop.nix` | ly 登录管理器、输入法、字体、音频、Haruna、Brave |
| `modules/nixos/mihomo.nix` | mihomo 服务与手动订阅更新 unit |
| `modules/home/proxy-client.nix` | Bash 与 KDE 的代理开关 |
| `modules/home/nvim/init.lua` | Neovim 0.12+ 配置 |

## 日常使用

```bash
cd ~/nixos-config
sudo nixos-rebuild switch --flake .#laurel
```

- 需要升级时在仓库里运行 `nix flake update`，再重建
- 格式化用 `nix fmt`（`nixfmt-tree`）

| 在 Bash 中输入 | 效果 |
| --- | --- |
| `rebuild` | 从任意目录重建并切换到 laurel 配置（用当前 `flake.lock`，不更新） |
| `update` | `nix flake update` 后再 rebuild，即真正的滚动更新 |
| `gc` | 立即执行每周使用的垃圾回收任务，沿用 14 天保留策略 |
| `mihomo-update` | 手动拉取订阅并重启 mihomo；开机不会自动拉取 |
| `boot-clean` | 清理到只剩当前 generation：删历史 → 重建启动菜单 → 回收 store |
| `proxy-on` / `proxy-off` | 同时切换当前终端和 KDE 桌面的代理，新开的 Bash 跟随该选择 |
| `htop` | 查看 CPU、内存和进程 |

- 启动菜单平时保留 10 条（`boot.loader.systemd-boot.configurationLimit`）
- 需要回收时用 `boot-clean` 清到只剩当前一个

## 桌面

Plasma 设置由 `plasma-manager` 声明，并开启了 `overrideConfig`

- 每次 activation 会删除或重置未声明的 KDE 配置（Dolphin、KRunner/Klipper、窗口规则、键盘布局、全局快捷键等）
- 面板/小部件布局（`appletsrc`）、代理开关（`kioslaverc`）和截图保存路径（`spectaclerc`）属于运行时状态，不在重置范围
- `plasmashellrc` 也保留，避免重跑 Plasma 迁移脚本
- 壁纸由 `workspace.wallpaper` 固定为 `~/Pictures/bliss.jpg`

Spectacle 自动保存到其默认截图目录。实际路径见 Spectacle 的图像保存设置

| 截图范围 | 快捷键 | US 键盘按法 |
| --- | --- | --- |
| 整个桌面 | `Alt+%` | `Alt+Shift+5` |
| 当前窗口 | `Alt+#` | `Alt+Shift+3` |
| 矩形选区 | `Alt+$` | `Alt+Shift+4` |

**Intel 视频解码**。这台 i5-12400 使用 iHD（VA-API）和 oneVPL（Quick Sync）

- 播放本地或网页视频时，用 `sudo intel_gpu_top` 看 Video 引擎负载
- Brave 中可用 `brave://media-internals` 检查当前视频选择的解码器
- `vulkaninfo --summary` 可查看 Vulkan 枚举的 GPU 及其顺序

## Neovim

使用原生 Lua 和 `vim.pack`（Neovim 0.12+，当前 0.12.6）

- `~/.config/nvim` 是指向 `modules/home/nvim` 的链接，改完 Lua 重新打开编辑器即可生效
- 只改 `init.lua` 不需要重建系统，改 `home.nix` 里的包才需要 `rebuild`

## 代理

订阅文件 `~/.config/mihomo/subscription-url` 只放一行 HTTPS 地址，权限设为 `600`：

```bash
install -d -m 700 ~/.config/mihomo
chmod 600 ~/.config/mihomo/subscription-url
```

- 订阅**只在手动执行 `mihomo-update` 时更新**，开机和定时器都不会拉取
- 已存在的配置会在开机时直接启动 mihomo，保持快速启动。首次安装或更换订阅后执行

```bash
mihomo-update
systemctl status mihomo
```

mihomo 的端口、模式、规则以订阅为准，本仓库不再覆盖 `mixed-port`/`port`

- Bash、跟随系统代理的 Brave 和 KDE 应用共用 `127.0.0.1:7890`，本机回环地址直连
- 如果订阅端口不是 7890，需要同步修改 `modules/home/proxy-client.nix`
- 两个开关只改变客户端设置，mihomo 继续按原计划运行

## 密码

`/etc/nixos/sakura-password-hash` 是 root 和 sakura 共用的密码哈希。修改密码：

```bash
sudo sh -c 'umask 077; mkpasswd > /etc/nixos/sakura-password-hash'
sudo chown root:root /etc/nixos/sakura-password-hash
sudo chmod 600 /etc/nixos/sakura-password-hash
sudo nixos-rebuild switch --flake ~/nixos-config#laurel
```

## 重装这台机器

以下步骤复用已有的 Btrfs 子卷和 EFI 系统分区。先用 `lsblk -f` 与 `hosts/laurel/hardware-configuration.nix` 核对 UUID；如果重新分区，UUID 会变，必须同步修改 hardware 文件。

### 数据盘命名

- `maia` 是单盘 Btrfs（`nvme0n1`，2T）
- `ganette` 是两块 256G SSD（`sda` + `sdb`）组成的多设备 Btrfs
- 格式化时直接带上正确名字；这两条会清空盘上数据，只在准备重装时执行：

```bash
sudo mkfs.btrfs -L maia /dev/nvme0n1
sudo mkfs.btrfs -L ganette /dev/sda /dev/sdb
```

已有文件系统改名不影响 UUID 和 fstab；换盘或标签不同步时，挂载后执行：

```bash
sudo btrfs filesystem label /home/sakura/maia maia
sudo btrfs filesystem label /home/sakura/ganette ganette
```

标签存在 Btrfs 元数据里，多设备卷一条命令就同时更新两块盘；重登 Plasma 后 Dolphin 会显示 `maia` 和 `ganette`。

### 挂载

```bash
ROOT=/dev/disk/by-uuid/4809a84e-4d94-49a4-b4f6-624b0ea24fa2
ESP=/dev/disk/by-uuid/77E1-DAC4

sudo mount --mkdir -o subvol=@,compress=zstd:3,noatime "$ROOT" /mnt
sudo mount --mkdir -o subvol=@home,compress=zstd:3,noatime "$ROOT" /mnt/home
sudo mount --mkdir -o subvol=@nix,compress=zstd:3,noatime "$ROOT" /mnt/nix
sudo mount --mkdir -o subvol=@log,compress=zstd:3,noatime "$ROOT" /mnt/var/log
sudo mount --mkdir "$ESP" /mnt/boot
```

### 安装环境联网

安装镜像使用 NetworkManager 时：

```bash
nmcli device wifi connect "SSID名称" password "密码"
```

### 密码

把仓库放在 `/mnt/home/sakura/nixos-config`。首次安装且目标卷还没有密码哈希时，在目标根卷生成：

```bash
sudo mkdir -p /mnt/etc/nixos
sudo sh -c 'umask 077; mkpasswd > /mnt/etc/nixos/sakura-password-hash'
sudo chown root:root /mnt/etc/nixos/sakura-password-hash
sudo chmod 600 /mnt/etc/nixos/sakura-password-hash
```

### 安装

ESP 已经挂到 `/mnt/boot`，再执行：

```bash
sudo nixos-install --root /mnt --no-root-passwd \
  --flake /mnt/home/sakura/nixos-config#laurel \
  --option substituters https://mirrors.ustc.edu.cn/nix-channels/store

sudo nixos-enter --root /mnt -c 'passwd -S root && passwd -S sakura'
```

`passwd -S` 的第二列为 `P` 表示已设置密码。首次登录后确认 sakura 对 `~/nixos-config` 有写权限；如果需要代理，先放好 `~/.config/mihomo/subscription-url`，再执行 `mihomo-update`。

## 其他本机设置

需要 dsh 的终端界面时，运行 `dsh plugin --profile tui add @deepseek-harness-tui/dsh-tui`，之后用 `dsh tui` 启动，Web 界面用 `dsh web`。
