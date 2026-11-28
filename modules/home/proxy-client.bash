# shellcheck shell=bash
_sakura_proxy() {
  local address=$1 bypass=$2 mode
  local key=(--file kioslaverc --group 'Proxy Settings' --key ProxyType)

  # 新开的 Bash 读 KDE 当前的模式。手动切换时先写 KDE，再改当前 shell。
  if (( $# == 3 )); then
    mode=$3
    kwriteconfig6 "${key[@]}" --notify "$mode" || return
  else
    mode=$(kreadconfig6 "${key[@]}") || return
  fi

  case $mode in
    1)
      export http_proxy="http://$address" https_proxy="http://$address"
      export all_proxy="socks5h://$address" no_proxy="$bypass"
      export HTTP_PROXY="$http_proxy" HTTPS_PROXY="$https_proxy"
      export ALL_PROXY="$all_proxy" NO_PROXY="$no_proxy"
      ;;
    0)
      unset http_proxy https_proxy all_proxy no_proxy
      unset HTTP_PROXY HTTPS_PROXY ALL_PROXY NO_PROXY
      ;;
  esac
}

mihomo-update() {
  local url_file="$HOME/.config/mihomo/subscription-url"
  local status=0
  if [[ ! -s $url_file ]]; then
    printf '缺少订阅地址 %s\n' "$url_file" >&2
    return 1
  fi
  sudo systemctl start mihomo-subscription.service || status=$?
  journalctl -u mihomo-subscription.service -n 8 --no-pager
  return "$status"
}
