# pugs-tf

NixOS monorepo for the **4v4 PASS Time Europe** TF2 community ([pugs.tf](https://pugs.tf)).

Manages two TF2 dedicated game servers, a unified FastAPI web application, server configs, SourceMod plugins, and the infrastructure glue that ties them together -- all declared in Nix and self-deployed via GitOps.

## Architecture

```
Proxmox VPS (moria)
└── NixOS VM (tf2)
    ├── Podman containers (quadlet-nix)
    │   ├── pugA (TF2 + SourceMod + SDR)  :27015
    │   └── pugB (TF2 + SourceMod + SDR)  :27016
    ├── Miss_Pauling (native systemd service)  :8000
    │   ├── pugs.tf (website + Steam auth + admin panel)
    │   └── fastdl.pugs.tf (FastDL file server)
    ├── nginx (reverse proxy + Let's Encrypt SSL)
    ├── comin (GitOps self-deploy from GitHub)
    └── sops-nix (encrypted secrets at rest)
```

### Key flows

**Config changes (push to deploy):**
A git push to `main` is picked up by comin (polls every 60s). comin runs `nixos-rebuild switch`, which rebuilds the system. The post-deploy hook then sets a `pending-restart` flag on each TF2 server wrapper. A systemd timer checks every 60 seconds -- when a flagged server has zero players, it gracefully shuts down and systemd restarts it with the new config.

**Temporary deploys:**
Pushing to the `testing-tf2` branch triggers a `nixos-rebuild test` -- the change takes effect immediately but reverts on the next reboot.

**Plugin updates:**
nvfetcher can be used to automatically check upstream plugin sources for new versions. Updated hashes are committed, comin picks up the change, and the servers rebuild with the new plugin derivations.

**Server self-registration:**
Each TF2 container runs a Python wrapper sidecar (`tf2-server-wrapper`) that exposes a management API on `port + 100`. On startup it registers itself with Miss Pauling's server registry so the web app knows which servers exist, their ports, and their SDR FakeIP addresses.

**SDR FakeIP tracking:**
Servers run with `+sv_enablefakeip 1`. The wrapper polls RCON for the assigned FakeIP and reports it to Miss Pauling, which displays connection info on the website.

## Repository structure

```
pugs-tf/
├── flake.nix                    # Flake inputs and outputs (the entry point)
├── flake.lock                   # Pinned dependency versions
├── CLAUDE.md                    # AI assistant / developer quick-reference
├── .sops.yaml                   # sops-nix key configuration
│
├── hosts/
│   └── tf2/                     # NixOS host configuration
│       ├── default.nix          # Top-level: imports, server + Miss Pauling declarations
│       ├── comin.nix            # GitOps: branch config, post-deploy restart hook
│       ├── firewall.nix         # UFW rules derived from declared server ports
│       ├── nginx.nix            # Reverse proxy + ACME SSL for pugs.tf / fastdl.pugs.tf
│       ├── podman.nix           # Container runtime setup + auto-prune
│       └── secrets.nix          # sops-nix secret declarations
│
├── modules/
│   ├── tf2-server.nix           # NixOS module: TF2 server instances (quadlet containers)
│   └── miss-pauling.nix         # NixOS module: Miss Pauling web app (systemd service)
│
├── lib/
│   ├── helpers.nix              # fetchSourceModPlugin* helper functions
│   ├── configs/
│   │   ├── default.nix          # Derivation that packages the config tree
│   │   └── tf/                  # Raw TF2 config files (cfg/, addons/)
│   │       ├── cfg/             # Server configs, exec files, whitelists
│   │       └── addons/          # SourceMod config files
│   └── plugins/
│       ├── default.nix          # symlinkJoin combining all active plugins
│       ├── logstf.nix           # Individual plugin derivations...
│       ├── demostf.nix
│       ├── p4sstime.nix
│       ├── soap.nix
│       └── ...                  # (16 plugins total)
│
├── packages/
│   ├── miss-pauling/            # Python web app (FastAPI + uvicorn)
│   │   ├── pyproject.toml
│   │   ├── uv.lock
│   │   └── src/miss_pauling/
│   │       ├── main.py          # ASGI dispatcher (routes by Host header)
│   │       ├── config.py        # Settings from /etc/miss-pauling/config.json
│   │       ├── website/         # pugs.tf: Steam auth, servers, admin panel
│   │       ├── fastdl/          # fastdl.pugs.tf: map downloads, TF2 version API
│   │       └── shared/          # Database models, repositories
│   │
│   ├── tf2-server-wrapper/      # Python sidecar for each TF2 container
│   │   ├── pyproject.toml
│   │   ├── uv.lock
│   │   └── src/tf2_server_wrapper/
│   │       ├── main.py          # Starts SRCDS + management API
│   │       ├── api.py           # HTTP endpoints: /status, /pending-restart, /shutdown
│   │       ├── srcds.py         # SRCDS process + RCON interface
│   │       ├── registration.py  # Self-registration with Miss Pauling
│   │       └── config.py        # Reads /tf2/config.json
│   │
│   └── tf2-container/           # Container image definition
│       ├── Containerfile        # Multi-stage: SteamCMD -> TF2 -> MetaMod -> SourceMod
│       └── entrypoint.sh        # Links configs/plugins/maps into TF2 tree, starts wrapper
│
└── secrets/
    ├── secrets.example.yaml     # Template showing expected secret keys
    └── secrets.yaml             # Encrypted secrets (committed; decrypted by sops-nix)
```

## Prerequisites

- **Nix** with flakes enabled (`nix.settings.experimental-features = [ "nix-command" "flakes" ]`)
- **A Proxmox VPS** (or any x86_64 Linux host capable of running NixOS)
- **GitHub account** for the repository (comin pulls from GitHub)
- **Domain names** `pugs.tf` and `fastdl.pugs.tf` with DNS A records pointing to the server

## Quick start (development)

```bash
git clone https://github.com/GoodGuyGroves/pugs-tf.git
cd pugs-tf
nix develop

# Validate the flake
nix flake check
nix flake show

# Build packages (requires x86_64-linux or cross-compilation)
nix build .#configs
nix build .#plugins
nix build .#plugin-logstf   # individual plugin

# Dry-run the full NixOS configuration
nix build .#nixosConfigurations.tf2.config.system.build.toplevel --dry-run
```

## Testing locally

### Miss Pauling (web app)

```bash
cd packages/miss-pauling
uv sync

# Run in development mode (binds to localhost:8000)
uv run python -m miss_pauling.main
```

The app routes by `Host` header: requests to `localhost` or `127.0.0.1` go to the website app, requests with `Host: fastdl.pugs.tf` go to FastDL. In development without the NixOS config JSON, you may need to set the `MISS_PAULING_CONFIG_PATH` environment variable or create a local settings file.

### Server registration API

```bash
# Check server status (wrapper management API)
curl http://127.0.0.1:27115/status

# Set pending restart flag
curl -X POST http://127.0.0.1:27115/pending-restart

# Trigger graceful shutdown
curl -X POST http://127.0.0.1:27115/shutdown
```

Management ports default to game port + 100 (pugA: 27115, pugB: 27116).

### TF2 server wrapper

```bash
cd packages/tf2-server-wrapper
uv sync

# The wrapper expects to be run inside the container with /tf2/config.json present.
# For local testing, create a config.json and set TF2_SERVER_CONFIG_PATH:
export TF2_SERVER_CONFIG_PATH=/path/to/test-config.json
uv run python -m tf2_server_wrapper
```

## Deployment guide

### 1. Provision a NixOS VM

Install NixOS on your host (Proxmox VM, bare metal, or cloud). A minimal installation is sufficient -- this flake declares everything else.

- Install NixOS from the minimal ISO or use [nixos-anywhere](https://github.com/nix-community/nixos-anywhere)
- Configure SSH access (ensure `sshd` is enabled)
- Note the host's SSH ed25519 public key

### 2. Configure secrets

Derive an age public key from the server's SSH host key:

```bash
nix-shell -p ssh-to-age --run \
  'ssh-keyscan -t ed25519 <server-ip> 2>/dev/null | ssh-to-age'
```

Update `.sops.yaml` with the real age public key (replace the placeholder).

Create and encrypt the secrets file:

```bash
cp secrets/secrets.example.yaml secrets/secrets.yaml
# Fill in real values
sops -e -i secrets/secrets.yaml
```

Remove `secrets/secrets.yaml` from `.gitignore` and commit the encrypted file. sops-nix decrypts it at NixOS activation time using the host's SSH key.

### 3. Initial deploy

The first deploy must be pushed to the server manually since comin is not yet running.

```bash
# Option A: nixos-rebuild over SSH
nixos-rebuild switch --flake .#tf2 \
  --target-host root@<server-ip> \
  --build-host localhost

# Option B: Colmena (if you have it configured)
colmena apply --on tf2
```

### 4. Build and load the TF2 container image

On the server:

```bash
cd /path/to/pugs-tf/packages/tf2-container
podman build -t tf2-server:latest .
```

This downloads SteamCMD, installs TF2 (app 232250), MetaMod:Source, and SourceMod into the image. The build takes several minutes on first run.

### 5. Enable comin (automatic from here)

comin is configured in `hosts/tf2/comin.nix` and starts automatically after the initial deploy. From this point forward, all changes are deployed by pushing to the `main` branch on GitHub.

Verify comin is running:

```bash
systemctl status comin
journalctl -u comin -f
```

### 6. Verify

```bash
# Check services
systemctl status miss-pauling
systemctl status nginx

# Check containers
podman ps

# Check comin
systemctl status comin

# Check the website
curl -s https://pugs.tf | head -20
```

## Adding a new server

To add a `pugC` server:

1. **Declare the server** in `hosts/tf2/default.nix`:

   ```nix
   services.tf2Server.pugC = {
     enable = true;
     port = 27017;
     hostname = "pugs.tf pugC";
     enableFakeIP = true;
     configs = self.packages.x86_64-linux.configs;
     plugins = self.packages.x86_64-linux.plugins;
     rconPasswordFile = config.sops.secrets."pugC_rcon_password".path;
     svPasswordFile = config.sops.secrets."sv_password".path;
     demostfApiKeyFile = config.sops.secrets."demostf_api_key".path;
     logstfApiKeyFile = config.sops.secrets."logstf_api_key".path;
     mapsDir = "/var/lib/tf2/maps";
   };
   ```

2. **Add the RCON secret** to `hosts/tf2/secrets.nix`:

   ```nix
   "pugC_rcon_password" = {};
   ```

3. **Add the secret value** to `secrets/secrets.yaml`:

   ```bash
   sops secrets/secrets.yaml
   # Add: pugC_rcon_password: "your-rcon-password"
   ```

4. **Commit and push** -- comin deploys automatically.

The firewall, Miss Pauling server registry, and comin restart hook all derive their configuration from the declared servers, so they update automatically.

## Updating plugins

### Automatic (nvfetcher)

nvfetcher can be configured to periodically check upstream sources for new plugin versions, update the hashes in `lib/plugins/`, and commit the changes. comin then deploys the update.

### Manual

1. Find the new download URL and compute the hash:

   ```bash
   nix-prefetch-url --unpack <new-url>
   ```

2. Edit the plugin file in `lib/plugins/<name>.nix` -- update `version`, `url`, and `hash`.

3. Verify the build:

   ```bash
   nix build .#plugin-<name>
   ```

4. Commit and push.

### Adding a new plugin

1. Create `lib/plugins/<name>.nix` using the appropriate helper:

   - `fetchSourceModPluginZip` -- standard zip with SourceMod sub-directories at root
   - `fetchSourceModPluginSmx` -- single pre-compiled `.smx` file
   - `fetchSourceModPluginZipFlat` -- zip with `.smx` files directly at root (e.g. krus.dk plugins)
   - `fetchSourceModPluginZipNested` -- zip with `addons/sourcemod/` prefix
   - `fetchSourceModPluginTarNested` -- tar.gz with `addons/sourcemod/` prefix

2. Add the plugin to `flake.nix` in the `packages.x86_64-linux` set:

   ```nix
   plugin-<name> = import ./lib/plugins/<name>.nix { inherit pkgs helpers; };
   ```

3. Include it in the combined `plugins` derivation in `lib/plugins/default.nix`.

4. Build and test:

   ```bash
   nix build .#plugin-<name>
   ls result/addons/sourcemod/plugins/
   ```

## Secrets management

Secrets are managed with [sops-nix](https://github.com/Mic92/sops-nix). The encrypted `secrets/secrets.yaml` is committed to git and decrypted at NixOS activation time.

**How it works:**
- `.sops.yaml` at the repo root defines which age keys can decrypt which files
- The server's SSH ed25519 host key is converted to an age key for decryption
- sops-nix declares secrets in `hosts/tf2/secrets.nix`; each appears at `/run/secrets/<name>` after activation
- NixOS modules reference these paths (e.g. `config.sops.secrets."pugA_rcon_password".path`)

**Current secrets:**

| Secret | Used by |
|---|---|
| `discord_client_secret` | Miss Pauling (OAuth2) |
| `discord_token` | Miss Pauling (bot) |
| `steam_api_key` | Miss Pauling (Steam Web API) |
| `api_secret_key` | Miss Pauling (JWT signing) |
| `pugA_rcon_password` | TF2 server pugA |
| `pugB_rcon_password` | TF2 server pugB |
| `sv_password` | Server join password (shared) |
| `demostf_api_key` | demos.tf uploads |
| `logstf_api_key` | logs.tf uploads |

**Adding a new secret:**

1. Edit the encrypted file: `sops secrets/secrets.yaml`
2. Declare it in `hosts/tf2/secrets.nix`:
   ```nix
   "my_new_secret" = {};
   ```
3. Reference it in the relevant module via `config.sops.secrets."my_new_secret".path`
4. Commit and push.

**Rotating a secret:**

1. `sops secrets/secrets.yaml` -- change the value
2. Commit and push -- comin deploys, sops-nix decrypts the new value, services restart.

## Troubleshooting

### comin is not deploying

```bash
# Check comin status and logs
systemctl status comin
journalctl -u comin -f

# Common causes:
# - Repository URL changed or went private (check hosts/tf2/comin.nix)
# - Nix evaluation error in the flake (test with: nix flake check)
# - Network connectivity issue
```

### TF2 server container won't start

```bash
# Check quadlet container status
podman ps -a
systemctl status pugA.service

# Check container logs
podman logs pugA

# Verify the image exists
podman images | grep tf2-server

# Common causes:
# - Container image not built yet (run podman build)
# - Secret file not available (check sops-nix: ls /run/secrets/)
# - Port conflict (the module validates this at eval time)
```

### Miss Pauling is not responding

```bash
# Check the service
systemctl status miss-pauling
journalctl -u miss-pauling -f

# Check nginx is proxying correctly
systemctl status nginx
curl -H "Host: pugs.tf" http://127.0.0.1:8000/

# Common causes:
# - Package not wired in yet (check services.missPauling.package)
# - Config JSON missing (check /etc/miss-pauling/config.json)
# - Database migration needed
```

### Servers stuck in "pending restart"

```bash
# Check the restart timer
systemctl status tf2-restart-check-pugA.timer
systemctl status tf2-restart-check-pugA.service

# Manually check the wrapper status
curl http://127.0.0.1:27115/status

# Force a restart (bypasses graceful wait)
podman restart pugA
```

### SSL certificate issues

```bash
# Check ACME status
systemctl status acme-pugs.tf
journalctl -u acme-pugs.tf

# Renew manually
systemctl start acme-pugs.tf
```
