#!/usr/bin/env python3
"""
Prueba del cliente IMAP, sin ningun servidor.

Lo que se comprueba es lo que no se puede ver a simple vista y duele si se
rompe: que el buzon se abra SIEMPRE en modo lectura (si no, mirar el widget te
marca los mensajes como leidos), que Proton use STARTTLS contra el Bridge en
loopback sin verificar su certificado autofirmado, que los demas usen SSL con
verificacion normal, y que una conexion que falla no quede colgada.

Uso: python3 test_imap.py
"""

import os
import ssl
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import imap  # noqa: E402


class FakeIMAP:
    """Anota lo que le van pidiendo, para poder revisarlo despues."""

    def __init__(self, host, port, timeout=None, ssl_context=None):
        self.host = host
        self.port = port
        self.ssl_context = ssl_context
        self.starttls_context = None
        self.logged_in = None
        self.selected = None
        self.readonly = None
        self.closed = False
        self.logged_out = False
        self.fail_login = False

    def starttls(self, context):
        self.starttls_context = context

    def login(self, user, password):
        if self.fail_login:
            raise imap.imaplib.IMAP4.error("AUTHENTICATIONFAILED")
        self.logged_in = (user, password)

    def select(self, mailbox, readonly=False):
        self.selected = mailbox
        self.readonly = readonly
        return "OK", [b"7"]

    def close(self):
        self.closed = True

    def logout(self):
        self.logged_out = True


def instalar_fakes(fail_login=False):
    """Reemplaza imaplib por los fakes y devuelve la lista de conexiones creadas."""
    creadas = []

    def constructor(clase):
        def crear(*args, **kwargs):
            conn = FakeIMAP(*args, **kwargs)
            conn.clase = clase
            conn.fail_login = fail_login
            creadas.append(conn)
            return conn
        return crear

    imap.imaplib.IMAP4 = constructor("plano")
    imap.imaplib.IMAP4_SSL = constructor("ssl")
    return creadas


def check(nombre, condicion):
    if not condicion:
        raise AssertionError(nombre)


def main():
    original = (imap.imaplib.IMAP4, imap.imaplib.IMAP4_SSL)
    error_original = imap.imaplib.IMAP4.error
    try:
        # imaplib.IMAP4.error se usa como excepcion: hay que conservarla
        class ErrorFalso(Exception):
            pass

        # --- Proton: loopback + STARTTLS, sin verificar el autofirmado ---
        creadas = instalar_fakes()
        imap.imaplib.IMAP4.error = error_original
        conn = imap.open_mailbox("127.0.0.1", 1143, "yo@proton.me", "clave",
                                 "INBOX", "starttls")
        check("Proton no usa una conexion plana + STARTTLS", conn.clase == "plano")
        check("Proton no hizo STARTTLS", conn.starttls_context is not None)
        check("verifica el certificado autofirmado del Bridge",
              conn.starttls_context.verify_mode == ssl.CERT_NONE)
        check("no desactivo check_hostname en loopback",
              conn.starttls_context.check_hostname is False)
        check("no abrio el buzon en modo lectura", conn.readonly is True)
        check("no abrio INBOX", conn.selected == '"INBOX"')
        check("no inicio sesion", conn.logged_in == ("yo@proton.me", "clave"))

        # --- Gmail: SSL de siempre, con verificacion normal ---
        creadas = instalar_fakes()
        imap.imaplib.IMAP4.error = error_original
        conn = imap.open_mailbox("imap.gmail.com", 993, "yo@gmail.com", "clave")
        check("Gmail no usa IMAP4_SSL", conn.clase == "ssl")
        check("Gmail no deberia hacer STARTTLS", conn.starttls_context is None)
        check("Gmail perdio la verificacion del certificado",
              conn.ssl_context.verify_mode == ssl.CERT_REQUIRED)
        check("Gmail no abrio en modo lectura", conn.readonly is True)

        # --- Un login que falla no puede dejar la conexion abierta ---
        creadas = instalar_fakes(fail_login=True)
        imap.imaplib.IMAP4.error = error_original
        try:
            imap.open_mailbox("imap.gmail.com", 993, "yo@gmail.com", "mala")
            raise AssertionError("un login rechazado no levanto excepcion")
        except error_original:
            pass
        check("la conexion fallida quedo colgada",
              creadas[0].closed and creadas[0].logged_out)

        # --- is_loopback ---
        for host in ("127.0.0.1", "::1", "localhost", "LOCALHOST"):
            check("no reconoce %s como loopback" % host, imap.is_loopback(host))
        for host in ("imap.gmail.com", "imap.mail.me.com", "10.0.0.1"):
            check("cree que %s es loopback" % host, not imap.is_loopback(host))
    finally:
        imap.imaplib.IMAP4, imap.imaplib.IMAP4_SSL = original
        imap.imaplib.IMAP4.error = error_original

    print("todo bien")
    return 0


if __name__ == "__main__":
    sys.exit(main())
