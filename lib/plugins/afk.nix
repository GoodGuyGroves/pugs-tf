# lib/plugins/afk.nix
#
# AFK manager — kicks idle players from the TF2 server.
# Source: https://sourcemod.krus.dk/
#
# The zip contains a single afk.smx file at the root.
{ pkgs, helpers }:

helpers.fetchSourceModPluginZipFlat {
  pname = "afk";
  version = "unstable-2026-04-30";
  url = "https://sourcemod.krus.dk/afk.zip";
  hash = "sha256-LuVe75hk8lzit/+zsdR+5kSndx7JaQoLT7I+ZqdJS+w=";

  # The upstream WAF blocks requests without a browser-like User-Agent.
  curlOptsList = [
    "--user-agent"
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:89.0) Gecko/20100101 Firefox/89.0"
    "--referer"
    "https://sourcemod.krus.dk/"
  ];

  meta = {
    description = "AFK manager plugin for TF2 SourceMod servers";
    homepage = "https://sourcemod.krus.dk/";
  };
}
