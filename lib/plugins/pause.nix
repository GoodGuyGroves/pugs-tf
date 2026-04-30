# lib/plugins/pause.nix
#
# Pause — allows players to pause/unpause competitive matches.
# Source: https://sourcemod.krus.dk/
#
# The zip contains a single pause.smx file at the root.
{ pkgs, helpers }:

helpers.fetchSourceModPluginZipFlat {
  pname = "pause";
  version = "unstable-2026-04-30";
  url = "https://sourcemod.krus.dk/pause.zip";
  hash = "sha256-s6RcOGfZ8lDTcLpUz8NUHZUgMRCKKNctEnyjjtPeSwE=";

  # The upstream WAF blocks requests without a browser-like User-Agent.
  curlOptsList = [
    "--user-agent"
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:89.0) Gecko/20100101 Firefox/89.0"
    "--referer"
    "https://sourcemod.krus.dk/"
  ];

  meta = {
    description = "Match pause/unpause plugin for TF2 SourceMod servers";
    homepage = "https://sourcemod.krus.dk/";
  };
}
