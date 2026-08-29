#!/usr/bin/env python3
"""
Cuantos mails sin leer hay y de quien, por IMAP.

IMAP y no OAuth a proposito: una contrasenia de aplicacion no vence nunca, no
depende de que Google apruebe la app, y el mismo script sirve para iCloud
cambiando el host. Con OAuth, el contador de no leidos necesitaria el scope
gmail.readonly, que Google clasifica como "restricted" — el mas sensible que hay,
sujeto a verificacion, para mostrar un numerito.

    Gmail:  imap.gmail.com    puerto 993   SSL       · clave en myaccount.google.com/apppasswords
    iCloud: imap.mail.me.com  puerto 993   SSL       · clave en appleid.apple.com
    Proton: 127.0.0.1         puerto 1143  STARTTLS  · clave que muestra Proton Mail Bridge

Proton es el raro de los tres: no expone IMAP a internet. Todo pasa por Proton
Mail Bridge, que corre en tu maquina, hace el descifrado local y levanta un IMAP
en loopback con STARTTLS y un certificado que se genera el mismo. Contra ese
certificado no hay CA que valga, asi que la verificacion se saltea — pero solo
en loopback, donde no hay nada que interceptar: el trafico no sale de la maquina.

La contrasenia entra por la variable de entorno MAIL_PASSWORD, NO por argumento:
lo que va en argv lo ve cualquiera que corra `ps` en la maquina.

El buzon se abre en modo lectura (readonly=True). Sin eso, mirar los encabezados
marcaria los mensajes como leidos — el widget te vaciaria la bandeja solo.

Salida: un JSON por stdout.
    {"ok": true, "unread": 3, "messages": [{"from":..., "subject":..., "date":...}]}
    {"ok": false, "error": "texto", "kind": "auth" | "network" | "config" | "unknown"}

`kind` es para que el lado QML (MailService.qml) sepa si vale la pena
reintentar solo (network: un corte de red, un timeout) o si hace falta que
el usuario reconecte la cuenta a mano (auth: la contrasenia de aplicacion
dejo de servir, o nunca fue una). Reintentar auth en loop no arregla nada y
solo le pega al servidor.

Uso: imap.py HOST PUERTO USUARIO [BUZON] [MAX_MENSAJES] [SEGURIDAD]
     SEGURIDAD: ssl (por defecto) | starttls
"""

import email.header
import email.utils
import imaplib
import json
import os
import ssl
import sys


def emit(payload):
    sys.stdout.write(json.dumps(payload) + "\n")
    sys.stdout.flush()


def is_loopback(host):
    return str(host).strip().lower() in ("127.0.0.1", "::1", "localhost")


def open_mailbox(host, port, user, password, mailbox="INBOX", security="ssl",
                 timeout=25):
    """
    Conecta, entra y abre el buzon en modo lectura. Devuelve la conexion.

    `readonly=True` no es un detalle: sin eso, mirar los encabezados marcaria los
    mensajes como leidos y el widget te vaciaria la bandeja solo.

    Lo usa tambien scripts/accounts/connect.py para verificar una credencial
    antes de guardarla: una sola forma de conectarse, y no dos que se
    desincronizan.
    """
    context = ssl.create_default_context()
    if is_loopback(host):
        # El certificado de Proton Mail Bridge se lo genera el mismo en cada
        # instalacion: no hay CA que lo firme. En loopback no hay nada en el
        # medio que interceptar, asi que verificarlo no aporta seguridad.
        context.check_hostname = False
        context.verify_mode = ssl.CERT_NONE

    if str(security).lower() == "starttls":
        conn = imaplib.IMAP4(host, port, timeout=timeout)
        conn.starttls(context)
    else:
        conn = imaplib.IMAP4_SSL(host, port, ssl_context=context, timeout=timeout)

    try:
        conn.login(user, password)
        status, _ = conn.select(f'"{mailbox}"', readonly=True)
        if status != "OK":
            raise imaplib.IMAP4.error("no se pudo abrir el buzon %s" % mailbox)
    except Exception:
        close_quietly(conn)
        raise
    return conn


