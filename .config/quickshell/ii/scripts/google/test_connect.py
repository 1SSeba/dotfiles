#!/usr/bin/env python3
"""
Prueba del flujo guiado de Google, sin hablar con Google.

Levanta connect.py de verdad (servidor, pagina, redirect, callback, protocolo de
stdout) con el canje del codigo reemplazado por uno falso, y lo maneja como lo
haria el navegador. Lo que queda sin cubrir es solo si Google contesta igual.

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
PORT = 8897
BASE = "http://127.0.0.1:%d" % PORT

# Se ejecuta en el proceso hijo: connect.py real, canje falso. El primer intento
# devuelve una respuesta sin refresh_token, que es el caso que hay que detectar.
CHILD = """
import sys
sys.path.insert(0, %r)
import connect
intentos = []
def fake_exchange(client_id, client_secret, code, verifier, redirect_uri):
    intentos.append(code)
    assert client_id == "id-de-prueba", client_id
    assert client_secret == "secreto-de-prueba", client_secret
    assert verifier, "falta el code_verifier de PKCE"
    if len(intentos) == 1:
        return {"access_token": "at", "expires_in": 3599}
    return {"access_token": "at", "refresh_token": "rt", "expires_in": 3599}
connect.auth.exchange = fake_exchange
sys.argv = ["connect.py"] + sys.argv[1:]
sys.exit(connect.main())
""" % HERE


class NoRedirect(urllib.request.HTTPRedirectHandler):
    """Sin esto urllib sigue el 303 y se va a accounts.google.com de verdad."""
    def redirect_request(self, *args):
        return None


opener = urllib.request.build_opener(NoRedirect)


def get(url):
    return opener.open(url, timeout=10)


def post(fields):
    return opener.open(BASE + "/connect",
                       urllib.parse.urlencode(fields).encode(), timeout=10)


def expect_status(call, code, what):
    try:
        call()
    except urllib.error.HTTPError as exc:
        assert exc.code == code, "%s: esperaba %d, vino %d" % (what, code, exc.code)
        return exc
    raise AssertionError("%s: no fue rechazado" % what)


def main():
    child = subprocess.Popen([sys.executable, "-c", CHILD, str(PORT)],
                             stdout=subprocess.PIPE, text=True)
    try:
        line = child.stdout.readline().strip()
        assert line.startswith("AUTHURL "), line
        url = line.split(" ", 1)[1]
        state = urllib.parse.parse_qs(urllib.parse.urlparse(url).query)["state"][0]

        expect_status(lambda: get(BASE + "/connect?state=nope"), 404,
                      "GET con state invalido")

        page = get(url).read().decode()
        for enlace in ["projectcreate", "calendar-json.googleapis.com",
                       "tasks.googleapis.com", "auth/clients/create"]:
            assert enlace in page, "falta el link a %s" % enlace
        assert "In production" in page, "no avisa de publicar el proyecto"

        expect_status(lambda: post({"state": "nope", "client_id": "a",
                                    "client_secret": "b"}), 400,
                      "POST con state invalido")

        exc = expect_status(lambda: post({"state": state, "client_id": "",
                                          "client_secret": ""}), 400,
                            "POST sin credenciales")
        assert "Faltan el Client ID" in exc.read().decode()

        # El envio bueno redirige a la pantalla de permisos de Google
        exc = expect_status(lambda: post({"state": state,
                                          "client_id": "id-de-prueba",
                                          "client_secret": "secreto-de-prueba"}),
                            303, "el formulario no redirigio")
        destino = exc.headers["Location"]
        query = urllib.parse.parse_qs(urllib.parse.urlparse(destino).query)
        assert destino.startswith("https://accounts.google.com/"), destino
        assert query["access_type"] == ["offline"], "sin esto no hay refresh token"
        assert query["prompt"] == ["consent"], "sin esto se pierde en el 2do login"
        assert query["code_challenge_method"] == ["S256"], "falta PKCE"
        assert query["state"] == [state]
        assert query["redirect_uri"] == ["http://127.0.0.1:%d/callback" % PORT]

        # Callback con state ajeno: no se canjea nada
        expect_status(lambda: get(BASE + "/callback?code=x&state=nope"), 400,
                      "callback con state invalido")

        # Primer canje: Google no manda refresh token -> hay que avisar, no guardar
        page = get(BASE + "/callback?code=uno&state=" + state).read().decode()
        assert "no devolvio refresh token" in page, page[:400]

        # Segundo: completo
        page = get(BASE + "/callback?code=dos&state=" + state).read().decode()
        assert "Cuenta de Google conectada" in page, page[:400]

        rest = child.stdout.read().strip()
        child.wait(timeout=10)
        assert rest.startswith("TOKENS "), rest
        tokens = json.loads(rest.split(" ", 1)[1])
        assert tokens["refresh_token"] == "rt", tokens
        # El cliente sale junto con los tokens: la shell lo guarda en el keyring
        assert tokens["client_id"] == "id-de-prueba", tokens
        assert tokens["client_secret"] == "secreto-de-prueba", tokens
    finally:
        if child.poll() is None:
            child.kill()

    print("todo bien")
    return 0


if __name__ == "__main__":
    sys.exit(main())
