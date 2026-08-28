pragma ComponentBehavior: Bound

import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

/**
 * Árbol de subagentes de una respuesta.
 *
 * Cuando Claude Code larga agentes con la tool Task, la respuesta deja de ser
 * una sola voz: hay un orquestador y N agentes trabajando en paralelo, cada uno
 * con sus propias tool calls. En el chat eso llegaba aplanado — el texto y las
 * tools de todos mezclados en el mismo mensaje, sin decir de quién era cada
 * cosa. Este bloque lo muestra como lo que es: una rama por agente, con su
 * estado, lo que está haciendo ahora y en qué terminó.
 *
 * El dato lo arma ClaudeCodeStrategy en `messageData.agents`.
 */
Rectangle {
    id: root

    /** Lista de agentes, tal como la deja la estrategia. */
    property var agents: []
    /** La respuesta todavía se está generando. */
    property bool done: true

    readonly property int runningCount: root.agents.filter(agent => agent.status === "running").length
    readonly property int errorCount: root.agents.filter(agent => agent.status === "error").length
    property bool collapsed: false
    /** Agente desplegado (su id), para ver las tools que usó. */
    property string openAgent: ""

    /**
     * Reloj para los cronómetros. Sólo tictaquea mientras haya algo corriendo:
     * un Timer prendido siempre re-evalúa el layout de todos los mensajes viejos
     * del chat una vez por segundo, para nada.
     */
    property double nowMs: Date.now()

    Timer {
        running: root.runningCount > 0
        interval: 1000
        repeat: true
        onTriggered: root.nowMs = Date.now()
    }

    function elapsedText(agent) {
        const end = agent.endedAt > 0 ? agent.endedAt : root.nowMs;
        const seconds = Math.max(0, Math.round((end - agent.startedAt) / 1000));
        if (seconds < 60) return `${seconds}s`;
        return `${Math.floor(seconds / 60)}m ${seconds % 60}s`;
    }

    Layout.fillWidth: true
    implicitHeight: layout.implicitHeight + 12
    radius: Appearance.rounding.small
    color: Appearance.colors.colLayer2
    border.width: 1
    border.color: root.runningCount > 0 ? Appearance.colors.colPrimary : Appearance.colors.colOutlineVariant

    Behavior on border.color {
        animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
    }
    Behavior on implicitHeight {
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
    }

    ColumnLayout {
        id: layout
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: 6
        }
        spacing: 4

        // ------------------------------------------------ Encabezado
        Item {
            Layout.fillWidth: true
            implicitHeight: Math.max(headerRow.implicitHeight, 24)

            MouseArea {
                id: headerArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.collapsed = !root.collapsed
            }

            RowLayout {
                id: headerRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                MaterialSymbol {
                    text: "account_tree"
                    iconSize: Appearance.font.pixelSize.large
                    color: root.runningCount > 0 ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer2
                }

                StyledText {
                    Layout.fillWidth: true
                    text: {
                        const total = root.agents.length;
                        const base = total === 1 ? Translation.tr("1 subagente")
                            : Translation.tr("%1 subagentes").arg(total);
                        if (root.runningCount > 0) return `${base} · ${Translation.tr("%1 trabajando").arg(root.runningCount)}`;
                        if (root.errorCount > 0) return `${base} · ${Translation.tr("%1 con error").arg(root.errorCount)}`;
                        return `${base} · ${Translation.tr("listos")}`;
                    }
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnLayer2
                    elide: Text.ElideRight
                }

                MaterialSymbol {
                    text: root.collapsed ? "keyboard_arrow_down" : "keyboard_arrow_up"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colSubtext
                }
            }
        }

        // ------------------------------------------------ Ramas
        Repeater {
            model: root.collapsed ? [] : root.agents

            delegate: Item {
                id: branch
                required property var modelData
                required property int index

                readonly property bool isOpen: root.openAgent === branch.modelData.id
                readonly property bool isLast: branch.index === root.agents.length - 1
                readonly property color statusColor: branch.modelData.status === "error" ? Appearance.m3colors.m3error
                    : branch.modelData.status === "running" ? Appearance.colors.colPrimary
                    : Appearance.colors.colSubtext

                Layout.fillWidth: true
                implicitHeight: branchColumn.implicitHeight + 4

                // El codo del árbol: la vertical baja desde la fila de arriba y
                // se corta en el último para que la rama termine, no siga sola.
                Rectangle {
                    x: 9
                    y: 0
                    width: 1
                    height: branch.isLast ? 12 : branch.height
                    color: Appearance.colors.colOutlineVariant
                }
                Rectangle {
                    x: 9
                    y: 12
                    width: 8
                    height: 1
                    color: Appearance.colors.colOutlineVariant
                }

                ColumnLayout {
                    id: branchColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.leftMargin: 20
                    spacing: 2

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: agentRow.implicitHeight + 10
                        radius: Appearance.rounding.small
                        color: agentArea.containsMouse ? Appearance.colors.colLayer1Hover : Appearance.colors.colLayer1

                        MouseArea {
                            id: agentArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.openAgent = branch.isOpen ? "" : branch.modelData.id
                        }

                        RowLayout {
                            id: agentRow
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 8

                            // Estado: girando mientras trabaja, tilde o error al terminar
                            Item {
                                implicitWidth: 18
                                implicitHeight: 18
                                Layout.alignment: Qt.AlignTop
                                Layout.topMargin: 1

                                MaterialLoadingIndicator {
                                    anchors.centerIn: parent
                                    visible: branch.modelData.status === "running"
                                    loading: branch.modelData.status === "running"
                                    implicitSize: 16
                                }
                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    visible: branch.modelData.status !== "running"
                                    text: branch.modelData.status === "error" ? "error" : "check_circle"
                                    iconSize: Appearance.font.pixelSize.large
                                    color: branch.statusColor
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    Rectangle {
                                        implicitWidth: agentTypeText.implicitWidth + 12
                                        implicitHeight: agentTypeText.implicitHeight + 4
                                        radius: Appearance.rounding.small
                                        color: branch.modelData.status === "running"
                                            ? Appearance.colors.colSecondaryContainer
                                            : Appearance.colors.colLayer2

                                        StyledText {
                                            id: agentTypeText
                                            anchors.centerIn: parent
                                            text: branch.modelData.name
                                            font.pixelSize: Appearance.font.pixelSize.smallest
                                            color: branch.modelData.status === "running"
                                                ? Appearance.colors.colOnSecondaryContainer
                                                : Appearance.colors.colOnLayer2
                                        }
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: branch.modelData.description
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        color: Appearance.colors.colOnLayer1
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                    }

                                    StyledText {
                                        text: root.elapsedText(branch.modelData)
                                        font.pixelSize: Appearance.font.pixelSize.smallest
                                        color: Appearance.colors.colSubtext
                                    }

                                    RowLayout {
                                        spacing: 2
                                        visible: branch.modelData.toolCount > 0

                                        MaterialSymbol {
                                            text: "handyman"
                                            iconSize: Appearance.font.pixelSize.smaller
                                            color: Appearance.colors.colSubtext
                                        }
                                        StyledText {
                                            text: branch.modelData.toolCount
                                            font.pixelSize: Appearance.font.pixelSize.smallest
                                            color: Appearance.colors.colSubtext
                                        }
                                    }
                                }

                                // Mientras corre: lo último que viene diciendo.
                                // Cuando termina: en qué terminó.
                                StyledText {
                                    Layout.fillWidth: true
                                    visible: text.length > 0 && !branch.isOpen
                                    text: branch.modelData.status === "running"
                                        ? branch.modelData.preview
                                        : branch.modelData.result
                                    font.pixelSize: Appearance.font.pixelSize.smallest
                                    color: Appearance.colors.colSubtext
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                }
                            }
                        }
                    }

                    // ---------------------------- Detalle: qué tools usó
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 8
                        visible: branch.isOpen
                        spacing: 1

                        Repeater {
                            model: branch.isOpen ? branch.modelData.tools : []

                            delegate: RowLayout {
                                id: toolRow
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 5

                                StyledText {
                                    text: "⏵"
                                    font.pixelSize: Appearance.font.pixelSize.smallest
                                    color: Appearance.colors.colSubtext
                                }
                                StyledText {
                                    text: toolRow.modelData.name
                                    font.pixelSize: Appearance.font.pixelSize.smallest
                                    font.family: Appearance.font.family.monospace
                                    color: Appearance.colors.colOnLayer1
                                }
                                StyledText {
                                    Layout.fillWidth: true
                                    text: toolRow.modelData.detail
                                    font.pixelSize: Appearance.font.pixelSize.smallest
                                    font.family: Appearance.font.family.monospace
                                    color: Appearance.colors.colSubtext
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                }
                            }
                        }

                        // Se guardan hasta 40 tools por agente; el resto se cuenta.
                        StyledText {
                            Layout.fillWidth: true
                            visible: branch.modelData.toolCount > branch.modelData.tools.length
                            text: Translation.tr("y %1 más").arg(branch.modelData.toolCount - branch.modelData.tools.length)
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: Appearance.colors.colSubtext
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: branch.modelData.result.length > 0
                            Layout.topMargin: 2
                            text: branch.modelData.result
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: Appearance.colors.colSubtext
                            wrapMode: Text.Wrap
                        }
                    }
                }
            }
        }
    }
}
