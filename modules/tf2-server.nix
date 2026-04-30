# modules/tf2-server.nix
#
# NixOS module for running one or more TF2 dedicated-server instances
# inside Podman containers via quadlet-nix.
#
# Uses the RFC 42 settings pattern (attrsOf submodule) so that each
# server instance is declared as:
#
#   services.tf2Server.pugA = { enable = true; port = 27015; ... };
#   services.tf2Server.pugB = { enable = true; port = 27025; ... };
#
{ config, lib, pkgs, ... }:

let
  cfg = config.services.tf2Server;

  # Only operate on servers that have enable = true.
  enabledServers = lib.filterAttrs (_: srv: srv.enable) cfg;

  # JSON format helper for generating config files.
  jsonFormat = pkgs.formats.json { };

  # Build the JSON config for a single server instance.
  serverConfigJson = name: srv:
    jsonFormat.generate "tf2-server-${name}-config.json" {
      serverName = srv.serverName;
      port = srv.port;
      tvPort = srv.tvPort;
      enableFakeIP = srv.enableFakeIP;
      hostname = srv.hostname;
      mapcycle = srv.mapcycle;
      map = srv.map;
      maxPlayers = srv.maxPlayers;
      managementPort = srv.managementPort;
      missPaulingUrl = srv.missPaulingUrl;
      rconPasswordFile = srv.rconPasswordFile;
      svPasswordFile = srv.svPasswordFile;
      demostfApiKeyFile = srv.demostfApiKeyFile;
      logstfApiKeyFile = srv.logstfApiKeyFile;
      logsTfUploaderSteamId = srv.logsTfUploaderSteamId;
      configsPath = toString srv.configs;
      pluginsPath = toString srv.plugins;
      mapsDir = srv.mapsDir;
      dataDir = srv.dataDir;
      extraArgs = srv.extraArgs;
    };

  # Collect all ports and management ports for conflict detection.
  allPorts =
    lib.mapAttrsToList (name: srv: { inherit name; port = srv.port; }) enabledServers;
  allTvPorts =
    lib.mapAttrsToList (name: srv: { inherit name; port = srv.tvPort; }) enabledServers;
  allMgmtPorts =
    lib.mapAttrsToList (name: srv: { inherit name; port = srv.managementPort; }) enabledServers;

  # Helper: find duplicate ports in a list of { name, port } attrsets.
  findDuplicates = entries:
    let
      grouped = lib.groupBy (e: toString e.port) entries;
      conflicts = lib.filterAttrs (_: v: builtins.length v > 1) grouped;
    in
    lib.mapAttrsToList
      (port: entries':
        "port ${port} is used by multiple servers: ${lib.concatMapStringsSep ", " (e: e.name) entries'}"
      )
      conflicts;

