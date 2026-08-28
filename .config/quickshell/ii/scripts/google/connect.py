#!/usr/bin/env python3
"""
Conectar Google en un solo click, sin tipear nada en el panel de la shell.

El problema que resuelve: Google no deja usar sus APIs sin un cliente OAuth
propio, y crearlo son seis pasos en Google Cloud Console. Antes eso significaba
ir a buscar dos credenciales a mano y pegarlas en Ajustes.

Aca todo eso pasa en el navegador, en una sola pestania:

    1. La pagina te lleva paso a paso, con un link directo a cada pantalla de
       Google Cloud Console (proyecto, APIs, publicar, crear cliente).
    2. Pegas Client ID y Client Secret en la pagina.
    3. Al enviar, la misma pagina te redirige a la pantalla de permisos de
       Google, y el redirect vuelve a este mismo servidor.
    4. Se canjea el codigo y salen los tokens.

Reusa scripts/google/auth.py para PKCE y para el canje: si el flujo de OAuth
cambia, cambia en un solo lugar.

Habla con la shell por stdout, igual que auth.py:
    AUTHURL <url>     abri esto en el navegador
    TOKENS  <json>    {client_id, client_secret, access_token, refresh_token, expires_in}
    ERROR   <texto>

Uso: connect.py [PUERTO]
"""

import html
import http.server
import json
import os
import secrets
import sys
import time
import urllib.error
import urllib.parse

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import auth  # noqa: E402  - vive al lado; es la fuente de verdad del OAuth

CONSOLE = "https://console.cloud.google.com"

PAGE = """<!doctype html>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>{title}</title>
<style>
  :root {{ color-scheme: dark; }}
  body {{
    margin: 0; min-height: 100vh; display: grid; place-items: center;
    background: #101014; color: #e6e6ea;
    font-family: system-ui, -apple-system, "Segoe UI", sans-serif;
  }}
  main {{ width: min(34rem, 92vw); padding: 2rem 0; }}
  h1 {{ font-size: 1.4rem; margin: 0 0 .4rem; }}
  p {{ line-height: 1.55; color: #b6b6c0; margin: .6rem 0; }}
  code {{ background: #1c1c22; padding: .1em .35em; border-radius: .3em; }}
  a {{ color: #9db8ff; }}
  ol {{ padding-left: 0; margin: 1.2rem 0; list-style: none; counter-reset: paso; }}
  li {{
    background: #17171d; border: 1px solid #26262f; border-radius: .8rem;
    padding: .9rem 1.1rem .9rem 3.1rem; margin: .6rem 0; position: relative;
    line-height: 1.5;
  }}
  li::before {{
    counter-increment: paso; content: counter(paso);
    position: absolute; left: .9rem; top: .85rem;
    width: 1.6rem; height: 1.6rem; border-radius: 50%;
    background: #3b5bdb; color: #fff; font-size: .85rem; font-weight: 700;
    display: grid; place-items: center;
  }}
  li b {{ color: #e6e6ea; }}
  .warn {{ color: #ffd8a8; }}
  label {{ display: block; margin: .9rem 0 .3rem; font-size: .85rem; color: #b6b6c0; }}
  input {{
    width: 100%; box-sizing: border-box; padding: .65rem .8rem;
    background: #0c0c10; border: 1px solid #2c2c36; border-radius: .5rem;
    color: #e6e6ea; font-size: 1rem; font-family: inherit;
  }}
  input:focus {{ outline: 2px solid #3b5bdb; border-color: transparent; }}
  button {{
    width: 100%; margin-top: 1.2rem; padding: .75rem;
    background: #3b5bdb; color: #fff; border: 0; border-radius: .5rem;
    font-size: 1rem; font-weight: 600; cursor: pointer; font-family: inherit;
  }}
  button:hover {{ background: #4c6ef5; }}
  .error {{
    background: #2a1618; border: 1px solid #5c2a2f; color: #ffc9c9;
    padding: .8rem 1rem; border-radius: .6rem; margin: 1rem 0;
  }}
  .ok {{ text-align: center; }}
  .ok h1 {{ font-size: 1.6rem; }}
</style>
<main>{body}</main>
"""

