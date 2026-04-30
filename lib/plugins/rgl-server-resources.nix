# lib/plugins/rgl-server-resources.nix
#
# RGL Server Resources — competitive league plugins, configs, and utilities.
# Source: https://github.com/RGLgg/server-resources-updater
#
# The zip contains addons/sourcemod/ with plugins/, scripting/, translations/,
# as well as addons/srctvplus.vdf and the srctvplus extension.
#
# Includes: tf2-comp-fixes, rglqol, pause, updater, demo_check,
# improved_match_timer, config_checker, and more.
{ pkgs, helpers }:

helpers.fetchSourceModPluginZipNested {
  pname = "rgl-server-resources";
  version = "372";
  url = "https://github.com/RGLgg/server-resources-updater/releases/download/v372/server-resources-updater.zip";
  hash = "sha256-Sc34hZO2lgWhqwGY04akJG0MtmkkcPGFo6pgPgJOrW0=";

  meta = {
    description = "RGL competitive league server resources for TF2";
    homepage = "https://github.com/RGLgg/server-resources-updater";
  };
}
