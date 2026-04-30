# lib/configs/default.nix
#
# Produces a store path containing the full TF2 server configuration tree.
# Secrets (rcon_password, API keys, etc.) are left as placeholders — the
# tf2-server-wrapper injects real values at runtime from sops-nix secrets.
{ pkgs }:

pkgs.stdenv.mkDerivation {
  pname = "tf2-passtime-configs";
  version = "0.1.0";

  src = ./tf;

  dontBuild = true;

  installPhase = ''
    mkdir -p $out
    cp -r . $out/
  '';

  meta = with pkgs.lib; {
    description = "TF2 server configs for the 4v4 PASS Time Europe community";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
