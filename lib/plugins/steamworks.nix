# lib/plugins/steamworks.nix
#
# SteamWorks — SourceMod extension providing Steam API access.
# Source: https://users.alliedmods.net/~kyles/builds/SteamWorks/
#
# The tar.gz contains addons/sourcemod/extensions/ and scripting/.
# This is a native extension (.so), not a .smx plugin.
{ pkgs, helpers }:

helpers.fetchSourceModPluginTarNested {
  pname = "steamworks";
  version = "git132";
  url = "https://users.alliedmods.net/~kyles/builds/SteamWorks/SteamWorks-git132-linux.tar.gz";
  hash = "sha256-47HA4oIcl4bARxpOR7rO49xeTrqIfJkDgEbHJg4NtTg=";

  meta = {
    description = "SteamWorks extension providing Steam API access for SourceMod";
    homepage = "https://users.alliedmods.net/~kyles/builds/SteamWorks/";
  };
}
