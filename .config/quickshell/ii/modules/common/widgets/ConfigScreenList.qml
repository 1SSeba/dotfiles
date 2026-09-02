import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/**
 * Selector de monitores para un widget puntual: fila de chips "Todos" +
 * uno por monitor conectado. Pensado para que cada widget del escritorio
 * (reloj, clima, notas, calendario...) pueda vivir en la pantalla que se
 * quiera, de forma independiente del resto.
 *
 * Vacío en `screenList` = "todos los monitores" (misma convención que
 * `bar.screenList` / `background.screenList`).
 */
ColumnLayout {
    id: root
    Layout.fillWidth: true
    spacing: 4
    // Se esconde solo: con un monitor la elección no decide nada.
    visible: Hyprland.monitors.values.length > 1

    property list<string> screenList: []
    signal changed(var newList)

    StyledText {
        text: Translation.tr("Show on")
        font.pixelSize: Appearance.font.pixelSize.smaller
        color: Appearance.colors.colSubtext
    }

    Flow {
        Layout.fillWidth: true
        spacing: 2

        SelectionGroupButton {
            buttonIcon: "tv_displays"
            buttonText: Translation.tr("All")
            leftmost: true
            rightmost: Hyprland.monitors.values.length === 0
            toggled: root.screenList.length === 0
            onClicked: root.changed([])
        }

        Repeater {
            model: Hyprland.monitors
            delegate: SelectionGroupButton {
                id: chip
                required property var modelData
                required property int index
                rightmost: chip.index === Hyprland.monitors.values.length - 1
                buttonIcon: "monitor"
                buttonText: chip.modelData.name
                toggled: root.screenList.length === 0 || root.screenList.includes(chip.modelData.name)
                onClicked: {
                    // Al arrancar desde "todos" (lista vacía), destildar un monitor tiene que
                    // partir de la lista real; si no, quitarlo dejaría la lista en cero y eso
                    // vuelve a significar "todos".
                    const allNames = Hyprland.monitors.values.map(m => m.name);
                    let list = root.screenList.length === 0 ? allNames.slice() : root.screenList.slice();
                    if (list.includes(chip.modelData.name)) {
                        list = list.filter(n => n !== chip.modelData.name);
                    } else {
                        list.push(chip.modelData.name);
                    }
                    // Si quedaron todos, se vuelve a la forma canónica: vacía.
                    root.changed(list.length === allNames.length ? [] : list);
                }
            }
        }
    }
}
