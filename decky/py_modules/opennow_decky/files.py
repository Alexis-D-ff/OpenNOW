import json
import os
import shutil
from pathlib import Path
from typing import Any


def read_json(path: Path) -> Any | None:
    try:
        with open(path, encoding="utf-8") as handle:
            return json.load(handle)
    except (OSError, ValueError):
        return None


def write_json_atomic(path: Path, value: Any, keep_backup: bool = False) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".tmp")
    with open(temporary, "w", encoding="utf-8") as handle:
        json.dump(value, handle, indent=2, ensure_ascii=False)
        handle.flush()
        os.fsync(handle.fileno())
    if keep_backup and read_json(path) is not None:
        backup = path.with_name(path.name + ".bak")
        shutil.copyfile(path, backup)
    os.replace(temporary, path)
