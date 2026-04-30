"""
Unified Miss Pauling ASGI application.

Routes requests based on the Host header:
- pugs.tf / www.pugs.tf -> website app
- fastdl.pugs.tf -> FastDL app
- localhost / 127.0.0.1 -> website app (development)
"""

import re
from typing import Optional

import uvicorn


# Host patterns for routing.
# Order matters: more specific patterns (subdomains) should come first.
_FASTDL_PATTERN = re.compile(r"^fastdl\.pugs\.tf(:\d+)?$")
_WEBSITE_PATTERN = re.compile(
    r"^(www\.)?pugs\.tf(:\d+)?$"
    r"|^localhost(:\d+)?$"
    r"|^127\.0\.0\.1(:\d+)?$"
)


def _get_host(scope: dict) -> Optional[str]:
    """Extract the Host header value from an ASGI scope."""
    headers = scope.get("headers", [])
    for name, value in headers:
        if name == b"host":
            return value.decode("latin-1")
    return None


async def app(scope: dict, receive, send) -> None:
    """
    Root ASGI application that dispatches to sub-apps based on Host header.

    For HTTP and WebSocket requests, the Host header determines which FastAPI
    sub-app handles the request. Lifespan events are forwarded to both apps.
    """
    if scope["type"] == "lifespan":
        # Forward lifespan to both sub-apps so they can run startup/shutdown hooks.
        # We run them sequentially to avoid interleaving issues.
        from miss_pauling.website.main import app as website_app
        from miss_pauling.fastdl.main import app as fastdl_app

        await _proxy_lifespan(scope, receive, send, [website_app, fastdl_app])
        return

    if scope["type"] in ("http", "websocket"):
        host = _get_host(scope)

        if host and _FASTDL_PATTERN.match(host):
            from miss_pauling.fastdl.main import app as fastdl_app

            await fastdl_app(scope, receive, send)
        else:
            # Default to website for pugs.tf, www.pugs.tf, localhost, or unknown hosts
            from miss_pauling.website.main import app as website_app

            await website_app(scope, receive, send)
        return

    # Unknown scope type — ignore
    return


async def _proxy_lifespan(scope, receive, send, apps):
    """
    Proxy lifespan events to multiple ASGI sub-apps.

    Sends startup to each app in order, then waits for shutdown and forwards it.
    """
    startup_complete = False

    async def child_receive():
        """Each child gets a synthetic startup event."""
        return {"type": "lifespan.startup"}

    async def child_send(message):
        nonlocal startup_complete
        if message["type"] == "lifespan.startup.complete":
            startup_complete = True

    # Wait for the real startup event
    message = await receive()
    if message["type"] != "lifespan.startup":
        return

    # Forward startup to each sub-app
    failed = False
    for sub_app in apps:
        startup_complete = False
        try:
            # Create a simple startup-only lifespan for each sub-app
            await _run_lifespan_startup(sub_app, scope)
        except Exception as e:
            print(f"Warning: lifespan startup failed for {sub_app}: {e}")
            failed = True

    if failed:
        await send({"type": "lifespan.startup.failed", "message": "Sub-app startup failed"})
        return

    await send({"type": "lifespan.startup.complete"})

    # Wait for shutdown
    message = await receive()
    if message["type"] == "lifespan.shutdown":
        # Run shutdown for each sub-app
        for sub_app in apps:
            try:
                await _run_lifespan_shutdown(sub_app, scope)
            except Exception as e:
                print(f"Warning: lifespan shutdown failed for {sub_app}: {e}")

        await send({"type": "lifespan.shutdown.complete"})


async def _run_lifespan_startup(sub_app, scope):
    """Run just the startup phase of a sub-app's lifespan."""
    import asyncio

    startup_done = asyncio.Event()
    result = {"failed": False}

    async def recv():
        return {"type": "lifespan.startup"}

    async def snd(message):
        if message["type"] in ("lifespan.startup.complete", "lifespan.startup.failed"):
            if message["type"] == "lifespan.startup.failed":
                result["failed"] = True
            startup_done.set()

    task = asyncio.create_task(sub_app(scope, recv, snd))

    # Store the task so we can use it during shutdown
    if not hasattr(sub_app, "_lifespan_task"):
        sub_app._lifespan_task = task  # type: ignore[attr-defined]

    await startup_done.wait()

    if result["failed"]:
        raise RuntimeError("Sub-app startup failed")


async def _run_lifespan_shutdown(sub_app, scope):
    """Send shutdown to a sub-app that's running its lifespan."""
    import asyncio

    task = getattr(sub_app, "_lifespan_task", None)
    if task and not task.done():
        task.cancel()
        try:
            await task
        except asyncio.CancelledError:
            pass


def main():
    """Entry point for the miss-pauling unified server."""
    uvicorn.run(
        "miss_pauling.main:app",
        host="0.0.0.0",
        port=8000,
        log_level="info",
    )


if __name__ == "__main__":
    main()
