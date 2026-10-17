import json
import os
import shutil
import signal
import subprocess
from pathlib import Path
from threading import Event, Timer
from typing import Callable

from . import host
from .install import FLATPAK_ID
from .net import open_url, require_host

DOWNLOAD_HOSTS = ("github.com", "objects.githubusercontent.com", "release-assets.githubusercontent.com")
FLATHUB = "https://dl.flathub.org/repo/flathub.flatpakrepo"
DROIDDECK_FLATPAK = "/usr/local/bin/droiddeck-flatpak"
INSTALL_TIMEOUT = 3600
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


def run_checked(command: list[str], message: str, timeout: float = 60) -> None:
    try:
        result = host.run(command, timeout=timeout)
    except subprocess.TimeoutExpired:
        raise InstallError(f"{message}: Flatpak didn't finish within {timeout:.0f} seconds") from None
    if result.returncode != 0:
        detail = (result.stderr or result.stdout).strip().splitlines()
        raise InstallError(f"{message}: {detail[-1] if detail else f'exit {result.returncode}'}")


def install_with_droiddeck(bundle: Path, progress: Progress) -> None:
    error = None
    expired = Event()
    with subprocess.Popen([DROIDDECK_FLATPAK, "install-bundle", str(bundle)], stdout=subprocess.PIPE,
                          stderr=subprocess.DEVNULL, text=True, env=host.host_environment(),
                          start_new_session=True) as child:
        watchdog = Timer(INSTALL_TIMEOUT, lambda: (expired.set(), os.killpg(child.pid, signal.SIGKILL)))
        watchdog.start()
        try:
            for line in child.stdout:
                try:
                    event = json.loads(line)
                except ValueError:
                    continue
                if event.get("e") == "progress":
                    steps = max(int(event.get("n") or 1), 1)
                    done = max(int(event.get("i") or 1) - 1, 0) + float(event.get("percent") or 0) / 100
                    progress("install", min(done / steps, 1.0))
                elif event.get("e") == "error":
                    error = event.get("message")
        finally:
            watchdog.cancel()
    if expired.is_set():
        raise InstallError(f"Flatpak couldn't install OpenNOW: it didn't finish within {INSTALL_TIMEOUT} seconds")
    if child.returncode != 0:
        raise InstallError(f"Flatpak couldn't install OpenNOW: {error or f'exit {child.returncode}'}")


def install_bundle(url: str, size: int, work_dir: Path, progress: Progress, cancelled: Event) -> None:
    bundle = work_dir / "OpenNOW.flatpak"
    try:
        download(url, bundle, size, progress, cancelled)
        if cancelled.is_set():
            raise Cancelled("Install cancelled")
        progress("install", 0.0)
        droiddeck = os.access(DROIDDECK_FLATPAK, os.X_OK)
        if not shutil.which("flatpak", path=host.host_environment().get("PATH")):
            raise InstallError("Set up Flatpak in DroidDeck's Store first" if droiddeck else "Flatpak isn't installed")
        run_checked(["flatpak", "remote-add", "--user", "--if-not-exists", "flathub", FLATHUB],
                    "Couldn't add Flathub for the KDE runtime")
        if droiddeck and host.run(["flatpak", "info", "--user", FLATPAK_ID], timeout=60).returncode != 0:
            install_with_droiddeck(bundle, progress)
        else:
            run_checked(["flatpak", "install", "--user", "--noninteractive", "-y", "--reinstall", str(bundle)],
                        "Flatpak couldn't install OpenNOW", timeout=INSTALL_TIMEOUT)
        run_checked(["flatpak", "info", "--user", FLATPAK_ID], "OpenNOW isn't installed after the Flatpak step")
        progress("install", 1.0)
    finally:
        bundle.unlink(missing_ok=True)
        bundle.with_name(bundle.name + ".part").unlink(missing_ok=True)
