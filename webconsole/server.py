#!/usr/bin/env python3
"""Web-Konsole für das Velocity/Paper-Netzwerk.

Steuert die Server direkt (starten/stoppen), streamt deren Ausgabe in den Browser
und schickt eingegebene Befehle an die Server-Konsole. Nur Python-Standardbibliothek.

Endpunkte
  GET  /                      -> Weboberflaeche
  GET  /api/state             -> Status aller Server
  GET  /api/logs?server=&after=&timeout=  -> neue Logzeilen (Long-Poll)
  POST /api/command           -> {server, command}
  POST /api/start|stop|restart-> {server}
  POST /api/start-all|stop-all
"""
import base64
import json
import os
import re
import signal
import subprocess
import threading
import time
from collections import deque
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlparse, parse_qs

HERE = Path(__file__).resolve().parent
BASE = HERE.parent
ANSI = re.compile(r"\x1b\[[0-9;?]*[A-Za-z]")

with (HERE / "config.json").open(encoding="utf-8") as fh:
    CONF = json.load(fh)

HOST = CONF.get("host", "127.0.0.1")
PORT = int(CONF.get("port", 8080))
PASSWORD = (CONF.get("password") or "").strip()
AUTOSTART = bool(CONF.get("autoStart", True))
BUFFER = int(CONF.get("bufferLines", 4000))


class Server:
    def __init__(self, name, role, port, directory):
        self.name = name
        self.role = role
        self.port = port
        self.dir = directory
        self.proc = None
        self.lines = deque(maxlen=BUFFER)
        self.seq = 0
        self.phase = "stopped"          # stopped | starting | ready | stopping
        self.cv = threading.Condition()
        self.lock = threading.RLock()

    # -- Status -----------------------------------------------------------
    def pid(self):
        return self.proc.pid if (self.proc and self.proc.poll() is None) else None

    def running(self):
        return self.pid() is not None

    def snapshot(self):
        return {"name": self.name, "role": self.role, "port": self.port,
                "phase": self.phase, "pid": self.pid()}

    # -- Logpuffer --------------------------------------------------------
    def _emit(self, text):
        with self.cv:
            self.seq += 1
            self.lines.append((self.seq, text))
            self.cv.notify_all()

    def logs_after(self, after, timeout):
        with self.cv:
            if after and self.seq <= after:
                self.cv.wait(timeout)
            return [(s, t) for (s, t) in self.lines if s > after]

    # -- Prozesssteuerung -------------------------------------------------
    def _reader(self, proc):
        try:
            for raw in proc.stdout:
                line = ANSI.sub("", raw).replace("\r", "").rstrip("\n")
                if self.phase == "starting" and "Done (" in line:
                    with self.lock:
                        self.phase = "ready"
                self._emit(line)
        finally:
            try:
                proc.stdout.close()
            except Exception:
                pass
            with self.lock:
                if self.proc is proc:
                    self.proc = None
                    self.phase = "stopped"
            self._emit(f"--- {self.name}: Prozess beendet ---")

    def start(self):
        with self.lock:
            if self.running():
                return False, "läuft bereits"
            self.phase = "starting"
            self._emit(f"--- Starte {self.name} (Port {self.port}) ---")
            try:
                proc = subprocess.Popen(
                    ["bash", "start.sh"], cwd=str(self.dir),
                    stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT, text=True, bufsize=1,
                )
            except Exception as exc:
                self.phase = "stopped"
                self._emit(f"!! Start fehlgeschlagen: {exc}")
                return False, str(exc)
            self.proc = proc
            threading.Thread(target=self._reader, args=(proc,), daemon=True).start()
            return True, "gestartet"

    def send(self, command):
        command = command.strip()
        if not command:
            return False, "leerer Befehl"
        with self.lock:
            if not self.running():
                return False, "Server läuft nicht"
            self._emit(f"> {command}")
            try:
                self.proc.stdin.write(command + "\n")
                self.proc.stdin.flush()
            except Exception as exc:
                return False, f"Fehler: {exc}"
            return True, "gesendet"

    def stop(self, timeout=150):
        with self.lock:
            if not self.running():
                return False, "läuft nicht"
            self.phase = "stopping"
            proc = self.proc
        try:
            proc.stdin.write("stop\n")
            proc.stdin.flush()
        except Exception:
            pass
        try:
            proc.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            proc.terminate()
            try:
                proc.wait(timeout=20)
            except subprocess.TimeoutExpired:
                proc.kill()
        return True, "gestoppt"

    def restart(self):
        self.stop()
        time.sleep(1)
        return self.start()


SERVERS = [
    Server("velocity", "Proxy", 25565, BASE / "velocity"),
    Server("lobby", "Backend", 25566, BASE / "lobby"),
    Server("smp", "Backend", 25567, BASE / "smp"),
]
BY_NAME = {s.name: s for s in SERVERS}


