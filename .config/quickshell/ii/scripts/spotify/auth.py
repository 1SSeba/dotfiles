#!/usr/bin/env python3
"""
Login de Spotify para la shell (Authorization Code + PKCE).

Vive fuera de QML porque PKCE necesita SHA-256 y hay que escuchar el redirect en
un puerto local: dos cosas que el motor QML no puede hacer. El servidor atiende
un solo pedido y se apaga.

Habla con la shell por stdout, una linea por evento:
    AUTHURL <url>     abri esto en el navegador
    TOKENS  <json>    {access_token, refresh_token, expires_in}
    ERROR   <texto>

Uso: auth.py CLIENT_ID [PUERTO]
"""

import base64
import hashlib
import http.server
import json
import secrets
import sys
import urllib.parse
import urllib.request

SCOPES = " ".join([
    # Leer tu biblioteca
    "playlist-read-private",
    "playlist-read-collaborative",
    "user-library-read",
    "user-read-private",
    "user-read-email",
    "user-top-read",
    "user-follow-read",
    "user-read-recently-played",
    # Leer y CONTROLAR la reproduccion (modify pide Premium; sin el
    # se cae solo a abrir el URI en el Spotify de escritorio)
    "user-read-playback-state",
    "user-read-currently-playing",
    "user-modify-playback-state",
])


def emit(tag, payload):
    sys.stdout.write("%s %s\n" % (tag, payload))
    sys.stdout.flush()


def make_verifier():
    """43-128 caracteres del alfabeto no reservado."""
    return base64.urlsafe_b64encode(secrets.token_bytes(64)).decode().rstrip("=")


def challenge_for(verifier):
    digest = hashlib.sha256(verifier.encode()).digest()
    return base64.urlsafe_b64encode(digest).decode().rstrip("=")


class CallbackHandler(http.server.BaseHTTPRequestHandler):
    code = None
    error = None

    def do_GET(self):
        query = urllib.parse.urlparse(self.path).query
        params = urllib.parse.parse_qs(query)
        CallbackHandler.code = params.get("code", [None])[0]
        CallbackHandler.error = params.get("error", [None])[0]

        ok = CallbackHandler.code is not None
        body = (
            "<html><body style='font-family:sans-serif;text-align:center;"
            "padding-top:3em;background:#111;color:#eee'>"
            "<h2>%s</h2><p>Ya podes cerrar esta pestania.</p></body></html>"
            % ("Spotify conectado" if ok else "No se pudo conectar")
        ).encode()

        self.send_response(200 if ok else 400)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass  # el log del servidor ensuciaria el canal de eventos


def exchange(client_id, code, verifier, redirect_uri):
    data = urllib.parse.urlencode({
        "grant_type": "authorization_code",
        "code": code,
        "redirect_uri": redirect_uri,
        "client_id": client_id,
        "code_verifier": verifier,
    }).encode()
    request = urllib.request.Request(
        "https://accounts.spotify.com/api/token",
        data=data,
        headers={"Content-Type": "application/x-www-form-urlencoded"},
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)


def main():
    if len(sys.argv) < 2 or not sys.argv[1].strip():
        emit("ERROR", "Falta el Client ID")
        return 1

    client_id = sys.argv[1].strip()
    port = int(sys.argv[2]) if len(sys.argv) > 2 else 8888
    redirect_uri = "http://127.0.0.1:%d/callback" % port

    verifier = make_verifier()
    params = urllib.parse.urlencode({
        "client_id": client_id,
        "response_type": "code",
        "redirect_uri": redirect_uri,
        "code_challenge_method": "S256",
        "code_challenge": challenge_for(verifier),
        "scope": SCOPES,
    })
    emit("AUTHURL", "https://accounts.spotify.com/authorize?" + params)

    try:
        server = http.server.HTTPServer(("127.0.0.1", port), CallbackHandler)
    except OSError as exc:
        emit("ERROR", "No se pudo escuchar en el puerto %d: %s" % (port, exc))
        return 1

    server.timeout = 300  # cinco minutos para completar el login
    server.handle_request()
    server.server_close()

    if CallbackHandler.error:
        emit("ERROR", "Spotify rechazo el permiso: %s" % CallbackHandler.error)
        return 1
    if not CallbackHandler.code:
        emit("ERROR", "El login se cancelo o tardo demasiado")
        return 1

    try:
        emit("TOKENS", json.dumps(exchange(client_id, CallbackHandler.code,
                                           verifier, redirect_uri)))
    except Exception as exc:  # noqa: BLE001 - cualquier fallo va al chat
        emit("ERROR", "No se pudo canjear el codigo: %s" % exc)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
