#!/usr/bin/env python3
"""
Pruebas de caldav.py contra un iCloud de mentira.

    python3 ~/.config/quickshell/ii/scripts/apple/test_caldav.py

No hay forma de probar esto contra iCloud de verdad sin las credenciales del
usuario, asi que se reemplaza la capa HTTP por respuestas grabadas con la forma
exacta que devuelve iCloud. Eso cubre todo lo que puede romperse del lado
nuestro: armado del XML, lectura del multistatus, parseo del ICS, y el
ida y vuelta de marcar un recordatorio como hecho.

Lo unico que queda sin verificar es que iCloud conteste lo que decimos que
contesta. Ahi ya hay que conectar una cuenta de verdad.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import caldav  # noqa: E402

FALLAS = []
PEDIDOS = []


def check(nombre, obtenido, esperado):
    if obtenido != esperado:
        FALLAS.append("%s\n    esperado: %r\n    obtenido: %r" % (nombre, esperado, obtenido))


def check_true(nombre, condicion):
    if not condicion:
        FALLAS.append(nombre)


# --------------------------------------------------------------------------- #
# El iCloud de mentira
# --------------------------------------------------------------------------- #

PRINCIPAL = """<?xml version="1.0"?>
<multistatus xmlns="DAV:"><response>
  <href>/</href><propstat><prop>
    <current-user-principal><href>/1234567/principal/</href></current-user-principal>
  </prop><status>HTTP/1.1 200 OK</status></propstat>
</response></multistatus>"""

HOME = """<?xml version="1.0"?>
<multistatus xmlns="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav"><response>
  <href>/1234567/principal/</href><propstat><prop>
    <C:calendar-home-set><href>/1234567/calendars/</href></C:calendar-home-set>
  </prop><status>HTTP/1.1 200 OK</status></propstat>
</response></multistatus>"""

CALENDARIOS = """<?xml version="1.0"?>
<multistatus xmlns="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav"
             xmlns:IC="http://apple.com/ns/ical/">
  <response>
    <href>/1234567/calendars/</href>
    <propstat><prop><resourcetype><collection/></resourcetype></prop></propstat>
  </response>
  <response>
    <href>/1234567/calendars/home/</href>
    <propstat><prop>
      <displayname>Personal</displayname>
      <resourcetype><collection/><C:calendar/></resourcetype>
      <IC:calendar-color>#FF2D55FF</IC:calendar-color>
      <C:supported-calendar-component-set><C:comp name="VEVENT"/></C:supported-calendar-component-set>
    </prop></propstat>
  </response>
  <response>
    <href>/1234567/calendars/tareas/</href>
    <propstat><prop>
      <displayname>Recordatorios</displayname>
      <resourcetype><collection/><C:calendar/></resourcetype>
      <IC:calendar-color>#34C759</IC:calendar-color>
      <C:supported-calendar-component-set><C:comp name="VTODO"/></C:supported-calendar-component-set>
    </prop></propstat>
  </response>
  <response>
    <href>/1234567/calendars/notes/</href>
    <propstat><prop>
      <displayname>Notas</displayname>
      <resourcetype><collection/></resourcetype>
    </prop></propstat>
  </response>
</multistatus>"""

EVENTOS = """<?xml version="1.0"?>
<multistatus xmlns="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
  <response>
    <href>/1234567/calendars/home/uno.ics</href>
    <propstat><prop>
      <getetag>"aaa"</getetag>
      <C:calendar-data>BEGIN:VCALENDAR
BEGIN:VEVENT
UID:uno
SUMMARY:Reunion de equipo
LOCATION:Sala 2
DTSTART;TZID=America/Santiago:20260901T100000
DTEND;TZID=America/Santiago:20260901T110000
END:VEVENT
END:VCALENDAR</C:calendar-data>
    </prop></propstat>
  </response>
  <response>
    <href>/1234567/calendars/home/dos.ics</href>
    <propstat><prop>
      <getetag>"bbb"</getetag>
      <C:calendar-data>BEGIN:VCALENDAR
BEGIN:VEVENT
UID:dos
SUMMARY:Feriado
DTSTART;VALUE=DATE:20260918
DTEND;VALUE=DATE:20260920
END:VEVENT
END:VCALENDAR</C:calendar-data>
    </prop></propstat>
  </response>
  <response>
    <href>/1234567/calendars/home/tres.ics</href>
    <propstat><prop>
      <getetag>"ccc"</getetag>
      <C:calendar-data>BEGIN:VCALENDAR
