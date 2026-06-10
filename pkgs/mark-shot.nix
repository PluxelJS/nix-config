{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  ninja,
  pkg-config,
  qt6,
  kdePackages,
  pipewire,
  libportal,
  grim,
  wl-clipboard,
  xclip,
  python3,
  libx11,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "mark-shot";
  version = "0.1.25";

  src = fetchFromGitHub {
    owner = "jswysnemc";
    repo = "mark-shot";
    rev = "v${finalAttrs.version}";
    hash = "sha256-hFR2PvGBsO1kQCqM913TbKHZyx2RRZpjtgOBTa5wvA8=";
  };

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
    qt6.wrapQtAppsHook
  ];

  buildInputs = [
    qt6.qtbase
    qt6.qtwayland
    kdePackages.layer-shell-qt
    pipewire
    libportal
    libx11
  ];

  cmakeFlags = [
    "-DBUILD_TESTING=OFF"
    "-DMARK_SHOT_WITH_LAYER_SHELL=ON"
    "-DMARK_SHOT_WITH_LIBPORTAL=ON"
  ];

  preFixup = ''
    qtWrapperArgs+=(
      --prefix PATH : "$out/bin:${lib.makeBinPath [
        grim
        wl-clipboard
        xclip
        python3
      ]}"
    )
  '';

  meta = {
    description = "Qt 6 screenshot and annotation tool for Linux desktops";
    homepage = "https://github.com/jswysnemc/mark-shot";
    license = lib.licenses.mit;
    mainProgram = "mark-shot";
    platforms = lib.platforms.linux;
  };
})
