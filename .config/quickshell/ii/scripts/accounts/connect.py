#!/usr/bin/env python3
"""
Conexion de cuenta por navegador, para proveedores que no tienen OAuth.

Apple no expone OAuth para iCloud: "Sign in with Apple" te loguea en *otros*
sitios, no da acceso a tus datos de iCloud. Lo unico que existe para un cliente
de terceros es CalDAV/IMAP con una contrasenia de aplicacion. Este script
reproduce la *experiencia* de un OAuth igual: se abre el navegador, hay una
pagina que explica y linkea directo a donde se genera la contrasenia, y lo que
tipeas se verifica de verdad contra el servidor antes de guardarse. La shell
nunca ve un campo de secreto en su propio panel.

Mismo molde y mismo protocolo que scripts/google/auth.py, para que la UI trate
los dos flujos igual:

    AUTHURL <url>     abri esto en el navegador
    CREDS   <json>    {provider, user, password, host, port, security}
    ERROR   <texto>

El servidor escucha en loopback, valida un `state` aleatorio en cada pedido y se
apaga solo cuando la verificacion sale bien (o cuando vence el plazo). La
contrasenia solo viaja del navegador a este proceso por 127.0.0.1 y sale por
stdout, que la shell lee y manda directo al keyring; nunca toca disco ni argv.

Uso: connect.py {icloud|gmail|proton} [PUERTO]
"""

import html
import http.server
import json
import os
import secrets
import socket
import sys
import time
import urllib.parse

# caldav.py vive al lado, en scripts/apple: la verificacion de iCloud es la
# misma que usa el calendario, y duplicarla seria pedir que se desincronicen.
_AQUI = os.path.dirname(os.path.abspath(__file__))
# caldav.py e imap.py viven al lado: la verificacion tiene que ser la misma que
# usan los widgets, o algun dia van a decir cosas distintas.
sys.path.insert(0, os.path.join(_AQUI, "..", "apple"))
sys.path.insert(0, os.path.join(_AQUI, "..", "mail"))

