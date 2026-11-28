{
  lib,
  pkgs,
  ...
}:

let
  # 卷名也是家目录下的挂载点。ganette 跨两块 SSD，共用一个 Btrfs UUID。
  dataDisks = {
    maia = "56e5fcd6-897f-42d9-90a6-9d3bec6edc8a";
    ganette = "f38c6d5a-3652-48cd-a2a2-6f7a18615959";
  };
  dataMountOptions = [
    "compress=zstd:3"
    "noatime"
    "nofail"
    "x-systemd.device-timeout=10s"
  ];
  # nixos-rebuild boot 后，系统 profile 可能已领先于 /run/current-system。
  updateBootMenu = "/nix/var/nix/profiles/system/bin/switch-to-configuration boot";
in
{
  imports = [
    ./hardware-configuration.nix
    ./users.nix
    ../../modules/nixos/desktop.nix
    ../../modules/nixos/ddns-go.nix
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
      ];
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
    optimise.automatic = true;
  };

  # GC 后同步 /boot，清掉指向已删除系统代的菜单项。
  systemd.services.nix-gc.postStart = updateBootMenu;

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    loader = {
      efi.canTouchEfiVariables = true;
      systemd-boot = {
        enable = true;
        configurationLimit = 10;
      };
    };
  };

  networking = {
    hostName = "laurel";
    networkmanager.enable = true;
  };

  services.ddns-go.enable = true;

  # Wi-Fi 连接勾选「忽略自动 DNS」，避免并行查询 DHCP 下发的 DNS。
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

  fileSystems = lib.mapAttrs' (
    name: uuid:
    lib.nameValuePair "/home/sakura/${name}" {
      device = "/dev/disk/by-uuid/${uuid}";
      fsType = "btrfs";
      options = dataMountOptions;
    }
  ) dataDisks;

  # 启动不等网络就绪。依赖 network-online.target 的服务可能早于联网启动。
  systemd.services.NetworkManager-wait-online.enable = false;
  hardware.usb-modeswitch.enable = true;
  services.btrfs.autoScrub.enable = true;
  services.fwupd.enable = true;

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
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

  # SSH 会话也需要 xterm-ghostty 等 terminfo。
  environment.enableAllTerminfo = true;
  environment.systemPackages = with pkgs; [
    git
    neovim
    unzip
    usb-modeswitch
    htop
    libva-utils
    intel-gpu-tools
    vulkan-tools
  ];

  system.stateVersion = "26.11";
}
