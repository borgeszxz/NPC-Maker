"""Packs src/ into an installable Roblox plugin (.rbxmx).

Layout convention:
    src/Main.server.luau   -> Script "Main" at the plugin root
    src/<Folder>/*.luau    -> ModuleScript inside Folder "<Folder>"

Run:  python build/build_plugin.py [--install]
"""

from __future__ import annotations

import argparse
import os
import shutil
import sys
from pathlib import Path
from xml.sax.saxutils import escape

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "src"
PLUGIN_NAME = "NPCMaker"
OUT = ROOT / "build" / f"{PLUGIN_NAME}.rbxmx"

HEADER = (
    '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
    'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
    'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" '
    'version="4">'
)

_referent = 0


def next_referent() -> str:
    global _referent
    _referent += 1
    return f"RBX{_referent}"


def indent(text: str, level: int) -> str:
    pad = "  " * level
    return "\n".join(pad + line if line else line for line in text.split("\n"))


def script_item(class_name: str, name: str, source: str, level: int) -> str:
    body = (
        f'<Item class="{class_name}" referent="{next_referent()}">\n'
        f"  <Properties>\n"
        f'    <string name="Name">{escape(name)}</string>\n'
        f'    <ProtectedString name="Source">{escape(source)}</ProtectedString>\n'
        f"  </Properties>\n"
        f"</Item>"
    )
    return indent(body, level)


def folder_item(name: str, children: list[str], level: int) -> str:
    opening = (
        f'<Item class="Folder" referent="{next_referent()}">\n'
        f"  <Properties>\n"
        f'    <string name="Name">{escape(name)}</string>\n'
        f"  </Properties>"
    )
    parts = [indent(opening, level)]
    parts.extend(children)
    parts.append(indent("</Item>", level))
    return "\n".join(parts)


def read_source(path: Path) -> str:
    text = path.read_text(encoding="utf-8")
    # Roblox stores LF; CRLF would show up as stray characters in the editor.
    return text.replace("\r\n", "\n")


def collect() -> str:
    if not SRC.is_dir():
        sys.exit(f"missing source directory: {SRC}")

    children: list[str] = []

    entry = SRC / "Main.server.luau"
    if not entry.is_file():
        sys.exit("missing src/Main.server.luau")
    children.append(script_item("Script", "Main", read_source(entry), 2))

    for folder in sorted(p for p in SRC.iterdir() if p.is_dir()):
        modules = sorted(folder.glob("*.luau"))
        if not modules:
            continue
        items = [
            script_item("ModuleScript", module.stem, read_source(module), 3)
            for module in modules
        ]
        children.append(folder_item(folder.name, items, 2))

    tree = folder_item(PLUGIN_NAME, children, 1)
    return f"{HEADER}\n{tree}\n</roblox>\n"


def plugins_directory() -> Path | None:
    local_appdata = os.environ.get("LOCALAPPDATA")
    if not local_appdata:
        return None
    candidate = Path(local_appdata) / "Roblox" / "Plugins"
    return candidate if candidate.is_dir() else None


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--install",
        action="store_true",
        help="also copy the built plugin into the local Roblox Plugins folder",
    )
    args = parser.parse_args()

    xml = collect()
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(xml, encoding="utf-8")
    print(f"built {OUT}  ({len(xml):,} bytes)")

    if args.install:
        target_dir = plugins_directory()
        if target_dir is None:
            sys.exit("could not locate the Roblox Plugins folder")
        target = target_dir / OUT.name
        shutil.copyfile(OUT, target)
        print(f"installed {target}")


if __name__ == "__main__":
    main()
