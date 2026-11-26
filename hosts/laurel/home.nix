{
  config,
  pkgs,
  ...
}:

let
  repoPath = "${config.home.homeDirectory}/nixos-config";
  nvimConfig = "${repoPath}/modules/home/nvim";

  # 多步维护命令交给 writeShellApplication：由 shellcheck 检查，PATH 也固定下来。
  # 单行的 rebuild/update 继续用别名，改起来更短。
  bootClean = pkgs.writeShellApplication {
    name = "boot-clean";
    runtimeInputs = with pkgs; [
      nix
      coreutils
      sudo
    ];
    text = ''
      # 只删系统 profile 的历史代；回收 store 时不加 -d，别动其他 profile 的代。
      sudo nix-env -p /nix/var/nix/profiles/system --delete-generations old
      sudo /run/current-system/bin/switch-to-configuration boot
      sudo nix-collect-garbage
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

  # 让 init.lua 直接在仓库中编辑；插件锁文件已入库，新装按锁定的提交拉插件。
  xdg.configFile.nvim.source = config.lib.file.mkOutOfStoreSymlink nvimConfig;

  programs.git = {
    enable = true;
    package = null; # git 由系统提供，这里只管理 sakura 的身份和几个默认值。
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
    resetFilesExclude = [ "plasmashellrc" ];

    workspace.wallpaper = "${config.home.homeDirectory}/Pictures/bliss.jpg";
    # wallpaper_picture 是 plasma-manager 自己生成的脚本；overrideConfig 打开后
    # 必须每次登录都跑，否则壁纸会被重置后的配置盖掉。
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

      "kdeglobals".General = {
        TerminalApplication = "ghostty";
        TerminalService = "com.mitchellh.ghostty.desktop";
      };

      "kwinrc" = {
        Wayland.InputMethod = "/run/current-system/sw/share/applications/fcitx5-wayland-launcher.desktop";
        # 数字是 KWin 的 ElectricBorder 枚举值，含义见系统设置 → 桌面特效。
        "Effect-overview".BorderActivate = 9;
      };
    };
  };

  programs.ghostty = {
    enable = true;
    settings = {
      theme = "Rose Pine Dawn";
      # 系统里只有 nerd-fonts 的族名，不写这行会落到 Noto Sans Mono CJK。
      font-family = "JetBrainsMono Nerd Font";
    };
  };

  programs.bash = {
    enable = true;
    shellAliases = {
      gc = "sudo systemctl start nix-gc.service && journalctl -u nix-gc.service -n 5 --no-pager";
      rebuild = ''nixos-rebuild switch --flake "${repoPath}#laurel" --sudo'';
      update = ''nix flake update --flake "${repoPath}" && nixos-rebuild switch --flake "${repoPath}#laurel" --sudo'';
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
        journalctl -u mihomo-subscription.service -n 8 --no-pager
        return $rc
      }

      # NixOS 的 /etc/bashrc 给 PS1 加了前导换行；保留同样的提示符样式，去掉空行。
      PS1='\[\033[1;32m\][\[\e]0;\u@\h: \w\a\]\u@\h:\w]\$\[\033[0m\] '
    '';
  };
}
