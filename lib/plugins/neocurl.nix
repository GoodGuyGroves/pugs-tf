# lib/plugins/neocurl.nix
#
# SM-neocurl — cURL extension for SourceMod (replaces the old cURL extension).
# Source: https://github.com/sapphonie/SM-neocurl-ext
#
# The zip contains extensions/, plugins/, and scripting/ at the root,
# which matches the standard fetchSourceModPluginZip layout.
# This is a native extension (.so/.dll), not a .smx plugin.
{ pkgs, helpers }:

helpers.fetchSourceModPluginZip {
  pname = "neocurl";
  version = "2.0.1-beta1";
  url = "https://github.com/sapphonie/SM-neocurl-ext/releases/download/v2.0.1-beta1/sm-neocurl-repack.zip";
  hash = "sha256-l7nhYMIrH0Yp7YvaK3gCizwbdMNyMn3FcfrOt8CPqMM=";

  meta = {
    description = "cURL extension for TF2 SourceMod servers";
    homepage = "https://github.com/sapphonie/SM-neocurl-ext";
  };
}
