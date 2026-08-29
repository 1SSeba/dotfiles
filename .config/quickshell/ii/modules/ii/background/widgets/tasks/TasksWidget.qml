import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.ii.background.widgets

/**
 * Tareas pendientes en el escritorio: las locales de siempre (Todo.qml) más
 * las de Google Tasks y Apple Reminders cuando esas cuentas están conectadas
 * (Settings > Cuentas). Todo el trabajo de sincronizar ya existía -- esto es
 * sólo la vitrina en el fondo, hermana de la que ya tenía el sidebar derecho
 * (modules/ii/sidebarRight/todo/TodoWidget.qml).
 */
AbstractBackgroundWidget {
    id: root
    configEntryName: "tasks"
    hoverEnabled: true

    readonly property real cardWidth: 260
    readonly property real cardHeight: 300
    readonly property int maxVisible: 6
    readonly property var pendingItems: Todo.unifiedList.filter(item => !item.done)
    readonly property var visibleItems: root.pendingItems.slice(0, root.maxVisible)
    readonly property int extraCount: Math.max(0, root.pendingItems.length - root.maxVisible)

    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight

    function commitNewTask() {
        const text = addField.text.trim();
        if (text.length === 0) return;
        Todo.addTask(text);
        addField.text = "";
    }

    /** Una tarea de la lista: círculo para marcarla hecha, texto, de dónde salió. */
    component TaskRow: RippleButton {
        id: taskRow
        required property var item

        Layout.fillWidth: true
        implicitHeight: rowContent.implicitHeight + 8
        buttonRadius: Appearance.rounding.small
        colBackground: "transparent"
        colBackgroundHover: Appearance.colors.colLayer1Hover
        downAction: () => Todo.toggleDone(taskRow.item)

        contentItem: RowLayout {
            id: rowContent
            spacing: 8

            MaterialSymbol {
                text: "radio_button_unchecked"
                iconSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colOnLayer0
                opacity: 0.6
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: taskRow.item.content
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnLayer0
                }

                // De dónde salió, igual que en el sidebar: sin esto una tarea de
                // la nube se confunde con una local.
                StyledText {
                    visible: taskRow.item.source !== "local"
                    text: taskRow.item.source === "apple" ? "iCloud" : "Google"
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: Appearance.colors.colOnLayer0
                    opacity: 0.5
                }
            }
        }
    }

    Rectangle {
        id: card
        implicitWidth: root.cardWidth
        implicitHeight: root.cardHeight
        radius: Appearance.rounding?.verylarge ?? 30
        color: Appearance.colors.colPrimaryContainer

        StyledRectangularShadow {
            target: card
            z: -2
        }

        ColumnLayout {
            anchors { fill: parent; margins: 16 }
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                MaterialSymbol {
                    text: "checklist"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnPrimaryContainer
                }
                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Tareas")
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.Medium
                    color: Appearance.colors.colOnPrimaryContainer
                }
                StyledText {
                    visible: root.pendingItems.length > 0
                    text: root.pendingItems.length
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnPrimaryContainer
                    opacity: 0.6
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: ColorUtils.transparentize(Appearance.colors.colLayer0, 0.8)
                radius: (Appearance.rounding?.verylarge ?? 30) - 8
                clip: true

                ColumnLayout {
                    anchors { fill: parent; margins: 10 }
                    spacing: 4
                    visible: root.pendingItems.length > 0

                    Repeater {
                        model: root.visibleItems
                        delegate: TaskRow {
                            required property var modelData
                            item: modelData
                        }
                    }

                    StyledText {
                        Layout.topMargin: 2
                        visible: root.extraCount > 0
                        text: Translation.tr("+%1 más").arg(root.extraCount)
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnLayer0
                        opacity: 0.6
                    }

                    Item { Layout.fillHeight: true }
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    visible: root.pendingItems.length === 0
                    spacing: 4

                    MaterialSymbol {
                        Layout.alignment: Qt.AlignHCenter
                        text: "check_circle"
                        iconSize: 28
                        color: Appearance.colors.colOnLayer0
                        opacity: 0.4
                    }
                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: Translation.tr("Sin pendientes")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnLayer0
                        opacity: 0.5
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                TextField {
                    id: addField
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Nueva tarea…")
                    color: Appearance.colors.colOnPrimaryContainer
                    placeholderTextColor: ColorUtils.transparentize(Appearance.colors.colOnPrimaryContainer, 0.5)
                    font.pixelSize: Appearance.font.pixelSize.small
                    padding: 8
                    onAccepted: root.commitNewTask()
                    background: Rectangle {
                        radius: Appearance.rounding.full
                        color: ColorUtils.transparentize(Appearance.colors.colOnPrimaryContainer, 0.85)
                    }
                }
                RippleButton {
                    implicitWidth: 32
                    implicitHeight: 32
                    buttonRadius: Appearance.rounding.full
                    colBackground: Appearance.colors.colPrimary
                    colBackgroundHover: Appearance.colors.colPrimaryHover
                    downAction: () => root.commitNewTask()
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "add"
                        iconSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colOnPrimary
                    }
                }
            }
        }
    }
}
