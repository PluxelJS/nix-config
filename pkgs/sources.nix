{ lib, fetchurl, fetchFromGitHub }:
let
  sources = builtins.fromJSON (builtins.readFile ../sources.json);
in
lib.mapAttrs (_: source: source // {
  src =
    if source.kind == "github" then
      fetchFromGitHub { inherit (source) owner repo rev hash; }
    else
      fetchurl {
        inherit (source) url name hash;
        curlOptsList = lib.optionals (source ? assetId) [
          "-H" "Accept: application/octet-stream"
        ];
      };
}) sources
