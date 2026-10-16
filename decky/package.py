import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent
NAME = "OpenNOW"
FILES = ["plugin.json", "package.json", "main.py", "LICENSE", "README.md", "dist/index.js"]


def package() -> Path:
    if not (ROOT / "dist/index.js").exists():
        raise SystemExit("Run the build first")
    output = ROOT / "out" / f"{NAME}.zip"
    output.parent.mkdir(exist_ok=True)
    modules = [path for path in (ROOT / "py_modules").rglob("*.py")]
    with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as archive:
        for path in [ROOT / name for name in FILES] + modules:
            archive.write(path, f"{NAME}/{path.relative_to(ROOT)}")
    return output


if __name__ == "__main__":
    print(package())
