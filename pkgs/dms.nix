{
  lib,
  buildGoModule,
  desktopSources,
}:

buildGoModule rec {
  pname = "dms";
  inherit (desktopSources.dms) version src vendorHash;

  modRoot = "core";
  subPackages = [ "cmd/dms" ];
  tags = [ "distro_binary" ];

  ldflags = [
    "-s"
    "-w"
    "-X main.Version=${version}"
  ];

  # Upstream's full suite includes environment-dependent desktop integration
  # tests. The package build still compiles the patched command and every
  # transitive Go dependency.
  doCheck = false;

  meta = {
    description = "Dank Material Shell backend";
    homepage = "https://github.com/AvengeMedia/DankMaterialShell";
    license = lib.licenses.mit;
    mainProgram = "dms";
    platforms = lib.platforms.linux;
  };
}
