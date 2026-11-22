{
  config,
  pkgs,
  ...
}:

let
  repoPath = "${config.home.homeDirectory}/nixos-config";
  nvimConfig = "${repoPath}/modules/home/nvim";

in
{
  imports = [ ../../modules/home/proxy-client.nix ];

  home = {
    stateVersion = "26.11";

    packages = with pkgs; [
      # 编译与调试
      gcc
      gnumake
      cmake
      ninja
      pkg-config
      gdb
      python314
      python3Packages.debugpy

      # Neovim 的解析器、语言服务和命令行工具
      tree-sitter
      clang-tools
      ruff
      ty
      lua-language-server
      vscode-json-languageserver
      biome
      tombi
      rumdl
      python3Packages.jupytext
      fzf
      fd
      ripgrep
      wl-clipboard

      deepseek-harness
      pnpm
      qq
    ];

    file.".npmrc".text = ''
      registry=https://registry.npmmirror.com/
    '';
  };

  xdg.userDirs = {
    enable = true;
    createDirectories = true;
  };

  # 让 init.lua 直接在仓库中编辑；插件锁文件由本地生成，不跟踪。
  xdg.configFile.nvim.source = config.lib.file.mkOutOfStoreSymlink nvimConfig;

  programs.git = {
    enable = true;
    package = null; # git 由系统提供，这里只管理 sakura 的身份。
    settings.user = {
      name = "SakuraLaurel";
      email = "brynhild@pku.edu.cn";
    };
  };

  programs.uv = {
    enable = true;
    settings = {
      python-downloads = "never";
      python-preference = "only-system";
    };
  };

  programs.plasma = {
    enable = true;

    overrideConfig = true;
    resetFilesExclude = [ "plasmashellrc" ];

    workspace.wallpaper = "/home/sakura/Pictures/bliss.jpg";
    startup.desktopScript."wallpaper_picture".runAlways = true;

    fonts = {
      general = {
        family = "Noto Sans";
        pointSize = 10;
      };
      fixedWidth = {
        family = "JetBrainsMono Nerd Font";
        pointSize = 10;
      };
    };

    input.keyboard.numlockOnStartup = "on";
    spectacle.shortcuts = {
      captureEntireDesktop = "Alt+%";
      captureActiveWindow = "Alt+#";
      captureRectangularRegion = "Alt+$";
    };

    # 台式机只接市电：不挂起、不关屏、不调暗，也不自动锁屏。
    powerdevil.AC = {
      autoSuspend.action = "nothing";
      turnOffDisplay.idleTimeout = "never";
      dimDisplay.enable = false;
      powerButtonAction = "shutDown";
      powerProfile = "performance";
    };

    kscreenlocker = {
      autoLock = false;
      lockOnResume = false;
      lockOnStartup = false;
    };

    configFile = {
      spectaclerc.General.autoSaveImage = true;

      "plasma-localerc" = {
        Formats.LANG = "zh_CN.UTF-8";
        Translations.LANGUAGE = "zh_CN";
      };

      "kwinrc" = {
        Wayland.InputMethod = "/run/current-system/sw/share/applications/fcitx5-wayland-launcher.desktop";
        "Effect-overview".BorderActivate = 9;
      };

      "plasma-org.kde.plasma.desktop-appletsrc" = {
        "Containments/2/Applets/19/Configuration/Appearance".showSeconds = 2;
      };
    };
  };

  programs.konsole = {
    enable = true;
    defaultProfile = "Sakura";
    profiles.Sakura = {
      font = {
        name = "JetBrainsMono Nerd Font";
        size = 14;
      };
      colorScheme = "RosePineDawn";
    };
    customColorSchemes.RosePineDawn = ../../modules/home/konsole/rose-pine-dawn.colorscheme;
  };

  programs.bash = {
    enable = true;
    shellAliases = {
      gc = "sudo systemctl start nix-gc.service && systemctl status nix-gc.service --no-pager -n 5";
      rebuild = ''sudo nixos-rebuild switch --flake "${repoPath}#sakura"'';
      update = ''cd "${repoPath}" && nix flake update && sudo nixos-rebuild switch --flake "${repoPath}#sakura"'';
      boot-clean = "sudo nix-env -p /nix/var/nix/profiles/system --delete-generations old && sudo /run/current-system/bin/switch-to-configuration boot && sudo nix-collect-garbage -d";
    };

    # 缺少订阅地址时明确报错；执行完始终打印日志，避免 systemctl 静默失败。
    initExtra = ''
      mihomo-update() {
        local url_file="$HOME/.config/mihomo/subscription-url"
        if [ ! -s "$url_file" ]; then
          echo "缺少订阅地址：$url_file" >&2
          return 1
        fi
        sudo systemctl start mihomo-subscription.service
        local rc=$?
        systemctl status mihomo-subscription.service --no-pager -n 5
        return $rc
      }
    '';
  };
}
