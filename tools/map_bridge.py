"""Receive map and inventory exports from the NOVA Studio editor plugins.

Run `python tools/map_bridge.py` and keep it open, then click "Export to repo" in the editor.
It listens on 127.0.0.1 only, so nothing outside this PC can reach it.
"""
import argparse
import json
import re
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MAPS = ROOT / "src" / "shared" / "maps"
PORT = 34872
NAME = re.compile(r"^[A-Za-z][A-Za-z0-9_]{0,63}$")
MAX_SOURCE = 256 * 1024
# The game falls back to this map, so it can never be deleted.
PROTECTED = {"SplitCircuit"}


def inventory_source(data):
    """Accept data only; never accept executable source from inventory requests."""
    if (not isinstance(data, dict) or not {"version", "items", "crates"} <= set(data)
            or set(data) - {"version", "items", "crates", "collections"} or data["version"] != 1):
        raise ValueError("Invalid inventory edits format")
    rarities = {"Common", "Uncommon", "Rare", "Epic", "Legendary", "Cosmic", "Chest"}
    # Roblox JSONEncode represents an empty Lua table as an array.
    for key in ("items", "crates", "collections"):
        if key not in data:
            continue
        if data[key] == []:
            data[key] = {}
        if not isinstance(data[key], dict):
            raise ValueError(f"Invalid {key} table")
    for item_id, edit in data["items"].items():
        check_id(item_id)
        if edit == []:
            edit = data["items"][item_id] = {}
        if not isinstance(edit, dict) or set(edit) - {"name", "rarity", "deleted", "collectionId"}:
            raise ValueError("Invalid item edit")
        if "name" in edit and (not isinstance(edit["name"], str) or not edit["name"].strip()
                               or len(edit["name"].encode("utf-8")) > 80 or any(ord(c) < 32 or ord(c) == 127 for c in edit["name"])):
            raise ValueError("Invalid display name")
        if "rarity" in edit and edit["rarity"] not in rarities:
            raise ValueError("Invalid rarity")
        if "deleted" in edit and not isinstance(edit["deleted"], bool):
            raise ValueError("Invalid deletion flag")
        if "collectionId" in edit and edit["collectionId"] is not False:
            check_collection_text(edit["collectionId"], 160)
    for collection_id, edit in data.get("collections", {}).items():
        check_collection_text(collection_id, 160)
        if not isinstance(edit, dict) or set(edit) - {"name", "deleted"}:
            raise ValueError("Invalid collection edit")
        if "name" in edit:
            check_collection_text(edit["name"], 80)
        if "deleted" in edit and not isinstance(edit["deleted"], bool):
            raise ValueError("Invalid collection deletion flag")
    for crate_id, rewards in data["crates"].items():
        check_id(crate_id)
        if not isinstance(rewards, list) or not rewards:
            raise ValueError("Crates require rewards")
        total, seen = 0, set()
        for reward in rewards:
            if not isinstance(reward, dict) or set(reward) != {"id", "weight"}:
                raise ValueError("Invalid reward")
            check_id(reward["id"])
            weight = reward["weight"]
            if isinstance(weight, bool) or not isinstance(weight, (int, float)) or not 0 < weight <= 100:
                raise ValueError("Invalid reward percentage")
            if reward["id"] in seen or data["items"].get(reward["id"], {}).get("deleted"):
                raise ValueError("Deleted or duplicate reward")
            seen.add(reward["id"])
            total += weight
        if abs(total - 100) > .0001:
            raise ValueError("Crate percentages must total 100%")

    def literal(value, indent=""):
        if isinstance(value, str):
            # Byte escapes are valid Luau, including Unicode and embedded quotes.
            return '"' + ''.join(chr(b) if 32 <= b < 127 and b not in (34, 92) else f"\\{b:03d}"
                                 for b in value.encode("utf-8")) + '"'
        if isinstance(value, bool):
            return "true" if value else "false"
        if isinstance(value, (int, float)):
            return repr(value)
        entries = enumerate(value, 1) if isinstance(value, list) else sorted(value.items())
        lines = ["{"]
        for key, entry in entries:
            lines.append(f"{indent}    [{literal(key)}] = {literal(entry, indent + '    ')},")
        return "\n".join(lines + [indent + "}"])
    return "-- Data exported by the NOVA Item Editor. Stable item IDs remain unchanged.\nreturn " + literal(data) + "\n"