FORM_BODY = """
<h1>Conectar Google</h1>
<p>Google no deja leer tu calendario sin un cliente propio. Son cuatro pantallas
y se hace una sola vez; los links van directo a cada una.</p>
{error}
<ol>
  <li>Crea un proyecto (o elegi uno que ya tengas):
      <a href="{console}/projectcreate" target="_blank" rel="noopener">abrir</a></li>
  <li>Habilita las dos APIs que se usan:
      <a href="{console}/apis/library/calendar-json.googleapis.com" target="_blank" rel="noopener">Calendar</a> y
      <a href="{console}/apis/library/tasks.googleapis.com" target="_blank" rel="noopener">Tasks</a>.
      Gmail no hace falta: el correo va por IMAP.</li>
  <li>En <a href="{console}/auth/audience" target="_blank" rel="noopener">Audience</a>,
      publica la app: <b>Publishing status &rarr; In production</b>.
      <span class="warn">Esto no es opcional</span> — en &laquo;Testing&raquo; Google
      vence el permiso a los 7 dias y habria que reconectar todas las semanas.
      Como no esta verificada, mas adelante vas a ver un aviso de Google:
      <b>Advanced &rarr; Go to (unsafe)</b>. Es tu propia app.</li>
  <li>Crea el cliente en
      <a href="{console}/auth/clients/create" target="_blank" rel="noopener">Clients</a>:
      tipo <b>Desktop app</b>. Te da un Client ID y un Client Secret; pegalos aca abajo.</li>
</ol>
<form method="post" action="/connect">
  <input type="hidden" name="state" value="{state}">
  <label for="client_id">Client ID</label>
  <input id="client_id" name="client_id" required autofocus autocomplete="off"
         placeholder="1234-abcd.apps.googleusercontent.com" value="{client_id}">
  <label for="client_secret">Client Secret</label>
  <input id="client_secret" name="client_secret" type="password" required
         autocomplete="off" placeholder="GOCSPX-...">
  <button type="submit">Continuar y dar permiso</button>
</form>
"""

OK_BODY = """
<div class="ok">
  <h1>Cuenta de Google conectada</h1>
  <p>Ya podes cerrar esta pestania.</p>
</div>
"""


def emit(tag, payload):
    sys.stdout.write("%s %s\n" % (tag, payload))
    sys.stdout.flush()


class State:
    token = None
    client_id = ""
    client_secret = ""
    verifier = ""
    redirect_uri = ""
    tokens = None
    done = False
    error = ""


def render_form(error=""):
    body = FORM_BODY.format(
        console=CONSOLE,
        state=html.escape(State.token),
        client_id=html.escape(State.client_id),
        error=('<div class="error">%s</div>' % html.escape(error)) if error else "",
    )
    return PAGE.format(title="Conectar Google", body=body)


def authorize_url():
    """La misma URL que arma auth.py, con el mismo puerto de vuelta."""
    State.verifier = auth.make_verifier()
    params = urllib.parse.urlencode({
        "client_id": State.client_id,
        "response_type": "code",
        "redirect_uri": State.redirect_uri,
        "code_challenge_method": "S256",
        "code_challenge": auth.challenge_for(State.verifier),
        "scope": " ".join(auth.DEFAULT_SCOPES),
        "state": State.token,
        # Los dos que hacen que exista un refresh token reutilizable
        "access_type": "offline",
        "prompt": "consent",
        "include_granted_scopes": "true",
    })
    return auth.AUTH_ENDPOINT + "?" + params


