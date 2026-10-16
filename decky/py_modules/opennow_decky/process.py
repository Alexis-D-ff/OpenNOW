import os
import signal
import time
from pathlib import Path

LOCK_NAME = "core.lock"


def process_name(pid: int, proc: str = "/proc") -> str:
    try:
        with open(f"{proc}/{pid}/comm", encoding="utf-8") as handle:
            return handle.read().strip()
    except OSError:
        return ""


def parent_pid(pid: int, proc: str = "/proc") -> int | None:
    try:
        with open(f"{proc}/{pid}/stat", encoding="utf-8") as handle:
            stat = handle.read()
    except OSError:
        return None
    fields = stat[stat.rfind(")") + 2:].split()
    return int(fields[1]) if len(fields) > 1 and fields[1].isdigit() else None


def lock_holder(data_dir: Path, locks_path: str = "/proc/locks", proc: str = "/proc") -> int | None:
    try:
        status = os.stat(data_dir / LOCK_NAME)
        with open(locks_path, encoding="ascii") as handle:
            lines = handle.read().splitlines()
    except OSError:
        return None
    device = f"{os.major(status.st_dev):02x}:{os.minor(status.st_dev):02x}"
    for line in lines:
        fields = line.split()
        if len(fields) < 6 or "->" in fields or fields[1] != "FLOCK" or not fields[4].isdigit():
            continue
        lock_device, _, inode = fields[5].rpartition(":")
        if inode != str(status.st_ino):
            continue
        pid = int(fields[4])
        if lock_device.lower() == device or process_name(pid, proc).startswith("opennow"):
            return pid
    return None


def alive(pid: int) -> bool:
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    return process_name(pid) != "" and not zombie(pid)


def zombie(pid: int) -> bool:
    try:
        with open(f"/proc/{pid}/stat", encoding="utf-8") as handle:
            stat = handle.read()
    except OSError:
        return False
    return stat[stat.rfind(")") + 2:].startswith("Z")


def stop(pid: int, grace_seconds: float = 5.0, poll_seconds: float = 0.1) -> bool:
    try:
        os.kill(pid, signal.SIGTERM)
    except ProcessLookupError:
        return False
    deadline = time.monotonic() + grace_seconds
    while time.monotonic() < deadline:
        if not alive(pid):
            return True
        time.sleep(poll_seconds)
    try:
        os.kill(pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    return True


def terminate(data_dir: Path, grace_seconds: float = 5.0) -> bool:
    core = lock_holder(data_dir)
    if core is None:
        return False
    app = parent_pid(core)
    return stop(app if app and process_name(app).startswith("opennow") else core, grace_seconds)
