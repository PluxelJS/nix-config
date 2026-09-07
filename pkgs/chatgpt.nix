{
  lib,
  stdenvNoCC,
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

stdenvNoCC.mkDerivation {
  pname = "chatgpt";

  # ChatGPT for Linux is a rolling desktop application. Upstream publishes the
  # current build through a mutable `latest` URL, so deliberately keep this
  # package impure instead of pinning a hash that would break Home Manager on
  # every upstream update.
  version = "latest";

  # Intentionally uses builtins.fetchurl without a hash.
  #
  # This requires impure evaluation (`--impure`), which is already how this
  # Home Manager configuration is invoked. When upstream replaces the latest
  # .deb, Nix can fetch the new object instead of failing with a fixed-output
  # hash mismatch.
  src = builtins.fetchurl {
    url = "https://persistent.oaistatic.com/codex-app-prod/linux/deb/latest/chatgpt_amd64.deb";
    name = "chatgpt_amd64.deb";
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
  autoPatchelfIgnoreMissingDeps = [
    "libc.musl-x86_64.so.1"
  ];

  # Do not put Qt 5 and Qt 6 in buildInputs together: their setup hooks are
  # intentionally mutually exclusive. Both are nevertheless needed to patch
  # the vendor's optional compatibility shims, so expose their libraries only
  # to autoPatchelf.
  preFixup = ''
    addAutoPatchelfSearchPath "${qt5.qtbase}/lib" "${qt6.qtbase}/lib"
  '';

  # The .deb normally installs an updater repository from its maintainer
  # scripts. Nix only extracts the application payload; package acquisition is
  # handled by this expression instead.
  unpackCmd = "dpkg-deb -x $curSrc source";

  installPhase = ''
    runHook preInstall

    install -dm755 "$out"
    mv usr "$out/"

    # Expose a stable executable in the Nix profile while invoking the bundled
    # application directly.
    makeWrapper "$out/usr/lib/chatgpt/ChatGPT" "$out/bin/chatgpt"

    runHook postInstall
  '';

  meta = {
    description = "OpenAI ChatGPT desktop application with Codex";
    homepage = "https://developers.openai.com/codex/app";
    license = lib.licenses.unfreeRedistributable;
    mainProgram = "chatgpt";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [
      binaryNativeCode
    ];
  };
}