# Sakura 的 NixOS 桌面

一台 i5-12400 台式机，使用 Plasma 6、Wayland 和 Fcitx5 拼音。Konsole 和 Neovim 共用 Rosé Pine Dawn 配色。仓库放在 `~/nixos-config`，由 sakura 用户维护。

| 想改什么 | 去哪里 |
| --- | --- |
| 引导、网络、Intel 核显、磁盘维护 | `configuration.nix` |
| SDDM、输入法、字体、音频、VLC | `modules/desktop.nix` |
| Git 身份、开发工具、截图快捷键、桌面电源 | `home.nix` |
| 编辑器、语言服务、调试快捷键 | `config/nvim/init.lua` |
| 代理订阅、更新时覆盖的本机设置 | `modules/mihomo.nix`、`modules/mihomo-config.py` |
| Bash 和 KDE 的代理开关 | `modules/proxy-client.nix` |
| 账户、磁盘和挂载点 | `users.nix`、`hardware-configuration.nix` |

## 从上一版迁移

如果还在用仓库根目录的订阅文件，或 Neovim 仍只链接单个 `init.lua`，先退出 Neovim，以 sakura 用户进入 `~/nixos-config` 做下面对应的迁移。已经迁移过的机器直接重建即可。

1. **代理订阅**。如果之前用过代理，把旧文件移到新位置。

   ```bash
   install -d -m 700 ~/.config/mihomo
   chmod 600 ./clash-subscribe && mv -iT ./clash-subscribe ~/.config/mihomo/subscription-url
   ```

2. **Neovim**。现在 Home Manager 链接整个 `config/nvim/` 目录。若 `~/.config/nvim` 是旧版留下的普通目录，先带回已有的插件锁文件，再把原目录移到备份位置。其中自建的 `after/`、`lua/` 等文件可以按需合入仓库。

   ```bash
   if [[ -d ~/.config/nvim && ! -L ~/.config/nvim ]]; then
     if [[ -f ~/.config/nvim/nvim-pack-lock.json ]]; then
       cp -i ~/.config/nvim/nvim-pack-lock.json config/nvim/
     fi
     backup=$(mktemp -d ~/.config/nvim-backup.XXXXXX) && mv ~/.config/nvim "$backup/"
   fi
   ```

如果是把 ZIP 合入现有 Git 工作区，先运行 `git add modules/desktop.nix modules/mihomo-config.py modules/proxy-client.nix`，让 flake 能读取新增模块，然后重建。

## 日常使用

```bash
cd ~/nixos-config
sudo nixos-rebuild switch --flake .#sakura
```

NixOS、Home Manager 和 plasma-manager 的版本记录在 `flake.lock`。需要升级时在仓库里运行 `nix flake update`，再重建。

| 在 Bash 中输入 | 效果 |
| --- | --- |
| `rebuild` | 从任意目录重建并切换到 sakura 配置 |
| `gc` | 立即执行每周使用的垃圾回收任务，沿用 14 天保留策略 |
| `proxy-on` / `proxy-off` | 同时切换当前终端和 KDE 桌面的代理，新开的 Bash 跟随该选择 |
| `htop` | 查看 CPU、内存和进程 |

**桌面**。首次应用这版后，重新登录一次 Plasma。SDDM 自动登录 sakura，进入桌面后开启 NumLock。市电下使用性能模式，空闲时保持屏幕亮度和显示，手动锁屏也沿用同一设置。短按电源键执行关机。双击常见音乐文件（MP3、M4A、FLAC、Ogg、WAV）默认用 VLC 播放。

**截图**。Spectacle 自动保存到其默认截图目录。实际路径见 Spectacle 的图像保存设置，沿用 KDE 的本地化目录和文件名。

| 截图范围 | 快捷键 | US 键盘按法 |
| --- | --- | --- |
| 整个桌面 | `Alt+%` | `Alt+Shift+5` |
| 当前窗口 | `Alt+#` | `Alt+Shift+3` |
| 矩形选区 | `Alt+$` | `Alt+Shift+4` |

