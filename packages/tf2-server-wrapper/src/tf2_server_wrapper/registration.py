import httpx
import asyncio
import logging
from collections.abc import Callable

logger = logging.getLogger(__name__)


class MissPaulingClient:
    def __init__(self, base_url: str, server_name: str):
        self.base_url = base_url.rstrip("/")
        self.server_name = server_name
        self._client = httpx.AsyncClient(timeout=10.0)
        self._heartbeat_task: asyncio.Task | None = None

    async def register(
        self,
        port: int,
        management_port: int,
        fake_ip: str | None = None,
        fake_port: int | None = None,
    ):
        """Register this server with Miss_Pauling."""
        try:
            resp = await self._client.post(
                f"{self.base_url}/api/servers/register",
                json={
                    "name": self.server_name,
                    "port": port,
                    "managementPort": management_port,
                    "managementUrl": f"http://127.0.0.1:{management_port}",
                    "fakeIp": fake_ip,
                    "fakePort": fake_port,
                },
            )
            if resp.status_code == 200:
                logger.info(f"Registered with Miss_Pauling at {self.base_url}")
            else:
                logger.warning(f"Registration returned {resp.status_code}: {resp.text}")
        except Exception as e:
            logger.warning(f"Failed to register with Miss_Pauling: {e}")

    async def heartbeat(
        self,
        port: int,
        management_port: int,
        fake_ip: str | None,
        fake_port: int | None,
        player_count: int = 0,
        current_map: str = "",
    ):
        """Send a heartbeat to Miss_Pauling."""
        try:
            resp = await self._client.post(
                f"{self.base_url}/api/servers/{self.server_name}/heartbeat",
                json={
                    "port": port,
                    "managementPort": management_port,
                    "fakeIp": fake_ip,
                    "fakePort": fake_port,
                    "playerCount": player_count,
                    "currentMap": current_map,
                },
            )
            if resp.status_code != 200:
                logger.debug(f"Heartbeat returned {resp.status_code}")
        except Exception as e:
            logger.debug(f"Heartbeat failed: {e}")

    async def deregister(self):
        """Deregister this server from Miss_Pauling."""
        try:
            await self._client.delete(f"{self.base_url}/api/servers/{self.server_name}")
            logger.info("Deregistered from Miss_Pauling")
        except Exception:
            pass  # Best-effort on shutdown

    async def start_heartbeat_loop(self, interval: int, get_status: Callable[[], dict]):
        """Start periodic heartbeat in the background."""

        async def loop():
            while True:
                await asyncio.sleep(interval)
                status = get_status()
                await self.heartbeat(**status)

        self._heartbeat_task = asyncio.create_task(loop())

    async def stop(self):
        if self._heartbeat_task:
            self._heartbeat_task.cancel()
        await self._client.aclose()
