{ config, pkgs, ... }:

let
  nvimConfig = "${config.home.homeDirectory}/nixos-config/config/nvim";
in
{
  imports = [ ./modules/proxy-client.nix ];

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

  # 让 init.lua 和 vim.pack 的锁文件都能在仓库中直接编辑。
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

    # 台式机接市电。手动锁屏时也沿用同一个显示器超时设置。
    powerdevil.AC = {
      autoSuspend.action = "nothing";
      turnOffDisplay = {
        idleTimeout = "never";
        idleTimeoutWhenLocked = "whenLockedAndUnlocked";
      };
      dimDisplay.enable = false;
      powerButtonAction = "shutDown";
      powerProfile = "performance";
    };

    kscreenlocker = {
      autoLock = false;
      lockOnResume = false;
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
    customColorSchemes.RosePineDawn = ./config/konsole/rose-pine-dawn.colorscheme;
  };

  programs.bash = {
    enable = true;
    shellAliases = {
      gc = "sudo systemctl start nix-gc.service";
      rebuild = ''sudo nixos-rebuild switch --flake "$HOME/nixos-config#sakura"'';
    };
  };
}
