{
  lib,
  stdenvNoCC,
  makeWrapper,
  coreutils,
  git,
  nix,
  usage,
}:
let
  runtimeInputs = [
    coreutils
    git
    nix
  ];
in
stdenvNoCC.mkDerivation {
  pname = "nixup";
  version = "0-unstable-2026-09-02";

  src = lib.fileset.toSource {
    root = ../.;
    fileset = lib.fileset.unions [
      ../home/files/bin/nixup
      ../home/files/bin/nixup.usage.kdl
    ];
  };

  nativeBuildInputs = [
    makeWrapper
    usage
  ];

  installPhase = ''
    runHook preInstall

    usageSpec="$out/share/usage/nixup.usage.kdl"
    mkdir -p "$out/bin" "$out/share/usage"
    install -m755 home/files/bin/nixup "$out/bin/nixup"
    install -m644 home/files/bin/nixup.usage.kdl "$usageSpec"

    substituteInPlace "$out/bin/nixup" \
      --replace-fail '@usageSpec@' "$usageSpec"
    usage lint "$usageSpec"
    install -dm755 "$out/share/zsh/site-functions" "$out/share/bash-completion/completions"
    usage generate completion -f "$usageSpec" zsh nixup \
      > "$out/share/zsh/site-functions/_nixup"
    usage generate completion -f "$usageSpec" bash nixup \
      > "$out/share/bash-completion/completions/nixup"
    wrapProgram "$out/bin/nixup" \
      --prefix PATH : ${lib.makeBinPath runtimeInputs}

    runHook postInstall
  '';

  meta = {
    description = "Safe updater for this Home Manager configuration";
    mainProgram = "nixup";
    platforms = lib.platforms.linux;
  };
}
