{
  lib,
  stdenvNoCC,
  stdenv,
  desktopSources,
  dpkg,
  autoPatchelfHook,
  makeWrapper,
  cacert,
  dbus,
  fontconfig,
  libGL,
  libx11,
  libxcb,
  libxcursor,
  libxi,
  libxkbcommon,
  vulkan-loader,
  wayland,
  xdg-utils,
  glib,
  p7zip,
  guiLauncher ? null,
}:
let
  # egui/winit loads these with dlopen, so ELF NEEDED entries do not cover them.
  runtimeLibraries = [
    stdenv.cc.cc.lib
    dbus
    fontconfig
    libGL
    libx11
    libxcb
    libxcursor
    libxi
    libxkbcommon
    vulkan-loader
    wayland
  ];
in
stdenvNoCC.mkDerivation {
  pname = "misterdownloadmanager";
  inherit (desktopSources.misterdownloadmanager) version src;

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    makeWrapper
  ];
  buildInputs = runtimeLibraries;
  runtimeDependencies = runtimeLibraries;
  unpackCmd = "dpkg-deb -x $curSrc source";

  installPhase = ''
    runHook preInstall

    install -dm755 "$out"
    mv usr/bin usr/share "$out/"
    # The Debian package's system-wide browser manifests name /usr/bin.
    # Home Manager registers this store's helper per user instead.
    substituteInPlace "$out/share/applications/misterdownloadmanager.desktop" \
      --replace-fail 'Exec=misterdownloadmanager %U' "Exec=$out/bin/misterdownloadmanager %U"

    runHook postInstall
  '';

  postFixup = ''
    # Keep all four programs in the same directory: the CLI, native host and
    # crash monitor locate the GUI and one another beside their real executable.
    for program in "$out"/bin/*; do
      wrapProgram "$program" \
        --prefix PATH : ${
          lib.makeBinPath [
            xdg-utils
            glib
            p7zip
          ]
        } \
        --set-default SSL_CERT_FILE ${cacert}/etc/ssl/certs/ca-bundle.crt
    done
  ''
  + lib.optionalString (guiLauncher != null) ''
    # Put the GL bridge on the GUI's own entry point, so a browser host started
    # without any graphics environment can launch the same GUI correctly.
    mv "$out/bin/misterdownloadmanager" "$out/bin/.misterdownloadmanager-launcher"
    makeWrapper ${lib.escapeShellArg guiLauncher} "$out/bin/misterdownloadmanager" \
      --add-flags "$out/bin/.misterdownloadmanager-launcher"
  '';

  meta = {
    description = "Download manager with browser integration, video and torrent support";
    homepage = "https://github.com/anefzaoui/misterdownloadmanager";
    license = lib.licenses.gpl3Plus;
    mainProgram = "misterdownloadmanager";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
