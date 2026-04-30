# hosts/tf2/podman.nix
#
# Podman container runtime configuration for the tf2 host.
# Quadlet container definitions live in modules/tf2-server.nix;
# this file handles the host-level Podman setup.
{ config, pkgs, ... }:

{
  # Podman container runtime
  virtualisation.podman = {
    enable = true;
    dockerCompat = true; # provide a `docker` alias
    defaultNetwork.settings.dns_enabled = true;

    # Auto-prune unused images weekly
    autoPrune = {
      enable = true;
      dates = "weekly";
      flags = [ "--all" ];
    };
  };

  # Ensure the top-level tf2 data directory exists.
  # Per-server subdirectories (data, maps) are created by
  # modules/tf2-server.nix via systemd.tmpfiles.
  systemd.tmpfiles.rules = [
    "d /var/lib/tf2 0755 root root -"
  ];

  # Container image management
  # The TF2 server image needs to be built and loaded locally
  # or pulled from a registry. For now, document the manual step.
  # TODO: nix2container will automate this in Phase 5
}
