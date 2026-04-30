"""
Unified configuration for Miss Pauling.

Reads from a Nix-generated JSON config file in production (via MISS_PAULING_CONFIG_PATH)
and falls back to the legacy settings.json files for development.

Secrets are read from file paths in production (sops-nix), or from environment
variables / .env in development.
"""

import json
import os
from functools import lru_cache
from pathlib import Path
from typing import Any

from pydantic import BaseModel, SecretStr, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

# ---------------------------------------------------------------------------
# Package directory (miss_pauling/)
# ---------------------------------------------------------------------------
_PACKAGE_DIR = Path(__file__).resolve().parent


# ---------------------------------------------------------------------------
# Sub-models
# ---------------------------------------------------------------------------


class TF2ServerConfig(BaseModel):
    """TF2 server info as provided by the Nix module."""

    serverName: str = ""
    port: int = 27015
    tvPort: int = 27020
    managementPort: int = 27115
    enableFakeIP: bool = False
    hostname: str = ""
    managementUrl: str = ""


class DatabaseConfig(BaseModel):
    """Database configuration."""

    type: str = "sqlite"
    path: str = "../db/sqlite.db"


class FastDLServerConfig(BaseModel):
    """Legacy FastDL per-server config (dev settings.json only)."""

    name: str
    tf_dir: str


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _read_secret_file(path: str | None) -> str | None:
    """Read the contents of a secret file, stripping trailing whitespace."""
    if path is None:
        return None
    p = Path(path)
    if not p.is_file():
        return None
    return p.read_text().strip()


def _load_nix_json(path: str) -> dict[str, Any]:
    """Load and flatten the Nix-generated camelCase JSON into snake_case keys
    that match our Settings field names."""
    with open(path, encoding="utf-8") as f:
        raw: dict[str, Any] = json.load(f)

    # Map camelCase keys from the Nix JSON to our Settings field names.
    key_map: dict[str, str] = {
        "port": "port",
        "host": "host",
        "domain": "domain",
        "fastdlDomain": "fastdl_domain",
        "environment": "environment",
        "workers": "workers",
        "discordApplicationId": "discord_application_id",
        "discordPublicKey": "discord_public_key",
        "discordClientSecretFile": "discord_client_secret_file",
        "discordTokenFile": "discord_token_file",
        "steamApiKeyFile": "steam_api_key_file",
        "apiSecretKeyFile": "api_secret_key_file",
        "database": "database",
        "mapsDir": "maps_dir",
        "tf2Servers": "tf2_servers",
        "logsTfUploaderSteamId": "logs_tf_uploader_steam_id",
    }

    mapped: dict[str, Any] = {}
    for nix_key, settings_key in key_map.items():
        if nix_key in raw:
            mapped[settings_key] = raw[nix_key]

    return mapped


def _load_dev_settings() -> dict[str, Any]:
    """Load the two legacy dev settings.json files and merge them into a
    single dict whose keys match Settings field names."""
    merged: dict[str, Any] = {}

    # -- Website settings --
    website_json = _PACKAGE_DIR / "website_settings.json"
    if website_json.is_file():
        with open(website_json, encoding="utf-8") as f:
            raw = json.load(f)

        # Map legacy UPPER_CASE keys to new field names.
        legacy_map: dict[str, str] = {
            "DISCORD_APPLICATION_ID": "discord_application_id",
            "DISCORD_PUBLIC_KEY": "discord_public_key",
            "DISCORD_CALLBACK_URL": "discord_callback_url",
            "STEAM_OPENID_REALM": "steam_openid_realm",
            "STEAM_OPENID_CALLBACK_URL": "steam_openid_callback_url",
            "LOGS_TF_UPLOADER_STEAM_ID": "logs_tf_uploader_steam_id",
            "SYSTEMD_SERVICES": "systemd_services",
        }

        for old_key, new_key in legacy_map.items():
            if old_key in raw:
                merged[new_key] = raw[old_key]

        # TF2_SERVERS: convert legacy list-of-dicts to dict keyed by name
        if "TF2_SERVERS" in raw:
            servers_dict: dict[str, dict[str, Any]] = {}
            server_dirs: dict[str, str] = {}
            for srv in raw["TF2_SERVERS"]:
                name = srv["name"]
                servers_dict[name] = {
                    "serverName": name,
                    "port": srv.get("port", 27015),
                    "hostname": srv.get("host", ""),
                }
                if "dir" in srv:
                    server_dirs[name] = srv["dir"]
            merged["tf2_servers"] = servers_dict
            if server_dirs:
                merged["legacy_server_dirs"] = server_dirs

    # -- FastDL settings --
    fastdl_json = _PACKAGE_DIR / "fastdl" / "settings.json"
    if fastdl_json.is_file():
        with open(fastdl_json, encoding="utf-8") as f:
            raw = json.load(f)

        fastdl_map: dict[str, str] = {
            "maps_dir": "maps_dir",
            "allowed_map_extensions": "allowed_map_extensions",
            "max_map_file_size": "max_map_file_size",
            "mapcycles": "mapcycles",
            "cors_origins": "cors_origins",
            "cors_methods": "cors_methods",
            "cors_headers": "cors_headers",
            "allowed_hosts": "allowed_hosts",
            "website_base_url": "website_base_url",
        }
        for old_key, new_key in fastdl_map.items():
            if old_key in raw:
                merged[new_key] = raw[old_key]

        # FastDL servers list (for mapcycle writes)
        if "servers" in raw:
            merged["fastdl_servers"] = raw["servers"]

    return merged


