# hosts/tf2/nginx.nix
#
# Nginx reverse proxy for Miss Pauling + FastDL with ACME (Let's Encrypt) SSL.
{ config, ... }:

let
  mp = config.services.missPauling;
  backendUrl = "http://${mp.host}:${toString mp.port}";
in
{
  # -- Nginx ----------------------------------------------------------------
  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;

    virtualHosts = {
      # Main website
      "${mp.domain}" = {
        forceSSL = true;
        enableACME = true;
        serverAliases = [ "www.${mp.domain}" ];
        locations."/" = {
          proxyPass = backendUrl;
          proxyWebsockets = true; # For /admin/logs/stream/ WebSocket
        };
      };

      # FastDL
      "${mp.fastdlDomain}" = {
        forceSSL = true;
        enableACME = true;
        locations."/" = {
          proxyPass = backendUrl;
          # FastDL may serve large map files — increase limits
          extraConfig = ''
            proxy_read_timeout 300;
            client_max_body_size 200M;
          '';
        };
      };
    };
  };

  # -- ACME (Let's Encrypt) -------------------------------------------------
  security.acme = {
    acceptTerms = true;
    defaults.email = "tf2@lumabyte.io";
  };

  # -- Firewall: allow HTTP/HTTPS -------------------------------------------
  networking.firewall.allowedTCPPorts = [ 80 443 ];
}
