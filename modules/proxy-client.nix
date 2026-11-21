let
  address = "127.0.0.1:7890";
  httpProxy = "http://${address}";
  bypass = "localhost,127.0.0.1,::1";
  modeKey = ''--file kioslaverc --group "Proxy Settings" --key ProxyType'';
in
{
  # 地址交给 Plasma Manager，模式留给 KDE 和终端在运行时切换。
  programs.plasma.configFile.kioslaverc."Proxy Settings" = {
    inherit httpProxy;
    httpsProxy = httpProxy;
    socksProxy = "socks5://${address}";
    NoProxyFor = bypass;
    ReversedException = false;
  };

  programs.bash = {
    shellAliases = {
      proxy-on = "_sakura_set_proxy 1";
      proxy-off = "_sakura_set_proxy 0";
    };
    initExtra = ''
      _sakura_proxy_env() {
        case "$1" in
          1)
            export http_proxy='${httpProxy}' https_proxy='${httpProxy}'
            export all_proxy='socks5h://${address}' no_proxy='${bypass}'
            export HTTP_PROXY="$http_proxy" HTTPS_PROXY="$https_proxy"
            export ALL_PROXY="$all_proxy" NO_PROXY="$no_proxy"
            ;;
          0)
            unset http_proxy https_proxy all_proxy no_proxy
            unset HTTP_PROXY HTTPS_PROXY ALL_PROXY NO_PROXY
            ;;
        esac
      }

      _sakura_set_proxy() {
        kwriteconfig6 ${modeKey} --notify "$1" && _sakura_proxy_env "$1"
      }

      _sakura_proxy_env "$(kreadconfig6 ${modeKey})"
    '';
  };
}
