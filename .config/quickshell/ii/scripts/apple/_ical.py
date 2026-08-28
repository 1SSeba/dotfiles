#!/usr/bin/env python3
"""
Lo minimo de iCalendar (RFC 5545) para leer un calendario de iCloud.

Vive aparte de caldav.py para poder probarlo sin red: parsear ICS y expandir
recurrencias es donde estan los errores dificiles, y son justo la parte que se
puede testear con archivos de ejemplo. Ver scripts/apple/test_ical.py.

No pretende ser una implementacion completa de la RFC. Cubre lo que aparece en un
calendario de verdad: eventos con y sin hora, zonas horarias, repeticiones
comunes, excepciones y overrides.
"""

import datetime
import re

try:
    from zoneinfo import ZoneInfo
except ImportError:  # pragma: no cover - Python < 3.9
    ZoneInfo = None


# --------------------------------------------------------------------------- #
# Parseo
# --------------------------------------------------------------------------- #

def unfold(text):
    """
    Una linea de ICS puede seguir en la siguiente si esta arranca con espacio o
    tab. Sin deshacer eso, cualquier asunto largo queda cortado a la mitad.
    """
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    return re.sub(r"\n[ \t]", "", text)


def split_line(line):
    """
    'DTSTART;TZID=America/Santiago:20260826T090000'
      -> ('DTSTART', {'TZID': 'America/Santiago'}, '20260826T090000')

    El valor puede tener ':' adentro (una URL, por ejemplo), asi que se corta en
    el primero que aparezca despues del nombre y sus parametros.
    """
    # Los parametros entre comillas pueden contener ':' y ';', hay que saltearlos
    in_quotes = False
    colon = -1
    for i, ch in enumerate(line):
        if ch == '"':
            in_quotes = not in_quotes
        elif ch == ":" and not in_quotes:
            colon = i
            break
    if colon < 0:
        return line.strip(), {}, ""

    head, value = line[:colon], line[colon + 1:]
    pieces = []
    buf = ""
    in_quotes = False
    for ch in head:
        if ch == '"':
            in_quotes = not in_quotes
            buf += ch
        elif ch == ";" and not in_quotes:
            pieces.append(buf)
            buf = ""
        else:
            buf += ch
    pieces.append(buf)

    name = pieces[0].strip().upper()
    params = {}
    for piece in pieces[1:]:
        if "=" in piece:
            key, val = piece.split("=", 1)
            params[key.strip().upper()] = val.strip().strip('"')
    return name, params, value


def unescape(value):
    """Los valores de texto escapan coma, punto y coma, barra y salto de linea."""
    out = []
    i = 0
    while i < len(value):
        ch = value[i]
        if ch == "\\" and i + 1 < len(value):
            nxt = value[i + 1]
            out.append({"n": "\n", "N": "\n", ",": ",", ";": ";", "\\": "\\"}.get(nxt, nxt))
            i += 2
        else:
            out.append(ch)
            i += 1
    return "".join(out)


def parse_components(text, wanted):
    """
    Devuelve una lista de dicts, uno por componente del tipo pedido
    (VEVENT o VTODO). Cada dict mapea NOMBRE -> lista de (params, valor):
    lista porque hay propiedades que aparecen varias veces (EXDATE, ATTENDEE).

    Los VALARM y demas sub-componentes se saltean enteros: no nos interesan y
    sus propiedades ensuciarian las del evento que los contiene.
    """
    components = []
    current = None
    skip_depth = 0

    for line in unfold(text).split("\n"):
        if not line.strip():
            continue
        name, params, value = split_line(line)

        if name == "BEGIN":
            comp = value.strip().upper()
            if current is not None:
                # Un sub-componente adentro del que nos interesa (VALARM)
                skip_depth += 1
            elif comp == wanted:
                current = {}
            continue

        if name == "END":
            comp = value.strip().upper()
            if skip_depth > 0:
                skip_depth -= 1
            elif current is not None and comp == wanted:
                components.append(current)
                current = None
            continue

        if current is not None and skip_depth == 0:
            current.setdefault(name, []).append((params, value))

    return components


