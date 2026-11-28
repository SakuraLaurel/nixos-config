# laurel 的 NixOS 桌面

i5-12400 台式机，Plasma 6、Wayland 和 Fcitx5。仓库放在 `~/nixos-config`，系统入口是 `.#laurel`。

## 日常命令

| 命令 | 用途 |
| --- | --- |
| `rebuild` | 按当前 `flake.lock` 重建并切换系统，可在任意目录执行 |
| `update` | 更新 `flake.lock`，随后重建并切换 |
| `nix fmt` | 在仓库根目录格式化 Nix 文件 |
| `proxy-on` / `proxy-off` | 切换 KDE 和当前 Bash 的代理，新开的 Bash 跟随 KDE |
| `mihomo-update` | 手动更新订阅、重启 mihomo，显示最近的更新日志 |
| `boot-clean` | 删除系统 profile 的全部历史代，只保留当前代，再重写启动菜单并回收空间 |
| `sudo fwupdmgr refresh && sudo fwupdmgr update` | 检查并安装设备固件更新 |

平时由每周 GC 清理 7 天前的旧代，启动菜单最多显示 10 代。需要回滚时别运行 `boot-clean`。

新建脚本或模块后，先用 `git add` 将文件纳入版本控制，flake 才能在重建时读取它。

## 改哪里

- `hosts/laurel/` 管主机。引导、网络和数据盘在 `default.nix`，账户在 `users.nix`，用户包和 Plasma 偏好在 `home.nix`。
- `modules/nixos/desktop.nix` 管桌面、字体、输入法和 Brave。`ddns-go.nix` 管动态 DNS。
- **代理**的系统服务和订阅目录在 `modules/nixos/mihomo.nix`，下载和校验在同目录的 `mihomo-subscription-update.sh`。KDE 和 Bash 共用的地址在 `modules/home/proxy-client.nix`，终端命令在同目录的 `proxy-client.bash`。
- **Neovim** 直接读取 `modules/home/nvim/`。改 Lua 后重开编辑器即可，回滚系统代仍会读取当前工作树。用 `:PackUpdate` 升级插件后一起提交 `nvim-pack-lock.json`。

## 代理与 DDNS

**代理。** 在 `~/.config/mihomo/subscription-url` 写入一行 HTTPS 订阅地址，设为 `0600`，运行 `mihomo-update`。开机沿用上次配置，只有手动更新才拉取订阅。下载或校验失败会保留旧文件。若重启失败，`/var/lib/mihomo-subscription/config.yaml` 已经是新文件。用 `systemctl status mihomo` 查启动状态，再用一次代理请求确认端口可用。

客户端默认使用 `127.0.0.1:7890`。订阅要提供 `mixed-port: 7890` 才能同时支持 HTTP 和 SOCKS。端口变更时同步修改 `proxy-client.nix` 的 `address`。已打开的其他 Bash 需要各自切换。

**DDNS。** 管理页面在 `http://127.0.0.1:9876`。远程使用 `ssh -L 9876:127.0.0.1:9876 sakura@laurel` 转发后，在本机打开同一地址。配置和凭据保存在 `/var/lib/ddns-go/config.yaml`。

阿里云使用单独的 RAM 用户和 DNS 权限。配置 AAAA 记录，TTL 设为 600。IPv6 取址选「通过命令获取」，跳过临时地址和已弃用地址。

```bash
dev=$(ip -6 route show default | awk '{print $5; exit}'); ip -6 addr show dev "$dev" scope global -temporary | awk '$1 == "inet6" && $0 !~ /deprecated/ {sub(/\/.*/, "", $2); print $2; exit}'
```

## 桌面与登录

- Plasma 会在激活时重置受管文件中的手动修改。面板布局、时钟、代理开关和截图目录可以在 GUI 调。壁纸需放在 `~/Pictures/bliss.jpg`。
- `Ctrl+Alt+T` 打开 Ghostty。US 键盘用 `Alt+Shift+5` 截全屏、`Alt+Shift+3` 截活动窗口、`Alt+Shift+4` 截选区。
- Brave 硬解可在播放视频时用 `sudo intel_gpu_top` 看 Video 引擎，或在 `brave://media-internals` 看解码器。
- dsh 的终端界面首次需要运行 `dsh plugin --profile tui add @deepseek-harness-tui/dsh-tui`，之后用 `dsh tui` 打开。
- SSH 仅接受公钥。更换 `~/.ssh/authorized_keys` 时保留现有会话，用新会话验证。
- root 和 sakura 共用 `/etc/nixos/sakura-password-hash`。改密码用 `sudo sh -c 'umask 077; mkpasswd > /etc/nixos/sakura-password-hash'`，再执行 `rebuild`。

## 重装到现有磁盘

先用 `lsblk -f` 核对 UUID。系统盘和 EFI 分区见 `hosts/laurel/hardware-configuration.nix`，数据盘见 `default.nix` 的 `dataDisks`。以下步骤复用原有子卷。需要 Wi-Fi 时，在安装环境运行 `nmcli --ask device wifi connect 'SSID'`。

**挂载。** 将下面两个设备路径换成核对过的值，在安装环境执行。

```bash
root_dev=/dev/disk/by-uuid/系统盘UUID
esp_dev=/dev/disk/by-uuid/EFI分区UUID
sudo mount --mkdir -o subvol=@,compress=zstd:3,noatime "$root_dev" /mnt
sudo mount --mkdir -o subvol=@home,compress=zstd:3,noatime "$root_dev" /mnt/home
sudo mount --mkdir -o subvol=@nix,compress=zstd:3,noatime "$root_dev" /mnt/nix
sudo mount --mkdir -o subvol=@log,compress=zstd:3,noatime "$root_dev" /mnt/var/log
sudo mount --mkdir "$esp_dev" /mnt/boot
```

**准备账户。** 仓库应位于 `/mnt/home/sakura/nixos-config`。如果目标卷还没有密码哈希，执行以下命令。全新家目录还需要恢复 sakura 的 SSH 公钥。

```bash
sudo mkdir -p /mnt/etc/nixos
sudo sh -c 'umask 077; mkpasswd > /mnt/etc/nixos/sakura-password-hash'
```

**安装并验证。** 确认 EFI 分区已挂到 `/mnt/boot`，再运行安装命令。

```bash
sudo nixos-install --root /mnt --no-root-passwd --flake /mnt/home/sakura/nixos-config#laurel \
  --option substituters https://mirrors.ustc.edu.cn/nix-channels/store
sudo nixos-enter --root /mnt -c 'passwd -S root && passwd -S sakura'
```

两个账户的第二列都应为 `P`。首次登录后确认仓库可写，用 `findmnt -M ~/maia` 和 `findmnt -M ~/ganette` 核对数据盘。`maia` 是 2T 单盘，`ganette` 是两块 256G SSD 组成的 Btrfs 卷。两者都用了 `nofail`，挂载失败也能进入桌面。
