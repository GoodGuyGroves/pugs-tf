# lib/plugins/restorescore.nix
#
# RestoreScore — restores player scores after map change or reconnect.
# Source: https://sourcemod.krus.dk/
#
# The zip contains a single restorescore.smx file at the root.
{ pkgs, helpers }:

helpers.fetchSourceModPluginZipFlat {
  pname = "restorescore";
  version = "unstable-2026-04-30";
  url = "https://sourcemod.krus.dk/restorescore.zip";
  hash = "sha256-Dh/WZhNPv/zJIFVTWTKKH1E1UaFnQTvO3i2QW0KArh8=";

  # The upstream WAF blocks requests without a browser-like User-Agent.
  curlOptsList = [
    "--user-agent"
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:89.0) Gecko/20100101 Firefox/89.0"
    "--referer"
    "https://sourcemod.krus.dk/"
  ];

  meta = {
    description = "Score restoration plugin for TF2 SourceMod servers";
    homepage = "https://sourcemod.krus.dk/";
  };
}
