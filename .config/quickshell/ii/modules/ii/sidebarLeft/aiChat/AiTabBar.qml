pragma ComponentBehavior: Bound

import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

/**
 * Barra de pestañas del chat: una pestaña por sesión, cada una con su agente.
 *
 * Cada chip muestra el icono del agente, su nombre, un indicador de "respondiendo"
 * y un punto cuando la respuesta terminó mientras mirabas otra pestaña. El botón "+"
 * despliega la lista de agentes de Config.options.ai.agents.
 */
ColumnLayout {
    id: root

    /** Está abierto el selector de agente. */
    property bool pickerOpen: false
    /** Está abierto el panel de historial (lo dibuja AiChat, acá sólo se pide). */
    property bool historyOpen: false

    signal historyToggled()
    readonly property var agents: Config.options?.ai?.agents ?? []

    spacing: 4

    RowLayout {
        Layout.fillWidth: true
        spacing: 4
        // Por encima de cualquier hermano que pueda quedar solapado: los botones
        // de historial y "+" viven en el extremo derecho de esta fila y son lo
        // primero que deja de responder si algo se dibuja encima.
        z: 10

        Flickable {
            id: tabStrip
            Layout.fillWidth: true
            implicitHeight: tabRow.implicitHeight
            contentWidth: tabRow.implicitWidth
            contentHeight: tabRow.implicitHeight
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            // Que la pestaña activa quede siempre a la vista
            Connections {
                target: Ai
                function onActiveIndexChanged() {
                    const item = tabRepeater.itemAt(Ai.activeIndex);
                    if (!item) return;
                    if (item.x < tabStrip.contentX)
                        tabStrip.contentX = item.x;
                    else if (item.x + item.width > tabStrip.contentX + tabStrip.width)
                        tabStrip.contentX = item.x + item.width - tabStrip.width;
                }
            }

            RowLayout {
                id: tabRow
                spacing: 4

                Repeater {
                    id: tabRepeater
                    model: Ai.sessions

                    delegate: Rectangle {
                        id: chip
                        required property var modelData
                        required property int index
                        readonly property bool isActive: chip.index === Ai.activeIndex

                        implicitWidth: chipRow.implicitWidth + 12 * 2
                        implicitHeight: 34
                        radius: Appearance.rounding.small
                        color: chip.isActive ? Appearance.colors.colSecondaryContainer
                            : (chipArea.containsMouse ? Appearance.colors.colLayer2Hover : Appearance.colors.colLayer2)

                        Behavior on color {
                            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                        }

                        MouseArea {
                            id: chipArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                            onClicked: event => {
                                if (event.button === Qt.MiddleButton) Ai.closeSession(chip.index);
                                else Ai.setActiveIndex(chip.index);
                            }
                        }

                        RowLayout {
                            id: chipRow
                            anchors.centerIn: parent
                            spacing: 6

                            // Dos símbolos en vez de uno con rotación condicional: si el
                            // mismo item gira y después para, se queda con el ángulo viejo.
                            MaterialSymbol {
                                visible: !chip.modelData.busy
                                text: chip.modelData.icon || "neurology"
                                iconSize: Appearance.font.pixelSize.large
                                color: chip.isActive ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer2
                            }

                            MaterialSymbol {
                                visible: chip.modelData.busy
                                text: "progress_activity"
                                iconSize: Appearance.font.pixelSize.large
                                color: chip.isActive ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer2

                                RotationAnimator on rotation {
                                    running: chip.modelData.busy
                                    loops: Animation.Infinite
                                    from: 0
                                    to: 360
                                    duration: 1400
                                }
                            }

                            StyledText {
                                text: chip.modelData.title
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: chip.isActive ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer2
                                elide: Text.ElideRight
                                Layout.maximumWidth: 120
                            }

                            // Punto de "terminó mientras no mirabas"
                            Rectangle {
                                visible: chip.modelData.unread
                                implicitWidth: 7
                                implicitHeight: 7
                                radius: 999
                                color: Appearance.colors.colPrimary
                            }

                            MaterialSymbol {
                                visible: chip.isActive || chipArea.containsMouse
                                text: "close"
                                iconSize: Appearance.font.pixelSize.normal
                                color: chip.isActive ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer2

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Ai.closeSession(chip.index)
                                }
                            }
                        }
                    }
                }
            }
        }

        RippleButton {
            id: historyButton
            hoverEnabled: true
            implicitWidth: 34
            implicitHeight: 34
            buttonRadius: Appearance.rounding.small
            toggled: root.historyOpen
            onClicked: root.historyToggled()

            contentItem: MaterialSymbol {
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: "history"
                iconSize: Appearance.font.pixelSize.larger
                color: root.historyOpen ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
            }

            StyledToolTip {
                text: Translation.tr("Historial")
            }
        }

        RippleButton {
            id: addButton
            hoverEnabled: true
            implicitWidth: 34
            implicitHeight: 34
            buttonRadius: Appearance.rounding.small
            toggled: root.pickerOpen
            onClicked: {
                // Con un solo agente definido no hay nada que elegir
                if (root.agents.length <= 1) Ai.newSession();
                else root.pickerOpen = !root.pickerOpen;
            }

            contentItem: MaterialSymbol {
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: "add"
                iconSize: Appearance.font.pixelSize.larger
                color: root.pickerOpen ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
            }

            StyledToolTip {
                text: Translation.tr("Pestaña nueva (Ctrl+T)")
            }
        }
    }

    // Selector de agente
    Item {
        Layout.fillWidth: true
        implicitHeight: root.pickerOpen ? pickerFlow.implicitHeight + 8 : 0
        clip: true
        opacity: root.pickerOpen ? 1 : 0
        visible: implicitHeight > 0

        Behavior on implicitHeight {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }
        Behavior on opacity {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }

        Flow {
            id: pickerFlow
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                topMargin: 4
            }
            spacing: 4

            Repeater {
                // Igual que en AiOptionPicker: no construir los botones si está cerrado
                model: root.pickerOpen ? root.agents : []

                delegate: RippleButton {
                    id: agentButton
                    required property var modelData
                    implicitHeight: 32
                    implicitWidth: agentButtonRow.implicitWidth + 12 * 2
                    buttonRadius: Appearance.rounding.small
                    colBackground: Appearance.colors.colLayer2

                    onClicked: {
                        Ai.newSession(agentButton.modelData.id);
                        root.pickerOpen = false;
                    }

                    contentItem: RowLayout {
                        id: agentButtonRow
                        spacing: 6

                        MaterialSymbol {
                            text: agentButton.modelData.icon || "neurology"
                            iconSize: Appearance.font.pixelSize.large
                            color: Appearance.colors.colOnLayer2
                        }
                        StyledText {
                            text: agentButton.modelData.name ?? agentButton.modelData.id
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnLayer2
                        }
                    }
                }
            }
        }
    }
}
