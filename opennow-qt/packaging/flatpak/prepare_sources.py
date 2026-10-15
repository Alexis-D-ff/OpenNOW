import argparse
import base64
import json
from pathlib import Path
import re
import subprocess


ROOT = Path(__file__).resolve().parents[3]


def prepare_manifest(root, version, public_key):
    number = r"(0|[1-9][0-9]*)"
    if not re.fullmatch(rf"{number}\.{number}\.{number}(-(nightly|supporter)\.[1-9][0-9]*\.[1-9][0-9]*)?", version):
        raise ValueError("Expected a stable, nightly, or supporter build version")
    if public_key:
        key = base64.b64decode(public_key, validate=True)
        if len(key) != 32 or base64.b64encode(key).decode() != public_key:
            raise ValueError("Expected a canonical base64 Ed25519 public key")
    directory = root / "opennow-qt/packaging/flatpak"
    manifest = json.loads((directory / "io.github.opencloudgaming.OpenNOW.json").read_text())
    manifest["modules"][-1]["config-opts"].extend([
        f"-DOPENNOW_BUILD_VERSION={version}",
        f"-DOPENNOW_UPDATE_ED25519_PUBLIC_KEY={public_key}",
    ])
    destination = directory / "io.github.opencloudgaming.OpenNOW.generated.json"
    destination.write_text(json.dumps(manifest, indent=4) + "\n")
    return destination


def vendor_sources(root):
    destination = root / "build/flatpak/cargo"
    destination.mkdir(parents=True, exist_ok=True)
    result = subprocess.run(
        [
            "cargo", "vendor", "--locked", "--versioned-dirs",
            "--manifest-path", str(root / "native/opennow-core/Cargo.toml"),
            "--sync", str(root / "native/opennow-streamer/Cargo.toml"),
            "vendor",
        ],
        cwd=destination, check=True, text=True, stdout=subprocess.PIPE,
    )
    config = result.stdout.replace(
        'directory = "vendor"', 'directory = "/run/build/opennow/cargo/vendor"'
    )
    if config == result.stdout:
        raise ValueError("Cargo did not emit the expected vendor directory configuration")
    (destination / "config.toml").write_text(config)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Vendor both locked Rust workspaces for offline Flatpak builds")
    parser.add_argument("--version")
    parser.add_argument("--update-public-key", default="")
    args = parser.parse_args()
    if args.version:
        prepare_manifest(ROOT, args.version, args.update_public_key)
    vendor_sources(ROOT)
