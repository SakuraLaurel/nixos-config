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
    enableDefaultPackages = false;
    packages = with pkgs; [
      nerd-fonts.jetbrains-mono
      noto-fonts-cjk-sans-static
      noto-fonts-color-emoji
    ];
    fontconfig.aliases = {
      "sans-serif".prefer = [ "Noto Sans CJK SC" ];
      monospace.prefer = [ "Noto Sans Mono CJK SC" ];
    };
  };

  services.desktopManager.plasma6 = {
    enable = true;
    enableQt5Integration = false;
    notoPackage = pkgs.noto-fonts-lgc-plus;
  };
  services.displayManager = {
    ly.enable = true;
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
    krdp
    ktexteditor
    okular
    plasma-browser-integration
    plasma-keyboard
    plasma-workspace-wallpapers
    qtvirtualkeyboard
    union
  ];
  # Plasma 模块默认会拉 KDE PIM 和 Orca 读屏，这里关掉，保持系统精简。
  programs.kde-pim.enable = false;
  services.orca.enable = false;
  environment.systemPackages = [ pkgs.vlc ];
  xdg.mime.defaultApplications = {
    "inode/directory" = "org.kde.dolphin.desktop";
    "audio/mpeg" = "vlc.desktop";
    "audio/mp4" = "vlc.desktop";
    "audio/flac" = "vlc.desktop";
    "audio/ogg" = "vlc.desktop";
    "audio/x-opus+ogg" = "vlc.desktop";
    "audio/vnd.wave" = "vlc.desktop";
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
