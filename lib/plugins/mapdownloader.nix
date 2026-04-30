# lib/plugins/mapdownloader.nix
#
# Map Downloader — automatically downloads missing maps via FastDL/redirect.
# Source: https://github.com/spiretf/mapdownloader
#
# Distributed as a single pre-compiled .smx file on the master branch.
{ pkgs, helpers }:

helpers.fetchSourceModPluginSmx {
  pname = "mapdownloader";
  version = "unstable-2026-04-30";
  url = "https://github.com/spiretf/mapdownloader/raw/master/plugin/mapdownloader.smx";
  hash = "sha256-U9SmTUCpOYN909+/Qao+aCxCHaRO+08Ww9s5eqKQHtI=";

  meta = {
    description = "Automatic map downloader for TF2 SourceMod servers";
    homepage = "https://github.com/spiretf/mapdownloader";
  };
}
