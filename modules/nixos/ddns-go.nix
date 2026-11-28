{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.ddns-go;
  stateDirectory = "ddns-go";
in
{
  options.services.ddns-go = {
    enable = lib.mkEnableOption "ddns-go dynamic DNS client";

    package = lib.mkPackageOption pkgs "ddns-go" { };

    listen = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1:9876";
      description = "Address for the ddns-go web interface. Keep it on loopback.";
    };

    interval = lib.mkOption {
      type = lib.types.ints.positive;
      default = 300;
      description = "How often to check the address, in seconds.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.ddns-go = {
      description = "ddns-go dynamic DNS client";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      # 命令取地址模式要用到 ip/awk；即使只用网卡模式，留着也无妨。
      path = with pkgs; [
        bash
        gawk
        iproute2
      ];

      serviceConfig = {
        ExecStart = "${lib.getExe cfg.package} -l ${cfg.listen} -f ${toString cfg.interval} -c /var/lib/${stateDirectory}/config.yaml";
        DynamicUser = true;
        StateDirectory = stateDirectory;
        StateDirectoryMode = "0700";
        WorkingDirectory = "/var/lib/${stateDirectory}";
        UMask = "0077";

        Restart = "on-failure";
        RestartSec = "10s";

        # ddns-go 只需要读写自己的配置、解析域名和访问阿里云 API。
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        LockPersonality = true;
        CapabilityBoundingSet = "";
        # Go 的 net.Interfaces() 和 ip 命令都要走 netlink。
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
          "AF_NETLINK"
        ];
      };
    };
  };
}
