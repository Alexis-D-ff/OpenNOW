import json
import ssl
import urllib.request
from typing import Any
from urllib.parse import urlparse

USER_AGENT = "OpenNOW-Decky"


class HostError(ValueError):
    pass


def ssl_context() -> ssl.SSLContext:
    try:
        import certifi
        return ssl.create_default_context(cafile=certifi.where())
    except ImportError:
        return ssl.create_default_context()


def require_host(url: str, hosts: tuple[str, ...]) -> None:
    parsed = urlparse(url)
    if parsed.scheme != "https" or parsed.hostname not in hosts:
        raise HostError(f"Refusing to contact {parsed.hostname or url}")


def open_url(url: str, body: dict | None = None, headers: dict | None = None, timeout: float = 30):
    data = None if body is None else json.dumps(body).encode()
    request = urllib.request.Request(url, data=data, headers={
        "User-Agent": USER_AGENT,
        **({"Content-Type": "application/json"} if body is not None else {}),
        **(headers or {}),
    })
    return urllib.request.urlopen(request, timeout=timeout, context=ssl_context())


def http_json(url: str, body: dict | None = None, headers: dict | None = None, timeout: float = 30) -> Any:
    with open_url(url, body, {"Accept": "application/json", **(headers or {})}, timeout) as response:
        return json.load(response)