PROVIDERS = {
    "icloud": {
        "title": "Conectar iCloud",
        "account_label": "Apple ID",
        "placeholder": "vos@icloud.com",
        "password_url": "https://account.apple.com/account/manage",
        "password_help": (
            "Entra a tu cuenta de Apple, abri <b>Iniciar sesion y seguridad</b> &rarr; "
            "<b>Contrasenias especificas de la app</b> y genera una nueva. Es una "
            "clave de 16 letras tipo <code>abcd-efgh-ijkl-mnop</code>: no es la "
            "contrasenia de tu Apple ID, y podes revocarla desde ahi cuando quieras."
        ),
        "scope_note": "Se usa para leer tu calendario y tus recordatorios (CalDAV) y "
                      "tu correo sin marcarlo como leido (IMAP).",
        "imap": {"host": "imap.mail.me.com", "port": 993, "security": "ssl"},
    },
    "proton": {
        "title": "Conectar Proton Mail",
        "account_label": "Direccion de Proton",
        "placeholder": "vos@proton.me",
        "password_url": "https://proton.me/mail/bridge",
        "password_help": (
            "Proton no expone IMAP a internet: tu correo esta cifrado de punta a "
            "punta y nadie fuera de tu maquina puede leerlo. El puente es "
            "<b>Proton Mail Bridge</b>, que corre local, descifra ahi mismo y "
            "levanta un IMAP en <code>127.0.0.1</code>.<br><br>"
            "Instalalo (en Arch esta en el AUR como <code>protonmail-bridge</code>), "
            "inicia sesion con tu cuenta de Proton y abri <b>Mailbox details</b>: "
            "ahi te muestra un usuario y una <b>contrasenia del Bridge</b>. Esa es "
            "la que va aca — no la de tu cuenta de Proton.<br><br>"
            "<b>Ojo:</b> Bridge necesita un plan pago de Proton (Mail Plus, "
            "Unlimited o Business). Con la cuenta gratis no hay IMAP posible."
        ),
        "scope_note": "Solo se usa para leer el buzon por IMAP, en modo lectura: "
                      "abrir el widget no marca nada como leido.",
        "imap": {"host": "127.0.0.1", "port": 1143, "security": "starttls"},
        # Bridge deja elegir el puerto, y a veces no es el de fabrica
        "ask_endpoint": True,
    },
    "gmail": {
        "title": "Conectar correo de Gmail",
        "account_label": "Direccion de Gmail",
        "placeholder": "vos@gmail.com",
        "password_url": "https://myaccount.google.com/apppasswords",
        "password_help": (
            "Google pide <b>verificacion en dos pasos</b> activada para poder generar "
            "una contrasenia de aplicacion. En esa pagina crea una y copia las 16 "
            "letras que te muestra."
        ),
        "scope_note": "Solo se usa para leer el buzon por IMAP, en modo lectura: "
                      "abrir el widget no marca nada como leido.",
        "imap": {"host": "imap.gmail.com", "port": 993, "security": "ssl"},
    },
}

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
  main {{ width: min(30rem, 92vw); padding: 2rem 0; }}
  h1 {{ font-size: 1.4rem; margin: 0 0 .4rem; }}
  p {{ line-height: 1.55; color: #b6b6c0; margin: .6rem 0; }}
  code {{ background: #1c1c22; padding: .1em .35em; border-radius: .3em; }}
  a {{ color: #9db8ff; }}
  .step {{
    background: #17171d; border: 1px solid #26262f; border-radius: .8rem;
    padding: 1rem 1.2rem; margin: 1rem 0;
  }}
  .cta {{
    display: inline-block; margin-top: .5rem; padding: .6rem 1rem;
    background: #3b5bdb; color: #fff; border-radius: .5rem;
    text-decoration: none; font-weight: 600;
  }}
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
  .fila {{ display: flex; gap: .8rem; }}
  .fila > div:first-child {{ flex: 2; }}
  .fila > div:last-child {{ flex: 1; }}
  .arriba {{ color: #8ce99a; }}
  .abajo {{ color: #ffc9c9; }}
  .ok {{ text-align: center; }}
  .ok h1 {{ font-size: 1.6rem; }}
</style>
<main>{body}</main>
"""

FORM_BODY = """
<h1>{title}</h1>
<p>{scope_note}</p>
{error}
<div class="step">
  <p>{password_help}</p>
  <a class="cta" href="{password_url}" target="_blank" rel="noopener">Generar la contrasenia</a>
</div>
<form method="post" action="/connect">
  <input type="hidden" name="state" value="{state}">
  {endpoint}
  <label for="user">{account_label}</label>
  <input id="user" name="user" type="email" required autofocus
         autocomplete="username" placeholder="{placeholder}" value="{user}">
  <label for="password">Contrasenia de aplicacion</label>
  <input id="password" name="password" type="password" required
         autocomplete="off" placeholder="xxxx-xxxx-xxxx-xxxx">
  <button type="submit">Verificar y conectar</button>
</form>
"""

ENDPOINT_FIELDS = """
<div class="step">
  <p>{estado}</p>
  <div class="fila">
    <div>
      <label for="host">Servidor del Bridge</label>
      <input id="host" name="host" value="{host}" autocomplete="off">
    </div>
    <div>
      <label for="port">Puerto IMAP</label>
      <input id="port" name="port" value="{port}" autocomplete="off" inputmode="numeric">
    </div>
  </div>
</div>
"""

OK_BODY = """
<div class="ok">
  <h1>Cuenta conectada</h1>
  <p>{detail}</p>
  <p>Ya podes cerrar esta pestania.</p>
</div>
"""


def emit(tag, payload):
    sys.stdout.write("%s %s\n" % (tag, payload))
    sys.stdout.flush()


def verify_icloud(user, password):
    """Devuelve el texto de confirmacion, o revienta con un error legible."""
    import caldav

    calendars = caldav.list_calendars(user, password)
    events = sum(1 for item in calendars if item.get("events"))
    todos = sum(1 for item in calendars if item.get("todos"))
    return "%d calendarios y %d listas de recordatorios." % (events, todos)


def verify_imap(user, password, host, port=993, security="ssl"):
    """Login de verdad contra el servidor. Devuelve el texto de confirmacion."""
    import imap  # scripts/mail/imap.py: el mismo cliente que usa el widget

    conn = imap.open_mailbox(host, port, user, password, "INBOX", security, timeout=15)
    try:
        typ, data = conn.search(None, "UNSEEN")
        sin_leer = len(data[0].split()) if typ == "OK" and data and data[0] else 0
        return "Entro bien: %d sin leer en la bandeja de entrada." % sin_leer
    finally:
        imap.close_quietly(conn)


def port_open(host, port, timeout=1.0):
    """Para poder decirte si el Bridge esta corriendo antes de que tipees nada."""
    try:
        with socket.create_connection((host, int(port)), timeout=timeout):
            return True
    except OSError:
        return False


def friendly_error(exc):
    text = str(exc) or type(exc).__name__
    lowered = text.lower()
    if State.provider == "proton" and isinstance(exc, (ConnectionRefusedError, socket.timeout)):
        # El error crudo seria "Connection refused", que no le dice nada a nadie
        return ("No hay nadie escuchando en %s:%s. Proton Mail Bridge tiene que "
                "estar abierto y con la sesion iniciada; fijate ademas que el "
                "puerto sea el que muestra en Settings." % (State.host, State.port))
    if "authentication" in lowered or "invalid credentials" in lowered or "401" in lowered:
        if State.provider == "proton":
            return ("Esas credenciales no entraron. Tiene que ser la contrasenia "
                    "que muestra el Bridge en Mailbox details, no la de tu cuenta "
                    "de Proton.")
        return ("Esas credenciales no entraron. Acordate de que tiene que ser una "
                "contrasenia de aplicacion, no la de tu cuenta.")
    if isinstance(exc, (socket.gaierror, socket.timeout, OSError)) and "resolve" in lowered:
        return "No se pudo llegar al servidor. Revisa la conexion."
    return text


def verify(provider, user, password):
    if provider == "icloud":
        detail = verify_icloud(user, password)
        # El correo de iCloud es opcional: hay Apple IDs sin buzon @icloud.com, y
        # fallar ahi seria mentir sobre el calendario, que si funciono.
        try:
            detail += " " + verify_imap(user, password, State.host, State.port,
                                        State.security)
        except Exception:  # noqa: BLE001
            detail += " (El correo de iCloud no respondio; el calendario si.)"
        return detail
    return verify_imap(user, password, State.host, State.port, State.security)


class State:
    token = None
    provider = None
    creds = None
    done = False
    # Adonde conectarse. Sale del proveedor y, en Proton, lo puede cambiar el
    # formulario: el Bridge deja elegir el puerto.
    host = ""
    port = 993
    security = "ssl"


def endpoint_block():
    """Los campos de servidor y puerto, solo donde tienen sentido (Proton)."""
    if not PROVIDERS[State.provider].get("ask_endpoint"):
        return ""
    arriba = port_open(State.host, State.port)
    estado = ('<span class="arriba">El Bridge esta escuchando en %s:%s.</span>'
              % (html.escape(State.host), State.port)) if arriba else (
             '<span class="abajo">Todavia no hay nadie en %s:%s.</span> '
             'Abri el Bridge e inicia sesion; si usa otro puerto, cambialo aca.'
             % (html.escape(State.host), State.port))
    return ENDPOINT_FIELDS.format(estado=estado,
                                  host=html.escape(State.host),
                                  port=State.port)


def render_form(error="", user=""):
    meta = PROVIDERS[State.provider]
    body = FORM_BODY.format(
        endpoint=endpoint_block(),
        title=html.escape(meta["title"]),
        scope_note=meta["scope_note"],
        password_help=meta["password_help"],
        password_url=meta["password_url"],
        account_label=html.escape(meta["account_label"]),
        placeholder=html.escape(meta["placeholder"]),
        state=html.escape(State.token),
        user=html.escape(user),
        error=('<div class="error">%s</div>' % html.escape(error)) if error else "",
    )
    return PAGE.format(title=html.escape(meta["title"]), body=body)


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

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        params = urllib.parse.parse_qs(parsed.query)
        if parsed.path != "/connect" or params.get("state", [None])[0] != State.token:
            self.reply(404, PAGE.format(title="No encontrado",
                                        body="<h1>Nada por aca</h1>"))
            return
        self.reply(200, render_form())

    def do_POST(self):
        if urllib.parse.urlparse(self.path).path != "/connect":
            self.reply(404, PAGE.format(title="No encontrado",
                                        body="<h1>Nada por aca</h1>"))
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

        # Proton deja mover el puerto del Bridge; los otros dos son fijos.
        if PROVIDERS[State.provider].get("ask_endpoint"):
            host = fields.get("host", [""])[0].strip()
            if host:
                State.host = host
            try:
                State.port = int(fields.get("port", [""])[0].strip())
            except ValueError:
                self.reply(400, render_form("El puerto tiene que ser un numero."))
                return

        user = fields.get("user", [""])[0].strip()
        password = "".join(fields.get("password", [""])[0].split())
        if not user or not password:
            self.reply(400, render_form("Faltan la cuenta o la contrasenia.", user))
            return

        try:
            detail = verify(State.provider, user, password)
        except Exception as exc:  # noqa: BLE001
            self.reply(200, render_form(friendly_error(exc), user))
            return

        State.creds = {"provider": State.provider, "user": user, "password": password,
                       "host": State.host, "port": State.port,
                       "security": State.security}
        State.done = True
        self.reply(200, PAGE.format(title="Cuenta conectada",
                                    body=OK_BODY.format(detail=html.escape(detail))))

    def log_message(self, *args):
        pass  # el log del servidor ensuciaria el canal de eventos


def main():
    if len(sys.argv) < 2 or sys.argv[1] not in PROVIDERS:
        emit("ERROR", "Uso: connect.py {icloud|gmail|proton} [PUERTO]")
        return 1

    State.provider = sys.argv[1]
    State.token = secrets.token_urlsafe(24)
    endpoint = PROVIDERS[State.provider].get("imap", {})
    State.host = endpoint.get("host", "")
    State.port = endpoint.get("port", 993)
    State.security = endpoint.get("security", "ssl")
    port = int(sys.argv[2]) if len(sys.argv) > 2 and sys.argv[2].strip() else 8891

    try:
        server = http.server.HTTPServer(("127.0.0.1", port), ConnectHandler)
    except OSError as exc:
        emit("ERROR", "No se pudo escuchar en el puerto %d: %s" % (port, exc))
        return 1

    emit("AUTHURL", "http://127.0.0.1:%d/connect?state=%s" % (port, State.token))

    # A diferencia del OAuth, aca puede haber varios intentos: el navegador pide
    # la pagina, manda el formulario, se equivoca, lo manda de nuevo. Seguimos
    # atendiendo hasta que una verificacion salga bien o se acabe el plazo.
    server.timeout = 5  # despierta seguido para poder mirar el reloj
    deadline = time.monotonic() + 600  # diez minutos: hay que ir a generar la clave
    while not State.done and time.monotonic() < deadline:
        server.handle_request()  # vuelve tambien por timeout, sin atender nada
    server.server_close()

    if not State.done:
        emit("ERROR", "La conexion se cancelo o tardo demasiado")
        return 1

    emit("CREDS", json.dumps(State.creds))
    return 0


if __name__ == "__main__":
    sys.exit(main())
