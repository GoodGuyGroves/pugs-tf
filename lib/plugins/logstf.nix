# lib/plugins/logstf.nix
#
# logs.tf — automatic log uploading for TF2 SourceMod servers.
# Source: https://sourcemod.krus.dk/
#
# The zip contains a single logstf.smx file.  We use fetchSourceModPluginZip
# since the upstream distributes it as a zip archive.
{ pkgs, helpers }:

helpers.fetchSourceModPluginZip {
  pname = "logstf";
  version = "unstable-2025-09-08";
  url = "https://sourcemod.krus.dk/logstf.zip";
  hash = "sha256-pQpattmS9VmO3ZIQUFn66az8GSmB4IvYhTTCFn6SUmo=";

  # The upstream WAF blocks requests without a browser-like User-Agent.
  curlOptsList = [
    "--user-agent"
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:89.0) Gecko/20100101 Firefox/89.0"
    "--referer"
    "https://sourcemod.krus.dk/"
  ];

  meta = {
    description = "Automatic logs.tf log uploading for TF2 SourceMod servers";
    homepage = "https://sourcemod.krus.dk/";
  };
}
