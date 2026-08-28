#!/usr/bin/env python3
"""
Cliente CalDAV para iCloud: calendario y recordatorios.

Por que CalDAV y no una API: Apple no expone ninguna API publica de iCloud para
apps de terceros. "Sign in with Apple" sirve para loguearte en OTROS sitios, no
para leer tus datos. Lo que si hay son los protocolos abiertos que iCloud habla
de verdad — CalDAV para Calendario y Recordatorios, IMAP para Mail — con una
contrasenia de aplicacion. No es un parche: es la via soportada.

La contrasenia entra por variable de entorno (APPLE_PASSWORD), NUNCA por
argumento: lo que va en argv lo ve cualquiera que corra `ps`.

Comandos:
    verify                              solo comprueba que las credenciales sirvan
    discover                            lista los calendarios y las listas de recordatorios
    events DESDE HASTA [url...]         eventos en el rango (ISO 8601)
    todos [url...]                      recordatorios pendientes y hechos
    todo-set-done URL ETAG true|false   marca o desmarca
    todo-delete URL ETAG                borra
    todo-add CALENDARIO_URL TEXTO       crea uno nuevo

Todo sale como un JSON por stdout: {"ok": true, ...} o {"ok": false, "error": ...}
"""

import base64
import datetime
import json
import os
import ssl
import sys
import urllib.error
import urllib.parse
import urllib.request
import uuid
import xml.etree.ElementTree as ET

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _ical as ical  # noqa: E402

BASE = "https://caldav.icloud.com"
NS = {"d": "DAV:", "c": "urn:ietf:params:xml:ns:caldav",
      "ical": "http://apple.com/ns/ical/"}
TIMEOUT = 30


def emit(payload):
    sys.stdout.write(json.dumps(payload) + "\n")
    sys.stdout.flush()


class DavError(Exception):
    pass


# --------------------------------------------------------------------------- #
# HTTP
# --------------------------------------------------------------------------- #

def request(method, url, body=None, headers=None, user="", password=""):
    token = base64.b64encode(("%s:%s" % (user, password)).encode()).decode()
    all_headers = {
        "Authorization": "Basic " + token,
        "User-Agent": "quickshell-ii/1.0",
    }
    if body is not None:
        all_headers["Content-Type"] = "application/xml; charset=utf-8"
    all_headers.update(headers or {})

    req = urllib.request.Request(
        url, data=body.encode("utf-8") if body else None,
        headers=all_headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT,
                                    context=ssl.create_default_context()) as response:
            return response.status, response.read().decode("utf-8", errors="replace"), \
                dict(response.headers)
    except urllib.error.HTTPError as exc:
        if exc.code == 401:
            raise DavError("iCloud rechazo las credenciales. Acordate de que tiene que "
                           "ser una contrasenia de aplicacion, no la de tu Apple ID.")
        detail = exc.read().decode("utf-8", errors="replace")[:200]
        raise DavError("iCloud respondio %s. %s" % (exc.code, detail.strip()))
    except urllib.error.URLError as exc:
        raise DavError("No se pudo conectar con iCloud: %s" % exc.reason)


def absolute(href, reference):
    """Los href del multistatus suelen venir como ruta; hay que pegarles el host."""
    if not href:
        return ""
    if href.startswith("http"):
        return href
    parts = urllib.parse.urlparse(reference)
    return "%s://%s%s" % (parts.scheme, parts.netloc, href)


def propfind(url, body, depth, user, password):
    status, text, _ = request("PROPFIND", url, body,
                              {"Depth": str(depth)}, user, password)
    if status not in (207, 200):
        raise DavError("PROPFIND devolvio %s" % status)
    return ET.fromstring(text)


# --------------------------------------------------------------------------- #
# Descubrimiento
# --------------------------------------------------------------------------- #

PRINCIPAL_BODY = """<?xml version="1.0" encoding="utf-8"?>
<d:propfind xmlns:d="DAV:"><d:prop><d:current-user-principal/></d:prop></d:propfind>"""

HOME_BODY = """<?xml version="1.0" encoding="utf-8"?>
<d:propfind xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
  <d:prop><c:calendar-home-set/></d:prop>
</d:propfind>"""

CALENDARS_BODY = """<?xml version="1.0" encoding="utf-8"?>
<d:propfind xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav"
            xmlns:ical="http://apple.com/ns/ical/">
  <d:prop>
    <d:displayname/>
    <d:resourcetype/>
    <ical:calendar-color/>
    <c:supported-calendar-component-set/>
  </d:prop>
</d:propfind>"""


def find_principal(user, password):
    tree = propfind(BASE + "/", PRINCIPAL_BODY, 0, user, password)
    node = tree.find(".//d:current-user-principal/d:href", NS)
    if node is None or not (node.text or "").strip():
        raise DavError("iCloud no devolvio el principal de la cuenta")
    return absolute(node.text.strip(), BASE)


