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

  # -- TF2 Servers ------------------------------------------------------
  services.tf2Server.pugA = {
    enable = true;
    # serverName defaults to "pugA" (the attr name)
    port = 27015;
    hostname = "pugs.tf pugA";
    enableFakeIP = true;
    configs = self.packages.x86_64-linux.configs;
    plugins = self.packages.x86_64-linux.configs; # placeholder — will be .plugins once all plugins are built (Issue #11)
    rconPasswordFile = "/run/secrets/pugA_rcon"; # placeholder path — real path comes from sops-nix (Issue #16)
    mapsDir = "/var/lib/tf2/maps";
  };

  services.tf2Server.pugB = {
    enable = true;
    # serverName defaults to "pugB" (the attr name)
    port = 27016;
    hostname = "pugs.tf pugB";
    enableFakeIP = true;
    configs = self.packages.x86_64-linux.configs;
    plugins = self.packages.x86_64-linux.configs; # placeholder — will be .plugins once all plugins are built (Issue #11)
    rconPasswordFile = "/run/secrets/pugB_rcon"; # placeholder path — real path comes from sops-nix (Issue #16)
    mapsDir = "/var/lib/tf2/maps";
  };

  # -- Miss Pauling (Discord bot + API) ---------------------------------
  services.missPauling = {
    enable = true;
    # package = null for now (will be set once the uv2nix derivation is wired in)
    domain = "pugs.tf";
    fastdlDomain = "fastdl.pugs.tf";
    discordApplicationId = "PLACEHOLDER";
    discordPublicKey = "PLACEHOLDER";
    # Secret file paths are placeholders — real paths come from sops-nix (Issue #16)
    discordClientSecretFile = "/run/secrets/discord_client_secret";
    discordTokenFile = "/run/secrets/discord_token";
    steamApiKeyFile = "/run/secrets/steam_api_key";
    apiSecretKeyFile = "/run/secrets/api_secret_key";
    mapsDir = "/var/lib/tf2/maps";
  };

  # -- System -----------------------------------------------------------
  system.stateVersion = "24.11";

  # -- Future configuration ---------------------------------------------
  # TODO: import hardware-configuration.nix once the machine is provisioned
  # TODO: comin (GitOps) configuration for automatic deployments (Issue #19)
  # TODO: sops-nix secret declarations (Issue #16)
  # TODO: nginx reverse proxy for Miss Pauling + FastDL (Issue #17)
  # TODO: firewall rules for game ports, SourceTV, and HTTP (Issue #20)
}
