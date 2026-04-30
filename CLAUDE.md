# pugs-tf

Monorepo for the **4v4 PASS Time Europe** TF2 community infrastructure.

## Architecture

- **NixOS** declarative system configuration
- **Podman** containers orchestrated with **quadlet-nix** (systemd-native container units)
- **comin** for GitOps: the server pulls this repo and rebuilds itself automatically
- **sops-nix** for encrypted secrets (Discord tokens, RCON passwords, etc.)
- **nix2container** for building OCI images without a Docker daemon

## Directory layout

| Path | Purpose |
|---|---|
| `hosts/tf2/` | NixOS host configuration for the TF2 server machine |
| `modules/` | Reusable NixOS modules (tf2-server, miss-pauling) |
| `packages/miss-pauling/` | Miss Pauling web app (Python/FastAPI, built with uv2nix) |
| `packages/tf2-server-wrapper/` | TF2 dedicated-server container wrapper sidecar |
| `packages/tf2-container/` | Containerfile + entrypoint for the TF2 server image |
| `lib/helpers.nix` | Shared Nix helpers (fetchSourceModPlugin*, etc.) |
| `lib/configs/` | TF2 server configuration fragments (cfg/, addons/) |
| `lib/plugins/` | SourceMod plugin sources and build logic |
| `secrets/` | Encrypted secrets (sops-nix) and example template |

## Common commands

```bash
# Enter the dev shell (Python, uv, Nix tools)
nix develop

# Validate flake syntax and evaluate all outputs
nix flake check

# Show all flake outputs
nix flake show

# Build a specific package (once packages are defined)
nix build .#<package-name>

# Evaluate the NixOS configuration (dry run)
nix build .#nixosConfigurations.tf2.config.system.build.toplevel --dry-run
```

## Running Miss Pauling locally

```bash
cd packages/miss-pauling
uv sync
uv run python -m miss_pauling.main
```

Miss Pauling runs a unified ASGI app on port 8000 that routes by `Host` header:
- `localhost` / `127.0.0.1` -> website app
- `fastdl.pugs.tf` -> FastDL app

In production the NixOS module generates `/etc/miss-pauling/config.json`; for local dev you can set `MISS_PAULING_CONFIG_PATH` to a local JSON file.

## Running the TF2 server wrapper locally

```bash
cd packages/tf2-server-wrapper
uv sync
export TF2_SERVER_CONFIG_PATH=/path/to/test-config.json
uv run python -m tf2_server_wrapper
```

The wrapper expects to run inside the TF2 container. For standalone testing, it needs a config JSON (see `modules/tf2-server.nix` for the schema) and won't be able to launch SRCDS unless the binary is available.

## Adding a new SourceMod plugin

1. Create `lib/plugins/<name>.nix` using the appropriate helper from `lib/helpers.nix`:
   - `fetchSourceModPluginZip` -- standard zip with SourceMod dirs at root
   - `fetchSourceModPluginSmx` -- single `.smx` file
   - `fetchSourceModPluginZipFlat` -- zip with `.smx` files at root (krus.dk style)
   - `fetchSourceModPluginZipNested` -- zip with `addons/sourcemod/` prefix
   - `fetchSourceModPluginTarNested` -- tar.gz with `addons/sourcemod/` prefix

2. Add the plugin to `flake.nix` under `packages.x86_64-linux`:
   ```nix
   plugin-<name> = import ./lib/plugins/<name>.nix { inherit pkgs helpers; };
   ```

3. Include it in the combined `plugins` derivation (`lib/plugins/default.nix`).

4. Build and verify:
   ```bash
   nix build .#plugin-<name>
   ls result/addons/sourcemod/plugins/
   ```

## Modifying server configs

Server configs live in `lib/configs/tf/`:
- `cfg/` -- exec configs, whitelists, server.cfg
- `addons/sourcemod/` -- SourceMod core configs, adminmenu, etc.

Changes are packaged into a derivation (`lib/configs/default.nix`) and bind-mounted read-only into each container at `/tf2/configs`. The entrypoint script symlinks them into the TF2 tree.

After editing, verify the configs build:
```bash
nix build .#configs
ls -R result/
```

## Key file locations for common tasks

| Task | File(s) |
|---|---|
| Add/remove a TF2 server | `hosts/tf2/default.nix`, `hosts/tf2/secrets.nix` |
| Change server settings (port, hostname, maxPlayers) | `hosts/tf2/default.nix` |
| Edit TF2 exec configs | `lib/configs/tf/cfg/` |
| Edit SourceMod configs | `lib/configs/tf/addons/sourcemod/` |
| Add/update a plugin | `lib/plugins/<name>.nix`, `lib/plugins/default.nix`, `flake.nix` |
| Add a new secret | `secrets/secrets.yaml`, `hosts/tf2/secrets.nix`, `.sops.yaml` |
| Change nginx/SSL config | `hosts/tf2/nginx.nix` |
| Change firewall rules | `hosts/tf2/firewall.nix` |
| Modify comin behavior | `hosts/tf2/comin.nix` |
| Change Miss Pauling settings | `hosts/tf2/default.nix` (NixOS options), `packages/miss-pauling/src/` (code) |
| Modify the container image | `packages/tf2-container/Containerfile`, `packages/tf2-container/entrypoint.sh` |
| Change the tf2-server NixOS module | `modules/tf2-server.nix` |
| Change the miss-pauling NixOS module | `modules/miss-pauling.nix` |
| Edit plugin fetch helpers | `lib/helpers.nix` |

## Secrets

Secrets are encrypted with sops-nix. Never commit unencrypted `secrets/secrets.yaml` (it is in `.gitignore` until encrypted). To edit:

```bash
sops secrets/secrets.yaml
```

Current secrets: `discord_client_secret`, `discord_token`, `steam_api_key`, `api_secret_key`, `pugA_rcon_password`, `pugB_rcon_password`, `sv_password`, `demostf_api_key`, `logstf_api_key`.

## Deployment

Changes to `main` are auto-deployed by comin (polls every 60s). Push to `testing-tf2` for temporary deploys that revert on reboot. After deploy, comin's post-deploy hook signals servers for graceful restart (waits for zero players before restarting).
