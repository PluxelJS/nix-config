{ lib, stdenv, git, libsecret, pkg-config }:

# Git's helper mixes SecretService reads with backend-selected writes/erases.
# In Flatpak, libsecret selects its portal file backend for the latter, so
# saved OAuth tokens cannot be found on the next read. Use SecretService for
# all three operations; the IDE already has org.freedesktop.secrets access.
stdenv.mkDerivation {
  pname = "git-credential-libsecret";
  inherit (git) version src;
  patches = [ ./patches/git-credential-libsecret-service.patch ];
  strictDeps = true;
  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ libsecret ];
  makeFlags = [ "-C" "contrib/credential/libsecret" ];
  installFlags = [ "gitexecdir=$(out)/bin" ];

  meta = {
    description = "Git credential helper using the shared desktop Secret Service";
    homepage = "https://git-scm.com/";
    license = lib.licenses.gpl2Only;
    platforms = lib.platforms.linux;
    mainProgram = "git-credential-libsecret";
  };
}
