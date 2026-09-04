{
  lib,
  stdenvNoCC,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  makeWrapper,
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  atk,
  cairo,
  cups,
  dbus,
  expat,
  gdk-pixbuf,
  glib,
  gtk3,
  libdrm,
  libgbm,
  libGL,
  libnotify,
  libusb1,
  libx11,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxrandr,
  libxcb,
  libxkbcommon,
  nspr,
  nss,
  pango,
  qt5,
  qt6,
  stdenv,
  udev,
  vulkan-loader,
  wayland,
  xorg,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "chatgpt";
  # The upstream Linux desktop app is named ChatGPT, while its bundled coding
  # experience and deep-link scheme are Codex. Keep the exact upstream build
  # version here rather than making the mutable `latest` URL impure.
  version = "26.901.20858";

  src = fetchurl {
    url = "https://persistent.oaistatic.com/codex-app-prod/linux/deb/latest/chatgpt_amd64.deb";
    hash = "sha256-QqZHfyL0E21iMh7ae0aXp52h62bWHcuFqwQghgoaUiM=";
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    expat
    gdk-pixbuf
    glib
    gtk3
    libdrm
    libgbm
    libGL
    libnotify
    libusb1
    libxkbcommon
    nspr
    nss
    pango
    stdenv.cc.cc
    udev
    vulkan-loader
    wayland
    libx11
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxrandr
    libxcb
  ];

  # The bundle carries prebuilt musl Node addons beside the glibc ones. They
  # cannot run on this target and are never selected by the x86_64 glibc app.
  autoPatchelfIgnoreMissingDeps = [ "libc.musl-x86_64.so.1" ];

  # Do not put Qt 5 and Qt 6 in buildInputs together: their setup hooks are
  # intentionally mutually exclusive. Both are nevertheless needed to patch
  # the vendor's optional compatibility shims, so add their libraries only to
  # autoPatchelf's search path.
  preFixup = ''
    addAutoPatchelfSearchPath "${qt5.qtbase}/lib" "${qt6.qtbase}/lib"
  '';

  # The .deb installs a root-owned updater repository in postinst. Nix only
  # extracts its application payload, so package updates remain declarative.
  unpackCmd = "dpkg-deb -x $curSrc source";

  installPhase = ''
    runHook preInstall

    install -dm755 "$out"
    mv usr "$out/"

    # The packaged launcher resolves its own location through `readlink -f`.
    # Expose a Nix-profile executable that invokes the actual app directly,
    # without depending on mutable /usr paths.
    makeWrapper "$out/usr/lib/chatgpt/ChatGPT" "$out/bin/chatgpt"

    runHook postInstall
  '';

  meta = {
    description = "OpenAI ChatGPT desktop application with Codex";
    homepage = "https://developers.openai.com/codex/app";
    license = lib.licenses.unfreeRedistributable;
    mainProgram = "chatgpt";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
