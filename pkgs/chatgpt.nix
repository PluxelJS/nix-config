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
    # Electron can load either Qt shim; each needs the matching platform
    # plugins as well as the libraries found by autoPatchelf.
    makeWrapper "$out/usr/lib/chatgpt/ChatGPT" "$out/bin/chatgpt" \
      --set QT_PLUGIN_PATH "${lib.makeSearchPath "lib/qt-6/plugins" [ qt6.qtbase qt6.qtwayland ]}:${lib.makeSearchPath "lib/qt-5/plugins" [ qt5.qtbase qt5.qtwayland ]}" \
      --set QT_QPA_PLATFORM_PLUGIN_PATH "${qt6.qtbase}/lib/qt-6/plugins/platforms"

    # Home Manager and XDG launchers discover desktop entries and icons under
    # share/, not the Debian payload's usr/share/.
    mv "$out/usr/share" "$out/share"
    substituteInPlace "$out/share/applications/chatgpt.desktop" \
      --replace-fail 'Exec=chatgpt %U' "Exec=$out/bin/chatgpt %U"

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
