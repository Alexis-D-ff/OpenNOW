import platform
import subprocess

from . import host
from .install import version_key
from .net import http_json

LATEST_RELEASE = "https://api.github.com/repos/OpenCloudGaming/OpenNOW/releases/latest"
RECENT_RELEASES = "https://api.github.com/repos/OpenCloudGaming/OpenNOW/releases?per_page=30"
ARCHITECTURES = {"x86_64": "x64", "amd64": "x64", "aarch64": "arm64", "arm64": "arm64"}
GITHUB_JSON = {"Accept": "application/vnd.github+json"}


def device_machine() -> str:
    try:
        result = host.run(["flatpak", "--default-arch"], timeout=15)
    except (OSError, subprocess.SubprocessError):
        return platform.machine()
    return (result.returncode == 0 and result.stdout.strip()) or platform.machine()


def fetch_latest(nightly: bool = False, timeout: float = 20) -> dict:
    if not nightly:
        return http_json(LATEST_RELEASE, headers=GITHUB_JSON, timeout=timeout)
    release = latest_nightly(http_json(RECENT_RELEASES, headers=GITHUB_JSON, timeout=timeout))
    if not release:
        raise ValueError("No nightly with a Flatpak for this device has been published")
    return release


def latest_nightly(releases: list, machine: str | None = None) -> dict | None:
    machine = machine or device_machine()
    return next((release for release in releases
                 if release.get("prerelease") and not release.get("draft")
                 and "-nightly." in (release.get("tag_name") or "")
                 and flatpak_asset(release, machine)), None)


def flatpak_asset(release: dict, machine: str | None = None) -> dict | None:
    arch = ARCHITECTURES.get((machine or device_machine()).lower())
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
        "installedVersionKnown": bool(installed_version),
        "updateAvailable": bool(installed_version) and version_key(version) > version_key(installed_version),
    }
