{
  config,
  lib,
  pkgs,
  ...
}:

let
  stateDirectory = "mihomo-subscription";
  configFile = "/var/lib/${stateDirectory}/config.yaml";
  subscriptionFile = "${config.users.users.sakura.home}/.config/mihomo/subscription-url";

  updateSubscription = pkgs.writeShellApplication {
    name = "mihomo-subscription-update";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      pkgs.diffutils
      (pkgs.python3.withPackages (ps: [ ps.pyyaml ]))
      pkgs.systemd
    ];
    text = ''
      target="$STATE_DIRECTORY/config.yaml"
      tmp=$(mktemp "$STATE_DIRECTORY/.config.yaml.XXXXXX")
      trap 'rm -f "$tmp"' EXIT

      # 冷启动时代理可能还不可用，直接取订阅。URL 从凭据文件读入 curl。
      curl --disable --fail --silent --show-error --location --globoff \
        --proto '=https' --proto-redir '=https' --noproxy '*' \
        --retry 3 --retry-max-time 75 --connect-timeout 10 --max-time 30 \
        --user-agent mihomo --output "$tmp" \
        --variable "url@$CREDENTIALS_DIRECTORY/url" --expand-url '{{url:trim}}'
      python3 ${./mihomo-config.py} "$tmp"

      # 内容没变就不要打断正在运行的连接。
      if cmp -s "$tmp" "$target"; then
        systemctl is-active --quiet mihomo.service || systemctl start --no-block mihomo.service
        exit 0
      fi

      mv -fT "$tmp" "$target"
      systemctl restart --no-block mihomo.service
    '';
  };
in
{
  services.mihomo = {
    enable = true;
    inherit configFile;
    tunMode = false;
  };

  # 首次启动时还没有配置文件，等服务下载完成后再启动，避免开机报错。
  systemd.services.mihomo.unitConfig.ConditionPathExists = configFile;

  # 自带一份 GeoIP 数据库，避免首次启动从 GitHub 下载 MMDB 失败。
  systemd.services.mihomo.preStart = ''
    rm -f "$STATE_DIRECTORY/geoip.metadb" "$STATE_DIRECTORY/country.mmdb"
    cp ${pkgs.dbip-country-lite.mmdb} "$STATE_DIRECTORY/country.mmdb"
  '';

  systemd.services.mihomo-subscription = {
    description = "Update the mihomo subscription";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    unitConfig.ConditionPathExists = subscriptionFile;

    serviceConfig = {
      Type = "oneshot";
      LoadCredential = "url:${subscriptionFile}";
      ExecStart = lib.getExe updateSubscription;
      StateDirectory = stateDirectory;
      StateDirectoryMode = "0700";
      UMask = "0077";
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      NoNewPrivileges = true;
      RestrictAddressFamilies = [
        "AF_INET"
        "AF_INET6"
        "AF_UNIX"
      ];
      TimeoutStartSec = "2min";
    };
  };

  systemd.timers.mihomo-subscription = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "30min";
    };
  };
}
