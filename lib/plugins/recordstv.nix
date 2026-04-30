# lib/plugins/recordstv.nix
#
# RecordSTV — automatically records SourceTV demos.
# Source: https://sourcemod.krus.dk/
#
# The zip contains a single recordstv.smx file at the root.
{ pkgs, helpers }:

helpers.fetchSourceModPluginZipFlat {
  pname = "recordstv";
  version = "unstable-2026-04-30";
  url = "https://sourcemod.krus.dk/recordstv.zip";
  hash = "sha256-VaMPY5Amp8k9Jxr+K9tVF8XnLyVUfeJ8cZzz9G92fIs=";

  # The upstream WAF blocks requests without a browser-like User-Agent.
  curlOptsList = [
    "--user-agent"
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:89.0) Gecko/20100101 Firefox/89.0"
    "--referer"
    "https://sourcemod.krus.dk/"
  ];

  meta = {
    description = "Automatic SourceTV demo recording for TF2 SourceMod servers";
    homepage = "https://sourcemod.krus.dk/";
  };
}
