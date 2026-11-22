{
  config,
  lib,
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
      auto-optimise-store = true;
      substituters = [
        "https://mirrors.ustc.edu.cn/nix-channels/store?priority=10"
        "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store?priority=20"
        "https://mirror.sjtu.edu.cn/nix-channels/store?priority=30"
        "https://cache.nixos.org/?priority=40"
      ];
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };
  };

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    loader = {
      efi.canTouchEfiVariables = true;
      systemd-boot = {
        enable = true;
        # ESP 只有 511 MiB；日常可用 boot-clean 手动清旧项。
        configurationLimit = 10;
      };
    };
  };

  # NetworkManager 管理有线和无线，Plasma 的网络设置也能直接用。
  networking = {
    hostName = "sakura";
    networkmanager.enable = true;
    firewall.enable = true;
  };

  # 数据盘：2T 单盘挂 laurel，两块 256G 合成的 btrfs 挂 maia。
  fileSystems."/home/sakura/laurel" = {
    device = "/dev/disk/by-uuid/56e5fcd6-897f-42d9-90a6-9d3bec6edc8a";
    fsType = "btrfs";
    options = [
      "compress=zstd:3"
      "noatime"
      "nofail"
      "x-systemd.device-timeout=10s"
    ];
  };

  fileSystems."/home/sakura/maia" = {
    device = "/dev/disk/by-uuid/f38c6d5a-3652-48cd-a2a2-6f7a18615959";
    fsType = "btrfs";
    options = [
      "compress=zstd:3"
      "noatime"
      "nofail"
      "x-systemd.device-timeout=10s"
    ];
  };

  # 订阅只手动更新，不需要开机等网络就绪。
  systemd.services.NetworkManager-wait-online.wantedBy = lib.mkForce [ ];

  hardware.usb-modeswitch.enable = true;

  services.btrfs.autoScrub.enable = true;
  services.fstrim.enable = true;

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = true;
    };
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

  environment.systemPackages = with pkgs; [
    git
    neovim
    curl
    unzip
    # Ghostty 设置 TERM=xterm-ghostty，需要对应 terminfo 才能用 clear 等。
    ghostty.terminfo
    usb-modeswitch
    htop
    libva-utils
    intel-gpu-tools
    vulkan-tools
  ];

  system.stateVersion = "26.11";
}
