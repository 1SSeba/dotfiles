pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.modules.common

/**
 * Google Tasks, normalizado para el widget de To Do.
 *
 * Expone `list` con la misma forma que usa Todo.qml para sus tareas locales
 * ({content, done}), más lo necesario para escribir de vuelta (remoteId, listId).
 * Así el widget no tiene que saber de dónde salió cada tarea salvo para mostrar
 * la marquita de origen.
 *
 * Las escrituras son optimistas: la tarea cambia en pantalla en el acto y recién
 * después se manda el PATCH. Si el PATCH falla se revierte y se avisa — esperar
 * el round-trip hacía que tildar algo se sintiera roto.
 */
Singleton {
    id: root

    readonly property string apiBase: "https://tasks.googleapis.com/tasks/v1"

    readonly property bool enabled: (Config.options?.services?.google?.tasks?.enable ?? false)
        && GoogleAccount.connected
    readonly property int refreshMinutes: Config.options?.services?.google?.tasks?.refreshMinutes ?? 15
    readonly property string configuredListId: Config.options?.services?.google?.tasks?.listId ?? ""

    /** [{content, done, remoteId, listId, due, source: "google"}] */
    property var list: []
    property var taskLists: []
    property string lastError: ""
    property bool loading: false
    property real lastSync: 0

    /** La lista contra la que se escribe. Vacío en la config = la que Google marca por defecto. */
    readonly property string targetListId: root.configuredListId.length > 0
        ? root.configuredListId
        : "@default"

    // ------------------------------------------------------------------ //
    // Lectura
    // ------------------------------------------------------------------ //

    function refresh() {
        if (!root.enabled) return;
        root.loading = true;

        const listId = root.targetListId;
        const url = `${root.apiBase}/lists/${encodeURIComponent(listId)}/tasks`
            + `?showCompleted=true&showHidden=true&maxResults=100`;

        GoogleAccount.api(url, data => {
            root.loading = false;
            root.lastSync = Date.now();
            root.list = (data?.items ?? [])
                // Las tareas sin título son las que quedan a medio crear en la app
                // de Google; mostrarlas como renglones vacíos no ayuda a nadie
                .filter(item => item && (item.title ?? "").trim().length > 0)
                .map(item => ({
                    "content": item.title,
                    "done": item.status === "completed",
                    "remoteId": item.id,
                    "listId": listId,
                    "due": item.due ?? "",
                    "source": "google"
                }));
            AccountsCache.set("googleTasks", root.list);
            if (root.lastError.length > 0) root.lastError = "";
        }, message => root.fail(message));
    }

    /** Pinta las de la última vez mientras la red contesta. */
    function restoreFromCache() {
        if (!root.enabled || root.lastSync > 0) return;
        const cached = AccountsCache.get("googleTasks", null);
        if (cached && cached.length > 0) root.list = cached;
    }

    Connections {
        target: AccountsCache
        function onLoadedChanged() { root.restoreFromCache(); }
    }

    /** Sólo para poder elegir lista desde Ajustes más adelante. */
    function refreshTaskLists() {
        if (!root.enabled) return;
        GoogleAccount.api(`${root.apiBase}/users/@me/lists`, data => {
            root.taskLists = (data?.items ?? []).map(l => ({ "id": l.id, "name": l.title }));
        }, message => console.log("[GoogleTasks]", message));
    }

    // ------------------------------------------------------------------ //
    // Escritura
    // ------------------------------------------------------------------ //

    /** Cambia `done` en la copia local ya mismo, para que la UI responda al toque. */
    function setLocalDone(remoteId, done) {
        root.list = root.list.map(t => t.remoteId === remoteId
            ? Object.assign({}, t, { "done": done })
            : t);
    }

    function setDone(task, done) {
        if (!task || !task.remoteId) return;
        const previous = task.done;
        root.setLocalDone(task.remoteId, done);

        const url = `${root.apiBase}/lists/${encodeURIComponent(task.listId)}`
            + `/tasks/${encodeURIComponent(task.remoteId)}`;
        // `completed` hay que mandarlo en null al desmarcar: si queda la fecha
        // vieja, Google reabre la tarea pero la sigue tratando como completada.
        const body = done
            ? ({ "status": "completed" })
            : ({ "status": "needsAction", "completed": null });

        GoogleAccount.request("PATCH", url, body, () => {
            if (root.lastError.length > 0) root.lastError = "";
        }, message => {
            root.setLocalDone(task.remoteId, previous);
            root.fail(message);
        });
    }

    function remove(task) {
        if (!task || !task.remoteId) return;
        const snapshot = root.list;
        root.list = root.list.filter(t => t.remoteId !== task.remoteId);

        const url = `${root.apiBase}/lists/${encodeURIComponent(task.listId)}`
            + `/tasks/${encodeURIComponent(task.remoteId)}`;
        GoogleAccount.request("DELETE", url, null, () => {
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

        const url = `${root.apiBase}/lists/${encodeURIComponent(root.targetListId)}/tasks`;
        GoogleAccount.request("POST", url, ({ "title": text }), data => {
            if (!data) { root.refresh(); return; }
            root.list = root.list.concat([{
                "content": data.title ?? text,
                "done": false,
                "remoteId": data.id,
                "listId": root.targetListId,
                "due": data.due ?? "",
                "source": "google"
            }]);
        }, message => root.fail(message));
        return true;
    }

    // ------------------------------------------------------------------ //

    function fail(message) {
        root.loading = false;
        root.lastError = message;
        console.log("[GoogleTasks]", message);
    }

    onEnabledChanged: {
        if (root.enabled) {
            root.restoreFromCache();
            root.refresh();
            root.refreshTaskLists();
        } else {
            root.list = [];
            root.taskLists = [];
            root.lastSync = 0;
            AccountsCache.clear("googleTasks");
        }
    }

    Connections {
        target: GoogleAccount
        function onReady() {
            if (root.enabled) {
                root.refresh();
                root.refreshTaskLists();
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
