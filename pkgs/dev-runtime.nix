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
  proxyLlm,
  usage,
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
    proxyLlm
  ];
in
stdenvNoCC.mkDerivation {
  pname = "dev-runtime";
  version = "0-unstable-2026-09-02";

  src = lib.fileset.toSource {
    root = ../.;
    fileset = ../home/files/dev-runtime;
  };

  nativeBuildInputs = [
    makeWrapper
    usage
  ];

  installPhase = ''
    runHook preInstall

    resourceRoot="$out/share/dev-runtime"
    mkdir -p "$resourceRoot" "$out/bin"

    install -m755 home/files/dev-runtime/dev-runtime "$out/bin/dev-runtime"
    install -m644 home/files/dev-runtime/compose.yaml "$resourceRoot/compose.yaml"
    install -m755 home/files/dev-runtime/postgres-init.sh "$resourceRoot/postgres-init.sh"
    install -m644 home/files/dev-runtime/dev-runtime.usage.kdl "$resourceRoot/dev-runtime.usage.kdl"

    substituteInPlace "$out/bin/dev-runtime" \
      --replace-fail '@resourceRoot@' "$resourceRoot"
    usage lint "$resourceRoot/dev-runtime.usage.kdl"
    install -dm755 "$out/share/zsh/site-functions" "$out/share/bash-completion/completions"
    usage generate completion -f "$resourceRoot/dev-runtime.usage.kdl" zsh dev-runtime \
      > "$out/share/zsh/site-functions/_dev-runtime"
    usage generate completion -f "$resourceRoot/dev-runtime.usage.kdl" bash dev-runtime \
      > "$out/share/bash-completion/completions/dev-runtime"
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
