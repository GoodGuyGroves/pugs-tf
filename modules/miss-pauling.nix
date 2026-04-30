# modules/miss-pauling.nix
#
# NixOS module for the Miss Pauling web application (Discord bot + API).
#
# Uses the RFC 42 settings pattern. Automatically discovers all enabled
# tf2Server instances and includes them in the generated config JSON,
# providing the critical bridge between Nix-declared servers and the
# Python web app.
{ config, lib, pkgs, ... }:

let
  cfg = config.services.missPauling;

  # JSON format helper for generating config files.
  jsonFormat = pkgs.formats.json { };

  # Collect all enabled tf2Server instances.
  tf2Servers = lib.filterAttrs (_: srv: srv.enable) config.services.tf2Server;

  # Extract the subset of each server's config that Miss Pauling needs.
  serverInfoForMP = lib.mapAttrs (name: srv: {
    inherit (srv) serverName port tvPort managementPort enableFakeIP hostname;
    managementUrl = "http://127.0.0.1:${toString srv.managementPort}";
  }) tf2Servers;

  # Build the complete config JSON that Miss Pauling reads at runtime.
  configJson = jsonFormat.generate "miss-pauling-config.json" ({
    port = cfg.port;
    host = cfg.host;
    domain = cfg.domain;
    fastdlDomain = cfg.fastdlDomain;
    environment = cfg.environment;
    workers = cfg.workers;

    # Discord (non-secret)
    discordApplicationId = cfg.discordApplicationId;
    discordPublicKey = cfg.discordPublicKey;

    # Secret file paths (resolved at runtime by the Python app)
    discordClientSecretFile = cfg.discordClientSecretFile;
    discordTokenFile = cfg.discordTokenFile;
    steamApiKeyFile = cfg.steamApiKeyFile;
    apiSecretKeyFile = cfg.apiSecretKeyFile;

    # Database
    database = {
      type = cfg.database.type;
      path = cfg.database.path;
    };

    # Maps
    mapsDir = cfg.mapsDir;

    # The bridge: all enabled TF2 servers
    tf2Servers = serverInfoForMP;
  } // lib.optionalAttrs (cfg.logsTfUploaderSteamId != null) {
    logsTfUploaderSteamId = cfg.logsTfUploaderSteamId;
  });

in
{
  # ---------------------------------------------------------------------------
  # Option interface
  # ---------------------------------------------------------------------------
  options.services.missPauling = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to enable the Miss Pauling web application.";
    };

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = ''
        The Miss Pauling Python package derivation.
        Set to null until the package is wired in (see packages/miss-pauling).
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8000;
      description = "Port for the uvicorn HTTP server.";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Bind address for the uvicorn HTTP server (behind nginx).";
    };

    domain = lib.mkOption {
      type = lib.types.str;
      default = "pugs.tf";
      description = "Public domain name for the web application.";
    };

    fastdlDomain = lib.mkOption {
      type = lib.types.str;
      default = "fastdl.pugs.tf";
      description = "Domain name for the FastDL file server.";
    };

    environment = lib.mkOption {
      type = lib.types.enum [ "development" "production" ];
      default = "production";
      description = "Application environment (affects logging, debug mode, etc.).";
    };

    workers = lib.mkOption {
      type = lib.types.int;
      default = 4;
      description = "Number of uvicorn worker processes.";
    };

    # -- Secret file paths (sops-nix) ----------------------------------------

    discordClientSecretFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to the file containing the Discord OAuth2 client secret.";
    };

    discordTokenFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to the file containing the Discord bot token.";
    };

    steamApiKeyFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to the file containing the Steam Web API key.";
    };

    apiSecretKeyFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to the file containing the application API secret key.";
    };

    # -- Non-secret config ----------------------------------------------------

    discordApplicationId = lib.mkOption {
      type = lib.types.str;
      description = "Discord application (client) ID.";
    };

    discordPublicKey = lib.mkOption {
      type = lib.types.str;
      description = "Discord application public key for interaction verification.";
    };

    logsTfUploaderSteamId = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Steam ID used as the uploader identity for logs.tf submissions, or null to omit.";
    };

    # -- Database -------------------------------------------------------------

    database = {
      type = lib.mkOption {
        type = lib.types.enum [ "sqlite" "postgresql" ];
        default = "sqlite";
        description = "Database backend type.";
      };

      path = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/miss-pauling/sqlite.db";
        description = "Path to the SQLite database file (only used when database.type is sqlite).";
      };
    };

    # -- Maps -----------------------------------------------------------------

    mapsDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/tf2/maps";
      description = "Path to the shared maps directory used by both TF2 servers and Miss Pauling.";
    };
  };

  # ---------------------------------------------------------------------------
  # Implementation
  # ---------------------------------------------------------------------------
  config = lib.mkIf cfg.enable {

    # -- Config JSON ----------------------------------------------------------
    environment.etc."miss-pauling/config.json" = {
      source = configJson;
    };

    # -- tmpfiles: ensure state directory exists -------------------------------
    systemd.tmpfiles.rules = [
      "d /var/lib/miss-pauling 0750 miss-pauling miss-pauling - -"
    ];

    # -- User and group -------------------------------------------------------
    users.users.miss-pauling = {
      isSystemUser = true;
      group = "miss-pauling";
      home = "/var/lib/miss-pauling";
      description = "Miss Pauling web application service user";
    };

    users.groups.miss-pauling = { };

    # -- systemd service ------------------------------------------------------
    systemd.services.miss-pauling = {
      description = "Miss Pauling web application";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      environment = {
        MISS_PAULING_CONFIG_PATH = "/etc/miss-pauling/config.json";
        PYTHONUNBUFFERED = "1";
      };

      serviceConfig = {
        Type = "simple";
        User = "miss-pauling";
        Group = "miss-pauling";
        DynamicUser = false;
        StateDirectory = "miss-pauling";

        ExecStart = lib.mkIf (cfg.package != null) (
          let
            pkg = cfg.package;
          in
          "${pkg}/bin/uvicorn miss_pauling.app:app"
          + " --host ${cfg.host}"
          + " --port ${toString cfg.port}"
          + " --workers ${toString cfg.workers}"
        );

        Restart = "always";
        RestartSec = 5;
      };
    };
  };
}
