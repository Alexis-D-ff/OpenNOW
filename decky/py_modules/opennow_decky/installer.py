import subprocess
from pathlib import Path
from threading import Event
from typing import Callable

from .install import FLATPAK_ID
from .net import open_url, require_host

DOWNLOAD_HOSTS = ("github.com", "objects.githubusercontent.com", "release-assets.githubusercontent.com")
FLATHUB = "https://dl.flathub.org/repo/flathub.flatpakrepo"
CHUNK = 256 * 1024

Progress = Callable[[str, float], None]


class InstallError(RuntimeError):
    pass


class Cancelled(InstallError):
    pass


def download(url: str, destination: Path, size: int, progress: Progress, cancelled: Event) -> None:
    require_host(url, DOWNLOAD_HOSTS)
    destination.parent.mkdir(parents=True, exist_ok=True)
    partial = destination.with_name(destination.name + ".part")
    received = 0
    with open_url(url, timeout=60) as response, open(partial, "wb") as handle:
        total = int(response.headers.get("Content-Length") or size or 0)
        while chunk := response.read(CHUNK):
            if cancelled.is_set():
                raise Cancelled("Install cancelled")
            handle.write(chunk)
            received += len(chunk)
            progress("download", min(received / total, 1.0) if total else 0.0)
    partial.replace(destination)


def run_checked(command: list[str], message: str) -> None:
    result = subprocess.run(command, capture_output=True, text=True, timeout=900, check=False)
    if result.returncode != 0:
        detail = (result.stderr or result.stdout).strip().splitlines()
        raise InstallError(f"{message}: {detail[-1] if detail else f'exit {result.returncode}'}")


def install_bundle(url: str, size: int, work_dir: Path, progress: Progress, cancelled: Event) -> None:
    bundle = work_dir / "OpenNOW.flatpak"
    try:
        download(url, bundle, size, progress, cancelled)
        if cancelled.is_set():
            raise Cancelled("Install cancelled")
        progress("install", 0.0)
        run_checked(["flatpak", "remote-add", "--user", "--if-not-exists", "flathub", FLATHUB],
                    "Couldn't add Flathub for the KDE runtime")
        run_checked(["flatpak", "install", "--user", "--noninteractive", "-y", "--reinstall", str(bundle)],
                    "Flatpak couldn't install OpenNOW")
        run_checked(["flatpak", "info", "--user", FLATPAK_ID], "OpenNOW isn't installed after the Flatpak step")
        progress("install", 1.0)
    finally:
        bundle.unlink(missing_ok=True)
        bundle.with_name(bundle.name + ".part").unlink(missing_ok=True)
