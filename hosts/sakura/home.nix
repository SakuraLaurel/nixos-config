{
  config,
  pkgs,
  ...
}:

let
  repoPath = "${config.home.homeDirectory}/nixos-config";
  nvimConfig = "${repoPath}/modules/home/nvim";

  cleanBootEntries = pkgs.writeShellApplication {
    name = "clean-boot-entries";
    runtimeInputs = with pkgs; [
      coreutils
      gnugrep
      gnused
    ];
    text = ''
      esp="''${ESP:-/boot}"
      entries="$esp/loader/entries"
      current="$(readlink -f /run/current-system)/init"
      keep=""

      for entry in "$entries"/nixos-*.conf; do
        [ -e "$entry" ] || continue
        if grep -qF "init=$current" "$entry"; then
          keep="$entry"
          break
        fi
      done

      if [ -z "$keep" ]; then
        echo "找不到当前系统的启动项，未做修改" >&2
        exit 1
      fi

      for entry in "$entries"/nixos-*.conf; do
        if [ "$entry" = "$keep" ]; then
          continue
        fi
        rm -f -- "$entry"
      done

      default="$(basename "$keep")"
      if [ -f "$esp/loader/loader.conf" ]; then
        sed -i -E "s|^default .*|default $default|" "$esp/loader/loader.conf"
      fi
      echo "保留启动项：$default"
    '';
  };
in
{
  imports = [ ../../modules/home/proxy-client.nix ];

  home = {
    stateVersion = "26.11";

    packages = [
      cleanBootEntries
    ]
    ++ (with pkgs; [
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
    ]);

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
      mihomo-update = "sudo systemctl start mihomo-subscription.service";
      boot-clean = "sudo ${cleanBootEntries}/bin/clean-boot-entries";
    };
  };
}
