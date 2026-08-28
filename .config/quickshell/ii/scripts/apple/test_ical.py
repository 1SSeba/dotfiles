#!/usr/bin/env python3
"""
Pruebas de _ical.py. Se corren asi:

    python3 ~/.config/quickshell/ii/scripts/apple/test_ical.py

Es lo unico del lado CalDAV que se puede verificar sin credenciales de iCloud:
el parseo de iCalendar y la expansion de recurrencias no necesitan red, y son
justo donde estan los errores que despues aparecen como "el cumpleanios de mi
vieja cae un dia antes".
"""

import datetime
import sys

import _ical as ical

FALLAS = []


def check(nombre, obtenido, esperado):
    if obtenido != esperado:
        FALLAS.append("%s\n    esperado: %r\n    obtenido: %r" % (nombre, esperado, obtenido))


def local(y, m, d, hh=0, mm=0):
    return datetime.datetime(y, m, d, hh, mm).astimezone()


# --------------------------------------------------------------------------- #
# Desdoblado y corte de lineas
# --------------------------------------------------------------------------- #

check("unfold junta la continuacion",
      ical.unfold("SUMMARY:Reunion muy\r\n  larga"),
      "SUMMARY:Reunion muy larga")

check("split_line con TZID",
      ical.split_line("DTSTART;TZID=America/Santiago:20260826T090000"),
      ("DTSTART", {"TZID": "America/Santiago"}, "20260826T090000"))

check("split_line: el valor puede tener dos puntos",
      ical.split_line("URL:https://ejemplo.com/x")[2],
      "https://ejemplo.com/x")

check("split_line: parametro entrecomillado con punto y coma adentro",
      ical.split_line('ATTENDEE;CN="Perez; Juan":mailto:j@x.com'),
      ("ATTENDEE", {"CN": "Perez; Juan"}, "mailto:j@x.com"))

check("unescape",
      ical.unescape(r"Uno\, dos\; tres\ncuatro"),
      "Uno, dos; tres\ncuatro")


# --------------------------------------------------------------------------- #
# Componentes
# --------------------------------------------------------------------------- #

ICS_CON_ALARMA = """BEGIN:VCALENDAR
BEGIN:VEVENT
UID:abc-123
SUMMARY:Dentista
DTSTART;TZID=America/Santiago:20260901T143000
DTEND;TZID=America/Santiago:20260901T153000
BEGIN:VALARM
ACTION:DISPLAY
SUMMARY:NO SOY EL EVENTO
TRIGGER:-PT15M
END:VALARM
END:VEVENT
BEGIN:VEVENT
UID:def-456
SUMMARY:Almuerzo
DTSTART;VALUE=DATE:20260902
END:VEVENT
END:VCALENDAR"""

eventos = ical.parse_components(ICS_CON_ALARMA, "VEVENT")
check("parse_components encuentra los dos eventos", len(eventos), 2)
check("el SUMMARY del VALARM no pisa al del evento",
      ical.first(eventos[0], "SUMMARY"), "Dentista")
check("el TRIGGER del VALARM no se cuela en el evento",
      "TRIGGER" in eventos[0], False)
check("segundo evento", ical.first(eventos[1], "SUMMARY"), "Almuerzo")


# --------------------------------------------------------------------------- #
# Fechas
# --------------------------------------------------------------------------- #

valor, todo_el_dia = ical.parse_dt("20260902", {"VALUE": "DATE"})
check("DATE da un date", (valor, todo_el_dia), (datetime.date(2026, 9, 2), True))

valor, todo_el_dia = ical.parse_dt("20260902", {})
check("ocho digitos sin VALUE=DATE tambien es todo el dia",
      (valor, todo_el_dia), (datetime.date(2026, 9, 2), True))

valor, todo_el_dia = ical.parse_dt("20260826T120000Z", {})
check("la Z es UTC",
      (valor.utcoffset(), todo_el_dia), (datetime.timedelta(0), False))

valor, _ = ical.parse_dt("20260826T090000", {"TZID": "America/Santiago"})
check("el TZID se respeta", str(valor.tzinfo), "America/Santiago")

