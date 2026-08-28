pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.modules.common

/**
 * Los Recordatorios de iCloud, normalizados igual que Google Tasks.
 *
 * Expone `list` con la misma forma que usa Todo.qml ({content, done}), más lo
 * necesario para escribir de vuelta (url, etag). Así el widget no tiene que
 * saber de dónde salió cada tarea salvo para mostrar la marquita de origen.
 *
 * El `etag` es lo que hace seguras las escrituras: va como `If-Match`, así que
 * si alguien tocó el recordatorio desde el iPhone entre que lo leímos y lo
 * escribimos, iCloud rechaza el cambio en vez de pisar lo del otro lado. Cada
 * escritura devuelve el etag nuevo y hay que guardarlo, o la siguiente falla.
 *
 * Las escrituras son optimistas: la tarea cambia en pantalla en el acto y recién
 * después sale el PUT. Si falla se revierte y se avisa — esperar el round-trip
 * hacía que tildar algo se sintiera roto.
 */
Singleton {
    id: root

    readonly property bool enabled: (Config.options?.services?.apple?.reminders?.enable ?? false)
        && AppleAccount.connected
    readonly property int refreshMinutes: Config.options?.services?.apple?.reminders?.refreshMinutes ?? 15
    readonly property string configuredListUrl: Config.options?.services?.apple?.reminders?.listUrl ?? ""

    /** [{content, done, url, etag, listName, due, source: "apple"}] */
    property var list: []
    property var lists: []
    property string lastError: ""
    property bool loading: false
    property real lastSync: 0

    /**
     * La lista contra la que se escribe. Vacío en la config = la primera que
     * devuelve iCloud, que es la que la app de Apple marca por defecto.
     */
    readonly property string targetListUrl: {
        if (root.configuredListUrl.length > 0) return root.configuredListUrl;
        return root.lists.length > 0 ? root.lists[0].url : "";
    }

    // ------------------------------------------------------------------ //
    // Lectura
    // ------------------------------------------------------------------ //

    function refresh() {
        if (!root.enabled) return;
        root.loading = true;

        const args = ["todos"].concat(
            root.configuredListUrl.length > 0 ? [root.configuredListUrl] : []);

        AppleAccount.run(args, data => {
            root.loading = false;
            root.lastSync = Date.now();
            root.list = (data.todos ?? []).map(item => ({
                "content": item.content,
                "done": !!item.done,
                "url": item.url,
                "etag": item.etag ?? "",
                "listName": item.listName ?? "iCloud",
                "due": item.due ?? 0,
                "dueAllDay": !!item.dueAllDay,
                "source": "apple"
            }));
            AccountsCache.set("appleReminders", root.list);
            if (root.lastError.length > 0) root.lastError = "";
        }, message => root.fail(message));
    }

    /** Pinta los de la última vez mientras iCloud contesta. */
    function restoreFromCache() {
        if (!root.enabled || root.lastSync > 0) return;
        const cached = AccountsCache.get("appleReminders", null);
        if (cached && cached.length > 0) root.list = cached;
    }

    Connections {
        target: AccountsCache
        function onLoadedChanged() { root.restoreFromCache(); }
    }

    /** Sólo para poder elegir lista desde Ajustes. */
    function refreshLists() {
        if (!root.enabled) return;
        AppleAccount.run(["discover"], data => {
            root.lists = (data.calendars ?? []).filter(c => c.todos);
        }, message => console.log("[AppleReminders]", message));
    }

    // ------------------------------------------------------------------ //
    // Escritura
    // ------------------------------------------------------------------ //

    /** Cambia la copia local ya mismo, para que la UI responda al toque. */
    function patchLocal(url, changes) {
        root.list = root.list.map(t => t.url === url
            ? Object.assign({}, t, changes)
            : t);
    }

    function setDone(task, done) {
        if (!task || !task.url) return;
        const previous = ({ "done": task.done, "etag": task.etag });
        root.patchLocal(task.url, ({ "done": done }));

        AppleAccount.run(["todo-set-done", task.url, task.etag, done ? "true" : "false"],
            data => {
                // Sin guardar el etag nuevo, la siguiente escritura sobre este
                // mismo recordatorio choca contra su propio If-Match.
                root.patchLocal(task.url, ({ "etag": data.etag ?? "" }));
                if (root.lastError.length > 0) root.lastError = "";
            },
            message => {
                root.patchLocal(task.url, previous);
                root.fail(message);
            });
    }

    function remove(task) {
        if (!task || !task.url) return;
        const snapshot = root.list;
        root.list = root.list.filter(t => t.url !== task.url);

        AppleAccount.run(["todo-delete", task.url, task.etag], () => {
            if (root.lastError.length > 0) root.lastError = "";
        }, message => {
            root.list = snapshot;
            root.fail(message);
        });
    }

    function add(content) {
        if (!root.enabled) return false;
        const text = String(content).trim();
        if (text.length === 0) return false;

        const target = root.targetListUrl;
        if (target.length === 0) {
            // Pasa si `discover` todavía no volvió. Perder la tarea sería peor
            // que hacer esperar un segundo, así que se pide y se reintenta.
            root.refreshLists();
            root.fail(Translation.tr("Todavía no sé en qué lista de iCloud guardarla. Probá de nuevo."));
            return false;
        }

        AppleAccount.run(["todo-add", target, text], data => {
            const created = data.todo ?? ({});
            root.list = root.list.concat([({
                "content": text,
                "done": false,
                "url": created.url ?? "",
                "etag": created.etag ?? "",
                "listName": Translation.tr("iCloud"),
                "due": 0,
                "dueAllDay": false,
                "source": "apple"
            })]);
            // iCloud a veces devuelve el PUT sin ETag. Sin él, tildar la tarea
            // recién creada fallaría; volver a leer la lista lo resuelve.
            if (!created.etag) root.refresh();
        }, message => root.fail(message));
        return true;
    }

    // ------------------------------------------------------------------ //

    function fail(message) {
        root.loading = false;
        root.lastError = message;
        console.log("[AppleReminders]", message);
    }

    onEnabledChanged: {
        if (root.enabled) {
            root.restoreFromCache();
            root.refresh();
            root.refreshLists();
        } else {
            root.list = [];
            root.lists = [];
            root.lastSync = 0;
            AccountsCache.clear("appleReminders");
        }
    }

    Connections {
        target: AppleAccount
        function onReady() {
            if (root.enabled) {
                root.refresh();
                root.refreshLists();
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
