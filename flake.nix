{
  description = "Home Manager setup for ahdg's core shell environment on Arch";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-mise.url = "github:NixOS/nixpkgs/nixos-unstable";
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

  outputs =
    {
      nixpkgs,
      nixpkgs-mise,
      home-manager,
      ragenix,
      nixgl,
      ...
    }:
    let
      system = "x86_64-linux";
      pkgsMise = import nixpkgs-mise {
        inherit system;
        config.allowUnfree = true;
      };
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [
          (final: prev: {
            mise = pkgsMise.mise;
            mark-shot = final.callPackage ./pkgs/mark-shot.nix { };
            meatshell = final.callPackage ./pkgs/meatshell.nix { };
            copyq = prev.copyq.overrideAttrs (old: {
              # CopyQ 15 fixed a leak in the long-running Wayland clipboard
              # monitor/provider processes. Keep the Nix-managed desktop on
              # the current release until the pinned nixpkgs catches up.
              version = "16.0.0";
              src = final.fetchurl {
                url = "https://github.com/hluk/CopyQ/releases/download/v16.0.0/CopyQ-16.0.0.tar.gz";
                hash = "sha256-2dizKZhhiu156Xzy0VLReEUMzR3+xgs/ys0Hs1ME+og=";
              };
              buildInputs = old.buildInputs ++ [
                final.kdePackages.qca
                final.kdePackages.qtkeychain
              ];
              cmakeFlags = old.cmakeFlags ++ [
                "-DMINIAUDIO_INCLUDE_DIR=${final.miniaudio.dev}/include/miniaudio"
              ];
              patches = [ ];
            });
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
    in
    {
      homeModules.default = ./home/default.nix;

      homeConfigurations = {
        ahdg = mkHome "desktop";
        ahdg-shell = mkHome "shell";
        ahdg-container = mkHome "container";
      };
    };
}