def _read_legacy_env_vars() -> dict[str, Any]:
    """Read legacy environment variable names that don't match our field names
    directly.  These are the old UPPER_CASE env vars from the previous config."""
    env_map: dict[str, str] = {
        # Old env var name -> new Settings field name
        "MISS_PAULING_API_SECRET_KEY": "api_secret_key",
        "STEAM_API_KEY": "steam_api_key",
        "DISCORD_CLIENT_SECRET": "discord_client_secret",
        "DISCORD_TOKEN": "discord_token",
    }
    result: dict[str, Any] = {}
    for env_name, field_name in env_map.items():
        val = os.environ.get(env_name)
        if val is not None:
            result[field_name] = val
    return result


# ---------------------------------------------------------------------------
# Settings class
# ---------------------------------------------------------------------------


class Settings(BaseSettings):
    """Unified settings for both the website and FastDL applications."""

    # -- General ---------------------------------------------------------------
    port: int = 8000
    host: str = "127.0.0.1"
    domain: str = "pugs.tf"
    fastdl_domain: str = "fastdl.pugs.tf"
    environment: str = "development"
    workers: int = 4

    # -- Auth (non-secret) -----------------------------------------------------
    discord_application_id: str = ""
    discord_public_key: str = ""

    # -- Auth (secrets) --------------------------------------------------------
    discord_client_secret: SecretStr = SecretStr("")
    discord_token: SecretStr = SecretStr("")
    steam_api_key: SecretStr = SecretStr("")
    api_secret_key: SecretStr = SecretStr("")

    # -- Secret file paths (set by Nix, read at init) --------------------------
    discord_client_secret_file: str | None = None
    discord_token_file: str | None = None
    steam_api_key_file: str | None = None
    api_secret_key_file: str | None = None

    # -- Database --------------------------------------------------------------
    database: DatabaseConfig = DatabaseConfig()

    # -- Maps ------------------------------------------------------------------
    maps_dir: str = "/var/lib/tf2/maps"

    # -- TF2 Servers (Nix: dict keyed by server name) --------------------------
    tf2_servers: dict[str, TF2ServerConfig] = {}

    # -- Legacy server dirs (dev only, maps server name -> dir path) -----------
    legacy_server_dirs: dict[str, str] = {}

    # -- logs.tf ---------------------------------------------------------------
    logs_tf_uploader_steam_id: str | None = None

    # -- FastDL specific -------------------------------------------------------
    allowed_map_extensions: list[str] = [".bsp"]
    max_map_file_size: int = 100  # MB
    mapcycles: list[str] = ["pt_official", "pt_all"]
    cors_origins: list[str] = ["*"]
    cors_methods: list[str] = ["GET", "POST", "HEAD"]
    cors_headers: list[str] = ["*"]
    allowed_hosts: list[str] = [
        "fastdl.pugs.tf", "www.pugs.tf", "pugs.tf", "localhost", "127.0.0.1",
    ]
    website_base_url: str = "http://localhost:8000"

    # -- FastDL legacy servers (dev only, for mapcycle file writes) -------------
    fastdl_servers: list[FastDLServerConfig] = []

    # -- Website CORS ----------------------------------------------------------
    website_cors_origins: list[str] = ["*"]
    website_cors_headers: list[str] = ["*"]
    website_cors_methods: list[str] = ["GET", "POST"]
    website_cors_credentials: bool = True

    # -- Session ---------------------------------------------------------------
    session_expiry_hours: int = 24 * 7  # 1 week

    # -- Systemd services (legacy, for admin log streaming) --------------------
    systemd_services: dict[str, Any] = {}

    # -- Steam OpenID (website auth) -------------------------------------------
    steam_openid_url: str = "https://steamcommunity.com/openid/login"
    steam_openid_realm: str = "http://localhost:8000"
    steam_openid_callback_url: str = "http://localhost:8000/auth/steam/callback"

    # -- Discord OAuth URLs (website auth) -------------------------------------
    discord_callback_url: str = "http://localhost:8000/auth/discord/callback"
    discord_oauth_url: str = "https://discord.com/api/oauth2/authorize"
    discord_token_url: str = "https://discord.com/api/oauth2/token"
    discord_api_url: str = "https://discord.com/api/v10"

    # -- DB (legacy compat) ----------------------------------------------------
    db_url: str | None = None

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
        case_sensitive=False,
    )

    @model_validator(mode="before")
    @classmethod
    def _load_config_sources(cls, data: dict[str, Any]) -> dict[str, Any]:
        """Load from Nix JSON or legacy dev settings.json files, then overlay
        with env vars and init kwargs."""
        config_path = os.environ.get("MISS_PAULING_CONFIG_PATH")

        if config_path and Path(config_path).is_file():
            base = _load_nix_json(config_path)
        else:
            base = _load_dev_settings()

        # Legacy env vars (old names that don't match new field names)
        legacy_env = _read_legacy_env_vars()
        base.update(legacy_env)

        # Values from data (pydantic-settings env parsing, init kwargs) win
        base.update({k: v for k, v in data.items() if v is not None})
        return base

    @model_validator(mode="after")
    def _resolve_secrets_from_files(self) -> "Settings":
        """Read secrets from file paths if the *_file fields are set."""
        file_to_secret = {
            "discord_client_secret_file": "discord_client_secret",
            "discord_token_file": "discord_token",
            "steam_api_key_file": "steam_api_key",
            "api_secret_key_file": "api_secret_key",
        }
        for file_field, secret_field in file_to_secret.items():
            file_path = getattr(self, file_field)
            value = _read_secret_file(file_path)
            if value:
                object.__setattr__(self, secret_field, SecretStr(value))
        return self

    @model_validator(mode="after")
    def _build_db_url(self) -> "Settings":
        """Generate the SQLAlchemy database URL from the database config."""
        db_type = self.database.type.lower()
        if db_type == "sqlite":
            if not self.database.path:
                raise ValueError(
                    "database.path is required when database.type is 'sqlite'"
                )
            self.db_url = f"sqlite:///{self.database.path}"
        elif db_type == "postgresql":
            if not self.db_url:
                raise ValueError(
                    "db_url is required when database.type is 'postgresql'"
                )
        else:
            raise ValueError(
                f"Unsupported database type: {db_type}. "
                "Supported types are 'sqlite' and 'postgresql'"
            )
        return self


# ---------------------------------------------------------------------------
# Backwards-compatible aliases (used by legacy imports)
# ---------------------------------------------------------------------------


class TF2Server(BaseModel):
    """Legacy TF2 server model for backward compatibility with the website."""

    name: str
    host: str = ""
    port: int = 27015
    dir: str = ""


# ---------------------------------------------------------------------------
# Singleton
# ---------------------------------------------------------------------------


@lru_cache()
def get_settings() -> Settings:
    """Return the singleton Settings instance."""
    return Settings()  # pyright: ignore[reportCallIssue]


settings = get_settings()


# ---------------------------------------------------------------------------
# Helper functions (backward-compatible)
# ---------------------------------------------------------------------------


def get_default_headers(s: Settings | None = None) -> dict[str, str]:
    """Return default headers for httpx requests."""
    return {"User-Agent": "FastAPI-Auth/1.0"}
