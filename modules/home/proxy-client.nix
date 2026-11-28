{ lib, ... }:

let
  # HTTP 和 SOCKS 共用订阅里的 mixed-port。
  address = "127.0.0.1:7890";
  httpProxy = "http://${address}";
  bypass = "localhost,127.0.0.1,::1";
  proxyCommand = lib.escapeShellArgs [
    "_sakura_proxy"
    address
    bypass
  ];
in
{
  # ProxyType 留给 KDE 和 Bash 在运行时切换。
  programs.plasma.configFile.kioslaverc."Proxy Settings" = {
    inherit httpProxy;
    httpsProxy = httpProxy;
    socksProxy = "socks5://${address}";
    NoProxyFor = bypass;
    ReversedException = false;
  };

  programs.bash = {
    shellAliases = {
      proxy-on = "${proxyCommand} 1";
      proxy-off = "${proxyCommand} 0";
    };
    initExtra = ''
      source ${./proxy-client.bash}
      ${proxyCommand}
    '';
  };
}
