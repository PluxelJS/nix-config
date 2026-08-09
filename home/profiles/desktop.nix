{ config, ... }:
let
  legacyProxyLlmState = "${config.home.homeDirectory}/code/_ACode";
in
{
  ahdg.profile = "desktop";
  services.proxyLlm = {
    enable = true;
    # Existing workstations migrate once; fresh machines initialize directly.
    # Only existence is inspected—the checkout is never copied into the store.
    legacyStateDir =
      if builtins.pathExists "${legacyProxyLlmState}/.env" then legacyProxyLlmState else null;
  };
}
