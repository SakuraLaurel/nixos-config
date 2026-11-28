{
  config,
  pkgs,
  ...
}:

let
  repoPath = "${config.home.homeDirectory}/nixos-config";
  nvimConfig = "${repoPath}/modules/home/nvim";

  # sudo 的 setuid 权限在 /run/wrappers/bin 上。
  bootClean = pkgs.writeShellApplication {
    name = "boot-clean";
    text = ''
      /run/wrappers/bin/sudo ${pkgs.nix}/bin/nix-env -p /nix/var/nix/profiles/system --delete-generations old
      /run/wrappers/bin/sudo /nix/var/nix/profiles/system/bin/switch-to-configuration boot
      /run/wrappers/bin/sudo ${pkgs.nix}/bin/nix-collect-garbage
    '';
  };

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
      python3
      python3Packages.debugpy

      # Neovim 调用的外部工具
      tree-sitter
      clang-tools
      ruff
      ty
      lua-language-server
      vscode-json-languageserver
      biome
      tombi
      rumdl
      fzf
      fd
      ripgrep
      wl-clipboard

      deepseek-harness
      pnpm
      qq
      bootClean
    ];

    file.".npmrc".text = ''
      registry=https://registry.npmmirror.com/
    '';
  };

  xdg.userDirs = {
    enable = true;
    createDirectories = true;
  };

  # 直接链接工作树，回滚系统代时仍会读取当前的 Lua。
  xdg.configFile.nvim.source = config.lib.file.mkOutOfStoreSymlink nvimConfig;

  programs.git = {
    enable = true;
    package = null; # git 由系统提供。
    settings = {
      user = {
        name = "SakuraLaurel";
        email = "brynhild@pku.edu.cn";
      };
      init.defaultBranch = "main";
      core.editor = "nvim";
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
    resetFilesExclude = [ "plasmashellrc" ]; # 保留 Plasma 迁移记录。

    workspace.wallpaper = "${config.home.homeDirectory}/Pictures/bliss.jpg";
    # overrideConfig 会重置壁纸，每次登录都要重新应用。
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

    hotkeys.commands.ghostty = {
      name = "Ghostty";
      key = "Ctrl+Alt+T";
      command = "ghostty";
    };

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

      "kdeglobals".General = {
        TerminalApplication = "ghostty";
        TerminalService = "com.mitchellh.ghostty.desktop";
      };

      "kwinrc" = {
        Wayland.InputMethod = "/run/current-system/sw/share/applications/fcitx5-wayland-launcher.desktop";
        # KWin 用 ElectricBorder 枚举值记录概览的触发边缘。
        "Effect-overview".BorderActivate = 9;
      };
    };
  };

  programs.ghostty = {
    enable = true;
    settings = {
      theme = "Rose Pine Dawn";
      # 族名需与 Nerd Font 一致，否则会回退到 CJK 等宽字体。
      font-family = "JetBrainsMono Nerd Font";
    };
  };

  programs.bash = {
    enable = true;
    shellAliases = {
      rebuild = ''nixos-rebuild switch --flake "${repoPath}#laurel" --sudo'';
      update = ''nix flake update --flake "${repoPath}" && nixos-rebuild switch --flake "${repoPath}#laurel" --sudo'';
    };

    # 沿用 NixOS 提示符的样式，去掉开头的换行。
    initExtra = ''
      PS1='\[\033[1;32m\][\[\e]0;\u@\h: \w\a\]\u@\h:\w]\$\[\033[0m\] '
    '';
  };
}
