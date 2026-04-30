# lib/plugins/auto-steam-update.nix
#
# Auto Steam Update — automatically restarts the server when a TF2 update
# is detected via SteamWorks.
# Source: https://github.com/Sarabveer/SM-Plugins
#
# Distributed as a single pre-compiled .smx file.
# Requires the SteamWorks extension to function.
{ pkgs, helpers }:

helpers.fetchSourceModPluginSmx {
  pname = "auto-steam-update";
  version = "unstable-2026-04-30";
  url = "https://github.com/Sarabveer/SM-Plugins/raw/master/sw_auto_steam_update/plugins/auto_steam_update.smx";
  hash = "sha256-l1977DIsPpqJ9c+j4IO1SvEdgMUnoGjygfaLJr6qGLo=";
  pluginName = "auto_steam_update";

  meta = {
    description = "Automatic server restart on TF2 update detection (requires SteamWorks)";
    homepage = "https://github.com/Sarabveer/SM-Plugins";
  };
}