valor, _ = ical.parse_dt("basura", {})
check("una fecha rota no explota, devuelve None", valor, None)


# --------------------------------------------------------------------------- #
# Recurrencias
# --------------------------------------------------------------------------- #

ventana_ini = local(2026, 1, 1)
ventana_fin = local(2027, 12, 31)

# Diaria con tope
inicio = local(2026, 8, 26, 9, 0)
salida = ical.expand_rrule(inicio, ical.parse_rrule("FREQ=DAILY;COUNT=3"),
                           ventana_ini, ventana_fin, set())
check("diaria con COUNT=3 da 3", len(salida), 3)
check("diaria: los dias son consecutivos",
      [d.day for d in salida], [26, 27, 28])

# Cada dos dias
salida = ical.expand_rrule(inicio, ical.parse_rrule("FREQ=DAILY;INTERVAL=2;COUNT=3"),
                           ventana_ini, ventana_fin, set())
check("INTERVAL=2 saltea un dia", [d.day for d in salida], [26, 28, 30])

# Semanal los lunes y miercoles
inicio_lunes = local(2026, 8, 31, 10, 0)   # 31/8/2026 es lunes
salida = ical.expand_rrule(inicio_lunes, ical.parse_rrule("FREQ=WEEKLY;BYDAY=MO,WE;COUNT=4"),
                           ventana_ini, ventana_fin, set())
check("semanal con BYDAY da 4", len(salida), 4)
check("semanal con BYDAY cae lunes y miercoles",
      sorted(set(d.weekday() for d in salida)), [0, 2])

# Mensual que arranca un 31: los meses de 30 no tienen instancia
inicio_31 = local(2026, 1, 31, 8, 0)
salida = ical.expand_rrule(inicio_31, ical.parse_rrule("FREQ=MONTHLY;COUNT=5"),
                           ventana_ini, ventana_fin, set())
check("mensual desde el 31 salta los meses cortos",
      [(d.month, d.day) for d in salida],
      [(1, 31), (3, 31), (5, 31), (7, 31), (8, 31)])

# Cumpleanios: anual, todo el dia
cumple = datetime.date(1994, 3, 15)
salida = ical.expand_rrule(cumple, ical.parse_rrule("FREQ=YEARLY"),
                           local(2026, 1, 1), local(2027, 12, 31), set())
check("el cumpleanios cae dos veces en dos anios", len(salida), 2)
check("y el dia es siempre el 15 de marzo",
      [(d.month, d.day) for d in salida], [(3, 15), (3, 15)])
check("y los anios son los de la ventana, no el original",
      [d.year for d in salida], [2026, 2027])

# UNTIL corta
salida = ical.expand_rrule(inicio, ical.parse_rrule("FREQ=DAILY;UNTIL=20260828T235959Z"),
                           ventana_ini, ventana_fin, set())
check("UNTIL corta la serie", [d.day for d in salida], [26, 27, 28])

# EXDATE saltea una instancia puntual
salida = ical.expand_rrule(inicio, ical.parse_rrule("FREQ=DAILY;COUNT=4"),
                           ventana_ini, ventana_fin, {"20260827T090000"})
check("EXDATE saca esa instancia", [d.day for d in salida], [26, 28, 29])

# Sin RRULE, una sola vez
check("sin FREQ devuelve solo el inicio",
      ical.expand_rrule(inicio, {}, ventana_ini, ventana_fin, set()), [inicio])

# Una regla infinita no puede colgar la shell
salida = ical.expand_rrule(local(1990, 1, 1, 9, 0), ical.parse_rrule("FREQ=DAILY"),
                           local(2026, 1, 1), local(2026, 1, 31), set())
check("una regla infinita respeta el freno y no cuelga", len(salida) <= 750, True)


# --------------------------------------------------------------------------- #

if FALLAS:
    print("FALLAS (%d):\n" % len(FALLAS))
    for f in FALLAS:
        print("  " + f + "\n")
    sys.exit(1)
print("todo bien")
