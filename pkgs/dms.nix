{
  lib,
  buildGoModule,
  desktopSources,
  makeWrapper,
  fetchFromGitHub,
}:
let
  # Gitlink pinned by the DMS 1.6.1 source; GitHub source archives omit it.
  dankCommon = fetchFromGitHub {
    owner = "AvengeMedia";
    repo = "dank-qml-common";
    rev = "26396ce432d6c71c3f5367438f96f4a8d667e160";
    hash = "sha256-/tT8rTznLADndTwLBzdgzzgfJH1ZhYQibYo5v/F8U+U=";
  };
in
buildGoModule rec {
  pname = "dms";
  inherit (desktopSources.dms) version src vendorHash;

  modRoot = "core";
  subPackages = [ "cmd/dms" ];
  tags = [ "distro_binary" ];

  nativeBuildInputs = [ makeWrapper ];

  # Plain Go builds do not embed the shell. Ship the matching QML tree and
  # dereference DankCommon so its relative source-tree symlink stays valid.
  postInstall = ''
    cp -r ${dankCommon}/. ../dank-qml-common/
    mkdir -p "$out/share/dms"
    cp -rL ../quickshell/. "$out/share/dms/"
    test -f "$out/share/dms/shell.qml"
    test -f "$out/share/dms/DankCommon/Session/Keyboard.qml"
    wrapProgram "$out/bin/dms" \
      --set-default DMS_SHELL_DIR "$out/share/dms"
  '';

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
    description = "Dank Material Shell backend and matching QML interface";
    homepage = "https://github.com/AvengeMedia/DankMaterialShell";
    license = lib.licenses.mit;
    mainProgram = "dms";
    platforms = lib.platforms.linux;
  };
}
