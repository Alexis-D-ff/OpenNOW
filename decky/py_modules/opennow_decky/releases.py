import platform

from .install import version_key
from .net import http_json

LATEST_RELEASE = "https://api.github.com/repos/OpenCloudGaming/OpenNOW/releases/latest"
ARCHITECTURES = {"x86_64": "x64", "amd64": "x64", "aarch64": "arm64", "arm64": "arm64"}


def fetch_latest(timeout: float = 20) -> dict:
    return http_json(LATEST_RELEASE, headers={"Accept": "application/vnd.github+json"}, timeout=timeout)


def flatpak_asset(release: dict, machine: str | None = None) -> dict | None:
    arch = ARCHITECTURES.get((machine or platform.machine()).lower())
    if not arch:
        return None
    suffix = f"-Linux-{arch}.flatpak"
    for asset in release.get("assets") or []:
        name = asset.get("name") or ""
        if name.startswith("OpenNOW-Qt-") and name.endswith(suffix):
            return {"name": name, "url": asset.get("browser_download_url") or "", "size": int(asset.get("size") or 0)}
    return None


def summarize(release: dict, installed_version: str | None, machine: str | None = None) -> dict:
    version = str(release.get("tag_name") or "").removeprefix("v")
    return {
        "version": version,
        "asset": flatpak_asset(release, machine),
        "updateAvailable": bool(installed_version) and version_key(version) > version_key(installed_version),
    }
