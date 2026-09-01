pragma ComponentBehavior: Bound

import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

/**
 * Modal para elegir con qué agente arrancar una pestaña nueva.
 *
 * Antes esto era una fila de chips que se desplegaba discretamente debajo de
 * la barra de pestañas — demasiado sutil, costaba notar que había algo para
 * elegir. Este es un diálogo de verdad: scrim + tarjeta centrada, mismo
 * patrón que el selector de idioma del traductor (ver SelectionDialog.qml).
 *
 * Quien lo usa lo hostea con un Loader anchors.fill + z alto, igual que
 * Translator.qml hace con SelectionDialog.
 */
Item {
    id: root

    property var agents: []
    signal canceled()
    signal agentPicked(string agentId)

    Rectangle { // Scrim
        anchors.fill: parent
        color: Appearance.colors.colScrim

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            preventStealing: true
            onClicked: root.canceled()
        }
    }

    Rectangle { // La tarjeta
        id: card
        anchors.centerIn: parent
        width: Math.min(parent.width - 32, 340)
        // `height`, no `implicitHeight`: este Rectangle es un Item plano, no
        // uno adentro de un Layout ni un Control — nada lo bindea solo a su
        // implicitHeight, así que quedaría con alto 0 (invisible) si sólo
        // seteara eso.
        height: cardColumn.implicitHeight + 32
        radius: Appearance.rounding.normal
        color: Appearance.m3colors.m3surfaceContainerHigh

        // Que un click adentro de la tarjeta no se propague al scrim y la cierre
        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            id: cardColumn
            anchors {
                fill: parent
                margins: 16
            }
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                MaterialSymbol {
                    text: "add_comment"
                    iconSize: Appearance.font.pixelSize.larger
                    color: Appearance.m3colors.m3onSurface
                }
                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Pestaña nueva")
                    font.pixelSize: Appearance.font.pixelSize.larger
                    color: Appearance.m3colors.m3onSurface
                }
                RippleButton {
                    implicitWidth: 26
                    implicitHeight: 26
                    buttonRadius: Appearance.rounding.small
                    contentItem: MaterialSymbol {
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: "close"
                        iconSize: Appearance.font.pixelSize.normal
                        color: Appearance.m3colors.m3onSurface
                    }
                    onClicked: root.canceled()
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("¿Con qué agente arranca?")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Repeater {
                    // Igual que en AiOptionPicker: no construir los botones si el
                    // modal está cerrado (el Loader que lo hostea ya se encarga de
                    // esto con `active`, pero por las dudas si se reusa distinto).
                    model: root.agents

                    delegate: RippleButton {
                        id: agentButton
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: 44
                        buttonRadius: Appearance.rounding.small
                        colBackground: Appearance.colors.colLayer2

                        onClicked: root.agentPicked(agentButton.modelData.id)

                        contentItem: RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10

                            MaterialSymbol {
                                text: agentButton.modelData.icon || "neurology"
                                iconSize: Appearance.font.pixelSize.larger
                                color: Appearance.colors.colOnLayer2
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                StyledText {
                                    Layout.fillWidth: true
                                    text: agentButton.modelData.name ?? agentButton.modelData.id
                                    font.pixelSize: Appearance.font.pixelSize.normal
                                    color: Appearance.colors.colOnLayer2
                                }
                                StyledText {
                                    Layout.fillWidth: true
                                    visible: text.length > 0
                                    text: agentButton.modelData.tool === "search" ? Translation.tr("Busca en la web")
                                        : (agentButton.modelData.model ?? "").length > 0 ? agentButton.modelData.model : ""
                                    font.pixelSize: Appearance.font.pixelSize.smallest
                                    color: Appearance.colors.colSubtext
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
