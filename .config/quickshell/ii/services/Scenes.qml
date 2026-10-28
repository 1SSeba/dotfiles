pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.modules.common

/**
 * Escenas de grabación (composición tipo OBS).
 *
 * Toda la manipulación de `Config.options.screenRecord.scenes` vive acá y no en
 * los widgets: el editor flotante de Super+G, la ventana Studio y la página de
 * Settings son tres UIs distintas sobre este mismo estado, y antes de esto la
 * lógica estaba duplicada en el editor.
 *
 * Regla que hay que respetar en cada mutación: `scenes` es un `list<var>`, y
 * mutarlo in-place NO dispara el guardado a disco. Siempre se reasigna una
 * copia entera (mismo patrón que `agentsSection` en ServicesConfig.qml).
 */
Singleton {
    id: root

    readonly property list<var> scenes: Config.options.screenRecord.scenes ?? []
    readonly property string activeSceneId: Config.options.screenRecord.activeSceneId
    readonly property var activeScene: root.scenes.find(s => s.id === root.activeSceneId) ?? root.scenes[0] ?? null
    readonly property int activeSceneIndex: root.scenes.findIndex(s => s.id === root.activeSceneId)
    readonly property bool recording: Persistent.states.record.enable

    // Lienzo de composición: lo configurado, o la resolución del monitor activo.
    property int monitorWidth: 1920
    property int monitorHeight: 1080
    readonly property int canvasWidth: Config.options.screenRecord.canvasWidth > 0 ? Config.options.screenRecord.canvasWidth : root.monitorWidth
    readonly property int canvasHeight: Config.options.screenRecord.canvasHeight > 0 ? Config.options.screenRecord.canvasHeight : root.monitorHeight

    // Listas vivas para los selectores de fuente
    property list<var> windows: []
    property list<string> cameras: []
    property list<var> monitors: []

    /**
     * Fuente seleccionada en la UI (-1 = ninguna). No se persiste: es estado de
     * edición. Vive acá y no en cada widget porque el lienzo y la lista de
     * fuentes tienen que compartir la misma selección, y pasársela entre ellos
     * con bindings en los dos sentidos genera binding loops.
     */
    property int selectedSourceIndex: -1
    onActiveSceneIdChanged: root.selectedSourceIndex = -1

    // ─────────────────────────────────────────────────────────── helpers

    function _commit(list) {
        Config.options.screenRecord.scenes = list;
    }

    function _copy() {
        return JSON.parse(JSON.stringify(root.scenes));
    }

    /** Devuelve [copia, escena] de la escena activa, o [null, null] si no hay. */
    function _editable(sceneId) {
        const list = root._copy();
        const scene = list.find(s => s.id === (sceneId ?? root.activeSceneId));
        return scene ? [list, scene] : [null, null];
    }

    function _uniqueId(list, base) {
        let n = 1;
        while (list.some(s => s.id === `${base}${n}`)) n++;
        return `${base}${n}`;
    }

    // ─────────────────────────────────────────────────────────── escenas

    function addScene(name) {
        const list = root._copy();
        const id = root._uniqueId(list, "scene");
        list.push({
            id: id,
            name: name && name.length > 0 ? name : Translation.tr("Escena %1").arg(list.length + 1),
            sources: [{ type: "screen", monitor: "", x: 0, y: 0, width: 1, height: 1, z: 0, visible: true, opacity: 1 }],
            audio: [{ type: "system", id: "", name: Translation.tr("Audio del sistema"), volume: 1, muted: false }]
        });
        root._commit(list);
        Config.options.screenRecord.activeSceneId = id;
        return id;
    }

    function duplicateScene(sceneId) {
        const list = root._copy();
        const original = list.find(s => s.id === (sceneId ?? root.activeSceneId));
        if (!original) return "";
        const id = root._uniqueId(list, "scene");
        const clone = JSON.parse(JSON.stringify(original));
        clone.id = id;
        clone.name = `${original.name} (copia)`;
        list.push(clone);
        root._commit(list);
        Config.options.screenRecord.activeSceneId = id;
        return id;
    }

    function removeScene(sceneId) {
        let list = root._copy().filter(s => s.id !== sceneId);
        if (list.length === 0) return; // nunca dejar cero escenas
        root._commit(list);
        if (root.activeSceneId === sceneId) {
            Config.options.screenRecord.activeSceneId = list[0].id;
        }
    }

    function renameScene(sceneId, name) {
        const [list, scene] = root._editable(sceneId);
        if (!scene || scene.name === name) return;
        scene.name = name;
        root._commit(list);
    }

    function setActiveScene(sceneId) {
        Config.options.screenRecord.activeSceneId = sceneId;
    }

    // ─────────────────────────────────────────────────────────── fuentes

    /** Valores por defecto de una fuente nueva según su tipo. */
    function _defaultSource(type, extra) {
        // Las fuentes de pantalla ocupan todo el lienzo; el resto entra como
        // recuadro chico abajo a la derecha, listo para arrastrar.
        const fullSize = (type === "screen");
        const base = {
            type: type,
            monitor: "",
            address: "",
            appClass: "",
            appTitle: "",
            device: "",
            path: "",
            x: fullSize ? 0 : 0.62,
            y: fullSize ? 0 : 0.62,
            width: fullSize ? 1 : 0.32,
            height: fullSize ? 1 : 0.32,
            z: 0,
            visible: true,
            opacity: 1
        };
        return Object.assign(base, extra ?? {});
    }

    function addSource(type, extra, sceneId) {
        const [list, scene] = root._editable(sceneId);
        if (!scene) return;
        scene.sources = scene.sources ?? [];
        const source = root._defaultSource(type, extra);
        source.z = scene.sources.length;
        scene.sources.push(source);
        root._commit(list);
    }

    function updateSource(index, patch, sceneId) {
        const [list, scene] = root._editable(sceneId);
        if (!scene || !scene.sources || !scene.sources[index]) return;
        Object.assign(scene.sources[index], patch);
        root._commit(list);
    }

    function removeSource(index, sceneId) {
        const [list, scene] = root._editable(sceneId);
        if (!scene || !scene.sources) return;
        scene.sources.splice(index, 1);
        scene.sources.forEach((s, i) => s.z = i); // recompactar el z-order
        root._commit(list);
    }

    /** Mueve una fuente en el z-order. delta -1 = atrás, +1 = adelante. */
    function moveSource(index, delta, sceneId) {
        const [list, scene] = root._editable(sceneId);
        if (!scene || !scene.sources) return;
        const target = index + delta;
        if (target < 0 || target >= scene.sources.length) return;
        const [moved] = scene.sources.splice(index, 1);
        scene.sources.splice(target, 0, moved);
        scene.sources.forEach((s, i) => s.z = i);
        root._commit(list);
    }

    function toggleSourceVisible(index, sceneId) {
        const [list, scene] = root._editable(sceneId);
        if (!scene || !scene.sources || !scene.sources[index]) return;
        const source = scene.sources[index];
        source.visible = !(source.visible ?? true);
        root._commit(list);
    }

    /**
     * Relación de aspecto real de la fuente (ancho/alto), o 0 si no se puede
     * saber (imagen y cámara: habría que abrir el archivo o el dispositivo).
     */
    function sourceAspect(source) {
        if (!source) return 0;
        if (source.type === "window") {
            const win = root.windows.find(w => w.address === source.address);
            return (win && win.height > 0) ? win.width / win.height : 0;
        }
        if (source.type === "screen") {
            const name = (source.monitor && source.monitor.length > 0)
                ? source.monitor
                : (root.monitors.find(m => m.focused)?.name ?? "");
            const mon = root.monitors.find(m => m.name === name);
            return (mon && mon.height > 0) ? mon.width / mon.height : 0;
        }
        return 0;
    }

    /**
     * Encuadres rápidos, equivalentes a los de OBS:
     *   "fit"     ajusta al lienzo respetando la relación de aspecto
     *   "stretch" estira a todo el lienzo (deforma)
     *   "center"  centra sin cambiar el tamaño
     *   "reset"   vuelve al recuadro chico por defecto
     */
    function fitSource(index, mode) {
        const source = root.activeScene?.sources?.[index];
        if (!source) return;

        if (mode === "stretch") {
            root.updateSource(index, { x: 0, y: 0, width: 1, height: 1 });
            return;
        }
        if (mode === "center") {
            root.updateSource(index, {
                x: (1 - (source.width ?? 0.3)) / 2,
                y: (1 - (source.height ?? 0.3)) / 2
            });
            return;
        }
        if (mode === "reset") {
            root.updateSource(index, { x: 0.62, y: 0.62, width: 0.32, height: 0.32 });
            return;
        }

        // fit: una fuente de aspecto `a` dibujada con fracciones (fw, fh) sobre
        // un lienzo de aspecto `c` termina con aspecto (fw/fh)*c, así que para
        // respetar `a` hace falta fw/fh = a/c.
        const canvasAspect = root.canvasWidth / Math.max(1, root.canvasHeight);
        const aspect = root.sourceAspect(source);
        if (aspect <= 0) {
            root.updateSource(index, { x: 0, y: 0, width: 1, height: 1 });
            return;
        }
        let w = 1;
        let h = canvasAspect / aspect;
        if (h > 1) {
            h = 1;
            w = aspect / canvasAspect;
        }
        root.updateSource(index, { x: (1 - w) / 2, y: (1 - h) / 2, width: w, height: h });
    }

    /** Mueve una fuente de a poco, en píxeles reales del lienzo. */
    function nudgeSource(index, dx, dy) {
        const source = root.activeScene?.sources?.[index];
        if (!source) return;
        const w = source.width ?? 0.3;
        const h = source.height ?? 0.3;
        root.updateSource(index, {
            x: Math.max(0, Math.min(1 - w, (source.x ?? 0) + dx / root.canvasWidth)),
            y: Math.max(0, Math.min(1 - h, (source.y ?? 0) + dy / root.canvasHeight))
        });
    }

    /** Etiqueta legible de una fuente, para listas y para la caja del lienzo. */
    function sourceLabel(source) {
        if (!source) return "";
        switch (source.type) {
        case "screen":
            return source.monitor && source.monitor.length > 0 ? source.monitor : Translation.tr("Pantalla activa");
        case "window":
            return source.appTitle && source.appTitle.length > 0 ? source.appTitle : (source.appClass ?? Translation.tr("Ventana"));
        case "webcam":
            return source.device && source.device.length > 0 ? source.device : Translation.tr("Cámara");
        case "image":
            return (source.path ?? "").split("/").pop() || Translation.tr("Imagen");
        }
        return source.type;
    }

    function sourceIcon(source) {
        switch (source?.type) {
        case "screen": return "monitor";
        case "window": return "web_asset";
        case "webcam": return "videocam";
        case "image": return "image";
        }
        return "widgets";
    }

    // ─────────────────────────────────────────────────────── audio (mezcla)

    function addAudio(type, id, name, sceneId) {
        const [list, scene] = root._editable(sceneId);
        if (!scene) return;
        scene.audio = scene.audio ?? [];
        // No duplicar la misma fuente dentro de una escena
        if (scene.audio.some(a => a.type === type && a.id === id)) return;
        scene.audio.push({ type: type, id: id ?? "", name: name ?? id ?? "", volume: 1, muted: false });
        root._commit(list);
    }

    function updateAudio(index, patch, sceneId) {
        const [list, scene] = root._editable(sceneId);
        if (!scene || !scene.audio || !scene.audio[index]) return;
        Object.assign(scene.audio[index], patch);
        root._commit(list);
    }

    function removeAudio(index, sceneId) {
        const [list, scene] = root._editable(sceneId);
        if (!scene || !scene.audio) return;
        scene.audio.splice(index, 1);
        root._commit(list);
    }

    /**
     * Objeto capturable para el preview en vivo del lienzo.
     *
     * `ScreencopyView` (el mismo que usan las miniaturas del overview y del
     * dock) acepta un Toplevel o una pantalla, así que el editor puede mostrar
     * la ventana/monitor de verdad en vez de un rectángulo gris. Ojo: esto es
     * solo para el preview — la grabación en sí no pasa por acá, la hace
     * wf-recorder recortando por geometría.
     */
    function captureSourceFor(source) {
        if (!source) return null;
        if (source.type === "window") {
            if (!source.address) return null;
            return ToplevelManager.toplevels.values.find(t => `0x${t.HyprlandToplevel?.address}` === source.address) ?? null;
        }
        if (source.type === "screen") {
            const wanted = (source.monitor && source.monitor.length > 0)
                ? source.monitor
                : (root.monitors.find(m => m.focused)?.name ?? "");
            return Quickshell.screens.find(s => s.name === wanted) ?? null;
        }
        return null;
    }

    function audioIcon(entry) {
        switch (entry?.type) {
        case "system": return "volume_up";
        case "mic": return "mic";
        case "app": return "apps";
        }
        return "graphic_eq";
    }

    // ────────────────────────────────────────────────── grabación (script)

    /** Arranca o detiene la grabación con escenas (el script hace toggle solo). */
    function toggleRecording() {
        Quickshell.execDetached([Directories.sceneRecordScriptPath]);
    }

    /**
     * Aplica la escena activa a una grabación en curso. El modelo acordado es
     * "corte breve": el script se llama dos veces (para y arranca) con una
     * pausa en el medio para que el proceso anterior termine de cerrar.
     */
    function applyActiveScene() {
        if (!root.recording) return;
        Quickshell.execDetached([Directories.sceneRecordScriptPath]);
        restartTimer.restart();
    }

    Timer {
        id: restartTimer
        interval: 600
        onTriggered: Quickshell.execDetached([Directories.sceneRecordScriptPath])
    }

    // ──────────────────────────────────────────────── listas vivas del sistema

    function refresh() {
        windowProc.running = true;
        cameraProc.running = true;
        monitorProc.running = true;
    }

    Component.onCompleted: root.refresh()

    /**
     * Escenas guardadas antes de que existieran las fuentes tipificadas y el
     * mezclador: no tienen la clave `audio`, y su `sources` está vacío porque
     * en ese modelo la pantalla era implícita. Se les completa una vez para
     * que no aparezcan como escenas vacías e inservibles.
     *
     * La ausencia de `audio` es lo que marca el formato viejo — una escena
     * nueva a la que le borraste todo el audio tiene `audio: []`, que no es
     * lo mismo que no tenerla.
     */
    property bool _migrated: false
    onScenesChanged: {
        if (root._migrated || root.scenes.length === 0) return;
        if (!root.scenes.some(s => s.audio === undefined)) {
            root._migrated = true;
            return;
        }
        const list = root._copy();
        list.forEach(scene => {
            if (scene.audio === undefined) {
                scene.audio = [{ type: "system", id: "", name: Translation.tr("Audio del sistema"), volume: 1, muted: false }];
            }
            if (!scene.sources || scene.sources.length === 0) {
                scene.sources = [root._defaultSource("screen", { z: 0 })];
            }
        });
        root._migrated = true;
        root._commit(list);
    }

    Process {
        id: windowProc
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.windows = JSON.parse(text)
                        .filter(c => !c.hidden && c.mapped !== false && (c.size?.[0] ?? 0) > 0)
                        .map(c => ({
                            address: c.address,
                            appClass: c.class ?? "",
                            appTitle: c.title ?? "",
                            x: c.at?.[0] ?? 0,
                            y: c.at?.[1] ?? 0,
                            width: c.size?.[0] ?? 0,
                            height: c.size?.[1] ?? 0
                        }));
                } catch (e) {
                    console.log("[Scenes] No se pudo leer hyprctl clients:", e);
                }
            }
        }
    }

    Process {
        id: cameraProc
        command: ["bash", "-c", "ls /dev/video* 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.cameras = text.split("\n").map(s => s.trim()).filter(s => s.length > 0);
            }
        }
    }

    Process {
        id: monitorProc
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(text);
                    root.monitors = parsed.map(m => ({ name: m.name, width: m.width, height: m.height, focused: m.focused }));
                    const focused = parsed.find(m => m.focused) ?? parsed[0];
                    if (focused) {
                        root.monitorWidth = focused.width;
                        root.monitorHeight = focused.height;
                    }
                } catch (e) {
                    console.log("[Scenes] No se pudo leer hyprctl monitors:", e);
                }
            }
        }
    }
}