def close_quietly(conn):
    if conn is None:
        return
    try:
        conn.close()
    except Exception:  # noqa: BLE001 - puede no haber buzon abierto
        pass
    try:
        conn.logout()
    except Exception:  # noqa: BLE001
        pass


def decode(raw):
    """Los encabezados vienen en MIME encoded-word (=?utf-8?B?...?=) mas de lo que uno cree."""
    if raw is None:
        return ""
    parts = []
    for chunk, charset in email.header.decode_header(raw):
        if isinstance(chunk, bytes):
            try:
                parts.append(chunk.decode(charset or "utf-8", errors="replace"))
            except LookupError:  # charset inventado por algun cliente
                parts.append(chunk.decode("utf-8", errors="replace"))
        else:
            parts.append(chunk)
    return "".join(parts).strip()


def pretty_sender(raw):
    """"Fulano <f@x.com>" -> "Fulano". Sin nombre, queda la direccion."""
    name, address = email.utils.parseaddr(decode(raw))
    return name if name else address


def main():
    if len(sys.argv) < 4:
        emit({"ok": False, "error": "Faltan host, puerto y usuario"})
        return 1

    host = sys.argv[1].strip()
    try:
        port = int(sys.argv[2])
    except ValueError:
        emit({"ok": False, "error": "Puerto invalido"})
        return 1
    user = sys.argv[3].strip()
    mailbox = sys.argv[4] if len(sys.argv) > 4 and sys.argv[4].strip() else "INBOX"
    try:
        limit = int(sys.argv[5]) if len(sys.argv) > 5 else 15
    except ValueError:
        limit = 15

    security = sys.argv[6] if len(sys.argv) > 6 and sys.argv[6].strip() else "ssl"

    password = os.environ.get("MAIL_PASSWORD", "")
    if not password:
        emit({"ok": False, "error": "Falta la contrasenia de aplicacion", "kind": "config"})
        return 1

    conn = None
    try:
        conn = open_mailbox(host, port, user, password, mailbox, security)

        typ, data = conn.search(None, "UNSEEN")
        if typ != "OK":
            emit({"ok": False, "error": "El servidor rechazo la busqueda"})
            return 1

        ids = data[0].split() if data and data[0] else []
        unread = len(ids)

        # Los mas nuevos primero; solo se bajan los encabezados de unos pocos,
        # el contador de arriba ya es exacto para todos.
        wanted = ids[-limit:][::-1]
        messages = []
        for msg_id in wanted:
            typ, fetched = conn.fetch(
                msg_id, "(BODY.PEEK[HEADER.FIELDS (FROM SUBJECT DATE)])")
            if typ != "OK" or not fetched or not isinstance(fetched[0], tuple):
                continue
            headers = email.message_from_bytes(fetched[0][1])
            date_raw = headers.get("Date")
            try:
                stamp = email.utils.parsedate_to_datetime(date_raw).timestamp()
            except Exception:  # noqa: BLE001 - fecha rota no invalida el mensaje
                stamp = 0
            messages.append({
                "from": pretty_sender(headers.get("From")),
                "subject": decode(headers.get("Subject")) or "(sin asunto)",
                "timestamp": stamp,
            })

        emit({"ok": True, "unread": unread, "messages": messages})
        return 0

    except imaplib.IMAP4.error as exc:
        # El caso tipico: contrasenia normal en vez de contrasenia de aplicacion,
        # o una contrasenia de aplicacion que Google/Apple ya revoco. No se
        # arregla solo: reintentar en loop no sirve de nada.
        emit({"ok": False, "error": "El servidor rechazo el login: %s" % exc, "kind": "auth"})
        return 1
    except (OSError, ssl.SSLError) as exc:
        # Corte de red, DNS, timeout: pasajero. Vale la pena reintentar pronto.
        emit({"ok": False, "error": "No se pudo conectar a %s: %s" % (host, exc), "kind": "network"})
        return 1
    except Exception as exc:  # noqa: BLE001
        emit({"ok": False, "error": str(exc), "kind": "unknown"})
        return 1
    finally:
        close_quietly(conn)


if __name__ == "__main__":
    sys.exit(main())