def start_all():
    for name in ("lobby", "smp"):
        BY_NAME[name].start()
    time.sleep(3)
    BY_NAME["velocity"].start()


def stop_all():
    for name in ("velocity", "lobby", "smp"):
        BY_NAME[name].stop()


def state():
    return {"servers": [s.snapshot() for s in SERVERS],
            "console": {"host": HOST, "port": PORT}}


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    server_version = "MCWebConsole/1.0"

    def log_message(self, *args):
        pass

    # -- Helfer -----------------------------------------------------------
    def _auth_ok(self):
        if not PASSWORD:
            return True
        header = self.headers.get("Authorization", "")
        if not header.startswith("Basic "):
            return False
        try:
            user, _, pw = base64.b64decode(header[6:]).decode("utf-8").partition(":")
        except Exception:
            return False
        return pw == PASSWORD or user == PASSWORD

    def _send(self, code, body=b"", ctype="application/json; charset=utf-8", extra=None):
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        for key, value in (extra or {}).items():
            self.send_header(key, value)
        self.end_headers()
        if body:
            self.wfile.write(body)

    def _json(self, obj, code=200):
        self._send(code, json.dumps(obj, ensure_ascii=False).encode("utf-8"))

    def _unauthorized(self):
        self._send(401, ctype="text/plain; charset=utf-8",
                   extra={"WWW-Authenticate": 'Basic realm="MC Web Console"'})

    def _body(self):
        length = int(self.headers.get("Content-Length") or 0)
        raw = self.rfile.read(length) if length else b""
        try:
            return json.loads(raw or b"{}")
        except Exception:
            return {}

    # -- GET --------------------------------------------------------------
    def do_GET(self):
        if not self._auth_ok():
            return self._unauthorized()
        url = urlparse(self.path)
        if url.path in ("/", "/index.html"):
            html = (HERE / "static" / "index.html").read_bytes()
            return self._send(200, html, "text/html; charset=utf-8")
        if url.path == "/api/state":
            return self._json(state())
        if url.path == "/api/logs":
            qs = parse_qs(url.query)
            srv = BY_NAME.get((qs.get("server") or [""])[0])
            if not srv:
                return self._json({"error": "unbekannter Server"}, 404)
            after = int((qs.get("after") or ["0"])[0])
            timeout = float((qs.get("timeout") or ["20"])[0])
            lines = srv.logs_after(after, timeout)
            return self._json({"lines": [{"seq": s, "text": t} for s, t in lines],
                               "phase": srv.phase})
        if url.path == "/favicon.ico":
            return self._send(204)
        return self._json({"error": "nicht gefunden"}, 404)

    # -- POST -------------------------------------------------------------
    def do_POST(self):
        if not self._auth_ok():
            return self._unauthorized()
        url = urlparse(self.path)
        data = self._body()

        if url.path == "/api/command":
            srv = BY_NAME.get(data.get("server"))
            if not srv:
                return self._json({"error": "unbekannter Server"}, 404)
            ok, msg = srv.send(str(data.get("command", "")))
            return self._json({"ok": ok, "message": msg})

        if url.path in ("/api/start", "/api/stop", "/api/restart"):
            srv = BY_NAME.get(data.get("server"))
            if not srv:
                return self._json({"error": "unbekannter Server"}, 404)
            action = url.path.rsplit("/", 1)[1]
            threading.Thread(target=getattr(srv, action), daemon=True).start()
            return self._json({"ok": True, "action": action, "server": srv.name})

        if url.path == "/api/start-all":
            threading.Thread(target=start_all, daemon=True).start()
            return self._json({"ok": True})
        if url.path == "/api/stop-all":
            threading.Thread(target=stop_all, daemon=True).start()
            return self._json({"ok": True})
        if url.path == "/api/shutdown":
            threading.Thread(target=shutdown, daemon=True).start()
            return self._json({"ok": True})

        return self._json({"error": "nicht gefunden"}, 404)


def shutdown():
    stop_all()
    os._exit(0)


def on_signal(signum, frame):
    print(f"Signal {signum} empfangen, stoppe Server ...", flush=True)
    threading.Thread(target=shutdown, daemon=True).start()


def main():
    for sig in (signal.SIGTERM, signal.SIGINT):
        signal.signal(sig, on_signal)

    httpd = ThreadingHTTPServer((HOST, PORT), Handler)
    httpd.daemon_threads = True
    (HERE / "webconsole.pid").write_text(str(os.getpid()))
    scheme = f"http://{HOST}:{PORT}"
    print(f"Web-Konsole bereit: {scheme}", flush=True)

    if AUTOSTART:
        threading.Thread(target=start_all, daemon=True).start()

    try:
        httpd.serve_forever()
    finally:
        (HERE / "webconsole.pid").unlink(missing_ok=True)


if __name__ == "__main__":
    main()
