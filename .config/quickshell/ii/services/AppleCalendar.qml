pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.modules.common

/**
 * Los eventos de tu calendario de iCloud, normalizados igual que los de Google.
 *
 * Expone exactamente la misma forma que GoogleCalendar (`eventsByDate`,
 * `upcoming`) para que Calendars.qml los pueda mezclar sin saber de dónde salió
 * cada evento. De CalDAV no sabe nada: todo pasa por AppleAccount.run().
 *
 * Sobre las fechas: caldav.py manda los eventos de todo el día como "YYYY-MM-DD"
 * y el resto como epoch en segundos, justamente para que acá no haya que
 * adivinar zonas horarias. Los de todo el día se materializan al mediodía — hay
 * zonas donde la medianoche de cierto día no existe (el cambio de hora la
 * saltea) y Date retrocede al día anterior, corriendo el evento un casillero.
 */
Singleton {
    id: root

    readonly property bool enabled: (Config.options?.services?.apple?.calendar?.enable ?? false)
        && AppleAccount.connected
    readonly property int refreshMinutes: Config.options?.services?.apple?.calendar?.refreshMinutes ?? 15
    readonly property var wantedCalendarUrls: Config.options?.services?.apple?.calendar?.calendarUrls ?? []

    /** { "2026-08-26": [ {summary, start, end, allDay, color, calendarName} ] } */
    property var eventsByDate: ({})
    /** Los próximos desde ahora, ya ordenados. Calendars.qml los recorta. */
    property var upcoming: []

    property var calendars: []
    property string lastError: ""
    property bool loading: false
    property real lastSync: 0

    /** Ventana que se le pide a iCloud. La mueve el widget cuando cambiás de mes. */
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

    function parseAllDay(str) {
        const parts = String(str).split("-");
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

        // caldav.py descubre los calendarios solo; le pasamos las URLs cuando
        // querés filtrar, y así de paso se ahorra el PROPFIND de descubrimiento.
        const args = ["events", root.windowStart.toISOString(), root.windowEnd.toISOString()]
            .concat(root.wantedCalendarUrls);

        AppleAccount.run(args, data => {
            root.loading = false;
            root.lastSync = Date.now();
            root.applyEvents(data.events ?? []);
        }, message => root.fail(message));
    }

    /** Sólo para poder elegir calendarios desde Ajustes. */
    function refreshCalendars() {
        if (!root.enabled) return;
        AppleAccount.run(["discover"], data => {
            root.calendars = (data.calendars ?? []).filter(c => c.events);
        }, message => console.log("[AppleCalendar]", message));
    }

    // ------------------------------------------------------------------ //
    // Cache
    // ------------------------------------------------------------------ //

    /** Lo que llega de caldav.py ya es JSON plano: se guarda tal cual. */
    function restoreFromCache() {
        if (!root.enabled || root.lastSync > 0) return;
        const cached = AccountsCache.get("appleEvents", null);
        if (!cached || cached.length === 0) return;
        root.applyEvents(cached, true);
    }

    Connections {
        target: AccountsCache
        function onLoadedChanged() { root.restoreFromCache(); }
    }

    // ------------------------------------------------------------------ //

    function applyEvents(list, fromCache = false) {
        if (!fromCache) AccountsCache.set("appleEvents", list);
        const parsed = list.map(item => {
            const allDay = !!item.allDay;
            const start = allDay ? root.parseAllDay(item.start)
                                 : new Date(Number(item.start) * 1000);
            const end = allDay ? root.parseAllDay(item.end)
                               : new Date(Number(item.end) * 1000);
            return ({
                "id": item.uid ?? "",
                "summary": item.summary ?? Translation.tr("(sin título)"),
                "location": item.location ?? "",
                "start": start,
                "end": end,
                "allDay": allDay,
                "color": item.color ?? "",
                "calendarName": item.calendarName ?? "iCloud",
                // iCloud no da un link por evento; su calendario web es lo mejor
                // que hay, y alcanza para que el click haga algo útil.
                "htmlLink": "https://www.icloud.com/calendar",
                "source": "apple"
            });
        }).filter(ev => !isNaN(ev.start.getTime()));

        const byDate = ({});
        parsed.forEach(ev => {
            // Un evento de varios días tiene que aparecer en cada casillero que
            // ocupa. En los de día completo el DTEND del iCal es exclusivo
            // (termina el día anterior), en los normales es inclusivo.
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

        const now = new Date();
        // Lo que todavía no terminó: un evento en curso sigue siendo "lo que viene"
        root.upcoming = parsed
            .filter(ev => ev.end >= now)
            .sort((a, b) => a.start - b.start);

        if (root.lastError.length > 0) root.lastError = "";
    }

    function eventsOn(dateKey) {
        return root.eventsByDate[dateKey] ?? [];
    }

    function fail(message) {
        root.loading = false;
        root.lastError = message;
        console.log("[AppleCalendar]", message);
    }

    function clear() {
        root.eventsByDate = ({});
        root.upcoming = [];
        root.calendars = [];
        root.lastSync = 0;
        AccountsCache.clear("appleEvents");
    }

    onEnabledChanged: {
        if (root.enabled) {
            root.restoreFromCache();
            root.refresh();
            root.refreshCalendars();
        } else {
            root.clear();
        }
    }

    Connections {
        target: AppleAccount
        function onReady() {
            if (root.enabled) {
                root.refresh();
                root.refreshCalendars();
            }
        }
    }

    Timer {
        running: root.enabled
        interval: Math.max(1, root.refreshMinutes) * 60 * 1000
        repeat: true
        onTriggered: root.refresh()
    }
}
