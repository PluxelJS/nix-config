{ config, lib, nixgl, ... }:
lib.mkIf config.ahdg.features.graphics {
  targets.genericLinux = {
    enable = true;

    nixGL = {
      packages = nixgl.packages;
      defaultWrapper = "mesa";
      installScripts = [ "mesa" ];
    };
  };
}
