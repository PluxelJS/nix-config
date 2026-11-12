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
            misterdownloadmanager = final.callPackage ./pkgs/misterdownloadmanager.nix { };
            zed-editor-bin = final.callPackage ./pkgs/zed-editor.nix { };
            copyq = final.symlinkJoin {
              name = "copyq-kde-${prev.copyq.version}";
              paths = [ prev.copyq ];
              nativeBuildInputs = [ final.makeWrapper ];
              # Theme plugins are runtime inputs; preserve the nixpkgs cache
              # instead of rebuilding CopyQ just to add their search paths.
              postBuild = ''
                wrapProgram "$out/bin/copyq" \
                  --prefix QT_PLUGIN_PATH : "${final.lib.makeSearchPath "lib/qt-6/plugins" [ final.darkly final.kdePackages.breeze final.kdePackages.plasma-integration ]}"
              '';
              inherit (prev.copyq) version meta;
            };
            songrec = final.symlinkJoin {
              name = "songrec-${prev.songrec.version}";
              paths = [ prev.songrec ];
              nativeBuildInputs = [ final.makeWrapper ];
              # Reuse the cached executable. Select the plugin-enabled ALSA
              # library at runtime instead of recompiling the Rust application.
              postBuild = ''
                wrapProgram "$out/bin/songrec" \
                  --prefix LD_LIBRARY_PATH : "${final.lib.makeLibraryPath [ final.alsa-lib-with-plugins ]}"
              '';
              inherit (prev.songrec) meta;
            };
          })
        ];
      };
      mkHome =
        {
          profile,
          username,
          homeDirectory,
          extraModules ? [ ],
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
          ]
          ++ extraModules;
        };
      requiredEnv =
        name:
        let
          value = builtins.getEnv name;
        in
        if value != "" then value else throw "portable outputs require --impure so ${name} is available";
      mkCurrentHome =
        profile:
        let
          localModule = requiredEnv "HOME" + "/.config/ahdg/home.nix";
        in
        mkHome {
          inherit profile;
          username = requiredEnv "USER";
          homeDirectory = requiredEnv "HOME";
          extraModules = nixpkgs.lib.optional (builtins.pathExists localModule) localModule;
        };
    in
    {
      # Let bootstrap run the Home Manager CLI from this flake's lock file
      # instead of fetching an unrelated latest release during first setup.
      packages.${system} = {
        home-manager = home-manager.packages.${system}.home-manager;
        chatgpt = pkgs.chatgpt;
        zed-editor = pkgs.zed-editor-bin;
        misterdownloadmanager = pkgs.misterdownloadmanager;
        dev-runtime = pkgs.dev-runtime;
        nixup = pkgs.callPackage ./pkgs/nixup.nix { };
      };

      homeModules.default = ./home/default.nix;
      homeModules.n2n = ./home/modules/n2n.nix;

      homeConfigurations = {
        # Resolve the invoking account with `--impure`.
        current = mkCurrentHome "desktop";
        current-shell = mkCurrentHome "shell";
        current-container = mkCurrentHome "container";
      };
    };
}
