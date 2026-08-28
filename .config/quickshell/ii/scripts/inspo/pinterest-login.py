#!/usr/bin/env python3
"""
Login OAuth de Pinterest para la pestaña Inspo.

Levanta un servidor local que atrapa el redirect, abre el navegador, cambia el
`code` por un access token y lo escupe como JSON por stdout.

    pinterest-login.py CLIENT_ID CLIENT_SECRET [PORT]

Se hace acá y no en QML porque el flujo necesita escuchar un puerto, y porque
así el secret nunca queda escrito en el script de request.
"""
import base64
import http.server
import json
import socket
import sys
import threading
import urllib.parse
import urllib.request
import webbrowser

AUTH_URL = "https://www.pinterest.com/oauth/"
TOKEN_URL = "https://api.pinterest.com/v5/oauth/token"
# Solo lectura: los boards y los pines que el usuario ya guardó.
SCOPES = "boards:read,pins:read"

DONE_PAGE = b"""<!doctype html><meta charset=utf-8>
<title>Listo</title>
<body style="font-family:system-ui;background:#111;color:#eee;
display:flex;align-items:center;justify-content:center;height:100vh;margin:0">
<div style="text-align:center">
<h2>Ya podes cerrar esta pestana</h2>
<p style="opacity:.6">Volve a la sidebar.</p>
</div>"""


class Handler(http.server.BaseHTTPRequestHandler):
    result = {}

    def do_GET(self):
        query = urllib.parse.urlparse(self.path).query
        params = urllib.parse.parse_qs(query)
        Handler.result = {k: v[0] for k, v in params.items()}
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.end_headers()
        self.wfile.write(DONE_PAGE)

    def log_message(self, *args):
        pass  # sin ruido en stderr


def fail(msg):
    print(json.dumps({"error": msg}))
    sys.exit(1)


def main():
    if len(sys.argv) < 3:
        fail("Faltan CLIENT_ID y CLIENT_SECRET")
    client_id, client_secret = sys.argv[1], sys.argv[2]
    port = int(sys.argv[3]) if len(sys.argv) > 3 else 8085
    redirect_uri = f"http://localhost:{port}/"

    try:
        server = http.server.HTTPServer(("127.0.0.1", port), Handler)
    except OSError as e:
        fail(f"No pude escuchar en el puerto {port}: {e}")
    server.timeout = 1

    auth = (
        AUTH_URL
        + "?"
        + urllib.parse.urlencode(
            {
                "client_id": client_id,
                "redirect_uri": redirect_uri,
                "response_type": "code",
                "scope": SCOPES,
            }
        )
    )
    # El navegador puede tardar; que no bloquee el wait del servidor.
    threading.Thread(target=lambda: webbrowser.open(auth), daemon=True).start()
    print(json.dumps({"status": "waiting", "url": auth}), flush=True)

    # Esperamos el redirect hasta 5 minutos.
    waited = 0
    while not Handler.result and waited < 300:
        server.handle_request()
        waited += 1
    server.server_close()

    if not Handler.result:
        fail("Se acabo el tiempo esperando el login")
    if "error" in Handler.result:
        fail(Handler.result.get("error_description") or Handler.result["error"])
    code = Handler.result.get("code")
    if not code:
        fail("Pinterest no devolvio un code")

    basic = base64.b64encode(f"{client_id}:{client_secret}".encode()).decode()
    body = urllib.parse.urlencode(
        {
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": redirect_uri,
        }
    ).encode()
    req = urllib.request.Request(
        TOKEN_URL,
        data=body,
        headers={
            "Authorization": f"Basic {basic}",
            "Content-Type": "application/x-www-form-urlencoded",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            token = json.load(resp)
    except urllib.error.HTTPError as e:
        detail = e.read().decode(errors="replace")[:400]
        fail(f"Pinterest rechazo el intercambio del code ({e.code}): {detail}")
    except (urllib.error.URLError, socket.timeout) as e:
        fail(f"No pude hablar con Pinterest: {e}")

    if "access_token" not in token:
        fail(f"Respuesta sin access_token: {json.dumps(token)[:300]}")

    print(
        json.dumps(
            {
                "status": "ok",
                "access_token": token["access_token"],
                "refresh_token": token.get("refresh_token", ""),
                "expires_in": token.get("expires_in", 0),
                "scope": token.get("scope", SCOPES),
            }
        )
    )


if __name__ == "__main__":
    main()
