pragma ComponentBehavior: Bound
import QtQml
import QtQuick
import Quickshell.Io
import qs.services
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
        root.applyMonitor(root.monitors[index])
        root.save()
        // Hyprland no acepta cualquier escala: ajusta a la válida más cercana.
        // Sin volver a leer, la UI seguiría mostrando el valor pedido y no el real.
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
