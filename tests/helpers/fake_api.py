#!/usr/bin/env python3
"""fake_api.py — fake GitHub API para los RED checks de setup.sh.

Sirve GET /user con el codigo y headers configurados por env, registra cada
request en un log y — best-effort — vuelca los cmdline de procesos `curl`
activos durante cada request (para verificar F1: el token jamas viaja en argv).
Imprime el puerto elegido en stdout (una linea) para que el runner lo capture.

Env:
  FAKE_API_CODE       codigo HTTP (default 200)
  FAKE_API_FAIL_FIRST 1 = el PRIMER request responde 401; el resto, FAKE_API_CODE
  FAKE_API_SCOPES     valor del header x-oauth-scopes (default: repo, read:org, workflow)
  FAKE_API_LOG        ruta del log de requests
  FAKE_API_CMDLINE    ruta del log de cmdlines capturados
"""
import http.server
import os
import socketserver
import sys
import time

LISTEN = ("127.0.0.1", 0)

_request_count = 0


def scan_curl_cmdlines():
    lines = []
    try:
        base = "/proc"
        for pid in os.listdir(base):
            if not pid.isdigit():
                continue
            try:
                with open(os.path.join(base, pid, "cmdline"), "rb") as f:
                    raw = f.read().replace(b"\0", b" ").decode("utf-8", "replace")
            except Exception:
                continue
            argv = raw.split()
            # F1: solo interesan procesos cuyo PROGRAMA es curl (basename del
            # argv[0]); un match de substring capturaria a pty_run.py por el env
            # SDD_OWN_DEBUG_CURL_CONFIG y por el spec del prompt con el token.
            if argv and os.path.basename(argv[0]) == "curl":
                lines.append(f"pid={pid} cmd={raw.strip()}")
    except Exception:
        pass
    return lines


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        global _request_count
        _request_count += 1
        code = int(os.environ.get("FAKE_API_CODE", "200"))
        if os.environ.get("FAKE_API_FAIL_FIRST") == "1" and _request_count == 1:
            code = 401
        scopes = os.environ.get("FAKE_API_SCOPES", "repo, read:org, workflow")
        body = b'{"login":"redtest-user","id":1234}'
        if os.environ.get("FAKE_API_LOG"):
            auth = self.headers.get("Authorization", "<none>")
            # redactar: el log del fake jamas guarda el token crudo (higiene F1)
            if auth.startswith("Bearer ") and len(auth) > 14:
                auth = f"Bearer {auth[7:11]}....{auth[-4:]}"
            lines = [
                f"{time.time():.3f} {self.command} {self.path}",
                f"  auth_header={auth}",
            ]
            cmds = scan_curl_cmdlines()
            if cmds:
                lines.append("  curl_cmdlines:")
                lines += [f"    {c}" for c in cmds]
                with open(os.environ["FAKE_API_CMDLINE"], "a") as f:
                    f.write("\n".join([f"t={time.time():.3f}"] + cmds) + "\n")
            with open(os.environ["FAKE_API_LOG"], "a") as f:
                f.write("\n".join(lines) + "\n")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        if code == 200 and scopes:
            self.send_header("x-oauth-scopes", scopes)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        pass


class Server(socketserver.TCPServer):
    allow_reuse_address = True


def main():
    srv = Server(LISTEN, Handler)
    print(f"{srv.server_address[0]}:{srv.server_address[1]}", flush=True)
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()