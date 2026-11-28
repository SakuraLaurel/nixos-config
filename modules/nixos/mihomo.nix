{
  config,
  lib,
  pkgs,
  ...
}:

let
  stateDirectory = "mihomo-subscription";
  configFile = "/var/lib/${stateDirectory}/config.yaml";
  subscriptionDir = "${config.users.users.sakura.home}/.config/mihomo";

  updateSubscription = pkgs.writeShellApplication {
    name = "mihomo-subscription-update";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      pkgs.systemd
      config.services.mihomo.package
    ];
    text = builtins.readFile ./mihomo-subscription-update.sh;
  };
in
{
  services.mihomo = {
    enable = true;
    inherit configFile;
  };

  systemd.tmpfiles.rules = [ "d ${subscriptionDir} 0700 sakura users -" ];

  # 新装时跳过空配置。第一次 mihomo-update 会启动服务。
  systemd.services.mihomo.unitConfig.ConditionPathExists = configFile;

  systemd.services.mihomo-subscription = {
    description = "Update the mihomo subscription (manual)";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    serviceConfig = {
      Type = "oneshot";
      LoadCredential = "url:${subscriptionDir}/subscription-url";
      ExecStart = lib.getExe updateSubscription;
      StateDirectory = stateDirectory;
      StateDirectoryMode = "0700"; # 下载的配置含节点凭据。
      TimeoutStartSec = "2min";
    };
  };
}
