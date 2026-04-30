# modules/tf2-server.nix
#
# NixOS module for running one or more TF2 dedicated-server instances
# inside Podman containers via quadlet-nix.
#
# Planned responsibilities:
#   - Build the TF2 server OCI image (SteamCMD + game files)
#   - Declare quadlet container units per server instance
#   - Wire up persistent volumes for server configs, maps, plugins
#   - Expose SRCDS ports and RCON
{ ... }:

{
  # Module implementation will be added in a later issue.
}