**Intel 视频解码**。这台 i5-12400 使用 iHD（VA-API）和 oneVPL（Quick Sync）。`vainfo` 列出驱动支持的格式，带 `VAEntrypointVLD` 的条目代表解码。播放本地或网页视频时，用 `sudo intel_gpu_top` 看 Video 引擎负载。Brave 中可用 `brave://media-internals` 检查当前视频选择的解码器。`vulkaninfo --summary` 可查看 Vulkan 枚举的 GPU 及其顺序。

**Neovim** 使用原生 Lua 和 `vim.pack`（Neovim 0.12+）。改完 Lua，重新打开编辑器即可。新装时，首次安装插件会生成 `config/nvim/nvim-pack-lock.json`。把它和 `init.lua` 一起提交，就能在其他机器上还原插件版本。在 macOS 上也可以把 Neovim 配置目录链接到本仓库的 `config/nvim`，并用本机的包管理器安装所需的外部工具。

**代理**。订阅文件 `~/.config/mihomo/subscription-url` 只放一行 HTTPS 地址，权限设为 `600`。开机和每天定时拉取。Bash、跟随系统代理的 Brave 和 KDE 应用共用 `127.0.0.1:7890`，本机回环地址直连。两个开关只改变客户端设置，mihomo 继续按原计划运行。其他已打开的终端保留各自的环境，可以在里面再次运行同一开关。编辑订阅地址后可立即刷新。

```bash
sudo systemctl start mihomo-subscription
systemctl status mihomo
```

**其他本机设置**。需要 dsh 的终端界面时，运行 `dsh plugin --profile tui add @deepseek-harness-tui/dsh-tui`，之后用 `dsh tui` 启动，Web 界面用 `dsh web`。KWallet 密码在 KWalletManager 中修改。

## 重装这台机器

这些步骤复用已有的 Btrfs 子卷和 EFI 系统分区。先用 `lsblk -f` 与 `hardware-configuration.nix` 核对 UUID。安装介质使用 NetworkManager 时，运行 `nmcli --ask device wifi connect "SSID名称"` 联网。如果 USB 网卡以虚拟光驱出现，先确认其设备名，再弹出对应的虚拟光驱。

```bash
rootDev=/dev/disk/by-uuid/4809a84e-4d94-49a4-b4f6-624b0ea24fa2
espDev=/dev/disk/by-uuid/77E1-DAC4
sudo mount --mkdir -o subvol=@,compress=zstd:3,noatime "$rootDev" /mnt
sudo mount --mkdir -o subvol=@home,compress=zstd:3,noatime "$rootDev" /mnt/home
sudo mount --mkdir -o subvol=@nix,compress=zstd:3,noatime "$rootDev" /mnt/nix
sudo mount --mkdir -o subvol=@log,compress=zstd:3,noatime "$rootDev" /mnt/var/log
sudo mount --mkdir "$espDev" /mnt/boot
```

将仓库放在 `/mnt/home/sakura/nixos-config`。root 和 sakura 按 `users.nix` 读取同一份密码哈希。首次安装且目标卷还没有该文件时，在目标根卷直接生成。

```bash
sudo mkdir -p /mnt/etc/nixos
sudo sh -c 'set -C; umask 077; mkpasswd > /mnt/etc/nixos/sakura-password-hash'
```

```bash
sudo nixos-install --root /mnt --no-root-passwd \
  --flake /mnt/home/sakura/nixos-config#sakura \
  --option substituters https://mirrors.ustc.edu.cn/nix-channels/store
sudo nixos-enter --root /mnt -c 'passwd -S root && passwd -S sakura'
```

`passwd -S` 的第二列为 `P` 表示已设置密码。首次登录后确认 sakura 对 `~/nixos-config` 有写权限，以便 Neovim 更新插件锁。