BEGIN:VEVENT
UID:tres
SUMMARY:Gimnasio
DTSTART;TZID=America/Santiago:20260907T070000
DTEND;TZID=America/Santiago:20260907T080000
RRULE:FREQ=WEEKLY;BYDAY=MO,WE;COUNT=4
END:VEVENT
END:VCALENDAR</C:calendar-data>
    </prop></propstat>
  </response>
</multistatus>"""

RECORDATORIOS = """<?xml version="1.0"?>
<multistatus xmlns="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
  <response>
    <href>/1234567/calendars/tareas/a.ics</href>
    <propstat><prop>
      <getetag>"t1"</getetag>
      <C:calendar-data>BEGIN:VCALENDAR
BEGIN:VTODO
UID:t1
SUMMARY:Comprar pan
STATUS:NEEDS-ACTION
END:VTODO
END:VCALENDAR</C:calendar-data>
    </prop></propstat>
  </response>
  <response>
    <href>/1234567/calendars/tareas/b.ics</href>
    <propstat><prop>
      <getetag>"t2"</getetag>
      <C:calendar-data>BEGIN:VCALENDAR
BEGIN:VTODO
UID:t2
SUMMARY:Llamar al dentista
STATUS:COMPLETED
COMPLETED:20260820T120000Z
END:VTODO
END:VCALENDAR</C:calendar-data>
    </prop></propstat>
  </response>
  <response>
    <href>/1234567/calendars/tareas/vacio.ics</href>
    <propstat><prop>
      <getetag>"t3"</getetag>
      <C:calendar-data>BEGIN:VCALENDAR
BEGIN:VTODO
UID:t3
SUMMARY:
END:VTODO
END:VCALENDAR</C:calendar-data>
    </prop></propstat>
  </response>
