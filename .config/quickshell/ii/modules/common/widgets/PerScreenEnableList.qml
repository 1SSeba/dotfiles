import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland

/**
 * Lista de monitores con un switch cada uno, para decidir en cuáles vive un
 * widget del fondo puntual. Es la misma UI que "Show bar on" de la barra
 * (ver BarConfig.qml), pero en vez de escribir un `list<string>` plano,
 * guarda el override en `configEntry.screens[<monitor>].enable` -- porque
 * ese mismo mapa también carga la posición/tamaño propios de cada pantalla
 * (ver AbstractBackgroundWidget.qml).
 *
 * Sin override en una pantalla = sigue el switch global de "Enable" de
 * siempre. Por eso "All" no es un tercer estado guardado, es simplemente
 * "sin overrides": tildarlo borra los que hubiera.
 */
ColumnLayout {
    id: root
    required property var configEntry // Config.options.background.widgets.<algo>

    // Con un solo monitor esto no decide nada.
    visible: Hyprland.monitors.values.length > 1
    Layout.fillWidth: true
    spacing: 2

    function isOverriddenOff(monitorName) {
        return root.configEntry?.screens?.[monitorName]?.enable === false;
    }

    function setOverriddenOff(monitorName, off) {
        if (!root.configEntry) return;
        const screens = Object.assign({}, root.configEntry.screens || {});
        const entry = Object.assign({}, screens[monitorName] || {});
        if (off) {
            entry.enable = false;
        } else {
            delete entry.enable;
        }
        if (Object.keys(entry).length === 0) {
            delete screens[monitorName];
        } else {
            screens[monitorName] = entry;
        }
        root.configEntry.screens = screens;
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: allSwitchItem.implicitHeight + 16 + 8
        color: Appearance.colors.colLayer1
        topLeftRadius: Appearance.rounding.normal
        topRightRadius: Appearance.rounding.normal
        bottomLeftRadius: Appearance.rounding.unsharpenmore
        bottomRightRadius: Appearance.rounding.unsharpenmore

        ConfigSwitch {
            id: allSwitchItem
            anchors {
                fill: parent
                margins: 8
            }
            buttonIcon: "tv_displays"
            text: Translation.tr("All")
            onCheckedChanged: {
                if (checked) {
                    Hyprland.monitors.values.forEach(m => root.setOverriddenOff(m.name, false));
                }
            }

            Binding {
                target: allSwitchItem
                property: "checked"
                value: !Hyprland.monitors.values.some(m => root.isOverriddenOff(m.name))
                restoreMode: Binding.RestoreBinding
            }
        }
    }

    Repeater {
        model: Hyprland.monitors
        delegate: Rectangle {
            id: monitorRow
            required property var modelData
            required property int index
            readonly property bool isLast: index === Hyprland.monitors.values.length - 1

            Layout.fillWidth: true
            implicitHeight: switchItem.implicitHeight + 16 + 8
            color: Appearance.colors.colLayer1
            topLeftRadius: Appearance.rounding.unsharpenmore
            topRightRadius: Appearance.rounding.unsharpenmore
            bottomLeftRadius: isLast ? Appearance.rounding.normal : Appearance.rounding.unsharpenmore
            bottomRightRadius: isLast ? Appearance.rounding.normal : Appearance.rounding.unsharpenmore

            ConfigSwitch {
                id: switchItem
                anchors {
                    fill: parent
                    margins: 8
                }
                buttonIcon: "monitor"
                text: monitorRow.modelData.name
                onCheckedChanged: {
                    root.setOverriddenOff(monitorRow.modelData.name, !checked);
                }

                Binding {
                    target: switchItem
                    property: "checked"
                    value: !root.isOverriddenOff(monitorRow.modelData.name)
                    restoreMode: Binding.RestoreBinding
                }
            }
        }
    }
}
