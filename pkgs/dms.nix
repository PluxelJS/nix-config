{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule rec {
  pname = "dms";
  version = "1.5.3";

  src = fetchFromGitHub {
    owner = "AvengeMedia";
    repo = "DankMaterialShell";
    rev = "v${version}";
    hash = "sha256-aTNuC9NDBnYAeEtFsleeUwmGX3AZlKOutbl+LQRPkmQ=";
  };

  modRoot = "core";
  subPackages = [ "cmd/dms" ];
  tags = [ "distro_binary" ];
  vendorHash = "sha256-nvxFHQhOfBGl3h51fgYDb39K0NCj+H8mAEyKr1qOwJQ=";

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
