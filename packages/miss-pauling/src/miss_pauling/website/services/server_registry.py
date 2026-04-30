"""In-memory registry of TF2 servers.

Servers self-register via the API when they start up and send periodic
heartbeats.  State is ephemeral — lost on Miss Pauling restart and
re-populated by the next round of heartbeats from the server wrappers.
"""

from __future__ import annotations

import logging
from datetime import datetime, timezone

from pydantic import BaseModel

from miss_pauling.config import get_settings

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Models
# ---------------------------------------------------------------------------


class RegisteredServer(BaseModel):
    """Current state of a registered TF2 server."""

    name: str
    port: int
    management_port: int
    management_url: str
    fake_ip: str | None = None
    fake_port: int | None = None
    player_count: int = 0
    current_map: str = ""
    registered_at: datetime
    last_heartbeat: datetime
    pending_restart: bool = False
    online: bool = True


# ---------------------------------------------------------------------------
# Registry
# ---------------------------------------------------------------------------


class ServerRegistry:
    """In-memory registry of TF2 servers.  Servers self-register via the API."""

    def __init__(self) -> None:
        self._servers: dict[str, RegisteredServer] = {}

    # -- mutations ----------------------------------------------------------

    def register(
        self,
        name: str,
        port: int,
        management_port: int,
        management_url: str,
        fake_ip: str | None = None,
        fake_port: int | None = None,
    ) -> RegisteredServer:
        """Register or re-register a server.

        Validates *name* against the Nix-defined ``settings.tf2_servers``
        dictionary — only pre-configured servers may register.
        """
        settings = get_settings()
        if name not in settings.tf2_servers:
            raise ValueError(
                f"Unknown server '{name}'. "
                "Only servers defined in the Nix configuration can register."
            )

        now = datetime.now(timezone.utc)
        server = RegisteredServer(
            name=name,
            port=port,
            management_port=management_port,
            management_url=management_url,
            fake_ip=fake_ip,
            fake_port=fake_port,
            registered_at=now,
            last_heartbeat=now,
        )
        self._servers[name] = server
        logger.info("Server registered: %s (port %d)", name, port)
        return server

    def heartbeat(
        self,
        name: str,
        player_count: int = 0,
        current_map: str = "",
        fake_ip: str | None = None,
        fake_port: int | None = None,
    ) -> RegisteredServer:
        """Update server status from a heartbeat."""
        server = self._servers.get(name)
        if server is None:
            raise KeyError(f"Server '{name}' is not registered")

        server.player_count = player_count
        server.current_map = current_map
        server.last_heartbeat = datetime.now(timezone.utc)
        server.online = True

        # Update FakeIP if provided (may arrive after initial registration)
        if fake_ip is not None:
            server.fake_ip = fake_ip
        if fake_port is not None:
            server.fake_port = fake_port

        return server

    def deregister(self, name: str) -> None:
        """Remove a server from the registry."""
        removed = self._servers.pop(name, None)
        if removed:
            logger.info("Server deregistered: %s", name)

    # -- pending restart ----------------------------------------------------

    def set_pending_restart(self, name: str) -> bool:
        """Mark a server for graceful restart when empty.  Returns True on success."""
        server = self._servers.get(name)
        if server is None:
            return False
        server.pending_restart = True
        logger.info("Pending restart set for server: %s", name)
        return True

    def clear_pending_restart(self, name: str) -> bool:
        """Clear the pending restart flag.  Returns True on success."""
        server = self._servers.get(name)
        if server is None:
            return False
        server.pending_restart = False
        logger.info("Pending restart cleared for server: %s", name)
        return True

    # -- queries ------------------------------------------------------------

    def get(self, name: str) -> RegisteredServer | None:
        """Return a single server or ``None``."""
        return self._servers.get(name)

    def get_all(self) -> dict[str, RegisteredServer]:
        """Return all registered servers."""
        return dict(self._servers)

    def get_connect_url(self, name: str) -> str | None:
        """Return a ``steam://connect/`` URL for the given server.

        Prefers the SDR FakeIP when available; falls back to the real
        host/port from the Nix configuration.
        """
        server = self._servers.get(name)
        if server is None:
            return None

        # Prefer FakeIP (SDR) for better routing
        if server.fake_ip and server.fake_port:
            return f"steam://connect/{server.fake_ip}:{server.fake_port}"

        # Fall back to the Nix-configured hostname
        settings = get_settings()
        srv_cfg = settings.tf2_servers.get(name)
        if srv_cfg and srv_cfg.hostname:
            return f"steam://connect/{srv_cfg.hostname}:{server.port}"

        return f"steam://connect/localhost:{server.port}"


# ---------------------------------------------------------------------------
# Global singleton
# ---------------------------------------------------------------------------

registry = ServerRegistry()
