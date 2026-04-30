"""
Backward-compatible config wrapper for FastDL.

All configuration now lives in miss_pauling.config.  This module re-exports
the unified settings and provides the snake_case attribute names that
existing FastDL code expects.
"""

from __future__ import annotations

from typing import Any

from miss_pauling.config import (
    Settings as _UnifiedSettings,
    FastDLServerConfig as ServerConfig,
    get_settings as _get_unified_settings,
)


class _FastDLSettingsProxy:
    """Thin proxy that adapts the unified Settings to the interface
    expected by existing FastDL code."""

    def __init__(self, unified: _UnifiedSettings) -> None:
        object.__setattr__(self, "_unified", unified)

    # -- FastDL servers (legacy list) ----------------------------------------
    @property
    def servers(self) -> list[ServerConfig]:
        return self._unified.fastdl_servers

    @property
    def maps_dir(self) -> str:
        return self._unified.maps_dir

    @property
    def allowed_map_extensions(self) -> list[str]:
        return self._unified.allowed_map_extensions

    @property
    def max_map_file_size(self) -> int:
        return self._unified.max_map_file_size

    @property
    def mapcycles(self) -> list[str]:
        return self._unified.mapcycles

    @property
    def cors_origins(self) -> list[str]:
        return self._unified.cors_origins

    @property
    def cors_methods(self) -> list[str]:
        return self._unified.cors_methods

    @property
    def cors_headers(self) -> list[str]:
        return self._unified.cors_headers

    @property
    def allowed_hosts(self) -> list[str]:
        return self._unified.allowed_hosts

    @property
    def website_base_url(self) -> str:
        return self._unified.website_base_url

    # -- Fallthrough for anything else ---------------------------------------
    def __getattr__(self, name: str) -> Any:
        return getattr(self._unified, name)

    def __repr__(self) -> str:
        return (
            f"FastDLSettings(maps_dir={self.maps_dir!r}, "
            f"servers={len(self.servers)}, "
            f"mapcycles={self.mapcycles!r})"
        )


# ---------------------------------------------------------------------------
# Public API (matches the old module interface)
# ---------------------------------------------------------------------------

Settings = _UnifiedSettings


def load_settings() -> _FastDLSettingsProxy:
    return _FastDLSettingsProxy(_get_unified_settings())


def get_settings() -> _FastDLSettingsProxy:
    return _FastDLSettingsProxy(_get_unified_settings())


settings = get_settings()
