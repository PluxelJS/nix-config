#!/usr/bin/env python3
"""Provision writable mise once, then install only missing global tools."""

import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

import tomlkit


def read_config(path):
    return tomlkit.parse(path.read_text()) if path.exists() else tomlkit.document()


def write_atomic(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as stream:
            stream.write(text)
        os.replace(name, path)
    finally:
        Path(name).unlink(missing_ok=True)


def seed_config(home, target, defaults, marker):
    if marker.exists():
        return
    config = read_config(target)
    tools = config.setdefault("tools", tomlkit.table())
    # Preserve host choices first, then import missing IDE tool declarations.
    # Never move install trees: scripts/venvs can embed their original paths.
    apps = home / ".var/app"
    configs = sorted(set([
        *apps.glob("com.jetbrains.*/config/mise/config.toml"),
        *apps.glob("com.jetbrains.*/home/.config/mise/config.toml"),
        *apps.glob("io.github.trumank.CodeStudio/home/.config/mise/config.toml"),
    ]))
    for path in configs:
        for tool, version in read_config(path).get("tools", {}).items():
            if tool not in tools:
                tools[tool] = version
                print(f"mise bootstrap: imported {tool} from {path}", flush=True)
            elif tools[tool] != version:
                print(f"mise bootstrap: keeping host choice for {tool}; original retained at {path}", flush=True)
    for tool, version in defaults.get("tools", {}).items():
        tools.setdefault(tool, version)
    settings = config.setdefault("settings", tomlkit.table())
    auto_update = defaults.get("settings", {}).get("self_update", {}).get("auto", True)
    settings.setdefault("self_update", tomlkit.table()).setdefault("auto", auto_update)
    backup = target.with_name(target.name + ".pre-shared-mise")
    if target.exists() and not backup.exists():
        shutil.copy2(target, backup)
    write_atomic(target, tomlkit.dumps(config))
    write_atomic(marker, "Shared mise initialized; subsequent choices remain user-owned.\n")


def ensure_binary(binary):
    if binary.is_file() and not binary.is_symlink() and os.access(binary, os.X_OK):
        return
    binary.parent.mkdir(parents=True, exist_ok=True)
    # Stage on the same filesystem so failed downloads never replace a binary.
    with tempfile.TemporaryDirectory(prefix=".mise-install-", dir=binary.parent) as staging:
        installer = Path(staging) / "install.sh"
        candidate = Path(staging) / "mise"
        subprocess.run(["curl", "--fail", "--silent", "--show-error", "--location",
                        "--retry", "3", "https://mise.run", "--output", str(installer)], check=True)
        env = os.environ | {"MISE_INSTALL_PATH": str(candidate), "MISE_INSTALL_MUSL": "1",
                            "MISE_INSTALL_HELP": "0"}
        subprocess.run(["sh", str(installer)], env=env, check=True)
        subprocess.run([str(candidate), "--version"], check=True)
        os.replace(candidate, binary)


def main():
    home = Path.home()
    binary = home / ".local/bin/mise"
    target = Path(os.environ["MISE_CONFIG_DIR"]) / "config.toml"
    marker = Path(os.environ["MISE_STATE_DIR"]) / "nix-bootstrap-v1"
    defaults = read_config(Path(sys.argv[1]))
    for variable in ("MISE_CONFIG_DIR", "MISE_DATA_DIR", "MISE_CACHE_DIR", "MISE_STATE_DIR"):
        Path(os.environ[variable]).mkdir(parents=True, exist_ok=True)
    ensure_binary(binary)
    seed_config(home, target, defaults, marker)
    # Avoid the checkout's project config and inherited project-specific flags.
    env = {key: value for key, value in os.environ.items()
           if not key.startswith("MISE_")}
    env.update({key: os.environ[key] for key in
                ("MISE_CONFIG_DIR", "MISE_DATA_DIR", "MISE_CACHE_DIR", "MISE_STATE_DIR")})
    env.update(MISE_GLOBAL_CONFIG_FILE=str(target), MISE_YES="1", MISE_SELF_UPDATE_AUTO="false")
    env["PATH"] = f"{binary.parent}:{env['MISE_DATA_DIR']}/shims:{env['PATH']}"
    with tempfile.TemporaryDirectory(prefix="mise-bootstrap-") as work:
        # Bare install retains already installed matching versions, unlike upgrade.
        subprocess.run([str(binary), "install"], cwd=work, env=env, check=True)
        subprocess.run([str(binary), "reshim"], cwd=work, env=env, check=True)


if __name__ == "__main__":
    main()
