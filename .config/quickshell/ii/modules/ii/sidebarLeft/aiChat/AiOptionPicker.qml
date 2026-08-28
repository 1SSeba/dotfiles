pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

/**
 * Panel que se despliega con una grilla de opciones para elegir con el mouse.
 * Lo usan el selector de modelo y el de esfuerzo, abajo del chat.
 *
 * Cada opción es `{ key, label, icon, customIcon, tooltip, selected }`:
 * - `icon` es un Material Symbol; `customIcon` es un nombre de assets/icons
 *   (los logos de los proveedores viven ahí), y gana sobre `icon` si está.
 * - `tooltip` es opcional, para explicar qué hace la opción.
 */
Item {
    id: root

    property bool open: false
    property var options: []
    signal picked(string key)

    implicitHeight: root.open ? optionFlow.implicitHeight + 8 : 0
    clip: true
    opacity: root.open ? 1 : 0
    visible: implicitHeight > 0

    Behavior on implicitHeight {
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
    }
    Behavior on opacity {
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
    }

    Flow {
        id: optionFlow
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            topMargin: 4
        }
        spacing: 4

        Repeater {
            // Solo se construyen los botones cuando el panel está abierto: si no,
            // quedan vivos N RippleButtons con sus animaciones por cada picker.
            model: root.open ? root.options : []

            delegate: RippleButton {
                id: optionButton
                required property var modelData

                implicitHeight: 32
                implicitWidth: optionRow.implicitWidth + 12 * 2
                buttonRadius: Appearance.rounding.small
                toggled: optionButton.modelData.selected ?? false
                colBackground: Appearance.colors.colLayer2

                onClicked: root.picked(optionButton.modelData.key)

                StyledToolTip {
                    extraVisibleCondition: (optionButton.modelData.tooltip ?? "").length > 0
                    text: optionButton.modelData.tooltip ?? ""
                }

                contentItem: RowLayout {
                    id: optionRow
                    spacing: 6

                    // Va en un Loader y no con `visible: false`: un CustomIcon con
                    // source vacío igual intenta abrir la carpeta de iconos y llena
                    // el log de "Cannot open: .../assets/icons/".
                    Loader {
                        active: (optionButton.modelData.customIcon ?? "").length > 0
                        Layout.preferredWidth: active ? Appearance.font.pixelSize.large : 0
                        Layout.preferredHeight: Appearance.font.pixelSize.large
                        sourceComponent: CustomIcon {
                            width: Appearance.font.pixelSize.large
                            height: Appearance.font.pixelSize.large
                            source: optionButton.modelData.customIcon ?? ""
                            colorize: true
                            color: optionButton.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer2
                        }
                    }

                    MaterialSymbol {
                        visible: (optionButton.modelData.customIcon ?? "").length === 0
                            && (optionButton.modelData.icon ?? "").length > 0
                        text: optionButton.modelData.icon ?? ""
                        iconSize: Appearance.font.pixelSize.large
                        color: optionButton.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer2
                    }

                    StyledText {
                        text: optionButton.modelData.label ?? optionButton.modelData.key
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: optionButton.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer2
                    }
                }
            }
        }
    }
}
