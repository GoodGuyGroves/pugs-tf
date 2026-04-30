# lib/plugins/supstats2.nix
#
# Supplemental Stats 2 — logs additional gameplay statistics for logs.tf.
# Source: https://sourcemod.krus.dk/
#
# The zip contains a single supstats2.smx file at the root.
{ pkgs, helpers }:

helpers.fetchSourceModPluginZipFlat {
  pname = "supstats2";
  version = "unstable-2026-04-30";
  url = "https://sourcemod.krus.dk/supstats2.zip";
  hash = "sha256-gg5IMP9cRUoVlnTIsbDrksVrpZGxuNfSk5BApnDeYbw=";

  # The upstream WAF blocks requests without a browser-like User-Agent.
  curlOptsList = [
    "--user-agent"
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:89.0) Gecko/20100101 Firefox/89.0"
    "--referer"
    "https://sourcemod.krus.dk/"
  ];

  meta = {
    description = "Supplemental gameplay statistics for logs.tf on TF2 SourceMod servers";
    homepage = "https://sourcemod.krus.dk/";
  };
}
