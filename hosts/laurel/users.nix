let
  passwordFile = "/etc/nixos/sakura-password-hash";
in
{
  users.mutableUsers = false;
  users.users.root.hashedPasswordFile = passwordFile;
  users.users.sakura = {
    isNormalUser = true;
    description = "Sakura";
    extraGroups = [
      "wheel"
      "video"
      "audio"
      "input"
    ];
    hashedPasswordFile = passwordFile;
  };
  security.sudo.wheelNeedsPassword = true;

  # 哈希文件只给 root 读，避免本机用户读取或改写。
  systemd.tmpfiles.rules = [
    "z ${passwordFile} 0600 root root -"
  ];
}
