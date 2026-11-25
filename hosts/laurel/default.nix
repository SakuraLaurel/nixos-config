{
  pkgs,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
    ./users.nix
    ../../modules/nixos/desktop.nix
    ../../modules/nixos/mihomo.nix
  ];

  nixpkgs.config.allowUnfreePackages = [ "qq" ];

  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      # 只留实测可用的两家（SJTU 已下线，NJU/JLU/HUST/阿里云都缺 nix-channels/store 路径）；
      # cache.nixos.org 由 NixOS 模块自动追加，不用手写。
      substituters = [
        "https://mirrors.ustc.edu.cn/nix-channels/store?priority=10"
        "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store?priority=20"
      ];
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };
    # 定时做 hardlink 优化，替代每次构建都跑的 auto-optimise-store。
    optimise.automatic = true;
  };

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    loader = {
      efi.canTouchEfiVariables = true;
      systemd-boot = {
        enable = true;
        # 平时菜单保留 10 条；要回收就用 boot-clean 清到只剩当前。
        configurationLimit = 10;
      };
    };
  };

  # NetworkManager 管理有线和无线，Plasma 的网络设置也能直接用。
  networking = {
    hostName = "laurel";
    networkmanager.enable = true;
  };

  # 注：Wi-Fi 连接若未勾选“忽略自动 DNS”，DHCP 下发的 DNS 会被并行查询。
  services.resolved = {
    enable = true;
    settings.Resolve = {
      DNS = [
        "223.5.5.5"
        "119.29.29.29"
      ];
      Domains = [ "~." ];
    };
  };

  # nsncd 保持 26.11 默认。实测 nscd socket 往返 <1ms；单标签名卡 4 秒是
  # systemd-resolved 的 LLMNR 超时（--protocol=dns 只要 1ms），与 nsncd 无关。

  # 数据盘：2T 单盘挂 maia，两块 256G 合成的 btrfs 挂 ganette。
  fileSystems."/home/sakura/maia" = {
    device = "/dev/disk/by-uuid/56e5fcd6-897f-42d9-90a6-9d3bec6edc8a";
    fsType = "btrfs";
    options = [
      "compress=zstd:3"
      "noatime"
      "nofail"
      "x-systemd.device-timeout=10s"
    ];
  };

  fileSystems."/home/sakura/ganette" = {
    device = "/dev/disk/by-uuid/f38c6d5a-3652-48cd-a2a2-6f7a18615959";
    fsType = "btrfs";
    options = [
      "compress=zstd:3"
      "noatime"
      "nofail"
      "x-systemd.device-timeout=10s"
    ];
  };

  # 没有开机即需联网的服务；关掉 wait-online 加快启动，mihomo 启动不依赖它。
  systemd.services.NetworkManager-wait-online.enable = false;
  hardware.usb-modeswitch.enable = true;
  services.btrfs.autoScrub.enable = true;

  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "no";
  };

  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver # VA-API（iHD）
      vpl-gpu-rt # Intel Quick Sync / oneVPL
    ];
  };

  time.timeZone = "Asia/Shanghai";
  i18n.defaultLocale = "zh_CN.UTF-8";

  # 统一安装常见终端的 terminfo（含 Ghostty 的 xterm-ghostty），省得逐个加包。
  environment.enableAllTerminfo = true;
  environment.systemPackages = with pkgs; [
    git
    neovim
    curl
    unzip
    usb-modeswitch
    htop
    libva-utils
    intel-gpu-tools
    vulkan-tools
  ];

  system.stateVersion = "26.11";
}
