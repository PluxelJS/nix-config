{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  fontconfig,
  freetype,
  gtk3,
  libGL,
  libx11,
  libxcb,
  libxkbcommon,
  udev,
  wayland,
}:
let
  runtimeLibraries = [
    fontconfig
    freetype
    gtk3
    libGL
    libx11
    libxcb
    libxkbcommon
    stdenv.cc.cc.lib
    udev
    wayland
  ];
in
stdenv.mkDerivation (finalAttrs: {
  pname = "meatshell";
  version = "0.6.5";

  src = fetchurl {
    url = "https://github.com/jeff141/meatshell/releases/download/v${finalAttrs.version}/meatshell-v${finalAttrs.version}-linux-x86_64.tar.gz";
    hash = "sha256-DnFR39czh6W32NBWXyf2uIuKiU1FWIuDcg893zGAqqQ=";
  };

  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = runtimeLibraries;
  runtimeDependencies = runtimeLibraries;

  installPhase = ''
    runHook preInstall

    install -Dm755 meatshell "$out/bin/meatshell"
    install -Dm644 meatshell.desktop "$out/share/applications/meatshell.desktop"
    install -Dm644 icon@512.png "$out/share/icons/hicolor/512x512/apps/meatshell.png"
    install -Dm644 README.md "$out/share/doc/meatshell/README.md"
    install -Dm644 THIRD_PARTY_NOTICES.md "$out/share/doc/meatshell/THIRD_PARTY_NOTICES.md"

    runHook postInstall
  '';

  meta = {
    description = "Lightweight FinalShell-style SSH/SFTP and terminal client";
    homepage = "https://github.com/jeff141/meatshell";
    license = with lib.licenses; [
      mit
      asl20
    ];
    mainProgram = "meatshell";
    platforms = [ "x86_64-linux" ];
  };
})
