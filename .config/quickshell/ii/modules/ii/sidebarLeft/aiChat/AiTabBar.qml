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
 * pide el modal de AiNewChatDialog (lo dibuja AiChat, acá sólo se pide) para
 * elegir con qué agente arrancar, salvo que haya uno solo configurado.
 */
ColumnLayout {
    id: root

    /** Está abierto el panel de historial (lo dibuja AiChat, acá sólo se pide). */
    property bool historyOpen: false

    signal historyToggled()
    /** Pide crear una pestaña nueva (AiChat decide si hace falta el modal de agente). */
    signal newChatDialogRequested()

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

        // Estos tres botones NO llevan StyledToolTip. Ya perdieron el click dos
        // veces por el mismo mecanismo: un Popup visible (el tooltip) queda
        // geométricamente encima de ALGO clickeable y se come el evento antes
        // de que llegue al botón — mover y/x lo parcha para un caso puntual
        // pero no lo elimina (sigue siendo un Popup frágil en una fila
        // angosta, con varios botones pegados). Son íconos autoexplicativos
        // con sus propios atajos ya documentados en otro lado (Ctrl+H,
        // Ctrl+T): la ganancia de un tooltip acá no vale volver a arriesgar
        // el click. Si hace falta explicarlos, mejor un StyledText fijo al
        // lado del ícono que un Popup.
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
        }

        RippleButton {
            id: addButton
            hoverEnabled: true
            implicitWidth: 34
            implicitHeight: 34
            buttonRadius: Appearance.rounding.small
            onClicked: root.newChatDialogRequested()

            contentItem: MaterialSymbol {
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: "add"
                iconSize: Appearance.font.pixelSize.larger
                color: Appearance.colors.colOnLayer1
            }
        }

        RippleButton {
            id: settingsButton
            hoverEnabled: true
            implicitWidth: 34
            implicitHeight: 34
            buttonRadius: Appearance.rounding.small
            // Abre la app de Settings (conectada al backend de Hyprland) directo
            // en Servicios → Proveedores: login de Claude Code, keys de Gemini
            // y OpenAI. Ver Ai.openAccountsSettings.
            onClicked: Ai.openAccountsSettings()

            contentItem: MaterialSymbol {
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: "settings"
                iconSize: Appearance.font.pixelSize.larger
                color: Appearance.colors.colOnLayer1
            }
        }
    }
}
