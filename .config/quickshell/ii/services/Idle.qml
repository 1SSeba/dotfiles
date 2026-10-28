pragma Singleton
import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

/**
 * A nice wrapper for date and time strings.
 */
Singleton {
    id: root

    property alias inhibit: idleInhibitor.enabled
    inhibit: false

    Connections {
        target: Persistent
        function onReadyChanged() {
            if (!Persistent.isNewHyprlandInstance) {
                root.inhibit = Persistent.states.idle.inhibit;
            } else {
                Persistent.states.idle.inhibit = root.inhibit;
            }
        }
    }

    function toggleInhibit(active = null) {
        if (active !== null) {
            root.inhibit = active;
        } else {
            root.inhibit = !root.inhibit;
        }
        Persistent.states.idle.inhibit = root.inhibit;
    }

    IdleInhibitor {
        id: idleInhibitor
        window: PanelWindow {
            // Inhibitor requires a "visible" surface
            // Actually not lol
            implicitWidth: 0
            implicitHeight: 0
            color: "transparent"
            // Just in case...
            anchors {
                right: true
                bottom: true
            }
            // Make it not interactable
            mask: Region {
                item: null
            }
        }
    }

    // El IdleInhibitor de arriba (protocolo wayland idle-inhibit sobre una
    // superficie layer-shell) no es respetado de forma confiable por
    // Hyprland/hypridle: en la práctica el PC se suspendió con "Keep awake"
    // activado. Como respaldo, tomamos también un inhibidor de logind que
    // bloquea el suspend directamente a nivel systemd, sin depender del
    // protocolo wayland ni de si Hyprland reconoce esta superficie.
    //
    // El --what incluye 'idle' ademas de 'sleep' a proposito: con solo
    // 'sleep' se bloquea la suspension, pero hypridle sigue corriendo sus
    // listeners y el equipo igual se bloqueaba a los 5 min y apagaba la
    // pantalla (dpms) a los 10. hypridle lee la propiedad BlockInhibited
    // de logind (general:ignore_systemd_inhibit = false por defecto), asi
    // que con 'idle' pausa TODOS sus timeouts: lock, dpms y suspend.
    Process {
        id: sleepInhibitProc
        running: root.inhibit
        command: ["systemd-inhibit", "--what=idle:sleep", "--mode=block", "--who=quickshell", "--why=Manual keep-awake toggle", "sleep", "infinity"]
    }
}
