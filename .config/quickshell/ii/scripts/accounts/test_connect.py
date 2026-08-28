#!/usr/bin/env python3
"""
Prueba del flujo de conexion por navegador, sin tocar Gmail ni iCloud.

Levanta connect.py de verdad (servidor, formulario, protocolo de stdout) con la
verificacion reemplazada por una falsa, y lo maneja como lo haria el navegador.
Lo que queda sin cubrir es solo si el servidor remoto acepta la credencial.

Uso: python3 test_connect.py
"""

import json
import os
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
PORT = 8899
BASE = "http://127.0.0.1:%d/connect" % PORT
GOOD = "abcdefghijklmnop"

# Se ejecuta en el proceso hijo: connect.py real, verify() falso. El fake mira
# State para que el test pueda comprobar contra que servidor se habria conectado.
CHILD = """
import sys
sys.path.insert(0, %r)
import connect
def fake_verify(provider, user, password):
    if password != %r:
        raise RuntimeError("Invalid credentials (Failure)")
    return "Entro bien contra %%s:%%s (%%s)." %% (
        connect.State.host, connect.State.port, connect.State.security)
connect.verify = fake_verify
sys.argv = ["connect.py"] + sys.argv[1:]
sys.exit(connect.main())
""" % (HERE, GOOD)


def post(fields):
    body = urllib.parse.urlencode(fields).encode()
    return urllib.request.urlopen(BASE, body, timeout=10).read().decode()


def expect_status(call, code, what):
    try:
        call()
    except urllib.error.HTTPError as exc:
        assert exc.code == code, "%s: esperaba %d, vino %d" % (what, code, exc.code)
        return
    raise AssertionError("%s: no fue rechazado" % what)


def main():
    child = subprocess.Popen([sys.executable, "-c", CHILD, "gmail", str(PORT)],
                             stdout=subprocess.PIPE, text=True)
    try:
        line = child.stdout.readline().strip()
        assert line.startswith("AUTHURL "), line
        url = line.split(" ", 1)[1]
        state = urllib.parse.parse_qs(urllib.parse.urlparse(url).query)["state"][0]

        expect_status(lambda: urllib.request.urlopen(BASE + "?state=nope", timeout=10),
                      404, "GET con state invalido")

        page = urllib.request.urlopen(url, timeout=10).read().decode()
        assert "myaccount.google.com/apppasswords" in page, "falta el link a la clave"
        assert 'type="password"' in page, "falta el campo de contrasenia"

        expect_status(lambda: post({"state": "nope", "user": "a@b.com", "password": "x"}),
                      400, "POST con state invalido")

        page = post({"state": state, "user": "a@b.com", "password": "malo"})
        assert 'class="error"' in page, "una credencial mala no mostro error"
        assert "contrasenia de aplicacion" in page, "el error no es el legible"
        assert 'value="a@b.com"' in page, "no conservo la cuenta tipeada"

        # Con espacios en el medio, como los copia y pega la gente de la pagina.
        page = post({"state": state, "user": "a@b.com", "password": "abcd efgh ijkl mnop"})
        assert "Cuenta conectada" in page, page[:400]

        rest = child.stdout.read().strip()
        child.wait(timeout=10)
        assert rest.startswith("CREDS "), rest
        creds = json.loads(rest.split(" ", 1)[1])
        assert creds == {"provider": "gmail", "user": "a@b.com", "password": GOOD,
                         "host": "imap.gmail.com", "port": 993,
                         "security": "ssl"}, creds
    finally:
        if child.poll() is None:
            child.kill()

    probar_proton()
    print("todo bien")
    return 0


def probar_proton():
    """
    Proton es el unico que no habla IMAP contra internet: todo pasa por Proton
    Mail Bridge, en loopback y con STARTTLS. La pagina tiene que explicar eso,
    decir si el Bridge esta escuchando, y dejar cambiar el puerto — el Bridge
    no siempre usa el de fabrica.
    """
    puerto = PORT + 1
    base = "http://127.0.0.1:%d/connect" % puerto
    child = subprocess.Popen([sys.executable, "-c", CHILD, "proton", str(puerto)],
                             stdout=subprocess.PIPE, text=True)
    try:
        url = child.stdout.readline().strip().split(" ", 1)[1]
        state = urllib.parse.parse_qs(urllib.parse.urlparse(url).query)["state"][0]

        page = urllib.request.urlopen(url, timeout=10).read().decode()
        assert "protonmail-bridge" in page, "no dice como instalar el Bridge"
        assert "plan pago" in page, "no avisa de que el Bridge necesita plan pago"
        assert 'value="127.0.0.1"' in page and 'value="1143"' in page, \
            "faltan los campos de servidor y puerto"
        # Sin Bridge corriendo tiene que decirlo, no dejarte adivinar
        assert "Todavia no hay nadie en 127.0.0.1:1143" in page, \
            "no avisa que el Bridge no esta escuchando"

        # Un puerto que no es numero se rechaza antes de intentar conectarse
        body = urllib.parse.urlencode({"state": state, "user": "yo@proton.me",
                                       "password": GOOD, "host": "127.0.0.1",
                                       "port": "mil"}).encode()
        try:
            urllib.request.urlopen(base, body, timeout=10)
            raise AssertionError("acepto un puerto que no es numero")
        except urllib.error.HTTPError as exc:
            assert exc.code == 400, exc.code

        body = urllib.parse.urlencode({"state": state, "user": "yo@proton.me",
                                       "password": GOOD, "host": "127.0.0.1",
                                       "port": "1144"}).encode()
        page = urllib.request.urlopen(base, body, timeout=10).read().decode()
        assert "Cuenta conectada" in page, page[:400]
        assert "127.0.0.1:1144 (starttls)" in page, "no uso el puerto del formulario"

        rest = child.stdout.read().strip()
        child.wait(timeout=10)
        creds = json.loads(rest.split(" ", 1)[1])
        assert creds == {"provider": "proton", "user": "yo@proton.me",
                         "password": GOOD, "host": "127.0.0.1", "port": 1144,
                         "security": "starttls"}, creds
    finally:
        if child.poll() is None:
            child.kill()


if __name__ == "__main__":
    sys.exit(main())
