import sys
import types
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "py_modules"))
sys.path.insert(0, str(ROOT))


def install_fake_decky(home: Path) -> types.ModuleType:
    module = types.ModuleType("decky")
    module.DECKY_USER_HOME = str(home)
    module.DECKY_PLUGIN_SETTINGS_DIR = str(home / "settings")
    module.DECKY_PLUGIN_RUNTIME_DIR = str(home / "runtime")
    module.DECKY_PLUGIN_VERSION = "0.0.0-test"
    module.DECKY_PLUGIN_LOG = str(home / "plugin.log")
    module.emitted = []

    async def emit(event, *args):
        module.emitted.append((event, args))

    module.emit = emit
    module.logger = types.SimpleNamespace(info=print, warning=print, error=print)
    sys.modules["decky"] = module
    return module
