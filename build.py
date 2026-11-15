#!/usr/bin/env python3
"""Pack module/ into an installable zip: dist/denylist_gui-<version>.zip

Usage: python build.py
- Paths inside the zip always use forward slashes (Windows-safe).
- Text files are normalised to LF line endings so shell scripts run on Android.
"""
import pathlib
import zipfile

ROOT = pathlib.Path(__file__).resolve().parent
SRC = ROOT / "module"
DIST = ROOT / "dist"
TEXT_SUFFIXES = {".sh", ".prop", ".html", ".js", ".css", ".json", ".txt", ""}


def read_prop(key: str) -> str:
    for line in (SRC / "module.prop").read_text(encoding="utf-8").splitlines():
        if line.startswith(key + "="):
            return line.split("=", 1)[1].strip()
    raise SystemExit(f"module.prop is missing '{key}'")


def main() -> None:
    mod_id, version = read_prop("id"), read_prop("version")
    DIST.mkdir(exist_ok=True)
    out = DIST / f"{mod_id}-{version}.zip"
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for f in sorted(p for p in SRC.rglob("*") if p.is_file()):
            data = f.read_bytes()
            if f.suffix in TEXT_SUFFIXES:
                data = data.replace(b"\r\n", b"\n")
            z.writestr(f.relative_to(SRC).as_posix(), data)
    print(f"built {out.relative_to(ROOT)} ({out.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
