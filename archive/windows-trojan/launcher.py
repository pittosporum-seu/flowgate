import os
import subprocess
import sys
import zipfile
from pathlib import Path


APP_NAME = "TrojanSubVPN"


def bundled_path(name: str) -> Path:
    base = Path(getattr(sys, "_MEIPASS", Path(__file__).resolve().parent))
    return base / name


def main() -> int:
    local_appdata = os.environ.get("LOCALAPPDATA")
    if not local_appdata:
        print("LOCALAPPDATA is not set.")
        input("Press Enter to exit...")
        return 1

    install_dir = Path(local_appdata) / APP_NAME
    payload_zip = bundled_path("payload.zip")
    script_path = install_dir / "app" / "TrojanSubVPN.ps1"

    try:
        install_dir.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(payload_zip, "r") as archive:
            archive.extractall(install_dir)
    except Exception as exc:
        print(f"Failed to unpack {APP_NAME}: {exc}")
        input("Press Enter to exit...")
        return 1

    if not script_path.exists():
        print(f"Startup script was not found: {script_path}")
        input("Press Enter to exit...")
        return 1

    command = [
        "powershell.exe",
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        str(script_path),
    ]
    try:
        return subprocess.call(command, cwd=str(install_dir))
    except KeyboardInterrupt:
        return 130
    except Exception as exc:
        print(f"Failed to start PowerShell menu: {exc}")
        input("Press Enter to exit...")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
