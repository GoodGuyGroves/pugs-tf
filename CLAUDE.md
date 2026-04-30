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
| `packages/miss-pauling/` | Miss Pauling Discord bot (Python, built with uv2nix) |
| `packages/tf2-server-wrapper/` | TF2 dedicated-server container wrapper |
| `lib/helpers.nix` | Shared Nix helpers (fetchSourceModPlugin, etc.) |
| `lib/configs/` | TF2 server configuration fragments |
| `lib/plugins/` | SourceMod plugin sources and build logic |
| `docs/` | Documentation |

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
