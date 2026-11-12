{
  lib,
  stdenvNoCC,
  desktopSources,
  autoPatchelfHook,
  stdenv,
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
  libxcb,
  ffmpeg,
  wayland,
  libGL,
  libpulseaudio,
  onnxruntime,
  zxing-cpp,
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
stdenvNoCC.mkDerivation {
  pname = "mark-shot";
  inherit (desktopSources.mark-shot) version src;

  sourceRoot = ".";

  nativeBuildInputs = [
    autoPatchelfHook
    python3
    qt6.wrapQtAppsHook
  ];

  buildInputs = [
    qt6.qtbase
    qt6.qtsvg
    qt6.qtwayland
    kdePackages.layer-shell-qt
    pipewire
    libportal
    libx11
    libxcb
    ffmpeg
    wayland
    libGL
    libpulseaudio
    onnxruntime
    zxing-cpp
    stdenv.cc.cc.lib
  ];

  postPatch = ''
    substituteInPlace libexec/mark-shot/mark-shot-ocr \
      --replace-fail '#!/usr/bin/env python3' '#!${ocrPython}/bin/python3'
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -r bin lib libexec share "$out/"
    runHook postInstall
  '';

  preFixup = ''
    qtWrapperArgs+=(
      --prefix QT_PLUGIN_PATH : "${kdePackages.layer-shell-qt}/${qt6.qtbase.qtPluginPrefix}"
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ kdePackages.layer-shell-qt ]}"
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
    wrapProgram "$out/libexec/mark-shot/mark-shot-ocr" \
      --prefix PATH : "${lib.makeBinPath [ ocrTesseract ]}" \
      --set MARK_SHOT_OCR_NO_VENV 1 \
      --set MARK_SHOT_OCR_VERSION PP-OCRv6 \
      --set MARK_SHOT_OCR_MODEL_DIR "${ocrModels}"
    # Retain the public helper command after upstream moved helpers to libexec.
    ln -s ../libexec/mark-shot/mark-shot-ocr "$out/bin/mark-shot-ocr"
  '';

  meta = {
    description = "Official prebuilt Mark Shot screenshot and annotation tool";
    homepage = "https://github.com/jswysnemc/mark-shot";
    license = lib.licenses.mit;
    mainProgram = "mark-shot";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
