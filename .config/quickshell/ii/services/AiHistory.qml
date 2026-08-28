pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import Quickshell
import Quickshell.Io
import QtQuick

/**
 * Historial de chats de IA: metadatos que los archivos de chat no guardan.
 *
 * Los .json de `Directories.aiChats` son una lista pelada de mensajes, sin
 * título, fecha, ni nada con qué organizarlos. Este servicio mantiene un índice
 * al lado (`chats-index.json`, FUERA de la carpeta de chats para que el `ls` de
 * Ai.qml no lo levante como si fuera un chat) con lo que hace falta para tener
 * historial de verdad: fijados, archivados y proyectos.
 *
 * El índice es sidecar a propósito: si se pierde o se borra, los chats siguen
 * cargando igual, sólo se van los metadatos.
 */
Singleton {
    id: root

    readonly property string filePath: `${Directories.state}/user/ai/chats-index.json`

    /** chatName -> { title, pinned, archived, projectId, updated } */
    property var entries: ({})
    /** [{ id, name, icon }] */
    property var projects: []
    property bool ready: false

    /** Los chats que hay en disco, ya cruzados con el índice. Más nuevo primero. */
    property var chats: []
    property bool scanning: false

    readonly property var defaultEntry: ({
        "title": "",
        "pinned": false,
        "archived": false,
        "projectId": "",
        "updated": 0
    })

    function entryFor(chatName) {
        return Object.assign({}, root.defaultEntry, root.entries[chatName] ?? {});
    }

    /**
     * Escribe un entry. Reasigna `entries` entero a propósito: mutar el objeto
     * in-place no notifica a los bindings de QML y la lista no se refresca.
     */
    function _setEntry(chatName, patch) {
        if (!chatName || chatName.length === 0) return;
        const next = Object.assign({}, root.entries);
        // `updated` es la última vez que pasó algo con este chat. Se sella acá y
        // no en cada llamador porque si no siempre se olvida en alguno, y un
        // campo de fecha que a veces se escribe ordena peor que no tenerlo.
        const stamped = Object.assign({ "updated": Date.now() }, patch);
        next[chatName] = Object.assign(root.entryFor(chatName), stamped);
        root.entries = next;
        root._scheduleWrite();
        root._reapplyToChats();
    }

    /** Marca actividad sin cambiar nada más (la sesión escribió en el archivo). */
    function touch(chatName) { root._setEntry(chatName, ({})); }

    function setTitle(chatName, title) { root._setEntry(chatName, { "title": title }); }
    function setPinned(chatName, pinned) { root._setEntry(chatName, { "pinned": pinned }); }
    function setArchived(chatName, archived) { root._setEntry(chatName, { "archived": archived }); }
    function setProject(chatName, projectId) { root._setEntry(chatName, { "projectId": projectId }); }

    function togglePinned(chatName) { root.setPinned(chatName, !root.entryFor(chatName).pinned); }
    function toggleArchived(chatName) { root.setArchived(chatName, !root.entryFor(chatName).archived); }

    /** Saca el chat del índice (no toca el archivo). */
    function forget(chatName) {
        const next = Object.assign({}, root.entries);
        delete next[chatName];
        root.entries = next;
        root._scheduleWrite();
    }

    /** Borra el chat de disco y su entrada del índice. */
    function deleteChat(chatName) {
        Quickshell.execDetached(["rm", "-f", `${Directories.aiChats}/${chatName}.json`]);
        root.forget(chatName);
        rescanTimer.restart();
    }

    /* ------------------------- Agrupado por fecha ------------------------ */

    /**
     * Etiqueta del grupo al que cae una fecha: Hoy / Ayer / Esta semana / mes.
     *
     * Se calcula contra medianoche y no restando 24h: "ayer" tiene que seguir
     * siendo ayer a las 00:30, y un chat de hace 20 horas puede perfectamente
     * ser de anteayer.
     */
    function groupLabelFor(mtime, now = new Date()) {
        const date = new Date(mtime);
        const midnight = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
        const day = 86400000;
        if (mtime >= midnight) return Translation.tr("Hoy");
        if (mtime >= midnight - day) return Translation.tr("Ayer");
        if (mtime >= midnight - 7 * day) return Translation.tr("Esta semana");
        if (mtime >= midnight - 30 * day) return Translation.tr("Este mes");
        if (date.getFullYear() === now.getFullYear()) return Qt.formatDateTime(date, "MMMM");
        return Qt.formatDateTime(date, "MMMM yyyy");
    }

    /**
     * Mete un `groupLabel` en el primer chat de cada grupo (vacío en el resto).
     *
     * La lista ya viene ordenada; acá sólo se marca dónde arranca cada tanda para
     * que el delegate dibuje el encabezado. Un ListView con section.property no
     * sirve: el modelo es un array de JS pelado y no tiene roles.
     */
    function withGroupLabels(list) {
        let last = "";
        return list.map(chat => {
            // Los fijados van todos juntos arriba, sin importar la fecha.
            const label = chat.pinned ? Translation.tr("Fijados") : root.groupLabelFor(chat.mtime);
            const first = label !== last;
            last = label;
            return Object.assign({}, chat, { "groupLabel": first ? label : "" });
        });
    }

    /* --------------------------- Proyectos --------------------------- */

    function projectById(projectId) {
        for (let i = 0; i < root.projects.length; i++) {
            if (root.projects[i].id === projectId) return root.projects[i];
        }
        return null;
    }

    function projectName(projectId) {
        return root.projectById(projectId)?.name ?? "";
    }

    function createProject(name, icon = "folder") {
        const clean = (name ?? "").trim();
        if (clean.length === 0) return "";
        const id = "p" + Date.now().toString(36) + Math.random().toString(36).substr(2, 4);
        root.projects = [...root.projects, { "id": id, "name": clean, "icon": icon }];
        root._scheduleWrite();
        return id;
    }

    function renameProject(projectId, name) {
        const clean = (name ?? "").trim();
        if (clean.length === 0) return;
        root.projects = root.projects.map(p => p.id === projectId ? Object.assign({}, p, { "name": clean }) : p);
        root._scheduleWrite();
    }

    /** Borra el proyecto y suelta los chats que lo tenían (no los borra). */
    function deleteProject(projectId) {
        root.projects = root.projects.filter(p => p.id !== projectId);
        const next = Object.assign({}, root.entries);
        for (const key in next) {
            if (next[key].projectId === projectId) next[key] = Object.assign({}, next[key], { "projectId": "" });
        }
        root.entries = next;
        root._scheduleWrite();
        root._reapplyToChats();
    }

    function chatCountForProject(projectId) {
        return root.chats.filter(c => c.projectId === projectId && !c.archived).length;
    }

    /* ------------------------- Escaneo de disco ------------------------ */

    function refresh() {
        if (root.scanning) return;
        root.scanning = true;
        scanProcess.running = true;
    }

    Timer {
        id: rescanTimer
        interval: 250
        repeat: false
        onTriggered: root.refresh()
    }

    /**
     * Un solo proceso saca todo lo que la UI necesita de cada archivo: fecha,
     * cantidad de mensajes y el primer mensaje del usuario como título de
     * respaldo. Leer los .json desde QML sería un FileView por chat.
     */
    Process {
        id: scanProcess
        command: ["python3", "-c", `
import json, os, sys
d = sys.argv[1]
out = []
try:
    names = os.listdir(d)
except OSError:
    names = []
for fn in names:
    if not fn.endswith(".json"):
        continue
    path = os.path.join(d, fn)
    try:
        st = os.stat(path)
        with open(path, encoding="utf-8") as fh:
            data = json.load(fh)
    except Exception:
        continue
    if not isinstance(data, list):
        continue
    snippet = ""
    agents = 0
    parts = []
    for m in data:
        if not isinstance(m, dict):
            continue
        body = (m.get("rawContent") or "").strip()
        if m.get("role") == "user" and not snippet and body:
            snippet = body.replace("\\n", " ")[:80]
        if body:
            parts.append(body)
        got = m.get("agents")
        if isinstance(got, list):
            agents += len(got)
    # El texto completo es para buscar, no para mostrar: se recorta porque un
    # chat largo en el indice hace que cada tecleo en el buscador escanee megas.
    haystack = " ".join(parts).lower()[:6000]
    out.append({
        "name": fn[:-5],
        "mtime": int(st.st_mtime * 1000),
        "count": len(data),
        "snippet": snippet,
        "agents": agents,
        "haystack": haystack,
    })
out.sort(key=lambda x: -x["mtime"])
print(json.dumps(out))
`, Directories.aiChats]

        stdout: StdioCollector {
            onStreamFinished: {
                root.scanning = false;
                if (text.trim().length === 0) {
                    root.chats = [];
                    return;
                }
                try {
                    root.chats = root._merge(JSON.parse(text));
                } catch (e) {
                    console.log("[AiHistory] No se pudo parsear el escaneo:", e);
                }
            }
        }
    }

    /** Cruza lo que hay en disco con los metadatos del índice. */
    function _merge(scanned) {
        return scanned.map(item => {
            const meta = root.entryFor(item.name);
            return {
                "name": item.name,
                "count": item.count,
                "snippet": item.snippet,
                "agents": item.agents ?? 0,
                "haystack": item.haystack ?? "",
                "mtime": meta.updated > 0 ? Math.max(meta.updated, item.mtime) : item.mtime,
                "title": meta.title.length > 0 ? meta.title : (item.snippet.length > 0 ? item.snippet : item.name),
                "pinned": meta.pinned,
                "archived": meta.archived,
                "projectId": meta.projectId
            };
        });
    }

    /** Rehace la lista visible sin volver a leer el disco. */
    function _reapplyToChats() {
        root.chats = root.chats.map(c => {
            const meta = root.entryFor(c.name);
            return Object.assign({}, c, {
                "title": meta.title.length > 0 ? meta.title : (c.snippet.length > 0 ? c.snippet : c.name),
                "pinned": meta.pinned,
                "archived": meta.archived,
                "projectId": meta.projectId
            });
        });
    }

    /* --------------------------- Persistencia -------------------------- */

    Timer {
        id: writeTimer
        interval: 200
        repeat: false
        onTriggered: indexFile.setText(JSON.stringify({
            "entries": root.entries,
            "projects": root.projects
        }, null, 2))
    }

    function _scheduleWrite() {
        if (!root.ready) return;
        writeTimer.restart();
    }

    FileView {
        id: indexFile
        path: root.filePath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const data = JSON.parse(indexFile.text());
                root.entries = data.entries ?? ({});
                root.projects = data.projects ?? [];
            } catch (e) {
                root.entries = ({});
                root.projects = [];
            }
            root.ready = true;
            root.refresh();
        }
        onLoadFailed: error => {
            // Todavía no existe: se crea en la primera escritura.
            root.ready = true;
            root.refresh();
        }
    }
}
