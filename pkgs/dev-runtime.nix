{
  lib,
  stdenvNoCC,
  makeWrapper,
  bash,
  coreutils,
  curl,
  gawk,
  gnugrep,
  gnused,
  openssl,
}:
let
  runtimeInputs = [
    bash
    coreutils
    curl
    gawk
    gnugrep
    gnused
    openssl
  ];
in
stdenvNoCC.mkDerivation {
  pname = "dev-runtime";
  version = "0-unstable-2026-09-02";

  src = lib.fileset.toSource {
    root = ../.;
    fileset = ../home/files/dev-runtime;
  };

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    resourceRoot="$out/share/dev-runtime"
    mkdir -p "$resourceRoot" "$out/bin"

    install -m755 home/files/dev-runtime/dev-runtime "$out/bin/dev-runtime"
    install -m644 home/files/dev-runtime/compose.yaml "$resourceRoot/compose.yaml"
    install -m755 home/files/dev-runtime/postgres-init.sh "$resourceRoot/postgres-init.sh"

    substituteInPlace "$out/bin/dev-runtime" \
      --replace-fail '@resourceRoot@' "$resourceRoot"
    wrapProgram "$out/bin/dev-runtime" \
      --prefix PATH : ${lib.makeBinPath runtimeInputs}

    runHook postInstall
  '';

  meta = {
    description = "Rootless Podman development runtime helper";
    mainProgram = "dev-runtime";
    platforms = lib.platforms.linux;
  };
}
