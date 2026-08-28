pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.modules.common

/**
 * Todos tus calendarios, sean de donde sean.
 *
 * GoogleCalendar y AppleCalendar ya normalizan sus eventos a la misma forma;
 * esto los junta en un solo `eventsByDate`/`upcoming` para que los widgets no
 * tengan que saber cuántos proveedores hay ni cuáles están conectados. Sumar
 * otro (CalDAV genérico, Nextcloud) es agregarlo a `providers` y nada más.
 *
 * Es sólo un mezclador: no habla con ninguna API ni guarda nada. Si los dos
 * proveedores están apagados, `eventsByDate` queda vacío y los widgets muestran
 * su estado de "no hay nada", que es lo correcto.
 */
Singleton {
    id: root

    readonly property var providers: [GoogleCalendar, AppleCalendar]

    readonly property int upcomingCount: Config.options?.services?.google?.calendar?.upcomingCount ?? 5

    readonly property bool enabled: root.providers.some(p => p.enabled)
    readonly property bool loading: root.providers.some(p => p.enabled && p.loading)
    readonly property real lastSync: root.providers.reduce((acc, p) => Math.max(acc, p.lastSync), 0)

    /**
     * El primer error que haya. Se muestra uno solo a propósito: si iCloud no
     * responde, apilar también "Google respondió 500" no ayuda a entender nada.
     */
    readonly property string lastError: {
        for (const provider of root.providers)
            if (provider.enabled && provider.lastError.length > 0) return provider.lastError;
        return "";
    }

    /** { "2026-08-26": [evento, ...] } con los dos proveedores mezclados y ordenados. */
    readonly property var eventsByDate: {
        const merged = ({});
        root.providers.forEach(provider => {
            if (!provider.enabled) return;
            const byDate = provider.eventsByDate ?? ({});
            Object.keys(byDate).forEach(key => {
                merged[key] = (merged[key] ?? []).concat(byDate[key]);
            });
        });
        // Los de todo el día primero, después por hora: el orden que ya usaba
        // cada proveedor por separado, ahora sobre la mezcla.
        Object.keys(merged).forEach(key => {
            merged[key].sort((a, b) => (a.allDay === b.allDay)
                ? a.start - b.start
                : (a.allDay ? -1 : 1));
        });
        return merged;
    }

    /** Los próximos `upcomingCount`, ya mezclados y ordenados. */
    readonly property var upcoming: {
        let all = [];
        root.providers.forEach(provider => {
            if (provider.enabled) all = all.concat(provider.upcoming ?? []);
        });
        return all.sort((a, b) => a.start - b.start).slice(0, root.upcomingCount);
    }

    // ------------------------------------------------------------------ //
    // Abrir en el navegador
    // ------------------------------------------------------------------ //

    /**
     * Adónde lleva un evento. Google da un link por evento; iCloud no expone
     * uno, así que lo mejor que hay es su calendario web.
     */
    function linkFor(event) {
        if (!event) return "";
        if ((event.htmlLink ?? "").length > 0) return event.htmlLink;
        return event.source === "apple"
            ? "https://www.icloud.com/calendar"
            : "https://calendar.google.com/calendar/r";
    }

    /** El día entero, abierto en la web del proveedor de su primer evento. */
    function dayLink(dateKey) {
        const events = root.eventsOn(dateKey);
        if (events.length === 0) return "";
        if (events[0].source === "apple") return "https://www.icloud.com/calendar";
        const parts = String(dateKey).split("-").map(Number);
        // Google acepta el día suelto sin ceros a la izquierda
        return `https://calendar.google.com/calendar/r/day/${parts[0]}/${parts[1]}/${parts[2]}`;
    }

    function open(event) {
        const url = root.linkFor(event);
        if (url.length > 0) Quickshell.execDetached(["xdg-open", url]);
    }

    function openDay(dateKey) {
        const url = root.dayLink(dateKey);
        if (url.length > 0) Quickshell.execDetached(["xdg-open", url]);
    }

    // ------------------------------------------------------------------ //

    function eventsOn(dateKey) {
        return root.eventsByDate[dateKey] ?? [];
    }

    function countOn(dateKey) {
        return (root.eventsByDate[dateKey] ?? []).length;
    }

    /** Le pide la ventana a todos: cambiar de mes tiene que traer los dos lados. */
    function ensureWindow(start, end) {
        root.providers.forEach(provider => {
            if (provider.enabled) provider.ensureWindow(start, end);
        });
    }

    function refresh() {
        root.providers.forEach(provider => {
            if (provider.enabled) provider.refresh();
        });
    }
}
