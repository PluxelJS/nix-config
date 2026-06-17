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
            songrec = prev.songrec.override {
              # SongRec opens ALSA through libasound at runtime. The plain
              # alsa-lib package in nixpkgs does not include the Pulse/PipeWire
              # compatibility plugins, which causes "snd_pcm_open" failures on
              # this desktop. Reuse the official merged package instead.
              alsa-lib = final.alsa-lib-with-plugins;
            };
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
