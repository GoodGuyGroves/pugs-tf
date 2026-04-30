from fastapi import FastAPI
from pydantic import BaseModel
from datetime import datetime

from tf2_server_wrapper.config import ServerConfig
from tf2_server_wrapper.srcds import SRCDSProcess

app = FastAPI(title="TF2 Server Wrapper", docs_url=None, redoc_url=None)

# These get set by main.py after initialization
_srcds: SRCDSProcess | None = None
_config: ServerConfig | None = None
_start_time: datetime | None = None
_pending_restart: bool = False


def init(srcds: SRCDSProcess, config: ServerConfig):
    global _srcds, _config, _start_time
    _srcds = srcds
    _config = config
    _start_time = datetime.utcnow()


class StatusResponse(BaseModel):
    serverName: str
    port: int
    fakeIp: str | None = None
    fakePort: int | None = None
    managementPort: int
    uptime: float  # seconds
    pendingRestart: bool
    playerCount: int


class ShutdownResponse(BaseModel):
    status: str
    serverName: str


class PendingRestartResponse(BaseModel):
    pendingRestart: bool
    serverName: str


@app.get("/health")
async def health():
    return {"status": "ok"}


@app.get("/status")
async def status() -> StatusResponse:
    uptime = (datetime.utcnow() - _start_time).total_seconds() if _start_time else 0
    return StatusResponse(
        serverName=_config.serverName,
        port=_config.port,
        fakeIp=_srcds.fake_ip if _srcds else None,
        fakePort=_srcds.fake_port if _srcds else None,
        managementPort=_config.managementPort,
        uptime=uptime,
        pendingRestart=_pending_restart,
        playerCount=0,  # TODO: query via RCON or A2S
    )


@app.post("/pending-restart")
async def set_pending_restart() -> PendingRestartResponse:
    global _pending_restart
    _pending_restart = True
    return PendingRestartResponse(pendingRestart=True, serverName=_config.serverName)


@app.get("/pending-restart")
async def get_pending_restart() -> PendingRestartResponse:
    return PendingRestartResponse(pendingRestart=_pending_restart, serverName=_config.serverName)


@app.delete("/pending-restart")
async def clear_pending_restart() -> PendingRestartResponse:
    global _pending_restart
    _pending_restart = False
    return PendingRestartResponse(pendingRestart=False, serverName=_config.serverName)


@app.post("/shutdown")
async def shutdown() -> ShutdownResponse:
    """Gracefully shutdown SRCDS. The container will auto-restart via Podman."""
    if _srcds:
        await _srcds.graceful_shutdown()
    return ShutdownResponse(status="shutting_down", serverName=_config.serverName)
