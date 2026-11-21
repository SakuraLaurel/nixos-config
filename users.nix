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
}
