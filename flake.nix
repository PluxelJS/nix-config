{
  description = "Home Manager setup for ahdg's core shell environment on Arch";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ragenix = {
      url = "github:yaxitech/ragenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixgl = {
      url = "github:nix-community/nixGL";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ragenix, nixgl, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [
          (final: prev: {
            mark-shot = final.callPackage ./pkgs/mark-shot.nix { };
          })
        ];
      };
      mkHome =
        profile:
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          extraSpecialArgs = {
            inherit ragenix;
            inherit nixgl;
          };
          modules = [
            ./home/default.nix
            ./home/profiles/${profile}.nix
            {
              home.username = "ahdg";
              home.homeDirectory = "/home/ahdg";
            }
          ];
        };
    in {
      homeModules.default = ./home/default.nix;

      homeConfigurations = {
        ahdg = mkHome "desktop";
        ahdg-shell = mkHome "shell";
        ahdg-container = mkHome "container";
      };
    };
}
