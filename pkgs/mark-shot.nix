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
  version = "0.1.45";

  src = fetchFromGitHub {
    owner = "jswysnemc";
    repo = "mark-shot";
    rev = "v${finalAttrs.version}";
    hash = "sha256-/MeGN7jq576psIc2P6Hr1L0n9v/XhdyKpM1hP06+DKk=";
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
      --prefix PATH : "$out/bin:${
        lib.makeBinPath [
          grim
          wl-clipboard
          xclip
          python3
        ]
      }"
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
