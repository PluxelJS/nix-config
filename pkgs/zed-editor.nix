{
  lib,
  stdenvNoCC,
  stdenv,
  desktopSources,
  autoPatchelfHook,
  makeWrapper,
  alsa-lib,
  glib,
  fontconfig,
  libGL,
  vulkan-loader,
  wayland,
}:

stdenvNoCC.mkDerivation {
  pname = "zed-editor-bin";
  inherit (desktopSources.zed-editor) version src;

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];
  buildInputs = [
    alsa-lib
    glib
    stdenv.cc.cc.lib
  ];
  runtimeDependencies = map lib.getLib [
    fontconfig
    libGL
    vulkan-loader
    wayland
  ];

  # Repackage the official release, including its bundled libraries. No Rust
  # toolchain or local compilation is needed to track stable Zed releases.
  dontBuild = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out"
    cp -a bin lib libexec share "$out/"
    install -Dm644 licenses.md "$out/share/doc/zed-editor/licenses.md"

    # Keep Home Manager's usual command and the upstream CLI name available.
    mv "$out/bin/zed" "$out/bin/zeditor"
    wrapProgram "$out/bin/zeditor" \
      --set ZED_UPDATE_EXPLANATION "Zed is managed by Nix; update it through nixup."
    ln -s zeditor "$out/bin/zed"
    substituteInPlace "$out/share/applications/dev.zed.Zed.desktop" \
      --replace-fail 'Exec=zed' 'Exec=zeditor'

    runHook postInstall
  '';

  meta = {
    description = "Zed editor, packaged from the official prebuilt release";
    homepage = "https://zed.dev";
    license = lib.licenses.gpl3Only;
    mainProgram = "zeditor";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
