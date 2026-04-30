# lib/plugins/p4sstime.nix
#
# p4sstime — PASS Time competitive plugin for TF2.
# Source: https://github.com/p4sstime/p4sstime-server-resources
#
# The GitHub release zip contains plugins/ and gamedata/ directories,
# which are standard SourceMod sub-directories.
{ pkgs, helpers }:

helpers.fetchSourceModPluginZip {
  pname = "p4sstime";
  version = "2.6.0-rc2";
  url = "https://github.com/p4sstime/p4sstime-server-resources/releases/download/v2.6.0-rc2/p4sstime.zip";
  hash = "sha256-v0TmWCRyJZkdqzuPGtoGE3dhMg1+AKWW+5mpns33G9A=";

  meta = {
    description = "PASS Time competitive plugin for TF2 SourceMod servers";
    homepage = "https://github.com/p4sstime/p4sstime-server-resources";
  };
}
