let
  passwordFile = "/etc/nixos/sakura-password-hash";
in
{
  users.mutableUsers = false;
  users.users.root.hashedPasswordFile = passwordFile;
  users.users.sakura = {
    isNormalUser = true;
    description = "Sakura";
    # logind 随桌面会话授予设备访问权。
    extraGroups = [ "wheel" ];
    hashedPasswordFile = passwordFile;
  };

  systemd.tmpfiles.rules = [ "z ${passwordFile} 0600 root root -" ];
}
