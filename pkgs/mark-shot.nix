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
  tesseract5,
  libx11,
}:
let
  ocrPython = python3.withPackages (ps: [ ps.rapidocr ]);
  ocrModels = "${ocrPython}/${ocrPython.sitePackages}/rapidocr/models";
  ocrTesseract = tesseract5.override {
    enableLanguages = [
      "eng"
      "chi_sim"
    ];
  };
in
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

  postPatch = ''
    # RapidOCR 3 uses model_root_dir. Point the upstream helper at the models
    # bundled by nixpkgs instead of its mutable per-user download directory.
    substituteInPlace scripts/mark-shot-ocr \
      --replace-fail '#!/usr/bin/env python3' '#!${ocrPython}/bin/python3' \
      --replace-fail '"Global.model_dir",' '"Global.model_root_dir",'
  '';

  preFixup = ''
    qtWrapperArgs+=(
      --prefix PATH : "$out/bin:${
        lib.makeBinPath [
          grim
          wl-clipboard
          xclip
          ocrPython
          ocrTesseract
        ]
      }"
      --set MARK_SHOT_OCR_NO_VENV 1
      --set MARK_SHOT_OCR_VERSION PP-OCRv6
      --set MARK_SHOT_OCR_MODEL_DIR "${ocrModels}"
    )
  '';

  postFixup = ''
    wrapProgram "$out/bin/mark-shot-ocr" \
      --prefix PATH : "${lib.makeBinPath [ ocrTesseract ]}" \
      --set MARK_SHOT_OCR_NO_VENV 1 \
      --set MARK_SHOT_OCR_VERSION PP-OCRv6 \
      --set MARK_SHOT_OCR_MODEL_DIR "${ocrModels}"
  '';

  meta = {
    description = "Qt 6 screenshot and annotation tool for Linux desktops";
    homepage = "https://github.com/jswysnemc/mark-shot";
    license = lib.licenses.mit;
    mainProgram = "mark-shot";
    platforms = lib.platforms.linux;
  };
})
