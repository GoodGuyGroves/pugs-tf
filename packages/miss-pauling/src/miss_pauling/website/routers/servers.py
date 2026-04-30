"""Server management API endpoints.

TF2 server wrappers call these endpoints to register, send heartbeats, and
check for pending restarts.  The ``/connect/{name}`` endpoint provides a
user-facing redirect to the best available ``steam://connect`` URL.
"""

from __future__ import annotations

import logging

from fastapi import APIRouter, HTTPException
from fastapi.responses import RedirectResponse
from pydantic import BaseModel

from miss_pauling.website.services.server_registry import (
    RegisteredServer,
    registry,
)

logger = logging.getLogger(__name__)

router = APIRouter(tags=["Servers"])


# ---------------------------------------------------------------------------
# Request / response models
# ---------------------------------------------------------------------------


class RegisterRequest(BaseModel):
    name: str
    port: int
    managementPort: int
    managementUrl: str
    fakeIp: str | None = None
    fakePort: int | None = None


class HeartbeatRequest(BaseModel):
    playerCount: int = 0
    currentMap: str = ""
    fakeIp: str | None = None
    fakePort: int | None = None


class PendingRestartResponse(BaseModel):
    name: str
    pendingRestart: bool


class ServerListEntry(BaseModel):
    """Lightweight view returned by the list endpoint."""

    name: str
    port: int
    player_count: int
    current_map: str
    online: bool
    pending_restart: bool
    connect_url: str | None
    fake_ip: str | None = None
    fake_port: int | None = None


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------


@router.post("/api/servers/register", response_model=RegisteredServer)
async def register_server(body: RegisterRequest) -> RegisteredServer:
    """Register a TF2 server (called by the wrapper on startup)."""
    try:
        server = registry.register(
            name=body.name,
            port=body.port,
            management_port=body.managementPort,
            management_url=body.managementUrl,
            fake_ip=body.fakeIp,
            fake_port=body.fakePort,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    return server


@router.post(
    "/api/servers/{name}/heartbeat", response_model=RegisteredServer
)
async def server_heartbeat(name: str, body: HeartbeatRequest) -> RegisteredServer:
    """Periodic status update from a TF2 server wrapper."""
    try:
        server = registry.heartbeat(
            name=name,
            player_count=body.playerCount,
            current_map=body.currentMap,
            fake_ip=body.fakeIp,
            fake_port=body.fakePort,
        )
    except KeyError as exc:
        raise HTTPException(status_code=404, detail=str(exc))
    return server


@router.post(
    "/api/servers/{name}/pending-restart",
    response_model=PendingRestartResponse,
)
async def set_pending_restart(name: str) -> PendingRestartResponse:
    """Mark a server for graceful restart when it becomes empty."""
    if not registry.set_pending_restart(name):
        raise HTTPException(status_code=404, detail=f"Server '{name}' not found")
    return PendingRestartResponse(name=name, pendingRestart=True)


@router.get(
    "/api/servers/{name}/pending-restart",
    response_model=PendingRestartResponse,
)
async def get_pending_restart(name: str) -> PendingRestartResponse:
    """Check whether a server has a pending restart."""
    server = registry.get(name)
    if server is None:
        raise HTTPException(status_code=404, detail=f"Server '{name}' not found")
    return PendingRestartResponse(name=name, pendingRestart=server.pending_restart)


@router.delete(
    "/api/servers/{name}/pending-restart",
    response_model=PendingRestartResponse,
)
async def clear_pending_restart(name: str) -> PendingRestartResponse:
    """Clear the pending restart flag for a server."""
    if not registry.clear_pending_restart(name):
        raise HTTPException(status_code=404, detail=f"Server '{name}' not found")
    return PendingRestartResponse(name=name, pendingRestart=False)


@router.get(
    "/api/servers/{name}/status", response_model=RegisteredServer
)
async def get_server_status(name: str) -> RegisteredServer:
    """Get detailed status for a single server."""
    server = registry.get(name)
    if server is None:
        raise HTTPException(status_code=404, detail=f"Server '{name}' not found")
    return server


@router.delete("/api/servers/{name}", status_code=204)
async def deregister_server(name: str) -> None:
    """Deregister a server (called by the wrapper on shutdown)."""
    registry.deregister(name)


@router.get("/api/servers", response_model=list[ServerListEntry])
async def list_servers() -> list[ServerListEntry]:
    """List all registered servers with lightweight status info."""
    entries: list[ServerListEntry] = []
    for name, server in registry.get_all().items():
        entries.append(
            ServerListEntry(
                name=server.name,
                port=server.port,
                player_count=server.player_count,
                current_map=server.current_map,
                online=server.online,
                pending_restart=server.pending_restart,
                connect_url=registry.get_connect_url(name),
                fake_ip=server.fake_ip,
                fake_port=server.fake_port,
            )
        )
    return entries


@router.get("/connect/{name}")
async def connect_redirect(name: str) -> RedirectResponse:
    """Redirect to the best available ``steam://connect`` URL for a server."""
    url = registry.get_connect_url(name)
    if url is None:
        raise HTTPException(status_code=404, detail=f"Server '{name}' not found")
    return RedirectResponse(url=url)