def write_inventory(data):
    source = inventory_source(data)
    destination = ROOT / "src" / "shared" / "InventoryEdits.luau"
    temporary = destination.with_suffix(".luau.tmp")
    temporary.write_text(source, encoding="utf-8", newline="\n")
    temporary.replace(destination)
    return destination


def check_collection_text(value, limit):
    if (not isinstance(value, str) or not value.strip() or len(value.encode("utf-8")) > limit
            or any(ord(c) < 32 or ord(c) == 127 for c in value)):
        raise ValueError("Invalid collection ID or name")


def check_id(map_id):
    if not isinstance(map_id, str) or not NAME.match(map_id):
        raise ValueError("Map id must be letters, digits or _ and start with a letter")


def write_map(map_id, source):
    """Validate one export and write it. Returns the written path."""
    check_id(map_id)
    if not isinstance(source, str) or not source.strip():
        raise ValueError("Empty map source")
    if len(source) > MAX_SOURCE:
        raise ValueError("Map source is too large")
    # Only accept the data modules the editor writes, never arbitrary scripts.
    if "Rows = {" not in source or "Spawns = {" not in source:
        raise ValueError("Not a NOVA map module")
    MAPS.mkdir(parents=True, exist_ok=True)
    path = MAPS / f"{map_id}.luau"
    path.write_text(source if source.endswith("\n") else source + "\n", encoding="utf-8", newline="\n")
    return path


def delete_map(map_id):
    """Delete one exported map. Returns the path, or None when it was never exported."""
    check_id(map_id)
    if map_id in PROTECTED:
        raise ValueError(f"{map_id} is the default map and cannot be deleted")
    path = MAPS / f"{map_id}.luau"
    if not path.is_file():
        return None
    path.unlink()
    return path


class Handler(BaseHTTPRequestHandler):
    def reply(self, status, body):
        data = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if self.path == "/ping":
            self.reply(200, {"ok": True, "maps": str(MAPS)})
        else:
            self.reply(404, {"ok": False, "error": "Not found"})

    def do_POST(self):
        if self.path not in ("/maps", "/maps/delete", "/inventory"):
            return self.reply(404, {"ok": False, "error": "Not found"})
        try:
            length = int(self.headers.get("Content-Length", 0))
            if length <= 0 or length > MAX_SOURCE + 1024:
                raise ValueError("Request is too large")
            body = json.loads(self.rfile.read(length))
            if self.path == "/inventory":
                path = write_inventory(body)
                print(f"Wrote {path.relative_to(ROOT)}")
            elif self.path == "/maps/delete":
                path = delete_map(body.get("id"))
                if path is None:
                    return self.reply(200, {"ok": True, "path": None})
                print(f"Deleted {path.relative_to(ROOT)}")
            else:
                path = write_map(body.get("id"), body.get("source"))
                print(f"Wrote {path.relative_to(ROOT)}")
        except (ValueError, TypeError, OSError, json.JSONDecodeError) as error:
            return self.reply(400, {"ok": False, "error": str(error)})
        self.reply(200, {"ok": True, "path": str(path.relative_to(ROOT)).replace("\\", "/")})

    def log_message(self, *args):
        pass


def main(default_port=PORT):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--port", type=int, default=default_port)
    args = parser.parse_args()
    # Without this, Windows lets a second bridge share the port and silently split requests.
    ThreadingHTTPServer.allow_reuse_address = False
    try:
        server = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    except OSError:
        raise SystemExit(f"Port {args.port} is busy. Another map bridge is probably running; close it first.")
    print(f"NOVA editor bridge on http://127.0.0.1:{args.port}  ->  {ROOT / 'src' / 'shared'}")
    print("Click 'Export to repo' in the NOVA Level Editor or Item Editor. Ctrl+C stops the bridge.")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
