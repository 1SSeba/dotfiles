pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.modules.common

/**
 * Los eventos de tu Google Calendar, normalizados para los widgets.
 *
 * No expone la respuesta cruda de Google a propósito: los widgets leen
 * `eventsByDate` y `upcoming`, que son formas propias de la shell. Cuando sumemos
 * iCloud por CalDAV va a alcanzar con que ese servicio llene las mismas dos
 * propiedades — los widgets no se tocan.
 *
 * De OAuth no sabe nada: todo pasa por GoogleAccount.request().
 */
Singleton {
    id: root

    readonly property string apiBase: "https://www.googleapis.com/calendar/v3"

    readonly property bool enabled: (Config.options?.services?.google?.calendar?.enable ?? false)
        && GoogleAccount.connected
    readonly property int refreshMinutes: Config.options?.services?.google?.calendar?.refreshMinutes ?? 10
    readonly property int upcomingCount: Config.options?.services?.google?.calendar?.upcomingCount ?? 5
    readonly property var wantedCalendarIds: Config.options?.services?.google?.calendar?.calendarIds ?? []

    /**
     * { "2026-08-26": [ {summary, start, end, allDay, color, htmlLink, calendarName} ] }
     * Las claves son fecha local, no UTC: un evento de las 21:00 del martes tiene
     * que caer en el martes que ves en la grilla, no en el miércoles UTC.
     */
    property var eventsByDate: ({})
    /** Los próximos `upcomingCount` desde ahora, ya ordenados. */
    property var upcoming: []

    property var calendars: []
    property string lastError: ""
    property bool loading: false
    property real lastSync: 0

    /** Ventana que se pide a Google. La mueve el widget cuando cambiás de mes. */
    property date windowStart: root.monthStart(new Date(), -1)
    property date windowEnd: root.monthStart(new Date(), 2)

    // ------------------------------------------------------------------ //
    // Fechas
    // ------------------------------------------------------------------ //

    function monthStart(from, monthOffset) {
        return new Date(from.getFullYear(), from.getMonth() + monthOffset, 1, 0, 0, 0, 0);
    }

    /** Clave local YYYY-MM-DD. toISOString() no sirve acá: convierte a UTC. */
    function dateKey(d) {
        const month = String(d.getMonth() + 1).padStart(2, "0");
        const day = String(d.getDate()).padStart(2, "0");
        return `${d.getFullYear()}-${month}-${day}`;
    }

    /**
     * Los eventos de día completo vienen con `date` (sin hora) y Google los da en
     * horario neutro. Parsearlos con `new Date("2026-08-26")` los interpreta como
     * UTC medianoche, que en América es el día anterior — de ahí que un
     * cumpleaños apareciera corrido un casillero.
     */
    function parseAllDay(str) {
        const parts = String(str).split("-");
        // Mediodía y no medianoche: hay zonas horarias donde la medianoche de
        // cierto día no existe (el cambio de hora la saltea) y Date retrocede al
        // día anterior, corriendo el evento un casillero.
        return new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]), 12, 0, 0, 0);
    }

    // ------------------------------------------------------------------ //
    // Carga
    // ------------------------------------------------------------------ //

    /** Mueve la ventana pedida. Si ya la cubríamos, no se vuelve a pedir nada. */
    function ensureWindow(start, end) {
        if (start >= root.windowStart && end <= root.windowEnd) return;
        root.windowStart = new Date(Math.min(start.getTime(), root.windowStart.getTime()));
        root.windowEnd = new Date(Math.max(end.getTime(), root.windowEnd.getTime()));
        root.refresh();
    }

    function refresh() {
        if (!root.enabled) return;
        root.loading = true;
        GoogleAccount.api(`${root.apiBase}/users/me/calendarList?minAccessRole=reader`,
            data => {
                const items = (data?.items ?? []).filter(c => c && !c.deleted);
                root.calendars = items.map(c => ({
                    "id": c.id,
                    "name": c.summaryOverride ?? c.summary ?? c.id,
                    "color": c.backgroundColor ?? "",
                    "selected": c.selected ?? false
                }));
                root.fetchEvents();
            },
            message => root.fail(message));
    }

    function fetchEvents() {
        // Vacío en la config = los que tenés marcados en Google. Si no marcaste
        // ninguno, todos: mejor de más que un calendario vacío sin explicación.
        let wanted = root.calendars.filter(c => root.wantedCalendarIds.length > 0
            ? root.wantedCalendarIds.indexOf(c.id) >= 0
            : c.selected);
        if (wanted.length === 0) wanted = root.calendars;

        if (wanted.length === 0) {
            root.loading = false;
            root.applyEvents([]);
            return;
        }

        const timeMin = root.windowStart.toISOString();
        const timeMax = root.windowEnd.toISOString();
        let collected = [];
        let remaining = wanted.length;

        wanted.forEach(cal => {
            const url = `${root.apiBase}/calendars/${encodeURIComponent(cal.id)}/events`
                + `?timeMin=${encodeURIComponent(timeMin)}`
                + `&timeMax=${encodeURIComponent(timeMax)}`
                + `&singleEvents=true&orderBy=startTime&maxResults=250`;

            const done = () => {
                remaining--;
                if (remaining === 0) {
                    root.loading = false;
                    root.lastSync = Date.now();
                    root.applyEvents(collected);
                }
            };

            GoogleAccount.api(url, data => {
                (data?.items ?? []).forEach(item => {
                    if (!item || item.status === "cancelled") return;
                    const allDay = !!(item.start?.date);
                    const start = allDay ? root.parseAllDay(item.start.date)
                                         : new Date(item.start?.dateTime);
                    const rawEnd = allDay ? (item.end?.date ? root.parseAllDay(item.end.date) : start)
                                          : new Date(item.end?.dateTime ?? item.start?.dateTime);
                    if (isNaN(start.getTime())) return;
                    collected.push({
                        "id": item.id,
                        "summary": item.summary ?? Translation.tr("(sin título)"),
                        "location": item.location ?? "",
                        "start": start,
                        "end": rawEnd,
                        "allDay": allDay,
                        "color": cal.color,
                        "calendarName": cal.name,
                        "htmlLink": item.htmlLink ?? ""
                    });
                });
                done();
            }, message => {
                // Que un calendario falle no invalida los demás
                console.log("[GoogleCalendar]", cal.name, message);
                done();
            });
        });
    }

    // ------------------------------------------------------------------ //
    // Cache
    // ------------------------------------------------------------------ //

    /**
     * Las fechas no sobreviven a JSON.stringify como Date, así que van en
     * milisegundos y se rearman al leer.
     */
    function serialize(list) {
        return list.map(ev => Object.assign({}, ev, {
            "start": ev.start.getTime(),
            "end": ev.end.getTime()
        }));
    }

    function hydrate(list) {
        return list.map(ev => Object.assign({}, ev, {
            "start": new Date(ev.start),
            "end": new Date(ev.end)
        }));
    }

    /** Pinta lo de la última vez mientras la red contesta. */
    function restoreFromCache() {
        if (!root.enabled || root.lastSync > 0) return;
        const cached = AccountsCache.get("googleEvents", null);
        if (!cached || cached.length === 0) return;
        root.applyEvents(root.hydrate(cached), true);
    }

    Connections {
        target: AccountsCache
        function onLoadedChanged() { root.restoreFromCache(); }
    }

    // ------------------------------------------------------------------ //

    function applyEvents(list, fromCache = false) {
        const byDate = ({});
        list.forEach(ev => {
            // Un evento de varios días tiene que aparecer en cada casillero que ocupa.
            // En los de día completo el `end` de Google es exclusivo (termina el día
            // anterior), en los normales es inclusivo.
            // Mediodía por lo mismo que en parseAllDay, y además hace que el
            // setDate(+1) del bucle no se trabe en un cambio de hora.
            let cursor = new Date(ev.start.getFullYear(), ev.start.getMonth(), ev.start.getDate(), 12);
            const last = new Date(ev.end.getFullYear(), ev.end.getMonth(), ev.end.getDate(), 12);
            if (ev.allDay) last.setDate(last.getDate() - 1);

            let guard = 0;
            while (cursor <= last && guard < 400) {
                const key = root.dateKey(cursor);
                if (!byDate[key]) byDate[key] = [];
                byDate[key].push(ev);
                cursor.setDate(cursor.getDate() + 1);
                guard++;
            }
            // Un evento que empieza y termina el mismo instante no entra al while
            if (guard === 0) {
                const key = root.dateKey(ev.start);
                if (!byDate[key]) byDate[key] = [];
                byDate[key].push(ev);
            }
        });

        Object.keys(byDate).forEach(key => {
            byDate[key].sort((a, b) => (a.allDay === b.allDay)
                ? a.start - b.start
                : (a.allDay ? -1 : 1));
        });

        root.eventsByDate = byDate;
        if (!fromCache) AccountsCache.set("googleEvents", root.serialize(list));

        const now = new Date();
        // Lo que todavía no terminó: un evento en curso sigue siendo "lo que viene"
        root.upcoming = list
            .filter(ev => ev.end >= now)
            .sort((a, b) => a.start - b.start)
            .slice(0, root.upcomingCount);

        if (root.lastError.length > 0) root.lastError = "";
    }

    function eventsOn(dateKey) {
        return root.eventsByDate[dateKey] ?? [];
    }

    function countOn(dateKey) {
        return (root.eventsByDate[dateKey] ?? []).length;
    }

    function fail(message) {
        root.loading = false;
        root.lastError = message;
        console.log("[GoogleCalendar]", message);
    }

    function clear() {
        root.eventsByDate = ({});
        root.upcoming = [];
        root.calendars = [];
        root.lastSync = 0;
        AccountsCache.clear("googleEvents");
    }

    onEnabledChanged: {
        if (root.enabled) {
            root.restoreFromCache();
            root.refresh();
        } else {
            root.clear();
        }
    }

    Connections {
        target: GoogleAccount
        function onReady() {
            if (root.enabled) root.refresh();
        }
    }

    Timer {
        running: root.enabled
        interval: Math.max(1, root.refreshMinutes) * 60 * 1000
        repeat: true
        onTriggered: root.refresh()
    }
}
