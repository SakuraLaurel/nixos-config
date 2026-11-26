{
  lib,
  pkgs,
  ...
}:

let
  haruna = "org.kde.haruna.desktop";
  # 同一款播放器接的音视频格式；增减格式只改这个列表。
  mediaTypes = [
    "audio/mpeg"
    "audio/mp4"
    "audio/flac"
    "audio/ogg"
    "audio/x-opus+ogg"
    "audio/vnd.wave"
    # .mkv 的规范 MIME 是 video/matroska，旧别名一并映射。
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
    # graphical-desktop 模块会 mkDefault true 打开整套默认字体，这里显式关掉，
    enableDefaultPackages = false;
    packages = with pkgs; [
      nerd-fonts.jetbrains-mono
      noto-fonts-cjk-sans-static
      noto-fonts-color-emoji
    ];
    # 65-nonlatin.conf 里中文的 CJK 回退只列了 Noto Sans CJK KR，不把 SC 加进来，
    # 中文就会落到韩文字形（直/骨/门 变样），所以这里显式 prefer SC。
    # Plasma 模块也会往 defaultFonts 追加自己的列表（Hack、Noto Sans Mono 等），
    # mkBefore 保证这里的首选一定排在最前，追加的只作为回退。
    fontconfig.defaultFonts = {
      sansSerif = lib.mkBefore [
        "Noto Sans"
        "Noto Sans CJK SC"
      ];
      monospace = lib.mkBefore [
        "JetBrainsMono Nerd Font"
        "Noto Sans Mono CJK SC"
      ];
      # 没装 CJK 衬线，中文在 serif 场景会掉到 Noto Sans CJK JP（日文字形）；
      # 用 SC 无衬线兜底，至少字形是大陆写法。要真衬线就加 noto-fonts-cjk-serif-static。
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
  }
  // lib.genAttrs mediaTypes (_: haruna);

  programs.brave = {
    enable = true;
    # Quick Commands 默认占用 Ctrl+Space，关掉后组合键交给 fcitx5。
    # 必须连带 nixpkgs 包装脚本里的 UseChromeOSDirectVideoDecoder：Chromium 对
    # 同名开关只认后出现的那条，漏掉它会把 VA-API 硬解一起覆盖掉。
    package = pkgs.brave.override {
      commandLineArgs = "--disable-features=OutdatedBuildDetector,UseChromeOSDirectVideoDecoder,BraveCommander";
    };
  };

  # 有图形会话时 graphical-desktop 已 mkDefault 打开 pipewire 的 alsa/pulse，
  # 只有 rtkit 没有任何模块替你开。
  security.rtkit.enable = true;
}
