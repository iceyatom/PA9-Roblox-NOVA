"""Receive maps from the NOVA Level Editor plugin and write or delete them in src/shared/maps.

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
        if self.path not in ("/maps", "/maps/delete"):
            return self.reply(404, {"ok": False, "error": "Not found"})
        try:
            length = int(self.headers.get("Content-Length", 0))
            if length > MAX_SOURCE + 1024:
                raise ValueError("Request is too large")
            body = json.loads(self.rfile.read(length))
            if self.path == "/maps/delete":
                path = delete_map(body.get("id"))
                if path is None:
                    return self.reply(200, {"ok": True, "path": None})
                print(f"Deleted {path.relative_to(ROOT)}")
            else:
                path = write_map(body.get("id"), body.get("source"))
                print(f"Wrote {path.relative_to(ROOT)}")
        except (ValueError, json.JSONDecodeError) as error:
            return self.reply(400, {"ok": False, "error": str(error)})
        self.reply(200, {"ok": True, "path": str(path.relative_to(ROOT)).replace("\\", "/")})

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--port", type=int, default=PORT)
    args = parser.parse_args()
    # Without this, Windows lets a second bridge share the port and silently split requests.
    ThreadingHTTPServer.allow_reuse_address = False
    try:
        server = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    except OSError:
        raise SystemExit(f"Port {args.port} is busy. Another map bridge is probably running; close it first.")
    print(f"NOVA map bridge on http://127.0.0.1:{args.port}  ->  {MAPS}")
    print("Click 'Export to repo' in the Studio level editor. Ctrl+C stops the bridge.")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
