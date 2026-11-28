{
  lib,
  pkgs,
  ...
}:

let
  haruna = "org.kde.haruna.desktop";
  mediaTypes = [
    "audio/mpeg"
    "audio/mp4"
    "audio/flac"
    "audio/ogg"
    "audio/x-opus+ogg"
    "audio/vnd.wave"
    # 兼容仍使用旧 MIME 名的 MKV 文件。
    "video/matroska"
    "video/x-matroska"
    "video/mp4"
    "video/webm"
    "video/ogg"
    "video/quicktime"
    "video/x-msvideo"
  ];
in
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
    enableDefaultPackages = false;
    packages = with pkgs; [
      nerd-fonts.jetbrains-mono
      noto-fonts-cjk-sans-static
      noto-fonts-color-emoji
    ];
    # 将 SC 排在 Plasma 的默认回退字体之前，避免简体中文显示日韩字形。
    fontconfig.defaultFonts = {
      sansSerif = lib.mkBefore [
        "Noto Sans"
        "Noto Sans CJK SC"
      ];
      monospace = lib.mkBefore [
        "JetBrainsMono Nerd Font"
        "Noto Sans Mono CJK SC"
      ];
      # 本机只装了 CJK 无衬线字体，中文衬线也回退到 SC。
      serif = lib.mkBefore [
        "Noto Serif"
        "Noto Sans CJK SC"
      ];
    };
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
  programs.kde-pim.enable = false;
  services.orca.enable = false;
  environment.systemPackages = [ pkgs.haruna ];
  xdg.mime.defaultApplications = {
    "inode/directory" = "org.kde.dolphin.desktop";
  }
  // lib.genAttrs mediaTypes (_: haruna);

  programs.brave = {
    enable = true;
    # 关闭 BraveCommander，把 Ctrl+Space 留给 Fcitx5。Chromium 只认最后一个
    # --disable-features，所以要带上包装器的原有参数，避免覆盖 VA-API 设置。
    package = pkgs.brave.override {
      commandLineArgs = "--disable-features=OutdatedBuildDetector,UseChromeOSDirectVideoDecoder,BraveCommander";
    };
  };

  # 图形桌面模块已启用 PipeWire 的 ALSA/Pulse 支持。
  security.rtkit.enable = true;
}
