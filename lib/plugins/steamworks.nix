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
  hash = "sha256-sNdw4pQcciFVPv7nkK9b/36AjyS1rfHkC8wkyj5znYU=";

  meta = {
    description = "SteamWorks extension providing Steam API access for SourceMod";
    homepage = "https://users.alliedmods.net/~kyles/builds/SteamWorks/";
  };
}
