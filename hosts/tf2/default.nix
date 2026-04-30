# hosts/tf2/default.nix
#
# Top-level NixOS configuration for the tf2 server host.
# Hardware-specific settings (disk layout, boot loader, etc.) will be
# added once the machine is provisioned.
{ config, pkgs, self, ... }:

{
  imports = [
    ./nginx.nix
    ./secrets.nix
  ];

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
    plugins = self.packages.x86_64-linux.plugins;
    rconPasswordFile = config.sops.secrets."pugA_rcon_password".path;
    svPasswordFile = config.sops.secrets."sv_password".path;
    demostfApiKeyFile = config.sops.secrets."demostf_api_key".path;
    logstfApiKeyFile = config.sops.secrets."logstf_api_key".path;
    mapsDir = "/var/lib/tf2/maps";
  };

  services.tf2Server.pugB = {
    enable = true;
    # serverName defaults to "pugB" (the attr name)
    port = 27016;
    hostname = "pugs.tf pugB";
    enableFakeIP = true;
    configs = self.packages.x86_64-linux.configs;
    plugins = self.packages.x86_64-linux.plugins;
    rconPasswordFile = config.sops.secrets."pugB_rcon_password".path;
    svPasswordFile = config.sops.secrets."sv_password".path;
    demostfApiKeyFile = config.sops.secrets."demostf_api_key".path;
    logstfApiKeyFile = config.sops.secrets."logstf_api_key".path;
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
    discordClientSecretFile = config.sops.secrets."discord_client_secret".path;
    discordTokenFile = config.sops.secrets."discord_token".path;
    steamApiKeyFile = config.sops.secrets."steam_api_key".path;
    apiSecretKeyFile = config.sops.secrets."api_secret_key".path;
    mapsDir = "/var/lib/tf2/maps";
  };

  # -- System -----------------------------------------------------------
  system.stateVersion = "24.11";

  # -- Future configuration ---------------------------------------------
  # TODO: import hardware-configuration.nix once the machine is provisioned
  # TODO: comin (GitOps) configuration for automatic deployments (Issue #19)
  # TODO: firewall rules for game ports, SourceTV, and HTTP (Issue #20)
}
