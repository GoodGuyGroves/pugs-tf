# hosts/tf2/default.nix
#
# Top-level NixOS configuration for the tf2 server host.
# Hardware-specific settings (disk layout, boot loader, etc.) will be
# added once the machine is provisioned.
{ config, pkgs, self, ... }:

{
  # -- Networking -------------------------------------------------------
  networking.hostName = "tf2";

  # -- Virtualisation ---------------------------------------------------
  # Podman is used as the container runtime for all game-server and
  # bot containers, orchestrated via quadlet-nix.
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;          # provide a `docker` alias
    defaultNetwork.settings.dns_enabled = true;
  };

  # -- System -----------------------------------------------------------
  system.stateVersion = "24.11";

  # -- Placeholder comments ---------------------------------------------
  # TODO: import hardware-configuration.nix once the machine is provisioned
  # TODO: tf2-server module options will be configured here
  # TODO: miss-pauling module options will be configured here
  # TODO: comin (GitOps) configuration for automatic deployments
  # TODO: sops-nix secret declarations
}
