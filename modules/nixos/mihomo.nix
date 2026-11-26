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
      pkgs.systemd
      config.services.mihomo.package
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

      # 用 mihomo 自己的解析器验收：HTML 错误页、半截 YAML 都会在这里被拒。
      # -d 指到本 unit 的 StateDirectory，geo 数据在这缓存，第二次起不再下载。
      mihomo -t -d "$STATE_DIRECTORY" -f "$tmp" || {
        echo "mihomo 不接受这份订阅，保留旧配置" >&2
        exit 1
      }

      mv -fT "$tmp" "$target"

      # 阻塞等重启结束：mihomo 真起来了，这个 unit 才算成功。
      systemctl restart mihomo.service
    '';
  };
in
{
  services.mihomo = {
    enable = true;
    inherit configFile;
  };

  # 首次启动时还没有配置文件，等服务下载完成后再启动，避免开机报错。
  systemd.services.mihomo.unitConfig.ConditionPathExists = configFile;

  # 不挂到 multi-user.target / timers：只在 mihomo-update 时手动启动。
  systemd.services.mihomo-subscription = {
    description = "Update the mihomo subscription (manual)";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    serviceConfig = {
      Type = "oneshot";
      LoadCredential = "url:${subscriptionFile}";
      ExecStart = lib.getExe updateSubscription;
      StateDirectory = stateDirectory;
      StateDirectoryMode = "0700"; # 目录别是 0755，里面是带凭据的配置
      TimeoutStartSec = "2min";
    };
  };
}
