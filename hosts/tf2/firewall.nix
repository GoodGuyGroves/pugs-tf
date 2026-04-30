# hosts/tf2/firewall.nix
#
# NixOS firewall rules for the TF2 server host.
#
# Opens:
#   - SSH (TCP 22)
#   - Game ports (TCP + UDP) — derived from tf2Server config
#   - SourceTV ports (UDP) — derived from tf2Server config
#   - HTTP/HTTPS (TCP 80, 443) — opened by nginx.nix, not duplicated here
#
# NOT opened (localhost-only by design):
#   - RCON — runs over TCP on the game port, but SDR FakeIP means
#     players connect via Valve relay and never reach the real IP.
#     We block external TCP on game ports and rely on the wrapper
#     sidecar (which talks RCON over localhost).
#   - Management API ports (wrapper sidecar HTTP)
{ config, lib, ... }:

let
  enabledServers = lib.filterAttrs (_: srv: srv.enable) config.services.tf2Server;

  gamePorts = lib.mapAttrsToList (_: srv: srv.port) enabledServers;
  tvPorts = lib.mapAttrsToList (_: srv: srv.tvPort) enabledServers;
in
{
  networking.firewall = {
    enable = true;

    # SSH only — game-port TCP (RCON) is intentionally excluded so
    # RCON is reachable only from localhost.
    allowedTCPPorts = [ 22 ];

    # Game traffic + SourceTV are UDP-only from the internet.
    # (SDR FakeIP routes player traffic through Valve relays over UDP.)
    allowedUDPPorts = gamePorts ++ tvPorts;
  };
}
