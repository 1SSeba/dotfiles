#!/usr/bin/env python3
"""
Login de Google para la shell (Authorization Code + PKCE + loopback).

Mismo molde que scripts/spotify/auth.py: vive fuera de QML porque PKCE necesita
SHA-256 y hay que escuchar el redirect en un puerto local. El servidor atiende un
solo pedido y se apaga.

Dos diferencias con Spotify que importan:

  1. Google exige `client_secret` incluso en clientes tipo "Desktop app", aun
     usando PKCE. No es realmente secreto (va embebido en cualquier app de
     escritorio), pero hay que mandarlo. Se guarda en el keyring igual que los
     tokens, nunca en la config.

  2. Sin `access_type=offline` Google no devuelve refresh token, y sin
     `prompt=consent` deja de devolverlo en el segundo login en adelante — te
     quedas con una sesion que muere en una hora y no se puede renovar. Van los
     dos siempre.

Para que el refresh token no venza a los 7 dias, el proyecto en Google Cloud
Console tiene que estar en "In production", no en "Testing". Ver docs/CUENTAS.md.

Habla con la shell por stdout, una linea por evento:
    AUTHURL <url>     abri esto en el navegador
    TOKENS  <json>    {access_token, refresh_token, expires_in}
    ERROR   <texto>

Uso: auth.py CLIENT_ID CLIENT_SECRET [PUERTO] [SCOPES...]
"""

import base64
import hashlib
import http.server
import json
import secrets
import sys
import urllib.error
import urllib.parse
import urllib.request

AUTH_ENDPOINT = "https://accounts.google.com/o/oauth2/v2/auth"
TOKEN_ENDPOINT = "https://oauth2.googleapis.com/token"

# Por defecto pedimos lo que consumen los widgets. El llamador puede pasar otros
# como argumentos sueltos para pedir menos (o mas) sin tocar este archivo.
DEFAULT_SCOPES = [
    "https://www.googleapis.com/auth/userinfo.email",
    "https://www.googleapis.com/auth/calendar.readonly",
    "https://www.googleapis.com/auth/tasks",
]


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
    state = None

    def do_GET(self):
        query = urllib.parse.urlparse(self.path).query
        params = urllib.parse.parse_qs(query)
        CallbackHandler.code = params.get("code", [None])[0]
        CallbackHandler.error = params.get("error", [None])[0]
        returned_state = params.get("state", [None])[0]

        # El state evita que otra cosa escuchando en localhost nos meta un codigo
        if returned_state != CallbackHandler.state:
            CallbackHandler.code = None
            CallbackHandler.error = "state invalido"

        ok = CallbackHandler.code is not None
        body = (
            "<html><body style='font-family:sans-serif;text-align:center;"
            "padding-top:3em;background:#111;color:#eee'>"
            "<h2>%s</h2><p>Ya podes cerrar esta pestania.</p></body></html>"
            % ("Cuenta de Google conectada" if ok else "No se pudo conectar")
        ).encode()

        self.send_response(200 if ok else 400)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass  # el log del servidor ensuciaria el canal de eventos


def exchange(client_id, client_secret, code, verifier, redirect_uri):
    data = urllib.parse.urlencode({
        "grant_type": "authorization_code",
        "code": code,
        "redirect_uri": redirect_uri,
        "client_id": client_id,
        "client_secret": client_secret,
        "code_verifier": verifier,
    }).encode()
    request = urllib.request.Request(
        TOKEN_ENDPOINT,
        data=data,
        headers={"Content-Type": "application/x-www-form-urlencoded"},
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)


def describe_http_error(exc):
    """El cuerpo del 400 de Google dice cual es el problema real; sin el, no hay pista."""
    try:
        detail = json.load(exc)
        return "%s: %s" % (detail.get("error", exc), detail.get("error_description", ""))
    except Exception:  # noqa: BLE001
        return str(exc)


def main():
    if len(sys.argv) < 3 or not sys.argv[1].strip() or not sys.argv[2].strip():
        emit("ERROR", "Faltan el Client ID y/o el Client Secret")
        return 1

    client_id = sys.argv[1].strip()
    client_secret = sys.argv[2].strip()
    port = int(sys.argv[3]) if len(sys.argv) > 3 and sys.argv[3].strip() else 8890
    scopes = sys.argv[4:] if len(sys.argv) > 4 else DEFAULT_SCOPES

    redirect_uri = "http://127.0.0.1:%d/callback" % port
    verifier = make_verifier()
    CallbackHandler.state = secrets.token_urlsafe(24)

    params = urllib.parse.urlencode({
        "client_id": client_id,
        "response_type": "code",
        "redirect_uri": redirect_uri,
        "code_challenge_method": "S256",
        "code_challenge": challenge_for(verifier),
        "scope": " ".join(scopes),
        "state": CallbackHandler.state,
        # Los dos que hacen que exista un refresh token reutilizable
        "access_type": "offline",
        "prompt": "consent",
        # Evita el selector de cuenta si ya hay una sola sesion iniciada
        "include_granted_scopes": "true",
    })
    emit("AUTHURL", AUTH_ENDPOINT + "?" + params)

    try:
        server = http.server.HTTPServer(("127.0.0.1", port), CallbackHandler)
    except OSError as exc:
        emit("ERROR", "No se pudo escuchar en el puerto %d: %s" % (port, exc))
        return 1

    server.timeout = 300  # cinco minutos para completar el login
    server.handle_request()
    server.server_close()

    if CallbackHandler.error:
        emit("ERROR", "Google rechazo el permiso: %s" % CallbackHandler.error)
        return 1
    if not CallbackHandler.code:
        emit("ERROR", "El login se cancelo o tardo demasiado")
        return 1

    try:
        tokens = exchange(client_id, client_secret, CallbackHandler.code,
                          verifier, redirect_uri)
    except urllib.error.HTTPError as exc:
        emit("ERROR", "No se pudo canjear el codigo: %s" % describe_http_error(exc))
        return 1
    except Exception as exc:  # noqa: BLE001
        emit("ERROR", "No se pudo canjear el codigo: %s" % exc)
        return 1

    if not tokens.get("refresh_token"):
        # Pasa si el usuario revoco a mano y Google reuso un grant viejo. Mejor
        # avisar ahora que descubrirlo en una hora cuando el access token muera.
        emit("ERROR", "Google no devolvio refresh token. Sacale el acceso a la app "
                      "en myaccount.google.com/permissions y volve a conectar.")
        return 1

    emit("TOKENS", json.dumps(tokens))
    return 0


if __name__ == "__main__":
    sys.exit(main())
