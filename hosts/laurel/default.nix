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
      substituters = [
        "https://mirrors.ustc.edu.cn/nix-channels/store?priority=10"
        "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store?priority=20"
        "https://mirror.sjtu.edu.cn/nix-channels/store?priority=30"
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

  # 实测 nsncd 的 hosts 查询会挂 2 秒再回落；换回 glibc nscd 规避。
  services.nscd.enableNsncd = false;

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