def first(component, name, default=""):
    entries = component.get(name)
    if not entries:
        return default
    return entries[0][1]


def first_params(component, name):
    entries = component.get(name)
    if not entries:
        return {}
    return entries[0][0]


# --------------------------------------------------------------------------- #
# Fechas
# --------------------------------------------------------------------------- #

def get_zone(name):
    if not name or ZoneInfo is None:
        return None
    try:
        return ZoneInfo(name)
    except Exception:  # noqa: BLE001 - TZID inventado por algun cliente
        return None


def parse_dt(value, params, default_tz=None):
    """
    Devuelve (datetime|date, all_day).

    Tres formas posibles:
      20260826               -> date, todo el dia
      20260826T090000Z       -> datetime en UTC
      20260826T090000        -> datetime en la zona del TZID, o local si no hay
    """
    value = value.strip()
    if not value:
        return None, False

    if params.get("VALUE", "").upper() == "DATE" or len(value) == 8:
        try:
            return datetime.date(int(value[0:4]), int(value[4:6]), int(value[6:8])), True
        except ValueError:
            return None, False

    match = re.match(r"^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})(Z?)$", value)
    if not match:
        return None, False
    year, month, day, hour, minute, second, zulu = match.groups()
    try:
        naive = datetime.datetime(int(year), int(month), int(day),
                                  int(hour), int(minute), int(second))
    except ValueError:
        return None, False

    if zulu:
        return naive.replace(tzinfo=datetime.timezone.utc), False

    zone = get_zone(params.get("TZID")) or default_tz
    if zone is not None:
        return naive.replace(tzinfo=zone), False
    # Sin zona declarada la RFC dice "hora local del que lee"
    return naive.astimezone(), False


def as_aware(value):
    """Un date suelto no se puede comparar con un datetime; se lleva a mediodia local."""
    if isinstance(value, datetime.datetime):
        return value if value.tzinfo else value.astimezone()
    if isinstance(value, datetime.date):
        return datetime.datetime(value.year, value.month, value.day, 12, 0).astimezone()
    return None


# --------------------------------------------------------------------------- #
# Recurrencias
# --------------------------------------------------------------------------- #

WEEKDAYS = {"MO": 0, "TU": 1, "WE": 2, "TH": 3, "FR": 4, "SA": 5, "SU": 6}


def parse_rrule(value):
    rule = {}
    for piece in value.split(";"):
        if "=" not in piece:
            continue
        key, val = piece.split("=", 1)
        rule[key.strip().upper()] = val.strip()
    return rule


def add_months(moment, count):
    """
    Sumar meses no es sumar dias. El 31 de enero + 1 mes no existe: la RFC dice
    que esa instancia simplemente no ocurre, asi que devolvemos None y el que
    llama la saltea (en vez de correrla al 3 de marzo, que es lo que haria una
    resta ingenua de dias).
    """
    month_index = moment.month - 1 + count
    year = moment.year + month_index // 12
    month = month_index % 12 + 1
    try:
        return moment.replace(year=year, month=month)
    except ValueError:
        return None


def _first_step(freq, interval, start_aware, window_start):
    """
    Desde que repeticion empezar a contar para llegar a la ventana visible.

    Sin esto, un evento diario que arranco en 2015 necesitaba miles de vueltas
    para llegar al mes que estas mirando, chocaba contra el freno y no mostraba
    NADA. Se salta directo a la vuelta anterior a la ventana.

    Solo se puede hacer cuando no hay COUNT: con COUNT hay que contar desde el
    principio, pero entonces la serie es finita y corta por definicion.
    """
    if window_start <= start_aware:
        return 0
    delta_days = (window_start - start_aware).days
    if freq == "DAILY":
        n = delta_days // interval
    elif freq == "WEEKLY":
        n = delta_days // (7 * interval)
    elif freq == "MONTHLY":
        months = (window_start.year - start_aware.year) * 12 + (window_start.month - start_aware.month)
        n = months // interval
    elif freq == "YEARLY":
        n = (window_start.year - start_aware.year) // interval
    else:
        return 0
    return max(0, n - 1)  # una de menos, por si el borde queda justo


