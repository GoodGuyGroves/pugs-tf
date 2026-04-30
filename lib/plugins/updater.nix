# lib/plugins/updater.nix
#
# Updater — automatic SourceMod plugin updater.
# Source: https://forums.alliedmods.net/showthread.php?t=169095
#
# NOTE: The alliedmods.net download URL blocks automated fetchers.
# The RGL server resources package already includes a copy of updater.smx,
# so this standalone derivation is provided for use without RGL.
# The hash is a placeholder until it can be fetched manually.
{ pkgs, helpers }:

helpers.fetchSourceModPluginZip {
  pname = "updater";
  version = "unstable-2020-08-28";
  url = "https://forums.alliedmods.net/attachment.php?attachmentid=183438&d=1598611003";
  # TODO: Replace placeholder hash — alliedmods.net blocks automated fetchers.
  # Download manually and run: nix hash file --type sha256 --sri <file>
  hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";

  curlOptsList = [
    "--user-agent"
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:89.0) Gecko/20100101 Firefox/89.0"
    "--referer"
    "https://forums.alliedmods.net"
  ];

  meta = {
    description = "Automatic plugin updater for TF2 SourceMod servers";
    homepage = "https://forums.alliedmods.net/showthread.php?t=169095";
  };
}
