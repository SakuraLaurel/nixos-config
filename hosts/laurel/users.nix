let
  passwordFile = "/etc/nixos/sakura-password-hash";
in
{
  users.mutableUsers = false;
  users.users.root.hashedPasswordFile = passwordFile;
  users.users.sakura = {
    isNormalUser = true;
    description = "Sakura";
    # 声卡、显卡、输入设备都由 logind 的 ACL 按当前会话授予，不需要常驻设备组。
    extraGroups = [ "wheel" ];
    hashedPasswordFile = passwordFile;
  };

  systemd.tmpfiles.rules = [
    # 哈希文件只给 root 读，避免本机用户读取或改写。
    "z ${passwordFile} 0600 root root -"
    # 订阅地址是机密；目录由系统预建，省掉装完手动 install -d。
    "d /home/sakura/.config/mihomo 0700 sakura users -"
  ];
}