def expand_rrule(start, rule, window_start, window_end, exdates, cap=2000):
    """
    Las fechas de inicio de cada repeticion que caen en la ventana pedida.

    Soporta FREQ DAILY/WEEKLY/MONTHLY/YEARLY con INTERVAL, COUNT, UNTIL, BYDAY
    (para semanales) y EXDATE. Alcanza para lo que hay en un calendario real:
    cumpleanios, reuniones semanales, pagos mensuales.

    Ojo con el orden entre COUNT y EXDATE: la RFC dice que COUNT cuenta lo que
    genera la regla, y recien despues EXDATE saca instancias. O sea que
    "COUNT=4 con un EXDATE" da tres eventos, no cuatro.

    `cap` es un freno duro: una regla infinita podria generar millones de
    instancias y colgar la shell.
    """
    freq = rule.get("FREQ", "").upper()
    if not freq:
        return [start]

    interval = int(rule.get("INTERVAL", "1") or "1")
    if interval < 1:
        interval = 1
    count = int(rule["COUNT"]) if rule.get("COUNT", "").isdigit() else None

    until = None
    if rule.get("UNTIL"):
        until_dt, _ = parse_dt(rule["UNTIL"], {})
        until = as_aware(until_dt)

    bydays = [WEEKDAYS[d[-2:].upper()] for d in rule.get("BYDAY", "").split(",")
              if d and d[-2:].upper() in WEEKDAYS]

    is_date = isinstance(start, datetime.date) and not isinstance(start, datetime.datetime)
    start_aware = as_aware(start)
    if start_aware is None:
        return []

    # Con COUNT hay que contar desde la primera; sin COUNT se puede saltar
    step = 0 if count is not None else _first_step(freq, interval, start_aware, window_start)

    # Margen para las semanales con BYDAY: el ancla de la semana puede caer
    # despues del final de la ventana y aun asi tener dias adentro
    tail = window_end + datetime.timedelta(days=7)

    results = []
    seen = 0
    for _ in range(cap):
        if freq == "DAILY":
            current = start + datetime.timedelta(days=step * interval)
        elif freq == "WEEKLY":
            current = start + datetime.timedelta(weeks=step * interval)
        elif freq == "MONTHLY":
            current = add_months(start, step * interval)
        elif freq == "YEARLY":
            current = add_months(start, step * interval * 12)
        else:
            return [start]
        step += 1

        if current is None:  # el 31 de un mes que no tiene 31: esa no ocurre
            continue

        # Las semanales con BYDAY dan una instancia por dia marcado de la semana
        candidates = [current]
        if freq == "WEEKLY" and bydays:
            week_start = current - datetime.timedelta(days=current.weekday())
            candidates = [week_start + datetime.timedelta(days=d) for d in sorted(bydays)]

        for candidate in candidates:
            aware = as_aware(candidate)
            if aware is None or aware < start_aware:
                continue
            if until is not None and aware > until:
                continue

            # COUNT cuenta antes de que EXDATE saque nada
            seen += 1
            if count is not None and seen > count:
                return results

            key = candidate.strftime("%Y%m%d") if is_date else candidate.strftime("%Y%m%dT%H%M%S")
            if key in exdates:
                continue
            if window_start <= aware <= window_end:
                results.append(candidate)

        anchor = as_aware(current)
        if anchor is not None and anchor > tail:
            break
        if until is not None and anchor is not None and anchor > until:
            break

    return results
