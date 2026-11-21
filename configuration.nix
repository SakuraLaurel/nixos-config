{ pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./modules/desktop.nix
    ./modules/mihomo.nix
    ./users.nix
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
        # ESP 只有 511 MiB，限制保留的启动项。
        configurationLimit = 10;
      };
    };
  };

  networking = {
    hostName = "sakura";
    useDHCP = false;
    useNetworkd = true;
    firewall.enable = true;
    wireless.iwd.enable = true;
  };
  systemd.network = {
    wait-online.enable = false;
    networks = {
      "10-ethernet" = {
        matchConfig.Type = "ether";
        networkConfig.DHCP = "yes";
      };
      "20-wlan" = {
        matchConfig.Type = "wlan";
        networkConfig = {
          DHCP = "no";
          Address = "192.168.3.254/24";
          DNS = "8.8.8.8";
        };
        routes = [
          {
            Destination = "0.0.0.0/0";
            Gateway = "192.168.3.1";
            Metric = 2000;
          }
        ];
      };
    };
  };
  services.resolved.enable = true;
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
    usb-modeswitch
    htop
    libva-utils
    intel-gpu-tools
    vulkan-tools
  ];

  system.stateVersion = "26.11";
}