def find_home(principal_url, user, password):
    tree = propfind(principal_url, HOME_BODY, 0, user, password)
    node = tree.find(".//c:calendar-home-set/d:href", NS)
    if node is None or not (node.text or "").strip():
        raise DavError("iCloud no devolvio la carpeta de calendarios")
    return absolute(node.text.strip(), principal_url)


def list_calendars(user, password):
    principal = find_principal(user, password)
    home = find_home(principal, user, password)
    tree = propfind(home, CALENDARS_BODY, 1, user, password)

    calendars = []
    for response in tree.findall("d:response", NS):
        href_node = response.find("d:href", NS)
        if href_node is None:
            continue
        url = absolute((href_node.text or "").strip(), home)
        if url.rstrip("/") == home.rstrip("/"):
            continue  # la carpeta misma, no un calendario

        if response.find(".//d:resourcetype/c:calendar", NS) is None:
            continue  # cuadernos, adjuntos y demas cosas que no son calendarios

        name_node = response.find(".//d:displayname", NS)
        color_node = response.find(".//ical:calendar-color", NS)

        # Un calendario sirve para eventos, para recordatorios, o para ambos.
        # Sin esta distincion los recordatorios aparecerian como eventos de las
        # 00:00 en la grilla, que es exactamente lo que no queremos.
        comps = [c.get("name", "").upper() for c in
                 response.findall(".//c:supported-calendar-component-set/c:comp", NS)]
        if not comps:
            comps = ["VEVENT"]

        color = (color_node.text or "").strip() if color_node is not None else ""
        if len(color) == 9 and color.startswith("#"):
            color = color[:7]  # iCloud manda #RRGGBBAA y QML espera #RRGGBB

        calendars.append({
            "url": url,
            "name": (name_node.text or "").strip() if name_node is not None else "iCloud",
            "color": color,
            "events": "VEVENT" in comps,
            "todos": "VTODO" in comps,
        })
    return calendars


# --------------------------------------------------------------------------- #
# Eventos
# --------------------------------------------------------------------------- #

