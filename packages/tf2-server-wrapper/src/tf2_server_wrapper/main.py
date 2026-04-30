import asyncio
import signal
import logging

import uvicorn

from tf2_server_wrapper.config import load_config
from tf2_server_wrapper.srcds import SRCDSProcess
from tf2_server_wrapper.api import app as api_app, init as init_api
from tf2_server_wrapper.registration import MissPaulingClient

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(name)s] %(levelname)s: %(message)s")
logger = logging.getLogger("tf2-server-wrapper")


async def run():
    config = load_config()
    logger.info(f"Starting wrapper for server '{config.serverName}' on port {config.port}")

    # Initialize SRCDS process manager
    srcds = SRCDSProcess(config)

    # Initialize management API
    init_api(srcds, config)

    # Initialize Miss_Pauling client
    mp_client = MissPaulingClient(config.missPaulingUrl, config.serverName)

    # Set up graceful shutdown
    shutdown_event = asyncio.Event()

    def handle_signal():
        logger.info("Received shutdown signal")
        shutdown_event.set()

    loop = asyncio.get_event_loop()
    for sig in (signal.SIGTERM, signal.SIGINT):
        loop.add_signal_handler(sig, handle_signal)

    # Start management API server in background
    api_config = uvicorn.Config(api_app, host="0.0.0.0", port=config.managementPort, log_level="warning")
    api_server = uvicorn.Server(api_config)
    api_task = asyncio.create_task(api_server.serve())

    # Start SRCDS
    await srcds.start()

    # FakeIP callback -- register with Miss_Pauling when we get the FakeIP
    async def on_fakeip(ip: str, port: int):
        await mp_client.register(config.port, config.managementPort, ip, port)

    # Monitor SRCDS output in background
    monitor_task = asyncio.create_task(srcds.monitor_output(on_fakeip=on_fakeip))

    # If no FakeIP (direct mode), register immediately
    if not config.enableFakeIP:
        await mp_client.register(config.port, config.managementPort)

    # Start heartbeat loop
    def get_heartbeat_status() -> dict:
        return {
            "port": config.port,
            "management_port": config.managementPort,
            "fake_ip": srcds.fake_ip,
            "fake_port": srcds.fake_port,
            "player_count": 0,  # TODO: query via RCON or A2S
            "current_map": config.map,  # TODO: track map changes
        }

    await mp_client.start_heartbeat_loop(30, get_heartbeat_status)

    # Wait for either shutdown signal or SRCDS exit
    srcds_wait = asyncio.create_task(srcds.wait())
    shutdown_wait = asyncio.create_task(shutdown_event.wait())

    done, pending = await asyncio.wait(
        [srcds_wait, shutdown_wait],
        return_when=asyncio.FIRST_COMPLETED,
    )

    if shutdown_event.is_set():
        # Graceful shutdown requested
        await srcds.graceful_shutdown()
    else:
        # SRCDS exited on its own
        exit_code = srcds_wait.result()
        logger.info(f"SRCDS exited with code {exit_code}")

    # Cleanup
    await mp_client.deregister()
    await mp_client.stop()
    api_server.should_exit = True
    await api_task

    # Cancel remaining tasks
    for task in pending:
        task.cancel()
    monitor_task.cancel()

    logger.info("Wrapper shutdown complete")


def main():
    asyncio.run(run())


if __name__ == "__main__":
    main()
