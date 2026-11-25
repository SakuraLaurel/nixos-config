{ pkgs, ... }:

{
  environment.sessionVariables.NIXOS_OZONE_WL = "1";
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      waylandFrontend = true;
      addons = [ pkgs.qt6Packages.fcitx5-chinese-addons ];
      settings = {
        globalOptions.Behavior.ShareInputState = "All";
        inputMethod = {
          "Groups/0" = {
            Name = "Default";
            "Default Layout" = "us";
            DefaultIM = "pinyin";
          };
          "Groups/0/Items/0" = {
            Name = "keyboard-us";
            Layout = "";
          };
          "Groups/0/Items/1" = {
            Name = "pinyin";
            Layout = "";
          };
          GroupOrder."0" = "Default";
        };
      };
    };
  };

  fonts = {
    packages = with pkgs; [
      nerd-fonts.jetbrains-mono
      noto-fonts-cjk-sans-static
      noto-fonts-color-emoji
    ];
    # plasma6 模块已把 monospace 默认设成 Hack/Noto Sans Mono，aliases 只会往
    # prefer 末尾追加；要真正改默认就得用 defaultFonts（自定义项排在最前）。
    fontconfig.defaultFonts.monospace = [
      "JetBrainsMono Nerd Font"
      "Noto Sans Mono CJK SC"
    ];
  };

  services.desktopManager.plasma6 = {
    enable = true;
    enableQt5Integration = false;
    notoPackage = pkgs.noto-fonts-lgc-plus;
  };
  services.displayManager = {
    plasma-login-manager.enable = true;
    autoLogin = {
      enable = true;
      user = "sakura";
    };
  };

  # 只留桌面和常用的 KDE 应用
  environment.plasma6.excludePackages = with pkgs.kdePackages; [
    discover
    dolphin-plugins
    elisa
    kate
    khelpcenter
    konsole
    krdp
    ktexteditor
    okular
    plasma-browser-integration
    plasma-keyboard
    plasma-workspace-wallpapers
    qrca
    qtvirtualkeyboard
    union
  ];
  # Plasma 模块默认会拉 KDE PIM 和 Orca 读屏，这里关掉，保持系统精简。
  programs.kde-pim.enable = false;
  services.orca.enable = false;
  environment.systemPackages = [ pkgs.haruna ];
  xdg.mime.defaultApplications = {
    "inode/directory" = "org.kde.dolphin.desktop";
    # 音频
    "audio/mpeg" = "org.kde.haruna.desktop";
    "audio/mp4" = "org.kde.haruna.desktop";
    "audio/flac" = "org.kde.haruna.desktop";
    "audio/ogg" = "org.kde.haruna.desktop";
    "audio/x-opus+ogg" = "org.kde.haruna.desktop";
    "audio/vnd.wave" = "org.kde.haruna.desktop";
    # 视频；.mkv 的规范 MIME 是 video/matroska，旧别名一并映射。
    "video/matroska" = "org.kde.haruna.desktop";
    "video/x-matroska" = "org.kde.haruna.desktop";
    "video/mp4" = "org.kde.haruna.desktop";
    "video/webm" = "org.kde.haruna.desktop";
    "video/ogg" = "org.kde.haruna.desktop";
    "video/quicktime" = "org.kde.haruna.desktop";
    "video/x-msvideo" = "org.kde.haruna.desktop";
  };

  programs.brave = {
    enable = true;
    # Quick Commands 默认占用 Ctrl+Space，关掉后组合键交给 fcitx5。
    package = pkgs.brave.override {
      commandLineArgs = "--disable-features=OutdatedBuildDetector,BraveCommander";
    };
  };

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };
  security.rtkit.enable = true;
}
