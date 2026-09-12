{
  description = "Portable Home Manager setup for an Arch-family workstation";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    dev-runtime = {
      url = "github:PluxelJS/dev-runtime";
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
      home-manager,
      agenix,
      nixgl,
      dev-runtime,
      ...
    }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [
          (final: prev: {
            desktopSources = final.callPackage ./pkgs/sources.nix { };
            dev-runtime = dev-runtime.packages.${system}.dev-runtime;
            mark-shot = final.callPackage ./pkgs/mark-shot.nix { };
            chatgpt = final.callPackage ./pkgs/chatgpt.nix { };
            meatshell = final.callPackage ./pkgs/meatshell.nix { };
            dms = final.callPackage ./pkgs/dms.nix { };
            copyq = prev.copyq.overrideAttrs (old: {
              # CopyQ 15 fixed a leak in the long-running Wayland clipboard
              # monitor/provider processes. Keep the Nix-managed desktop on
              # the current release until the pinned nixpkgs catches up.
              inherit (final.desktopSources.copyq) version src;
              buildInputs = old.buildInputs ++ [
                # CopyQ is a Qt application, so let it use the same KDE
                # platform theme and widget styles as the rest of the desktop.
                final.darkly
                final.kdePackages.breeze
                final.kdePackages.plasma-integration
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
        {
          profile,
          username,
          homeDirectory,
        }:
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          extraSpecialArgs = {
            inherit agenix;
            inherit nixgl;
          };
          modules = [
            agenix.homeManagerModules.default
            dev-runtime.homeManagerModules.default
            ./home/default.nix
            ./home/profiles/${profile}.nix
            {
              home = {
                inherit username homeDirectory;
              };
            }
          ];
        };
      requiredEnv =
        name:
        let
          value = builtins.getEnv name;
        in
        if value != "" then value else throw "portable outputs require --impure so ${name} is available";
      mkCurrentHome =
        profile:
        mkHome {
          inherit profile;
          username = requiredEnv "USER";
          homeDirectory = requiredEnv "HOME";
        };
    in
    {
      # Let bootstrap run the Home Manager CLI from this flake's lock file
      # instead of fetching an unrelated latest release during first setup.
      packages.${system} = {
        home-manager = home-manager.packages.${system}.home-manager;
        chatgpt = pkgs.chatgpt;
        dev-runtime = pkgs.dev-runtime;
        # Expose the dependency derivation for the source updater's vendor hash.
        dms = pkgs.dms;
        nixup = pkgs.callPackage ./pkgs/nixup.nix { };
      };

      homeModules.default = ./home/default.nix;

      homeConfigurations = {
        # Resolve the invoking account with `--impure`.
        current = mkCurrentHome "desktop";
        current-shell = mkCurrentHome "shell";
        current-container = mkCurrentHome "container";
      };
    };
}
