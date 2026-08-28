pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import Quickshell;
import Quickshell.Io;
import QtQuick;

/**
 * Simple to-do list manager.
 * Each item is an object with "content" and "done" properties.
 *
 * `list` sigue siendo SÓLO lo local, guardado en el archivo, con los índices
 * intactos: todo lo que ya existía y usa índices sigue andando igual. Las tareas
 * de Google y los recordatorios de iCloud se suman aparte, en `unifiedList`, y
 * nunca tocan el archivo — si desconectás una cuenta, tus tareas locales quedan
 * exactamente como estaban.
 *
 * Para modificar una tarea desde la UI conviene usar `toggleDone(item)` y
 * `removeItem(item)`, que miran de dónde salió y despachan solas. Las funciones
 * por índice de más abajo son las de siempre y sólo valen para las locales.
 */
Singleton {
    id: root
    property var filePath: Directories.todoPath
    property var list: []

    /**
     * Lo local, lo de Google y lo de iCloud en una sola lista, que es lo que
     * muestra el widget. Cada item lleva `source`; las locales además
     * `originalIndex`, que es su posición en `list` — el índice que esperan
     * markDone/deleteItem.
     */
    readonly property var unifiedList: {
        let todas = root.list.map(function(item, i) {
            return Object.assign({}, item, { "source": "local", "originalIndex": i });
        });
        if (GoogleTasks.enabled) todas = todas.concat(GoogleTasks.list);
        if (AppleReminders.enabled) todas = todas.concat(AppleReminders.list);
        return todas;
    }

    readonly property int remainingCount: root.unifiedList.filter(function(t) { return !t.done; }).length

    /** Marca o desmarca, venga de donde venga. */
    function toggleDone(item) {
        if (!item) return;
        if (item.source === "google") {
            GoogleTasks.setDone(item, !item.done);
            return;
        }
        if (item.source === "apple") {
            AppleReminders.setDone(item, !item.done);
            return;
        }
        if (item.done) root.markUnfinished(item.originalIndex);
        else root.markDone(item.originalIndex);
    }

    /**
     * Adónde lleva una tarea en el navegador. Ni Google Tasks ni Recordatorios
     * dan un link por tarea, así que se abre su lista web — que es lo que uno
     * quiere cuando hace click: verla donde se puede editar en serio.
     */
    function linkFor(item) {
        if (!item) return "";
        if (item.source === "google") return "https://tasks.google.com/";
        if (item.source === "apple") return "https://www.icloud.com/reminders";
        return "";  // las locales viven en un archivo, no hay web que abrir
    }

    function open(item) {
        const url = root.linkFor(item);
        if (url.length > 0) Quickshell.execDetached(["xdg-open", url]);
    }

    /** Borra, venga de donde venga. */
    function removeItem(item) {
        if (!item) return;
        if (item.source === "google") {
            GoogleTasks.remove(item);
            return;
        }
        if (item.source === "apple") {
            AppleReminders.remove(item);
            return;
        }
        root.deleteItem(item.originalIndex);
    }

    
    function addItem(item) {
        list.push(item)
        // Reassign to trigger onListChanged
        root.list = list.slice(0)
        todoFileView.setText(JSON.stringify(root.list))
    }

    /**
     * Tarea nueva. Va a la nube si esa cuenta está conectada Y lo pediste en
     * Ajustes; si no, al archivo local de siempre. El default es local a
     * propósito: conectar una cuenta no debería cambiar en silencio dónde
     * terminan las cosas que escribís.
     *
     * Si marcaste las dos, gana Google: escribir la misma tarea en los dos lados
     * dejaría dos copias que después hay que tildar por separado.
     */
    function addTask(desc) {
        if (GoogleTasks.enabled
            && (Config.options?.services?.google?.tasks?.addNewTasksToGoogle ?? false)
            && GoogleTasks.add(desc)) return;

        if (AppleReminders.enabled
            && (Config.options?.services?.apple?.reminders?.addNewTasksToApple ?? false)
            && AppleReminders.add(desc)) return;

        const item = {
            "content": desc,
            "done": false,
        }
        addItem(item)
    }

    function markDone(index) {
        if (index >= 0 && index < list.length) {
            list[index].done = true
            // Reassign to trigger onListChanged
            root.list = list.slice(0)
            todoFileView.setText(JSON.stringify(root.list))
        }
    }

    function markUnfinished(index) {
        if (index >= 0 && index < list.length) {
            list[index].done = false
            // Reassign to trigger onListChanged
            root.list = list.slice(0)
            todoFileView.setText(JSON.stringify(root.list))
        }
    }

    function deleteItem(index) {
        if (index >= 0 && index < list.length) {
            list.splice(index, 1)
            // Reassign to trigger onListChanged
            root.list = list.slice(0)
            todoFileView.setText(JSON.stringify(root.list))
        }
    }

    function refresh() {
        todoFileView.reload()
    }

    Component.onCompleted: {
        refresh()
    }

    FileView {
        id: todoFileView
        path: Qt.resolvedUrl(root.filePath)
        onLoaded: {
            // Un JSON roto tiraba una excepcion que dejaba root.list en su valor
            // anterior sin decir nada. Mejor avisar y no perder el archivo.
            try {
                const parsed = JSON.parse(todoFileView.text())
                root.list = Array.isArray(parsed) ? parsed : []
                console.log("[To Do] File loaded")
            } catch (e) {
                console.log("[To Do] Archivo ilegible, no se toca: " + e)
            }
        }
        onLoadFailed: (error) => {
            if(error == FileViewError.FileNotFound) {
                console.log("[To Do] File not found, creating new file.")
                root.list = []
                todoFileView.setText(JSON.stringify(root.list))
            } else {
                console.log("[To Do] Error loading file: " + error)
            }
        }
    }
}

