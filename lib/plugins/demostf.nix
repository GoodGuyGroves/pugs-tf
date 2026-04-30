# lib/plugins/demostf.nix
#
# demos.tf — automatic demo uploading for TF2 SourceMod servers.
# Source: https://github.com/demostf/plugin
#
# Distributed as a single pre-compiled .smx file on the master branch.
{ pkgs, helpers }:

helpers.fetchSourceModPluginSmx {
  pname = "demostf";
  version = "unstable-2025-04-28";
  url = "https://github.com/demostf/plugin/raw/master/demostf.smx";
  hash = "sha256-4vrU55cO0OtgnSnOFzNkCJY967qaM5J2hATN/0f9kNA=";

  meta = {
    description = "Automatic demos.tf demo uploading for TF2 SourceMod servers";
    homepage = "https://github.com/demostf/plugin";
  };
}