in
{
  # ---------------------------------------------------------------------------
  # Option interface
  # ---------------------------------------------------------------------------
  options.services.tf2Server = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule ({ name, config, ... }: {
      options = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether to enable this TF2 server instance.";
        };

        serverName = lib.mkOption {
          type = lib.types.str;
          default = name;
          description = "Display name for the server (defaults to the attribute name).";
        };

        port = lib.mkOption {
          type = lib.types.port;
          default = 27015;
          description = "UDP game port for the SRCDS instance.";
        };

        tvPort = lib.mkOption {
          type = lib.types.port;
          default = config.port + 5;
          defaultText = lib.literalExpression "port + 5";
          description = "SourceTV port (defaults to game port + 5).";
        };

        rconPasswordFile = lib.mkOption {
          type = lib.types.path;
          description = "Path to a file containing the RCON password (e.g. sops-nix secret).";
        };

        svPasswordFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = "Path to a file containing the server password, or null for no password.";
        };

        enableFakeIP = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether to enable Steam Datagram Relay FakeIP for this server.";
        };

        hostname = lib.mkOption {
          type = lib.types.str;
          description = "The hostname string shown in the TF2 server browser.";
        };

        configs = lib.mkOption {
          type = lib.types.package;
          description = "Derivation containing TF2 server configuration files.";
        };

        plugins = lib.mkOption {
          type = lib.types.package;
          description = "Derivation (typically a symlinkJoin) containing SourceMod plugins.";
        };

        mapcycle = lib.mkOption {
          type = lib.types.str;
          default = "mapcycle_pt_official.txt";
          description = "Name of the mapcycle file to use.";
        };

        map = lib.mkOption {
          type = lib.types.str;
          default = "pass_arena2_b10";
          description = "Initial map to load when the server starts.";
        };

        maxPlayers = lib.mkOption {
          type = lib.types.int;
          default = 9;
          description = "Maximum number of player slots (including SourceTV).";
        };

        managementPort = lib.mkOption {
          type = lib.types.port;
          default = config.port + 100;
          defaultText = lib.literalExpression "port + 100";
          description = "HTTP port for the wrapper sidecar management API.";
        };

        missPaulingUrl = lib.mkOption {
          type = lib.types.str;
          default = "http://127.0.0.1:8000";
          description = "URL of the Miss Pauling bot API.";
        };

        demostfApiKeyFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = "Path to a file containing the demos.tf API key, or null to disable.";
        };

        logstfApiKeyFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = "Path to a file containing the logs.tf API key, or null to disable.";
        };

        logsTfUploaderSteamId = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Steam ID used as the uploader identity for logs.tf submissions.";
        };

        extraArgs = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Extra command-line arguments passed to the SRCDS binary.";
        };

        mapsDir = lib.mkOption {
          type = lib.types.str;
          default = "/var/lib/tf2/maps";
          description = "Path to the shared maps directory.";
        };

        dataDir = lib.mkOption {
          type = lib.types.str;
          default = "/var/lib/tf2/${name}/data";
          defaultText = lib.literalExpression ''"/var/lib/tf2/''${name}/data"'';
          description = "Per-server data directory for demos, logs, etc.";
        };
      };
    }));
    default = { };
    description = "Attribute set of TF2 dedicated-server instances to run.";
  };

  # ---------------------------------------------------------------------------
  # Implementation
  # ---------------------------------------------------------------------------
  config = lib.mkIf (enabledServers != { }) {

    # -- Assertions: detect port conflicts -----------------------------------
    assertions =
      let
        portConflicts = findDuplicates allPorts;
        tvPortConflicts = findDuplicates allTvPorts;
        mgmtConflicts = findDuplicates allMgmtPorts;

        # Also check for cross-category overlaps (game vs TV vs mgmt).
        allUsedPorts = allPorts ++ allTvPorts ++ allMgmtPorts;
        crossConflicts = findDuplicates allUsedPorts;
      in
      (map (msg: { assertion = false; message = "tf2Server: game ${msg}"; }) portConflicts)
      ++ (map (msg: { assertion = false; message = "tf2Server: TV ${msg}"; }) tvPortConflicts)
      ++ (map (msg: { assertion = false; message = "tf2Server: management ${msg}"; }) mgmtConflicts)
      ++ (map (msg: { assertion = false; message = "tf2Server: cross-category ${msg}"; }) crossConflicts);

    # -- Config JSON files ---------------------------------------------------
    environment.etc = lib.mapAttrs'
      (name: srv:
        lib.nameValuePair "tf2-servers/${name}/config.json" {
          source = serverConfigJson name srv;
        }
      )
      enabledServers;

    # -- Data directories ----------------------------------------------------
    systemd.tmpfiles.rules =
      lib.mapAttrsToList
        (name: srv: "d ${srv.dataDir} 0750 root root - -")
        enabledServers
      ++ [ "d /var/lib/tf2/maps 0755 root root - -" ];

    # -- TODO: Podman quadlet containers (Phase 2) ---------------------------
    # The quadlet-nix container definitions will be added here once the
    # tf2-server-wrapper container image is built (Issue #X, Phase 2).
    # Each enabled server will get a virtualisation.quadlet.containers.<name>
    # definition with appropriate port mappings, volume mounts, and the
    # config.json bind-mounted into the container.

    # -- Pending restart check timers ----------------------------------------
    systemd.services = lib.mapAttrs'
      (name: srv:
        lib.nameValuePair "tf2-restart-check-${name}" {
          description = "Check for pending restart of TF2 server ${name}";
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${pkgs.bash}/bin/bash -c 'echo \"checking restart for ${name}\"'";
          };
        }
      )
      enabledServers;

    systemd.timers = lib.mapAttrs'
      (name: srv:
        lib.nameValuePair "tf2-restart-check-${name}" {
          description = "Periodic restart check for TF2 server ${name}";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnActiveSec = "60s";
            OnUnitActiveSec = "60s";
            AccuracySec = "5s";
          };
        }
      )
      enabledServers;
  };
}
