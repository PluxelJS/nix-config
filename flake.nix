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
    nixgl = {
      url = "github:nix-community/nixGL";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    proxy-llm = {
      url = "github:PluxelJS/Proxy-LLM-API/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      agenix,
      nixgl,
      proxy-llm,
      ...
    }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [
          (final: prev: {
            mark-shot = final.callPackage ./pkgs/mark-shot.nix { };
            meatshell = final.callPackage ./pkgs/meatshell.nix { };
            dms = final.callPackage ./pkgs/dms.nix { };
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
            proxy-llm.homeManagerModules.default
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
        proxy-llm = proxy-llm.packages.${system}.default;
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
