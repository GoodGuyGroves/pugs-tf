# lib/plugins/classwarning.nix
#
# ClassWarning — warns players when too many of one class are selected.
# Source: https://sourcemod.krus.dk/
#
# The zip contains a single classwarning.smx file at the root.
{ pkgs, helpers }:

helpers.fetchSourceModPluginZipFlat {
  pname = "classwarning";
  version = "unstable-2026-04-30";
  url = "https://sourcemod.krus.dk/classwarning.zip";
  hash = "sha256-0qWp6SEk8DfkSR+6fBUlAKIeFZsZI3aAM1BWow2cn9M=";

  # The upstream WAF blocks requests without a browser-like User-Agent.
  curlOptsList = [
    "--user-agent"
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:89.0) Gecko/20100101 Firefox/89.0"
    "--referer"
    "https://sourcemod.krus.dk/"
  ];

  meta = {
    description = "Class limit warning plugin for TF2 SourceMod servers";
    homepage = "https://sourcemod.krus.dk/";
  };
}
