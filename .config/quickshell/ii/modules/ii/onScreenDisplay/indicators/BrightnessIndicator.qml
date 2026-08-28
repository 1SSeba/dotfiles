import qs.services
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.modules.ii.onScreenDisplay

OsdValueIndicator {
    id: root
    property var focusedScreen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name)
    property var brightnessMonitor: Brightness.getMonitorForScreen(focusedScreen)

    icon: Hyprsunset.temperatureActive ? "routine" : "light_mode"
    rotateIcon: true
    scaleIcon: true
    name: Translation.tr("Brightness")
    // brightness va de 0 a 1: el 50 de antes clavaba el indicador al maximo.
    value: root.brightnessMonitor?.brightness ?? 1
}
