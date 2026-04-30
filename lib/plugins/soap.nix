# lib/plugins/soap.nix
#
# SOAP-TF2DM — Deathmatch plugin for TF2 competitive warmup.
# Source: https://github.com/sapphonie/SOAP-TF2DM
#
# The zip contains addons/sourcemod/ with configs/, plugins/, and scripting/.
{ pkgs, helpers }:

helpers.fetchSourceModPluginZipNested {
  pname = "soap";
  version = "4.4.8";
  url = "https://github.com/sapphonie/SOAP-TF2DM/releases/download/v4.4.8/soap.zip";
  hash = "sha256-7tzYmJn7iUCwKwni2zZCxDAwixoxyW5iXZ82ppsUxE8=";

  meta = {
    description = "SOAP-TF2DM deathmatch plugin for TF2 SourceMod servers";
    homepage = "https://github.com/sapphonie/SOAP-TF2DM";
  };
}