class ConnectHandler(http.server.BaseHTTPRequestHandler):
    def reply(self, status, page):
        payload = page.encode()
        self.send_response(status)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(payload)))
        # La pagina lleva un state de un solo uso: que no quede en el cache.
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(payload)

    def not_found(self):
        self.reply(404, PAGE.format(title="No encontrado", body="<h1>Nada por aca</h1>"))

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        params = urllib.parse.parse_qs(parsed.query)
        given_state = params.get("state", [None])[0]

        if parsed.path == "/connect":
            if given_state != State.token:
                self.not_found()
                return
            self.reply(200, render_form())
            return

        if parsed.path != "/callback":
            self.not_found()
            return

        # El state evita que otra cosa escuchando en localhost nos meta un codigo
        if given_state != State.token:
            self.reply(400, render_form("La sesion de conexion vencio. Volve a "
                                        "abrir el link desde la shell."))
            return

        error = params.get("error", [None])[0]
        if error:
            self.reply(200, render_form("Google rechazo el permiso: %s" % error))
            return

        code = params.get("code", [None])[0]
        if not code:
            self.reply(400, render_form("Google no devolvio ningun codigo."))
            return

        try:
            tokens = auth.exchange(State.client_id, State.client_secret, code,
                                   State.verifier, State.redirect_uri)
        except urllib.error.HTTPError as exc:
            self.reply(200, render_form("No se pudo canjear el codigo: %s"
                                        % auth.describe_http_error(exc)))
            return
        except Exception as exc:  # noqa: BLE001
            self.reply(200, render_form("No se pudo canjear el codigo: %s" % exc))
            return

        if not tokens.get("refresh_token"):
            # Pasa si el usuario ya le habia dado permiso a esta app y Google
            # reuso el grant viejo. Mejor avisar ahora que descubrirlo en una
            # hora, cuando el access token muera y no haya con que renovarlo.
            self.reply(200, render_form(
                "Google no devolvio refresh token. Sacale el acceso a la app en "
                "myaccount.google.com/permissions y volve a intentar."))
            return

        tokens["client_id"] = State.client_id
        tokens["client_secret"] = State.client_secret
        State.tokens = tokens
        State.done = True
        self.reply(200, PAGE.format(title="Cuenta conectada", body=OK_BODY))

    def do_POST(self):
        if urllib.parse.urlparse(self.path).path != "/connect":
            self.not_found()
            return

        length = int(self.headers.get("Content-Length") or 0)
        if length > 8192:  # un formulario de dos campos no pesa mas que esto
            self.reply(400, render_form("El formulario vino con algo raro."))
            return
        fields = urllib.parse.parse_qs(self.rfile.read(length).decode("utf-8", "replace"))

        # Sin esto, cualquier pagina abierta en el navegador podria postear aca.
        if fields.get("state", [None])[0] != State.token:
            self.reply(400, render_form("La sesion de conexion vencio. Volve a "
                                        "abrir el link desde la shell."))
            return

        State.client_id = fields.get("client_id", [""])[0].strip()
        State.client_secret = fields.get("client_secret", [""])[0].strip()
        if not State.client_id or not State.client_secret:
            self.reply(400, render_form("Faltan el Client ID o el Client Secret."))
            return

        # En vez de pedirte que abras otra cosa, la misma pestania sigue a la
        # pantalla de permisos de Google y vuelve sola.
        self.send_response(303)
        self.send_header("Location", authorize_url())
        self.send_header("Cache-Control", "no-store")
        self.end_headers()

    def log_message(self, *args):
        pass  # el log del servidor ensuciaria el canal de eventos


def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 and sys.argv[1].strip() else 8890
    State.token = secrets.token_urlsafe(24)
    State.redirect_uri = "http://127.0.0.1:%d/callback" % port
    if len(sys.argv) > 2:
        State.client_id = sys.argv[2].strip()  # el que ya estaba, para no retipearlo

    try:
        server = http.server.HTTPServer(("127.0.0.1", port), ConnectHandler)
    except OSError as exc:
        emit("ERROR", "No se pudo escuchar en el puerto %d: %s" % (port, exc))
        return 1

    emit("AUTHURL", "http://127.0.0.1:%d/connect?state=%s" % (port, State.token))

    # Puede haber varios intentos: la pagina, el formulario, el permiso, la
    # vuelta. Y en el medio hay que ir a crear el cliente en la consola de
    # Google, que lleva su rato.
    server.timeout = 5  # despierta seguido para poder mirar el reloj
    deadline = time.monotonic() + 900  # quince minutos
    while not State.done and time.monotonic() < deadline:
        server.handle_request()  # vuelve tambien por timeout, sin atender nada
    server.server_close()

    if not State.done:
        emit("ERROR", "La conexion se cancelo o tardo demasiado")
        return 1

    emit("TOKENS", json.dumps(State.tokens))
    return 0


if __name__ == "__main__":
    sys.exit(main())
