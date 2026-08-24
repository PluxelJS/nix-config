{
  writeShellApplication,
  git,
  nix,
}:
writeShellApplication {
  name = "nixup";
  runtimeInputs = [
    git
    nix
  ];
  text = builtins.readFile ../home/files/bin/nixup;
}
