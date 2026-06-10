{ config, lib, pkgs, ... }:
lib.mkIf config.ahdg.features.gui {
  home.packages = [ pkgs.mark-shot ];

  xdg.configFile."mark-shot/config.json".text = builtins.toJSON {
    annotation = {
      defaultTool = "move";
      fullscreenDefaultTool = "select";
      defaultColor = "#FF4D4D";
    };
    windowDetection = {
      enabled = false;
      command = "";
      env = { };
      timeoutMs = 1000;
    };
    ocr = {
      enabled = false;
      backend = "rapidocr";
      command = "";
      timeoutMs = 30000;
    };
  };
}
