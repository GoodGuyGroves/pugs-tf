"""
Backward-compatible config wrapper for the website.

All configuration now lives in miss_pauling.config.  This module re-exports
the unified settings and provides UPPER_CASE property aliases so existing
website code continues to work without modification.
"""

from __future__ import annotations

from typing import Any

from pydantic import SecretStr

from miss_pauling.config import (
    Settings as _UnifiedSettings,
    TF2Server,
    get_default_headers,
    get_settings as _get_unified_settings,
)


class _WebsiteSettingsProxy:
    """Thin proxy that exposes the old UPPER_CASE attribute names by
    delegating to the unified Settings instance underneath."""

    def __init__(self, unified: _UnifiedSettings) -> None:
        object.__setattr__(self, "_unified", unified)

    # -- Secrets (UPPER_CASE) ------------------------------------------------
    @property
    def MISS_PAULING_API_SECRET_KEY(self) -> SecretStr:
        return self._unified.api_secret_key

    @property
    def STEAM_API_KEY(self) -> SecretStr:
        return self._unified.steam_api_key

    @property
    def DISCORD_CLIENT_SECRET(self) -> SecretStr:
        return self._unified.discord_client_secret

    @property
    def DISCORD_TOKEN(self) -> SecretStr:
        return self._unified.discord_token

    # -- Discord / Steam (non-secret) ----------------------------------------
    @property
    def DISCORD_APPLICATION_ID(self) -> str:
        return self._unified.discord_application_id

    @property
    def DISCORD_PUBLIC_KEY(self) -> str:
        return self._unified.discord_public_key

    @property
    def DISCORD_CALLBACK_URL(self) -> str:
        return self._unified.discord_callback_url

    @property
    def DISCORD_OAUTH_URL(self) -> str:
        return self._unified.discord_oauth_url

    @property
    def DISCORD_TOKEN_URL(self) -> str:
        return self._unified.discord_token_url

    @property
    def DISCORD_API_URL(self) -> str:
        return self._unified.discord_api_url

    @property
    def STEAM_OPENID_URL(self) -> str:
        return self._unified.steam_openid_url

    @property
    def STEAM_OPENID_REALM(self) -> str:
        return self._unified.steam_openid_realm

    @property
    def STEAM_OPENID_CALLBACK_URL(self) -> str:
        return self._unified.steam_openid_callback_url

    # -- CORS ----------------------------------------------------------------
    @property
    def MISS_PAULING_CORS_ORIGINS(self) -> list[str]:
        return self._unified.website_cors_origins

    @property
    def MISS_PAULING_CORS_HEADERS(self) -> list[str]:
        return self._unified.website_cors_headers

    @property
    def MISS_PAULING_CORS_METHODS(self) -> list[str]:
        return self._unified.website_cors_methods

    @property
    def MISS_PAULING_CORS_CREDENTIALS(self) -> bool:
        return self._unified.website_cors_credentials

    # -- Session -------------------------------------------------------------
    @property
    def MISS_PAULING_SESSION_EXPIRY_HOURS(self) -> int:
        return self._unified.session_expiry_hours

    # -- TF2 Servers (returns a list of legacy TF2Server objects) ------------
    @property
    def TF2_SERVERS(self) -> list[TF2Server]:
        servers: list[TF2Server] = []
        for name, srv in self._unified.tf2_servers.items():
            server_dir = self._unified.legacy_server_dirs.get(name, "")
            servers.append(
                TF2Server(
                    name=name,
                    host=srv.hostname,
                    port=srv.port,
                    dir=server_dir,
                )
            )
        return servers

    # -- logs.tf -------------------------------------------------------------
    @property
    def LOGS_TF_UPLOADER_STEAM_ID(self) -> str | None:
        return self._unified.logs_tf_uploader_steam_id

    # -- Systemd services (admin log streaming) ------------------------------
    @property
    def SYSTEMD_SERVICES(self) -> dict[str, Any]:
        return self._unified.systemd_services

    # -- DB ------------------------------------------------------------------
    @property
    def MISS_PAULING_DB_TYPE(self) -> str:
        return self._unified.database.type

    @property
    def MISS_PAULING_DB_PATH(self) -> str | None:
        return self._unified.database.path

    @property
    def MISS_PAULING_DB_URL(self) -> str | None:
        return self._unified.db_url

    # -- Environment ---------------------------------------------------------
    @property
    def environment(self) -> str:
        return self._unified.environment

    # -- Fallthrough for anything else ---------------------------------------
    def __getattr__(self, name: str) -> Any:
        return getattr(self._unified, name)


# ---------------------------------------------------------------------------
# Public API (matches the old module interface)
# ---------------------------------------------------------------------------

Settings = _UnifiedSettings


def get_settings() -> _WebsiteSettingsProxy:
    """Return the backward-compatible settings proxy."""
    return _WebsiteSettingsProxy(_get_unified_settings())


settings = get_settings()
