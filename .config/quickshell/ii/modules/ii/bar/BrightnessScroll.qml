import qs
import Quickshell
import qs.services
import qs.modules.common
import QtQuick

/** Brillo del monitor donde está la barra. */
ScrollControl {
    id: root

    // Cada pantalla tiene su propio brillo, así que hay que resolver el monitor de
    // la barra y no usar un valor global.
    readonly property var screen: root.QsWindow?.window?.screen ?? null
    readonly property var monitor: Brightness.getMonitorForScreen(root.screen)

    value: root.monitor?.brightness ?? 0
    icon: value < 0.34 ? "brightness_low" : value < 0.67 ? "brightness_medium" : "brightness_high"
    tooltipText: Translation.tr("Scroll to change brightness")

    onIncrease: Brightness.increaseBrightness()
    onDecrease: Brightness.decreaseBrightness()
    onMovedAway: GlobalStates.osdBrightnessOpen = false
}
