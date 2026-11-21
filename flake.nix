{
  description = "Sakura's Intel i5-12400 desktop";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      plasma-manager,
      ...
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      nixosConfigurations.sakura = nixpkgs.lib.nixosSystem {
        modules = [
          ./hosts/sakura
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              backupFileExtension = "bak";
              sharedModules = [ plasma-manager.homeModules.plasma-manager ];
              users.sakura = import ./hosts/sakura/home.nix;
            };
          }
        ];
      };
      formatter.${system} = pkgs.nixfmt-tree;
    };
}
