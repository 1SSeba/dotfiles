pragma ComponentBehavior: Bound
import QtQml
import QtQuick
import Quickshell.Io
import qs.services
import qs.modules.common
import "../"

NestableObject {
    id: root

    property var monitors: []

    Component.onCompleted: fetchProc.running = true

    function updateMonitor(index, changes) {
        let m = root.monitors.slice()
        m[index] = Object.assign({}, m[index], changes)
        root.monitors = m
    }

    /**
     * Una línea de monitors.conf.
     *
     * El fork escribe Lua (hl.monitor{...}) porque su Hyprland se configura así.
     * Acá la config es .conf y hyprland.conf hace `source=monitors.conf`, de modo
     * que escribir Lua dejaba un monitors.lua que nadie lee: los cambios se
     * aplicaban en vivo pero se perdían en el siguiente reload.
     */
    function _buildConfLine(m) {
        if (m.disabled)
            return `monitor = ${m.name},disable`

        let line = `monitor = ${m.name},${m.currentMode},${m.x}x${m.y},${m.scale}`
        if (m.transform && m.transform !== 0)
            line += `,transform,${m.transform}`
        return line
    }

    function save() {
        if (root.monitors.length === 0) return
        if (root.monitors.some(m => !m.name)) return

        const header = "# Generado por la shell (Settings -> Hyprland -> Pantallas)\n"
        const lines = header + root.monitors.map(m => root._buildConfLine(m)).join("\n")

        const escaped = lines.replace(/'/g, "'\\''")
        saveProc.command = ["bash", "-c",
            `printf '%s\n' '${escaped}' > ~/.config/hypr/monitors.conf`]
        saveProc.running = true
    }

    function applyMonitor(m) {
        if (!m.name) return

        const base = `${m.name},${m.currentMode},${m.x}x${m.y},${m.scale}`
        applyProc.command = ["hyprctl", "keyword", "monitor",
            m.disabled
                ? `${m.name},disable`
                : (m.transform && m.transform !== 0)
                    ? `${base},transform,${m.transform}`
                    : base]
        applyProc.running = true
    }

    function applyAndSave(index) {
        root._trackModeRequest(index, true)
        root.applyMonitor(root.monitors[index])
        root.save()
        // Hyprland no acepta cualquier escala: ajusta a la válida más cercana.
        // Sin volver a leer, la UI seguiría mostrando el valor pedido y no el real.
        refetchTimer.restart()
    }

    /*
     * ── Verificación y fallback de modo ──────────────────────────────────
     *
     * El driver puede rechazar un modo que no esté en la lista del conector.
     * Comprobado en el log de Hyprland al pedir 1440x1080@144 en DP-1:
     *
     *   atomic drm request: failed to commit: Invalid argument, ATOMIC_TEST_ONLY
     *   drm: Modesetting DP-1 with 1440x900@59.89Hz
     *
     * O sea: Hyprland no se queda sin imagen, cae al modo del EDID más
     * parecido — y termina cambiándote la RESOLUCIÓN, no sólo el refresco.
     * Eso es lo que hay que evitar: el usuario eligió una resolución, y si el
     * Hz pedido no se puede, es preferible esa misma resolución a otro Hz
     * antes que saltar a una resolución distinta.
     *
     * Por eso cada pedido se verifica contra lo que quedó de verdad (el
     * refetch de más abajo) y, si la resolución no coincide, se reintenta con
     * el siguiente Hz candidato: primero el mejor que el EDID anuncia para esa
     * resolución, después 60Hz (el más universal).
     */
    property var _pendingMode: null
    /** Qué pasó con el último cambio de modo, para mostrarlo en la UI. */
    property string lastModeNotice: ""

    function _trackModeRequest(index, persist) {
        const m = root.monitors[index]
        if (!m || m.disabled) {
            root._pendingMode = null
            return
        }
        root._pendingMode = {
            name: m.name,
            width: m.width,
            height: m.height,
            refreshRate: m.refreshRate,
            tried: [m.refreshRate],
            persist: persist === true
        }
    }

    function _hzLabel(hz) {
        return Number.isInteger(hz) ? hz.toString() : hz.toFixed(2)
    }

    /** Siguiente Hz a probar para la resolución pedida, o null si no queda ninguno. */
    function _nextRateCandidate(m, req) {
        const candidates = []

        let edidBest = 0
        for (const mode of (m.availableModes ?? [])) {
            const parts = mode.match(/(\d+)x(\d+)@([\d.]+)Hz/)
            if (!parts) continue
            if (parseInt(parts[1]) === req.width && parseInt(parts[2]) === req.height)
                edidBest = Math.max(edidBest, parseFloat(parts[3]))
        }
        if (edidBest > 0) candidates.push(edidBest)
        candidates.push(60)

        for (const hz of candidates) {
            if (!req.tried.some(t => Math.abs(t - hz) < 0.5)) return hz
        }
        return null
    }

    function _verifyPendingMode() {
        const req = root._pendingMode
        if (!req) return

        const index = root.monitors.findIndex(m => m.name === req.name)
        if (index < 0) {
            root._pendingMode = null
            return
        }
        const m = root.monitors[index]

        // La resolución es lo que manda; el Hz es best-effort.
        if (m.width === req.width && m.height === req.height) {
            root._pendingMode = null
            if (Math.abs(m.refreshRate - req.tried[0]) > 0.5) {
                root.lastModeNotice = Translation.tr("The driver rejected %1×%2 at %3 Hz — it is running at %4 Hz instead.")
                    .arg(req.width).arg(req.height)
                    .arg(root._hzLabel(req.tried[0])).arg(root._hzLabel(m.refreshRate))
            } else {
                root.lastModeNotice = ""
            }
            // El reintento sólo aplicó en vivo: recién ahora que sabemos cuál
            // modo agarró tiene sentido escribirlo en monitors.conf.
            if (req.persist && req.tried.length > 1) root.save()
            return
        }

        const nextHz = root._nextRateCandidate(m, req)
        if (nextHz === null) {
            root._pendingMode = null
            root.lastModeNotice = Translation.tr("The driver rejected %1×%2 — it fell back to %3×%4 at %5 Hz.")
                .arg(req.width).arg(req.height)
                .arg(m.width).arg(m.height).arg(root._hzLabel(m.refreshRate))
            return
        }

        req.tried.push(nextHz)
        const mode = `${req.width}x${req.height}@${nextHz.toFixed(2)}Hz`
        root.lastModeNotice = Translation.tr("Retrying %1×%2 at %3 Hz…")
            .arg(req.width).arg(req.height).arg(root._hzLabel(nextHz))
        root.updateMonitor(index, {
            currentMode: mode,
            width: req.width,
            height: req.height,
            refreshRate: nextHz
        })
        root.applyMonitor(root.monitors[index])
        refetchTimer.restart()
    }

    // Resoluciones "custom" (ej. 1440x1080 estirado para CS2) que la mayoría
    // de monitores no anuncia en su EDID, así que no aparecen en availableModes.
    // Se aplican solo en vivo (hyprctl keyword, sin save()) para que sean un
    // modo "gaming" temporal: un reload/reinicio de Hyprland vuelve al nativo.
    property var _nativeModeByMonitor: ({})

    function applyCustomMode(index, width, height, refreshRate) {
        const m = root.monitors[index]
        if (!m) return
        if (!(m.name in root._nativeModeByMonitor))
            root._nativeModeByMonitor[m.name] = m.currentMode

        // Se guarda ANTES de aplicar: aunque el driver rechace el modo, la
        // resolución queda en la lista para volver a elegirla o borrarla.
        const mode = root.addCustomMode(m.name, width, height, refreshRate)
        root.updateMonitor(index, { currentMode: mode, width, height, refreshRate })
        // persist:false — desde el diálogo el modo es "gaming" temporal, no se
        // escribe en monitors.conf; pero igual se verifica y reintenta.
        root._trackModeRequest(index, false)
        root.applyMonitor(root.monitors[index])
        refetchTimer.restart()
    }

    function restoreNativeMode(index) {
        const m = root.monitors[index]
        if (!m) return
        const native = root._nativeModeByMonitor[m.name]
        if (!native) return

        const parts = native.match(/(\d+)x(\d+)@([\d.]+)Hz/)
        if (!parts) return
        root.updateMonitor(index, {
            currentMode: native,
            width: parseInt(parts[1]),
            height: parseInt(parts[2]),
            refreshRate: parseFloat(parts[3])
        })
        // Volver a la nativa siempre debería andar; si no, que el fallback
        // haga lo suyo igual que en cualquier otro cambio.
        root._trackModeRequest(index, false)
        root.lastModeNotice = ""
        root.applyMonitor(root.monitors[index])
        refetchTimer.restart()
    }

    Timer {
        id: refetchTimer
        interval: 300
        onTriggered: fetchProc.running = true
    }

    function logicalWidth(m) {
        return (m.transform === 1 || m.transform === 3) ? m.height : m.width
    }

    /**
     * El refresco máximo que anuncia el monitor, y el Hz al que se ofrece
     * CUALQUIER resolución de su lista.
     *
     * El EDID capa a ~60Hz todo lo que no sea la resolución nativa: en este
     * equipo DP-1 (panel de 165Hz) lista 1280x720 sólo a 60/59.94/50, y
     * HDMI-A-1 (144Hz) hace lo mismo. Ofrecer cada resolución al refresco real
     * del panel es justamente lo que se pide para jugar estirado sin perder Hz.
     * Si el driver termina rechazando esa combinación, el refetch posterior a
     * aplicar deja la UI mostrando lo que quedó de verdad.
     */
    function maxRefreshRate(m) {
        let max = 0
        for (const mode of (m?.availableModes ?? [])) {
            const parts = mode.match(/(\d+)x(\d+)@([\d.]+)Hz/)
            if (parts) max = Math.max(max, parseFloat(parts[3]))
        }
        return max > 0 ? max : (m?.refreshRate ?? 60)
    }

    /** Resoluciones custom guardadas para un monitor (ver Config.customModesByMonitor). */
    function customModesFor(monitorName) {
        if (!monitorName) return []
        return (Config.options.customModesByMonitor ?? {})[monitorName] ?? []
    }

    function addCustomMode(monitorName, width, height, refreshRate) {
        const value = `${width}x${height}@${refreshRate.toFixed(2)}Hz`
        if (!monitorName) return value

        // Objeto nuevo, no mutación: si se escribe adentro del mismo objeto, la
        // property var no emite el cambio y la lista de resoluciones no se entera.
        const all = Object.assign({}, Config.options.customModesByMonitor ?? {})
        const list = (all[monitorName] ?? []).slice()
        if (!list.includes(value)) list.push(value)
        all[monitorName] = list
        Config.options.customModesByMonitor = all
        return value
    }

    function removeCustomMode(monitorName, value) {
        if (!monitorName) return
        const all = Object.assign({}, Config.options.customModesByMonitor ?? {})
        all[monitorName] = (all[monitorName] ?? []).filter(v => v !== value)
        Config.options.customModesByMonitor = all
    }

    function _modeEntry(width, height, refreshRate, isCustom) {
        const hzLabel = Number.isInteger(refreshRate) ? refreshRate.toString() : refreshRate.toFixed(2)
        return {
            // `value` mantiene el formato crudo de Hyprland para que siga
            // matcheando contra `currentMode` y lo parseen los regex de afuera.
            value: `${width}x${height}@${refreshRate.toFixed(2)}Hz`,
            display: `${width} × ${height}  ·  ${hzLabel} Hz` + (isCustom ? "  ·  custom" : ""),
            width, height, refreshRate,
            custom: isCustom
        }
    }

    /**
     * La lista de resoluciones que ve el usuario: una entrada por resolución
     * (no una por cada combinación resolución+Hz del EDID, que llenaba el combo
     * de duplicados a 50/59.94/60Hz), más las custom guardadas, más el modo que
     * el monitor tiene puesto ahora mismo — este último para que el combo nunca
     * quede mostrando algo distinto de la realidad si el driver sustituyó el modo.
     */
    function sortedAvailableModes(m) {
        if (!m) return []

        const hz = root.maxRefreshRate(m)
        const seenValue = ({})
        const modes = []

        function push(entry) {
            if (seenValue[entry.value]) return
            seenValue[entry.value] = true
            modes.push(entry)
        }

        const seenResolution = ({})
        for (const mode of (m.availableModes ?? [])) {
            const parts = mode.match(/(\d+)x(\d+)@([\d.]+)Hz/)
            if (!parts) continue
            const width = parseInt(parts[1])
            const height = parseInt(parts[2])
            const key = `${width}x${height}`
            if (seenResolution[key]) continue
            seenResolution[key] = true
            push(root._modeEntry(width, height, hz, false))
        }

        for (const mode of root.customModesFor(m.name)) {
            const parts = String(mode).match(/(\d+)x(\d+)@([\d.]+)Hz/)
            if (!parts) continue
            push(root._modeEntry(parseInt(parts[1]), parseInt(parts[2]), parseFloat(parts[3]), true))
        }

        const current = String(m.currentMode ?? "").match(/(\d+)x(\d+)@([\d.]+)Hz/)
        if (current)
            push(root._modeEntry(parseInt(current[1]), parseInt(current[2]), parseFloat(current[3]), false))

        modes.sort((a, b) => (b.width * b.height - a.width * a.height) || (b.refreshRate - a.refreshRate))
        return modes
    }

    function logicalHeight(m) {
        return (m.transform === 1 || m.transform === 3) ? m.width : m.height
    }

    Process {
        id: fetchProc
        command: ["hyprctl", "monitors", "all", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.monitors = JSON.parse(text).map(m => ({
                        name:          m.name,
                        description:   m.description,
                        width:         m.width,
                        height:        m.height,
                        refreshRate:   m.refreshRate,
                        x:             m.x,
                        y:             m.y,
                        scale:         m.scale,
                        transform:     m.transform ?? 0,
                        disabled:      m.disabled,
                        availableModes: m.availableModes,
                        currentMode:   `${m.width}x${m.height}@${m.refreshRate.toFixed(2)}Hz`
                    }))
                    // Con los datos reales ya cargados: ver si el modo que se
                    // pidió es el que quedó, y reintentar con otro Hz si no.
                    root._verifyPendingMode()
                } catch(e) {
                    console.log("[MonitorConfig] Error parseando JSON:", e)
                }
            }
        }
    }

    Process { id: applyProc }

    Process {
        id: saveProc
        onRunningChanged: if (!running) reloadProc.running = true
    }

    Process {
        id: reloadProc
        command: ["hyprctl", "reload"]
    }
}