</multistatus>"""

ICS_SUELTO = """BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VTODO
UID:t1
SUMMARY:Comprar pan
STATUS:NEEDS-ACTION
PERCENT-COMPLETE:0
X-APPLE-COSA:no me borres
END:VTODO
END:VCALENDAR"""


def fake_request(method, url, body=None, headers=None, user="", password=""):
    PEDIDOS.append({"method": method, "url": url, "body": body,
                    "headers": headers or {}})
    if method == "PROPFIND":
        if url.endswith("caldav.icloud.com/"):
            return 207, PRINCIPAL, {}
        if "principal" in url:
            return 207, HOME, {}
        return 207, CALENDARIOS, {}
    if method == "REPORT":
        return (207, RECORDATORIOS, {}) if "tareas" in url else (207, EVENTOS, {})
    if method == "GET":
        return 200, ICS_SUELTO, {}
    if method in ("PUT", "DELETE"):
        return 204, "", {"ETag": '"nuevo"'}
    raise AssertionError("metodo inesperado: " + method)


caldav.request = fake_request


# --------------------------------------------------------------------------- #
# Descubrimiento
# --------------------------------------------------------------------------- #

calendarios = caldav.list_calendars("yo@icloud.com", "clave")

check("descubre 2 calendarios y descarta las Notas", len(calendarios), 2)
check("el href relativo se vuelve absoluto",
      calendarios[0]["url"], "https://caldav.icloud.com/1234567/calendars/home/")
check("nombre", calendarios[0]["name"], "Personal")
check("el color #RRGGBBAA de iCloud se recorta a #RRGGBB",
      calendarios[0]["color"], "#FF2D55")
check("el color que ya venia de 7 no se toca", calendarios[1]["color"], "#34C759")
check("Personal es de eventos, no de recordatorios",
      (calendarios[0]["events"], calendarios[0]["todos"]), (True, False))
check("Recordatorios es de tareas, no de eventos",
      (calendarios[1]["events"], calendarios[1]["todos"]), (False, True))


# --------------------------------------------------------------------------- #
# Eventos
# --------------------------------------------------------------------------- #

desde = caldav.parse_iso("2026-09-01T00:00:00")
hasta = caldav.parse_iso("2026-09-30T23:59:59")
solo_eventos = [c for c in calendarios if c["events"]]
eventos = caldav.collect_events(solo_eventos, desde, hasta, "yo", "clave")

por_uid = {}
for e in eventos:
    por_uid.setdefault(e["uid"], []).append(e)

check("tres eventos distintos", sorted(por_uid), ["dos", "tres", "uno"])

reunion = por_uid["uno"][0]
check("evento con hora: no es de todo el dia", reunion["allDay"], False)
check("evento con hora: start es epoch", isinstance(reunion["start"], float), True)
check("lugar", reunion["location"], "Sala 2")
check("hereda el color del calendario", reunion["color"], "#FF2D55")
check("hereda el nombre del calendario", reunion["calendarName"], "Personal")
check("dura una hora", reunion["end"] - reunion["start"], 3600.0)

feriado = por_uid["dos"][0]
check("evento de dia completo", feriado["allDay"], True)
check("start va como fecha suelta", feriado["start"], "2026-09-18")
check("y conserva el end exclusivo tal como vino", feriado["end"], "2026-09-20")

gimnasio = por_uid["tres"]
check("la recurrencia se expande a 4", len(gimnasio), 4)
check("todas duran una hora",
      sorted(set(g["end"] - g["start"] for g in gimnasio)), [3600.0])
check_true("las 4 caen dentro de la ventana pedida",
           all(desde.timestamp() <= g["start"] <= hasta.timestamp() for g in gimnasio))

reportes = [p for p in PEDIDOS if p["method"] == "REPORT"]
check_true("el REPORT pide expand al servidor", "<c:expand" in reportes[0]["body"])
check_true("el REPORT filtra por rango", "<c:time-range" in reportes[0]["body"])
check_true("el rango se manda en UTC", "20260901T" in reportes[0]["body"])


# --------------------------------------------------------------------------- #
# Recordatorios
# --------------------------------------------------------------------------- #

solo_todos = [c for c in calendarios if c["todos"]]
todos = caldav.collect_todos(solo_todos, "yo", "clave")

check("dos recordatorios; el de titulo vacio se descarta", len(todos), 2)
check("pendiente", (todos[0]["content"], todos[0]["done"]), ("Comprar pan", False))
check("hecho", (todos[1]["content"], todos[1]["done"]), ("Llamar al dentista", True))
check("trae el etag para poder escribir", todos[0]["etag"], '"t1"')
check("trae el nombre de la lista", todos[0]["listName"], "Recordatorios")


# --------------------------------------------------------------------------- #
# Escritura
# --------------------------------------------------------------------------- #

marcado = caldav.patch_todo_ics(ICS_SUELTO, True)
check_true("marcar pone STATUS:COMPLETED", "STATUS:COMPLETED" in marcado)
check_true("marcar pone el 100%", "PERCENT-COMPLETE:100" in marcado)
check_true("marcar deja fecha de completado", "COMPLETED:" in marcado)
check_true("no queda el STATUS viejo", "STATUS:NEEDS-ACTION" not in marcado)
check_true("no queda el 0% viejo", "PERCENT-COMPLETE:0" not in marcado)
check_true("los campos que no entendemos sobreviven", "X-APPLE-COSA:no me borres" in marcado)
check("STATUS aparece una sola vez", marcado.count("STATUS:"), 1)

desmarcado = caldav.patch_todo_ics(marcado, False)
check_true("desmarcar vuelve a NEEDS-ACTION", "STATUS:NEEDS-ACTION" in desmarcado)
check_true("y saca la fecha de completado", "COMPLETED:" not in desmarcado)
check_true("y sigue conservando lo raro", "X-APPLE-COSA:no me borres" in desmarcado)

PEDIDOS.clear()
caldav.set_todo_done("https://caldav.icloud.com/x/a.ics", '"t1"', True, "yo", "clave")
put = [p for p in PEDIDOS if p["method"] == "PUT"][0]
check("el PUT manda If-Match para no pisar cambios de otro lado",
      put["headers"].get("If-Match"), '"t1"')

PEDIDOS.clear()
creado = caldav.add_todo("https://caldav.icloud.com/x/tareas", "Sacar la basura", "yo", "clave")
put = [p for p in PEDIDOS if p["method"] == "PUT"][0]
check("el alta usa If-None-Match para no pisar uno que ya exista",
      put["headers"].get("If-None-Match"), "*")
check_true("el alta manda un VTODO", "BEGIN:VTODO" in put["body"])
check_true("con el texto pedido", "SUMMARY:Sacar la basura" in put["body"])
check_true("la url del nuevo termina en .ics", creado["url"].endswith(".ics"))


# --------------------------------------------------------------------------- #

if FALLAS:
    print("FALLAS (%d):\n" % len(FALLAS))
    for f in FALLAS:
        print("  " + f + "\n")
    sys.exit(1)
print("todo bien")
