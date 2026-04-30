from pydantic import BaseModel
from pathlib import Path
import json
import os


class ServerConfig(BaseModel):
    serverName: str
    port: int
    tvPort: int
    enableFakeIP: bool
    hostname: str
    mapcycle: str
    map: str
    maxPlayers: int
    managementPort: int
    missPaulingUrl: str
    rconPasswordFile: str
    svPasswordFile: str | None = None
    demostfApiKeyFile: str | None = None
    logstfApiKeyFile: str | None = None
    logsTfUploaderSteamId: str | None = None
    configsPath: str
    pluginsPath: str
    mapsDir: str
    dataDir: str
    extraArgs: list[str] = []


def load_config() -> ServerConfig:
    config_path = os.environ.get("TF2_SERVER_CONFIG_PATH", "/etc/tf2-servers/default/config.json")
    with open(config_path) as f:
        return ServerConfig(**json.load(f))


def read_secret(path: str | None) -> str | None:
    if path is None:
        return None
    return Path(path).read_text().strip()