def dav_stamp(moment):
    return moment.astimezone(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ")


def events_body(start, end):
    # `expand` le pide al servidor que resuelva las repeticiones el mismo. iCloud
    # suele hacerlo; si no, abajo se expanden a mano con _ical.expand_rrule.
    return """<?xml version="1.0" encoding="utf-8"?>
<c:calendar-query xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
  <d:prop>
    <d:getetag/>
    <c:calendar-data>
      <c:expand start="%s" end="%s"/>
    </c:calendar-data>
  </d:prop>
  <c:filter>
    <c:comp-filter name="VCALENDAR">
      <c:comp-filter name="VEVENT">
        <c:time-range start="%s" end="%s"/>
      </c:comp-filter>
    </c:comp-filter>
  </c:filter>
</c:calendar-query>""" % (dav_stamp(start), dav_stamp(end),
                          dav_stamp(start), dav_stamp(end))


TODOS_BODY = """<?xml version="1.0" encoding="utf-8"?>
<c:calendar-query xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
  <d:prop>
    <d:getetag/>
    <c:calendar-data/>
  </d:prop>
  <c:filter>
    <c:comp-filter name="VCALENDAR">
      <c:comp-filter name="VTODO"/>
    </c:comp-filter>
  </c:filter>
</c:calendar-query>"""


def report(url, body, user, password):
    status, text, _ = request("REPORT", url, body,
                              {"Depth": "1"}, user, password)
    if status not in (207, 200):
        raise DavError("REPORT devolvio %s" % status)
    tree = ET.fromstring(text)
    out = []
    for response in tree.findall("d:response", NS):
        href_node = response.find("d:href", NS)
        etag_node = response.find(".//d:getetag", NS)
        data_node = response.find(".//c:calendar-data", NS)
        if data_node is None or not (data_node.text or "").strip():
            continue
        out.append({
            "url": absolute((href_node.text or "").strip(), url) if href_node is not None else "",
            "etag": (etag_node.text or "").strip() if etag_node is not None else "",
            "ics": data_node.text,
        })
    return out


def to_epoch(value):
    aware = ical.as_aware(value)
    return aware.timestamp() if aware else 0


def event_payload(component, start, end, all_day, calendar):
    return {
        "uid": ical.unescape(ical.first(component, "UID")),
        "summary": ical.unescape(ical.first(component, "SUMMARY")) or "(sin titulo)",
        "location": ical.unescape(ical.first(component, "LOCATION")),
        "allDay": all_day,
        # Los de todo el dia van como fecha suelta; los demas como epoch. Asi el
        # lado QML no tiene que adivinar zonas horarias.
        "start": start.strftime("%Y-%m-%d") if all_day else to_epoch(start),
        "end": end.strftime("%Y-%m-%d") if all_day else to_epoch(end),
        "calendarName": calendar["name"],
        "color": calendar["color"],
    }


def collect_events(calendars, start, end, user, password):
    window_start = start.astimezone()
    window_end = end.astimezone()
    events = []

    for calendar in calendars:
        try:
            entries = report(calendar["url"], events_body(start, end), user, password)
        except DavError as exc:
            # Que un calendario falle no puede dejarte sin los otros
            sys.stderr.write("[caldav] %s: %s\n" % (calendar["name"], exc))
            continue

        for entry in entries:
            for component in ical.parse_components(entry["ics"], "VEVENT"):
                dt_start, all_day = ical.parse_dt(
                    ical.first(component, "DTSTART"),
                    ical.first_params(component, "DTSTART"))
                if dt_start is None:
                    continue

                dt_end, _ = ical.parse_dt(
                    ical.first(component, "DTEND"),
                    ical.first_params(component, "DTEND"))
                if dt_end is None:
                    dt_end = dt_start
                span = None
                if isinstance(dt_end, datetime.datetime) and isinstance(dt_start, datetime.datetime):
                    span = dt_end - dt_start
                elif isinstance(dt_start, datetime.date):
                    span = (dt_end - dt_start) if isinstance(dt_end, datetime.date) \
                        else datetime.timedelta(days=1)

                rrule = ical.first(component, "RRULE")
                if not rrule:
                    starts = [dt_start]
                else:
                    # Si el servidor ya expandio, cada entry trae una sola
                    # instancia sin RRULE. Esto es el plan B.
                    exdates = set()
                    for params, value in component.get("EXDATE", []):
                        for piece in value.split(","):
                            exdates.add(piece.strip().rstrip("Z"))
                    starts = ical.expand_rrule(
                        dt_start, ical.parse_rrule(rrule),
                        window_start, window_end, exdates)

                for instance in starts:
                    instance_end = instance + span if span is not None else instance
                    events.append(event_payload(component, instance, instance_end,
                                                all_day, calendar))
    return events


# --------------------------------------------------------------------------- #
# Recordatorios
# --------------------------------------------------------------------------- #

def collect_todos(calendars, user, password):
    todos = []
    for calendar in calendars:
        try:
            entries = report(calendar["url"], TODOS_BODY, user, password)
        except DavError as exc:
            sys.stderr.write("[caldav] %s: %s\n" % (calendar["name"], exc))
            continue

        for entry in entries:
            for component in ical.parse_components(entry["ics"], "VTODO"):
                summary = ical.unescape(ical.first(component, "SUMMARY")).strip()
                if not summary:
                    continue
                status = ical.first(component, "STATUS").upper()
                due_value, due_all_day = ical.parse_dt(
                    ical.first(component, "DUE"),
                    ical.first_params(component, "DUE"))
                todos.append({
                    "content": summary,
                    "done": status == "COMPLETED",
                    "url": entry["url"],
                    "etag": entry["etag"],
                    "listName": calendar["name"],
                    "due": to_epoch(due_value) if due_value else 0,
                    "dueAllDay": due_all_day,
                })
    return todos


def patch_todo_ics(text, done):
    """
    Reescribe STATUS/COMPLETED/PERCENT-COMPLETE del VTODO conservando todo lo
    demas. Se edita el ICS original en vez de generar uno nuevo para no perder
    campos que no entendemos (alarmas, geo, la lista de compartidos).
    """
    lines = [l for l in ical.unfold(text).split("\n") if l.strip()]
    out = []
    inside = False
    for line in lines:
        name, _, value = ical.split_line(line)
        if name == "BEGIN" and value.strip().upper() == "VTODO":
            inside = True
            out.append(line)
            continue
        if name == "END" and value.strip().upper() == "VTODO":
            if done:
                out.append("STATUS:COMPLETED")
                out.append("PERCENT-COMPLETE:100")
                out.append("COMPLETED:" + datetime.datetime.now(datetime.timezone.utc)
                           .strftime("%Y%m%dT%H%M%SZ"))
            else:
                out.append("STATUS:NEEDS-ACTION")
                out.append("PERCENT-COMPLETE:0")
            out.append(line)
            inside = False
            continue
        if inside and name in ("STATUS", "COMPLETED", "PERCENT-COMPLETE"):
            continue  # se reescriben arriba
        out.append(line)
    return "\r\n".join(out) + "\r\n"


def set_todo_done(url, etag, done, user, password):
    status, text, _ = request("GET", url, None, {}, user, password)
    if status != 200:
        raise DavError("No se pudo leer el recordatorio (%s)" % status)
    updated = patch_todo_ics(text, done)

    headers = {"Content-Type": "text/calendar; charset=utf-8"}
    if etag:
        # Si alguien lo cambio desde el iPhone mientras tanto, el PUT falla en vez
        # de pisar el cambio del otro lado
        headers["If-Match"] = etag
    status, _, response_headers = request("PUT", url, updated, headers, user, password)
    if status not in (200, 201, 204):
        raise DavError("No se pudo guardar el recordatorio (%s)" % status)
    return response_headers.get("ETag", "")


def delete_todo(url, etag, user, password):
    headers = {}
    if etag:
        headers["If-Match"] = etag
    status, _, _ = request("DELETE", url, None, headers, user, password)
    if status not in (200, 204):
        raise DavError("No se pudo borrar el recordatorio (%s)" % status)


def escape_text(value):
    return (value.replace("\\", "\\\\").replace(";", "\\;")
            .replace(",", "\\,").replace("\n", "\\n"))


def add_todo(calendar_url, summary, user, password):
    uid = str(uuid.uuid4()).upper()
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    ics = "\r\n".join([
        "BEGIN:VCALENDAR",
        "VERSION:2.0",
        "PRODID:-//quickshell-ii//ES",
        "BEGIN:VTODO",
        "UID:" + uid,
        "DTSTAMP:" + stamp,
        "SUMMARY:" + escape_text(summary),
        "STATUS:NEEDS-ACTION",
        "PERCENT-COMPLETE:0",
        "END:VTODO",
        "END:VCALENDAR",
        "",
    ])
    url = calendar_url.rstrip("/") + "/" + uid + ".ics"
    status, _, headers = request("PUT", url, ics,
                                 {"Content-Type": "text/calendar; charset=utf-8",
                                  "If-None-Match": "*"}, user, password)
    if status not in (200, 201, 204):
        raise DavError("No se pudo crear el recordatorio (%s)" % status)
    return {"url": url, "etag": headers.get("ETag", ""), "uid": uid}


# --------------------------------------------------------------------------- #

def parse_iso(value):
    text = value.strip().replace("Z", "+00:00")
    moment = datetime.datetime.fromisoformat(text)
    return moment if moment.tzinfo else moment.astimezone()


def main():
    if len(sys.argv) < 2:
        emit({"ok": False, "error": "Falta el comando"})
        return 1

    user = os.environ.get("APPLE_ID", "").strip()
    password = os.environ.get("APPLE_PASSWORD", "")
    if not user or not password:
        emit({"ok": False, "error": "Faltan el Apple ID y/o la contrasenia de aplicacion"})
        return 1

    command = sys.argv[1]
    args = sys.argv[2:]

    try:
        if command == "verify":
            calendars = list_calendars(user, password)
            emit({"ok": True, "calendars": len(calendars)})

        elif command == "discover":
            emit({"ok": True, "calendars": list_calendars(user, password)})

        elif command == "events":
            if len(args) < 2:
                emit({"ok": False, "error": "Faltan el desde y el hasta"})
                return 1
            start, end = parse_iso(args[0]), parse_iso(args[1])
            wanted = set(args[2:])
            calendars = [c for c in list_calendars(user, password)
                         if c["events"] and (not wanted or c["url"] in wanted)]
            emit({"ok": True, "events": collect_events(calendars, start, end, user, password)})

        elif command == "todos":
            wanted = set(args)
            calendars = [c for c in list_calendars(user, password)
                         if c["todos"] and (not wanted or c["url"] in wanted)]
            emit({"ok": True, "todos": collect_todos(calendars, user, password)})

        elif command == "todo-set-done":
            if len(args) < 3:
                emit({"ok": False, "error": "Faltan url, etag y estado"})
                return 1
            etag = set_todo_done(args[0], args[1], args[2].lower() == "true", user, password)
            emit({"ok": True, "etag": etag})

        elif command == "todo-delete":
            if not args:
                emit({"ok": False, "error": "Falta la url"})
                return 1
            delete_todo(args[0], args[1] if len(args) > 1 else "", user, password)
            emit({"ok": True})

        elif command == "todo-add":
            if len(args) < 2:
                emit({"ok": False, "error": "Faltan el calendario y el texto"})
                return 1
            created = add_todo(args[0], " ".join(args[1:]), user, password)
            emit({"ok": True, "todo": created})

        else:
            emit({"ok": False, "error": "Comando desconocido: %s" % command})
            return 1

    except DavError as exc:
        emit({"ok": False, "error": str(exc)})
        return 1
    except ET.ParseError as exc:
        emit({"ok": False, "error": "iCloud devolvio algo que no es XML: %s" % exc})
        return 1
    except Exception as exc:  # noqa: BLE001
        emit({"ok": False, "error": "%s: %s" % (type(exc).__name__, exc)})
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
