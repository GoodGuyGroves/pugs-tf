# lib/plugins/update-check.nix
#
# UpdateCheck — checks for pending TF2 game updates.
# Source: https://forums.alliedmods.net/showthread.php?t=258698
#
# NOTE: The alliedmods.net download URL blocks automated fetchers.
# The hash is a placeholder until it can be fetched manually.
{ pkgs, helpers }:

helpers.fetchSourceModPluginSmx {
  pname = "update-check";
  version = "unstable-2015-10-30";
  url = "https://forums.alliedmods.net/attachment.php?attachmentid=149268&d=1446230007";
  # TODO: Replace placeholder hash — alliedmods.net blocks automated fetchers.
  # Download manually and run: nix hash file --type sha256 --sri <file>
  hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  pluginName = "UpdateCheck";

  curlOptsList = [
    "--user-agent"
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:89.0) Gecko/20100101 Firefox/89.0"
    "--referer"
    "https://forums.alliedmods.net"
  ];

  meta = {
    description = "TF2 game update detection plugin for SourceMod servers";
    homepage = "https://forums.alliedmods.net/showthread.php?t=258698";
  };
}
