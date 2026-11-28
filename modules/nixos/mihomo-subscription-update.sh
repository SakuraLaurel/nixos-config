# shellcheck shell=bash
set -euo pipefail

tmp=$(mktemp "$STATE_DIRECTORY/.config.yaml.XXXXXX")
trap 'rm -f "$tmp"' EXIT

# 冷启动也要能直连订阅。让 curl 从凭据文件读取 URL，避免它出现在命令行里。
curl --disable --fail --silent --show-error --location --globoff \
  --proto '=https' --proto-redir '=https' --noproxy '*' \
  --retry 3 --retry-max-time 75 --connect-timeout 10 --max-time 30 \
  --user-agent mihomo --output "$tmp" \
  --variable "url@$CREDENTIALS_DIRECTORY/url" --expand-url '{{url:trim}}'

# 在同一目录校验并替换，下载或解析失败都会保留旧配置。
if ! mihomo -t -d "$STATE_DIRECTORY" -f "$tmp"; then
  echo "mihomo 不接受这份订阅，保留旧配置" >&2
  exit 1
fi

mv -fT "$tmp" "$STATE_DIRECTORY/config.yaml"
systemctl restart mihomo.service
