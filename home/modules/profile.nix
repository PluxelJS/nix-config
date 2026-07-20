{ config, lib, ... }:
let
  types = lib.types;
  cfg = config.ahdg;
  featureNames = [
    "fastfetch"
    "ghostty"
    "desktopXdg"
    "fonts"
    "gui"
    "localsend"
    "portal"
    "flatpak"
    "graphics"
    "themeRuntime"
  ];

  profileFeaturePresets = {
    desktop = featureNames;
    shell = [ "fonts" ];
    container = [ ];
  };

  featureOptionType = types.enum featureNames;
  presetFeatures = profileFeaturePresets.${cfg.profile};

  enabledFeatures = builtins.filter (feature: cfg.features.${feature}) featureNames;

  deploymentName =
    if cfg.profile == "desktop" && enabledFeatures == profileFeaturePresets.desktop then
      "desktop"
    else if cfg.profile == "shell" && enabledFeatures == profileFeaturePresets.shell then
      "shell"
    else if cfg.profile == "shell" && enabledFeatures == [ ] then
      "shell-minimal"
    else if cfg.profile == "container" && enabledFeatures == [ ] then
      "container"
    else if cfg.profile == "container" && enabledFeatures == [ "fonts" ] then
      "container-fonts"
    else
      "${cfg.profile}-custom";
in
{
  options.ahdg = {
    profile = lib.mkOption {
      type = types.enum [
        "desktop"
        "shell"
        "container"
      ];
      default = "desktop";
      description = ''
        High-level deployment profile. `desktop` enables the full local GUI
        stack, `shell` keeps only the shell/tooling stack plus fonts, and
        `container` strips it down even further.
      '';
    };

    extraFeatures = lib.mkOption {
      type = types.listOf featureOptionType;
      default = [ ];
      example = [ "fonts" ];
      description = ''
        Extra capability toggles to layer onto the selected base profile
        without copying the whole profile definition.
      '';
    };

    disabledFeatures = lib.mkOption {
      type = types.listOf featureOptionType;
      default = [ ];
      example = [ "fonts" ];
      description = ''
        Capability toggles to subtract from the selected base profile. This is
        mainly useful for minimal shell/container deployments.
      '';
    };

    deploymentName = lib.mkOption {
      type = types.str;
      readOnly = true;
      description = "Resolved deployment label after applying feature overrides.";
    };

    features = {
      fastfetch = lib.mkEnableOption "fastfetch and its asset bundle";
      ghostty = lib.mkEnableOption "Ghostty terminal integration";
      desktopXdg = lib.mkEnableOption "desktop MIME defaults, user dirs, and terminal registration";
      fonts = lib.mkEnableOption "font packages and fontconfig policy";
      gui = lib.mkEnableOption "desktop theme stack such as GTK, Plasma, and icon assets";
      localsend = lib.mkEnableOption "LocalSend and its CachyOS host integration";
      portal = lib.mkEnableOption "xdg-desktop-portal integration";
      flatpak = lib.mkEnableOption "global Flatpak host integration";
      graphics = lib.mkEnableOption "nixGL-based graphics wrappers";
      themeRuntime = lib.mkEnableOption "mutable theme runtime files such as DMS-managed Ghostty colors";
    };
  };

  config = {
    ahdg = {
      inherit deploymentName;

      features = lib.genAttrs featureNames (
        feature:
        lib.mkDefault (
          (builtins.elem feature presetFeatures || builtins.elem feature cfg.extraFeatures)
          && !(builtins.elem feature cfg.disabledFeatures)
        )
      );
    };

    assertions = [
      {
        assertion = lib.intersectLists cfg.extraFeatures cfg.disabledFeatures == [ ];
        message = "A feature cannot be present in both ahdg.extraFeatures and ahdg.disabledFeatures.";
      }
      {
        assertion = !cfg.features.flatpak || cfg.features.gui;
        message = "Flatpak host integration requires the GUI theme stack.";
      }
      {
        assertion = !cfg.features.portal || cfg.features.gui;
        message = "Portal integration requires the GUI theme stack.";
      }
      {
        assertion = !cfg.features.localsend || (cfg.features.gui && cfg.features.graphics);
        message = "LocalSend on CachyOS requires the GUI and nixGL graphics features.";
      }
      {
        assertion = !cfg.features.themeRuntime || cfg.features.ghostty;
        message = "Mutable theme runtime support currently only applies to Ghostty.";
      }
      {
        assertion = !cfg.features.ghostty || cfg.features.graphics;
        message = "Ghostty on Arch should keep nixGL graphics integration enabled.";
      }
    ];

    home.sessionVariables = {
      AHDG_PROFILE = deploymentName;
      AHDG_BASE_PROFILE = cfg.profile;
      AHDG_ENABLED_FEATURES = lib.concatStringsSep ":" enabledFeatures;
    };

    xdg.configFile."ahdg/profile".text = "${deploymentName}\n";
    xdg.configFile."ahdg/base-profile".text = "${cfg.profile}\n";
    xdg.configFile."ahdg/enabled-features".text =
      lib.concatStringsSep "\n" enabledFeatures
      + lib.optionalString (enabledFeatures != [ ]) "\n";
  };
}
