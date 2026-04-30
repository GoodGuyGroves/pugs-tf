# hosts/tf2/secrets.nix
#
# sops-nix secret declarations for the tf2 host.
# Each secret defined here is decrypted at activation time
# and made available under /run/secrets/<name>.
{ config, ... }:

{
  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;

    # Age key derived from the host's SSH ed25519 key.
    # sops-nix automatically converts the SSH key to an age key.
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

    secrets = {
      # -- Miss_Pauling --
      "discord_client_secret" = {};
      "discord_token" = {};
      "steam_api_key" = {};
      "api_secret_key" = {};

      # -- TF2 servers --
      "pugA_rcon_password" = {};
      "pugB_rcon_password" = {};
      "sv_password" = {};

      # -- Plugin API keys --
      "demostf_api_key" = {};
      "logstf_api_key" = {};
    };
  };
}
