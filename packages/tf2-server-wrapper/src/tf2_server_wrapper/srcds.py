import asyncio
import re
import logging

from tf2_server_wrapper.config import ServerConfig

logger = logging.getLogger(__name__)

FAKEIP_PATTERN = re.compile(r"FakeIP(?:\s+allocation\s+succeeded)?.*?(\d+\.\d+\.\d+\.\d+):(\d+)")


class SRCDSProcess:
    def __init__(self, config: ServerConfig):
        self.config = config
        self.process: asyncio.subprocess.Process | None = None
        self.fake_ip: str | None = None
        self.fake_port: int | None = None
        self._running = False

    def build_command(self) -> list[str]:
        cmd = [
            "./srcds_run",
            "-game", "tf",
            "-port", str(self.config.port),
            "+tv_port", str(self.config.tvPort),
            "+maxplayers", str(self.config.maxPlayers),
            "+map", self.config.map,
            "-norestart",  # we handle restarts ourselves
        ]
        if self.config.enableFakeIP:
            cmd.append("-enablefakeip")
        cmd.extend(self.config.extraArgs)
        return cmd

    async def start(self):
        """Start SRCDS and monitor its output."""
        cmd = self.build_command()
        logger.info(f"Starting SRCDS: {' '.join(cmd)}")

        self.process = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.STDOUT,
            stdin=asyncio.subprocess.PIPE,
        )
        self._running = True

    async def monitor_output(self, on_fakeip=None):
        """Read SRCDS stdout line by line, looking for FakeIP and logging."""
        while self._running and self.process and self.process.stdout:
            line = await self.process.stdout.readline()
            if not line:
                break
            text = line.decode("utf-8", errors="replace").rstrip()
            logger.info(f"[SRCDS] {text}")

            # Check for FakeIP allocation
            match = FAKEIP_PATTERN.search(text)
            if match:
                self.fake_ip = match.group(1)
                self.fake_port = int(match.group(2))
                logger.info(f"FakeIP detected: {self.fake_ip}:{self.fake_port}")
                if on_fakeip:
                    await on_fakeip(self.fake_ip, self.fake_port)

    async def send_command(self, command: str):
        """Send a command to SRCDS stdin."""
        if self.process and self.process.stdin:
            self.process.stdin.write(f"{command}\n".encode())
            await self.process.stdin.drain()

    async def graceful_shutdown(self, timeout: int = 30):
        """Send quit to SRCDS and wait for it to exit."""
        logger.info("Initiating graceful shutdown...")
        self._running = False
        if self.process:
            await self.send_command("quit")
            try:
                await asyncio.wait_for(self.process.wait(), timeout=timeout)
                logger.info("SRCDS exited cleanly")
            except asyncio.TimeoutError:
                logger.warning(f"SRCDS didn't exit within {timeout}s, terminating")
                self.process.terminate()
                await self.process.wait()

    async def wait(self) -> int:
        """Wait for SRCDS to exit and return the exit code."""
        if self.process:
            return await self.process.wait()
        return -1
