pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import Quickshell
import Quickshell.Io
import QtQuick

/**
 * Las notas del widget del escritorio, guardadas en una vault de Obsidian: cada
 * nota es un .md (ver scripts/notes/vault.py, que hace todo el trabajo con
 * archivos). Se editan y se ordenan igual desde el widget o desde Obsidian.
 *
 * Cada item: { id: "Trabajo/Informe.md", folder: "Trabajo", title: "Informe",
 * content, pinned, createdAt, attachments: [] }. createdAt es la última
 * modificación del archivo, así que una nota recién tocada sube arriba.
 *
 * Carpetas: las de la vault, tal cual. Archivar es mover a `archiveFolder`;
 * fijar es la propiedad `pinned` del frontmatter.
 */
Singleton {
    id: root

    property string vaultPath: Config.options?.background?.widgets?.notes?.vaultPath
        ?? "/mnt/raid/Obsidian/Notas Escritorio"
    readonly property string vaultName: root.vaultPath.split("/").filter(s => s.length > 0).pop() ?? ""
    readonly property string archiveFolder: "Archivo"
    property var list: []
    /** Todas las carpetas de la vault, también las vacías ("Trabajo", "Trabajo/2026"...). */
    property var folders: []
    property bool loaded: false
    property string lastError: ""

    // Lo que Obsidian cambie se ve acá con esta demora como mucho. No hay
    // inotifywait instalado y FileView sólo vigila archivos, no carpetas.
    readonly property int pollInterval: 4000

    // Las operaciones van de a una: dos escrituras en paralelo sobre la misma
    // vault podrían pisarse (renombrar mientras otra guarda, por ejemplo).
    property var queue: []
    // Lo que vino la última vez, para no tocar el modelo si nada cambió.
    property string lastSnapshot: ""

    function isArchived(note) {
        return note.folder === root.archiveFolder || note.folder.startsWith(root.archiveFolder + "/")
    }

    function addNote(title, content, folder, pinned) {
        root.enqueue(["save", ""], {
            "NOTE_TITLE": title ?? "",
            "NOTE_CONTENT": content ?? "",
            "NOTE_FOLDER": folder ?? "",
            "NOTE_PINNED": pinned ? "1" : "0"
        })
    }

    function updateNote(id, title, content) {
        // Se ve cambiada al instante; si el título cambió, el archivo se
        // renombra y el id nuevo llega con la respuesta.
        root.patch(id, { "title": title, "content": content })
        root.enqueue(["save", id], { "NOTE_TITLE": title ?? "", "NOTE_CONTENT": content ?? "" })
    }

    function deleteNote(id) {
        // Fuera de la lista ya, para que la animación de salida no espere al disco.
        root.list = root.list.filter(n => n.id !== id)
        root.enqueue(["trash", id])
    }

    function moveNote(id, folder) {
        const note = root.list.find(n => n.id === id)
        if (!note || note.folder === folder) return
        // El id nuevo ya, así la nota no "sale y vuelve a entrar" en la vista
        // Todas cuando llega la respuesta del disco. (Si ahí había otra con el
        // mismo nombre, el script le suma " 2" y la relectura lo corrige.)
        const name = id.split("/").pop()
        root.patch(id, { "folder": folder, "id": folder ? `${folder}/${name}` : name })
        root.enqueue(["move", id, folder])
    }

    function setArchived(id, archived) {
        root.moveNote(id, archived ? root.archiveFolder : "")
    }

    function setPinned(id, pinned) {
        root.patch(id, { "pinned": pinned })
        root.enqueue(["pin", id, pinned ? "1" : "0"])
    }

    function createFolder(name) {
        if (name.trim().length === 0) return
        root.enqueue(["mkdir", name.trim()])
    }

    /** La carpeta entera va a la papelera de Obsidian, con lo que tenga adentro. */
    function deleteFolder(folder) {
        root.folders = root.folders.filter(f => f !== folder && !f.startsWith(folder + "/"))
        root.list = root.list.filter(n => n.folder !== folder && !n.folder.startsWith(folder + "/"))
        root.enqueue(["rmdir", folder])
    }

    function refresh() {
        // Una relectura encolada ya alcanza; no hace falta sumar otra.
        if (root.queue.some(op => op.args[0] === "list")) return
        root.enqueue(["list"])
    }

    function openInObsidian(id) {
        const target = id
            ? `obsidian://open?path=${encodeURIComponent(root.vaultPath + "/" + id)}`
            : `obsidian://open?vault=${encodeURIComponent(root.vaultName)}`
        Quickshell.execDetached(["xdg-open", target])
    }

    function patch(id, changes) {
        root.list = root.list.map(n => n.id === id ? Object.assign({}, n, changes) : n)
    }

    function enqueue(args, env) {
        root.queue = root.queue.concat([{ "args": args, "env": env ?? ({}) }])
        root.runNext()
    }

    function runNext() {
        if (vaultProc.running || root.queue.length === 0) return
        const op = root.queue[0]
        root.queue = root.queue.slice(1)
        vaultProc.environment = op.env
        vaultProc.command = ["python3",
            `${Directories.scriptPath}/notes/vault.py`.replace(/file:\/\//, ""),
            op.args[0], root.vaultPath].concat(op.args.slice(1))
        vaultProc.running = true
    }

    function applyResult(line) {
        let data
        try {
            data = JSON.parse(line)
        } catch (e) {
            root.lastError = String(e)
            console.log("[Notes] respuesta ilegible:", line)
            return
        }
        if (!data.ok) {
            root.lastError = data.error ?? "error desconocido"
            console.log("[Notes]", root.lastError)
            // Lo optimista quedó mal: releer lo que hay de verdad en disco.
            root.lastSnapshot = ""
            root.refresh()
            return
        }
        root.lastError = ""
        root.loaded = true
        // Con más operaciones en cola, esta lista ya es vieja: aplicarla haría
        // reaparecer un instante una nota que se acaba de borrar.
        if (root.queue.length > 0) return
        const snapshot = JSON.stringify([data.notes, data.folders])
        if (snapshot === root.lastSnapshot) return
        root.lastSnapshot = snapshot
        root.folders = data.folders ?? []
        root.list = data.notes.map(n => ({
            "id": n.id,
            "folder": n.folder,
            "title": n.title,
            "content": n.content,
            "pinned": n.pinned,
            "createdAt": n.modified,
            "attachments": []
        }))
    }

    Process {
        id: vaultProc
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim().length > 0) root.applyResult(text.trim())
                Qt.callLater(root.runNext)
            }
        }
        // Diferido y desde los dos lados: si la siguiente operación arrancara
        // antes de que llegue la salida de esta, esa respuesta se perdería.
        onExited: Qt.callLater(root.runNext)
    }

    Timer {
        interval: root.pollInterval
        running: true
        repeat: true
        onTriggered: if (!vaultProc.running && root.queue.length === 0) root.refresh()
    }

    onVaultPathChanged: {
        root.lastSnapshot = ""
        root.refresh()
    }

    Component.onCompleted: root.refresh()
}
