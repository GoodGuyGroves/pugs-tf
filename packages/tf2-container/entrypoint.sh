#!/usr/bin/env bash
# packages/tf2-container/entrypoint.sh
#
# Container entrypoint for the TF2 dedicated server.
# Prepares the runtime directory layout by linking in externally-mounted
# configs, plugins, maps, and data directories, then hands off to the
# Python wrapper process.

set -euo pipefail

TF2_DIR="/home/steam/tf2"
TF_DIR="${TF2_DIR}/tf"

# -----------------------------------------------------------------------------
# 1. Configs: symlink/copy from /tf2/configs into tf/cfg/ and tf/addons/
# -----------------------------------------------------------------------------
if [ -d /tf2/configs/cfg ]; then
    echo "[entrypoint] Linking config files from /tf2/configs/cfg/ -> ${TF_DIR}/cfg/"
    for f in /tf2/configs/cfg/*; do
        [ -e "$f" ] || continue
        target="${TF_DIR}/cfg/$(basename "$f")"
        ln -sf "$f" "$target"
    done
fi

if [ -d /tf2/configs/addons ]; then
    echo "[entrypoint] Linking addon configs from /tf2/configs/addons/ -> ${TF_DIR}/addons/"
    mkdir -p "${TF_DIR}/addons"
    for f in /tf2/configs/addons/*; do
        [ -e "$f" ] || continue
        target="${TF_DIR}/addons/$(basename "$f")"
        ln -sf "$f" "$target"
    done
fi

# -----------------------------------------------------------------------------
# 2. Plugins: symlink from /tf2/plugins into tf/addons/sourcemod/
# -----------------------------------------------------------------------------
if [ -d /tf2/plugins ]; then
    echo "[entrypoint] Linking plugins from /tf2/plugins/ -> ${TF_DIR}/addons/sourcemod/"
    SM_DIR="${TF_DIR}/addons/sourcemod"
    mkdir -p "${SM_DIR}/plugins" "${SM_DIR}/configs" "${SM_DIR}/translations" "${SM_DIR}/gamedata" "${SM_DIR}/extensions"

    # Link plugin .smx files
    if [ -d /tf2/plugins/plugins ]; then
        for f in /tf2/plugins/plugins/*.smx; do
            [ -e "$f" ] || continue
            ln -sf "$f" "${SM_DIR}/plugins/$(basename "$f")"
        done
    fi

    # Link plugin configs
    if [ -d /tf2/plugins/configs ]; then
        for f in /tf2/plugins/configs/*; do
            [ -e "$f" ] || continue
            ln -sf "$f" "${SM_DIR}/configs/$(basename "$f")"
        done
    fi

    # Link translations
    if [ -d /tf2/plugins/translations ]; then
        for f in /tf2/plugins/translations/*; do
            [ -e "$f" ] || continue
            ln -sf "$f" "${SM_DIR}/translations/$(basename "$f")"
        done
    fi

    # Link gamedata
    if [ -d /tf2/plugins/gamedata ]; then
        for f in /tf2/plugins/gamedata/*; do
            [ -e "$f" ] || continue
            ln -sf "$f" "${SM_DIR}/gamedata/$(basename "$f")"
        done
    fi

    # Link extensions
    if [ -d /tf2/plugins/extensions ]; then
        for f in /tf2/plugins/extensions/*; do
            [ -e "$f" ] || continue
            ln -sf "$f" "${SM_DIR}/extensions/$(basename "$f")"
        done
    fi
fi

# -----------------------------------------------------------------------------
# 3. Maps: link from /tf2/maps into tf/maps/
# -----------------------------------------------------------------------------
if [ -d /tf2/maps ]; then
    echo "[entrypoint] Linking maps from /tf2/maps/ -> ${TF_DIR}/maps/"
    for f in /tf2/maps/*.bsp; do
        [ -e "$f" ] || continue
        target="${TF_DIR}/maps/$(basename "$f")"
        # Only link if the map doesn't already exist (stock maps)
        [ -e "$target" ] || ln -sf "$f" "$target"
    done
fi

# -----------------------------------------------------------------------------
# 4. Data directories: ensure demos/logs dirs exist
# -----------------------------------------------------------------------------
echo "[entrypoint] Ensuring data directories exist in /tf2/data/"
mkdir -p /tf2/data/demos /tf2/data/logs /tf2/data/stv_demos

# Symlink data directories into the TF2 tree so the server writes there
ln -sfn /tf2/data/demos "${TF_DIR}/demos" 2>/dev/null || true
ln -sfn /tf2/data/logs "${TF_DIR}/logs" 2>/dev/null || true
ln -sfn /tf2/data/stv_demos "${TF_DIR}/stv_demos" 2>/dev/null || true

# -----------------------------------------------------------------------------
# 5. Hand off to the Python wrapper
# -----------------------------------------------------------------------------
echo "[entrypoint] Starting TF2 server wrapper..."
exec python3 -m tf2_server_wrapper
