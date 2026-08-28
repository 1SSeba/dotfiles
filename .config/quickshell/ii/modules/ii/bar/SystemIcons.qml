import QtQuick
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root
    property bool borderless: Config.options.bar.borderless
    property bool showDate: Config.options.bar.verbose
    property bool vertical: Config.options.bar.vertical
    property bool isMaterial: Config.options.bar.cornerStyle === 3
    readonly property color colIcon: root.isMaterial ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1

    implicitWidth: root.vertical ? 32 : flow.implicitWidth + 4
    implicitHeight: root.vertical ? flow.implicitHeight + 4 : 32

    MouseArea {
        anchors.fill: parent
        onPressed: {
            GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen;
        }
    }

    Flow {
        id: flow
        anchors.centerIn: parent
        flow: root.vertical ? Flow.TopToBottom : Flow.LeftToRight
        spacing: root.isMaterial ? 2 : root.vertical ? 6 : 10

        Revealer {
            reveal: true
            MaterialSymbol {
                text: Audio.sink?.audio?.muted ? "volume_off" : "volume_up"
                iconSize: Appearance.font.pixelSize.larger
                color: root.colIcon
            }
        }
        Revealer {
            reveal: Audio.source?.audio?.muted ?? false
            MaterialSymbol {
                text: "mic_off"
                iconSize: Appearance.font.pixelSize.larger
                color: root.colIcon
            }
        }
        // Se instancia directo en vez de con Loader: acá el indicador ya es un
        // Loader y así el color queda bindeado en vez de asignado una sola vez.
        HyprlandXkbIndicator {
            vertical: root.vertical
            color: root.colIcon
        }
        MaterialSymbol {
            text: Network.materialSymbol
            iconSize: Appearance.font.pixelSize.larger
            color: root.colIcon
        }
        MaterialSymbol {
            visible: BluetoothStatus.available
            text: BluetoothStatus.connected ? "bluetooth_connected" : BluetoothStatus.enabled ? "bluetooth" : "bluetooth_disabled"
            iconSize: Appearance.font.pixelSize.larger
            color: root.colIcon
        }
        // El indicador de notificaciones va inline y no vía NotificationUnreadCount.qml
        // porque ese archivo referencia el id externo `rightSidebarButton`, que no
        // existe en este contexto y reventaría al cargarlo desde acá.
        MaterialSymbol {
            id: notifSymbol
            readonly property bool showUnreadCount: Config.options.bar.indicators.notifications.showUnreadCount
            visible: Notifications.silent || Notifications.unread > 0
            text: Notifications.silent ? "notifications_paused" : "notifications"
            iconSize: Appearance.font.pixelSize.larger
            color: root.colIcon

            Rectangle {
                visible: !Notifications.silent && Notifications.unread > 0
                anchors {
                    right: parent.right
                    top: parent.top
                    rightMargin: notifSymbol.showUnreadCount ? 0 : 1
                    topMargin: notifSymbol.showUnreadCount ? 0 : 3
                }
                radius: Appearance.rounding.full
                color: root.colIcon
                z: 1

                implicitHeight: notifSymbol.showUnreadCount ? Math.max(unreadText.implicitWidth, unreadText.implicitHeight) : 8
                implicitWidth: implicitHeight

                StyledText {
                    id: unreadText
                    visible: notifSymbol.showUnreadCount
                    anchors.centerIn: parent
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: root.isMaterial ? Appearance.colors.colPrimary : Appearance.colors.colLayer0
                    text: Notifications.unread
                }
            }
        }
    }
}
