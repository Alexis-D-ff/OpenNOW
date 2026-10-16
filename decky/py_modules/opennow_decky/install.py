import glob
import os
import re
import subprocess
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Callable

from . import host

FLATPAK_ID = "io.github.opencloudgaming.OpenNOW"
NATIVE_PATHS = ("/usr/bin/opennow-qt", "/usr/local/bin/opennow-qt", "/opt/OpenNOW/bin/opennow-qt")
APPIMAGE_DIRS = ("Applications", "AppImages", "Downloads", "Desktop", ".local/bin", "")
APPIMAGE_VERSION = re.compile(r"OpenNOW(?:-Qt)?-(\d+\.\d+\.\d+(?:-(?:nightly|rc|beta|alpha)[0-9A-Za-z.]*)?)", re.IGNORECASE)

Runner = Callable[[list[str]], subprocess.CompletedProcess]


@dataclass(frozen=True)
class Install:
    kind: str
    path: str
    version: str | None
    revision: str | None
    exe: str
    args: tuple[str, ...]
    data_dir: str

    def to_dict(self) -> dict:
        value = asdict(self)
        value["args"] = list(self.args)
        return value


def run_quiet(command: list[str]) -> subprocess.CompletedProcess:
    return host.run(command, timeout=15)


def version_key(version: str | None) -> tuple:
    if not version:
        return ()
    core, _, suffix = version.partition("-")
    numbers = tuple(int(part) for part in core.split(".") if part.isdigit())
    nightly = [int(part) for part in re.findall(r"\d+", suffix)]
    return numbers + ((1,) if not suffix else (0, *nightly))


def native_data_dir(home: Path) -> Path:
    config = Path(os.environ.get("XDG_CONFIG_HOME") or home / ".config")
    primary = config / "OpenNOW"
    legacy = config / "opennow"
    if not primary.exists() and legacy.exists():
        return legacy
    return primary


def flatpak_data_dir(home: Path) -> Path:
    return home / ".var" / "app" / FLATPAK_ID / "config" / "OpenNOW"


def detect_flatpak(home: Path, run: Runner) -> Install | None:
    for scope in ("--user", "--system"):
        try:
            result = run(["flatpak", "info", scope, FLATPAK_ID])
        except (OSError, subprocess.SubprocessError):
            return None
        if result.returncode != 0:
            continue
        fields = {}
        for line in result.stdout.splitlines():
            key, _, value = line.strip().partition(":")
            fields[key] = value.strip()
        return Install(
            kind="flatpak",
            path=FLATPAK_ID,
            version=fields.get("Version") or None,
            revision=fields.get("Commit") or None,
            exe="/usr/bin/flatpak",
            args=("run", scope, FLATPAK_ID),
            data_dir=str(flatpak_data_dir(home)),
        )
    return None


def appimage_version(path: str) -> str | None:
    match = APPIMAGE_VERSION.search(os.path.basename(path))
    return match.group(1) if match else None


def detect_appimage(home: Path) -> Install | None:
    candidates = []
    for directory in APPIMAGE_DIRS:
        pattern = str(home / directory / "*.AppImage")
        candidates.extend(
            path for path in glob.glob(pattern)
            if "opennow" in os.path.basename(path).lower() and os.access(path, os.X_OK)
        )
    if not candidates:
        return None
    newest = max(candidates, key=lambda path: (version_key(appimage_version(path)), os.path.getmtime(path)))
    return appimage_install(newest, home)


def appimage_install(path: str, home: Path) -> Install:
    return Install(
        kind="appimage",
        path=path,
        version=appimage_version(path),
        revision=None,
        exe=path,
        args=(),
        data_dir=str(native_data_dir(home)),
    )


def detect_native(home: Path) -> Install | None:
    for path in NATIVE_PATHS:
        if os.access(path, os.X_OK):
            return Install(kind="native", path=path, version=None, revision=None, exe=path, args=(), data_dir=str(native_data_dir(home)))
    return None


def custom_install(path: str, home: Path) -> Install | None:
    if not os.path.isfile(path) or not os.access(path, os.X_OK):
        return None
    if path.lower().endswith(".appimage"):
        return appimage_install(path, home)
    return Install(kind="custom", path=path, version=None, revision=None, exe=path, args=(), data_dir=str(native_data_dir(home)))


def detect(home: Path, custom_path: str = "", run: Runner | None = None) -> Install | None:
    if custom_path:
        return custom_install(custom_path, home)
    return detect_flatpak(home, run or run_quiet) or detect_appimage(home) or detect_native(home)
