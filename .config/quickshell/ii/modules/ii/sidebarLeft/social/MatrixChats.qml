pragma ComponentBehavior: Bound

import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

/**
 * Tus chats de Matrix dentro del sidebar.
 *
 * Con el puente de WhatsApp andando, cada conversación de WhatsApp aparece acá
 * como una sala más: se leen y se contestan sin salir de la shell.
 */
Item {
    id: root

    /** La pestaña está a la vista: sólo entonces vale la pena sincronizar. */
    property bool active: false

    // El /sync es un long-poll: dejarlo corriendo con la pestaña cerrada es tener
    // una petición colgada para siempre sin que nadie mire el resultado.
    onActiveChanged: MatrixService.watching = root.active
    Component.onCompleted: MatrixService.watching = root.active
    Component.onDestruction: MatrixService.watching = false

    // ------------------------------------------------------------------ //
    // Sin conectar: entrar al homeserver
    // ------------------------------------------------------------------ //

    ColumnLayout {
        anchors {
            fill: parent
            margins: 12
        }
        spacing: 8
        visible: !MatrixService.connected

        Item { Layout.fillHeight: true }

        MaterialSymbol {
            Layout.alignment: Qt.AlignHCenter
            text: "forum"
            iconSize: 32
            color: Appearance.colors.colSubtext
        }

        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            font.pixelSize: Appearance.font.pixelSize.small
            color: MatrixService.state === "error" ? Appearance.m3colors.m3error : Appearance.colors.colSubtext
            text: MatrixService.state === "error"
                ? MatrixService.lastError
                : Translation.tr("Entrá a tu homeserver para ver los chats acá.\nCon el puente andando, WhatsApp aparece\ncomo un chat más.")
        }

        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: MatrixService.homeserver
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
            elide: Text.ElideMiddle
        }

        MaterialTextField {
            id: userField
            Layout.fillWidth: true
            Layout.topMargin: 4
            placeholderText: Translation.tr("Usuario (por ejemplo scruzd)")
            onAccepted: passwordField.forceActiveFocus()
        }

        MaterialTextField {
            id: passwordField
            Layout.fillWidth: true
            placeholderText: Translation.tr("Contraseña")
            echoMode: TextInput.Password
            onAccepted: MatrixService.login(userField.text, passwordField.text)
        }

        RippleButton {
            Layout.alignment: Qt.AlignHCenter
            implicitHeight: 34
            implicitWidth: loginRow.implicitWidth + 16 * 2
            buttonRadius: Appearance.rounding.full
            enabled: !MatrixService.loading
            colBackground: Appearance.colors.colPrimary
            colBackgroundHover: Appearance.colors.colPrimaryHover
            onClicked: MatrixService.login(userField.text, passwordField.text)

            contentItem: RowLayout {
                id: loginRow
                spacing: 6
                MaterialSymbol {
                    text: "login"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnPrimary
                }
                StyledText {
                    text: MatrixService.loading ? Translation.tr("Entrando…") : Translation.tr("Entrar")
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnPrimary
                }
            }
        }

        Item { Layout.fillHeight: true }
    }

    // ------------------------------------------------------------------ //
    // Conectado
    // ------------------------------------------------------------------ //

    ColumnLayout {
        anchors {
            fill: parent
            margins: 8
        }
        spacing: 6
        visible: MatrixService.connected

        // Validador: mismo criterio que en Spotify, decir qué pasa en un renglón
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            RippleButton {
                visible: MatrixService.openRoomId.length > 0
                implicitHeight: 28
                implicitWidth: 28
                buttonRadius: Appearance.rounding.small
                colBackground: Appearance.colors.colLayer2
                onClicked: MatrixService.closeChat()

                contentItem: MaterialSymbol {
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: "arrow_back"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colOnLayer2
                }
            }

            MaterialSymbol {
                visible: MatrixService.openRoomId.length === 0
                text: {
                    if (MatrixService.state === "error") return "error";
                    if (MatrixService.healthy) return "check_circle";
                    return "sync";
                }
                iconSize: Appearance.font.pixelSize.small
                color: MatrixService.state === "error" ? Appearance.m3colors.m3error
                    : (MatrixService.healthy ? Appearance.colors.colPrimary : Appearance.colors.colSubtext)
            }

            StyledText {
                Layout.fillWidth: true
                text: MatrixService.openRoom?.name ?? MatrixService.status
                font.pixelSize: MatrixService.openRoomId.length > 0
                    ? Appearance.font.pixelSize.normal
                    : Appearance.font.pixelSize.smaller
                color: MatrixService.state === "error" && MatrixService.openRoomId.length === 0
                    ? Appearance.m3colors.m3error
                    : Appearance.colors.colOnLayer1
                elide: Text.ElideRight
            }

            RippleButton {
                implicitHeight: 28
                implicitWidth: 28
                buttonRadius: Appearance.rounding.small
                colBackground: Appearance.colors.colLayer2
                onClicked: MatrixService.sync()

                contentItem: MaterialSymbol {
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: "sync"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colOnLayer2

                    RotationAnimation on rotation {
                        running: MatrixService.syncing || MatrixService.loading
                        from: 0
                        to: 360
                        duration: 1000
                        loops: Animation.Infinite
                        alwaysRunToEnd: true
                    }
                }

                StyledToolTip { text: Translation.tr("Sincronizar ahora") }
            }

            RippleButton {
                visible: MatrixService.openRoomId.length === 0
                implicitHeight: 28
                implicitWidth: 28
                buttonRadius: Appearance.rounding.small
                colBackground: Appearance.colors.colLayer2
                onClicked: MatrixService.logout()

                contentItem: MaterialSymbol {
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: "logout"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colOnLayer2
                }

                StyledToolTip { text: Translation.tr("Cerrar sesión de Matrix") }
            }
        }

        // ---------------- Lista de chats ---------------- //

        StyledListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: MatrixService.openRoomId.length === 0
            spacing: 2
            clip: true
            model: MatrixService.rooms

            delegate: RippleButton {
                id: roomEntry
                required property var modelData

                width: ListView.view.width
                implicitHeight: 48
                buttonRadius: Appearance.rounding.small
                colBackground: "transparent"
                colBackgroundHover: Appearance.colors.colLayer1Hover
                onClicked: MatrixService.openChat(roomEntry.modelData.id)

                contentItem: RowLayout {
                    spacing: 8

                    Rectangle {
                        implicitWidth: 34
                        implicitHeight: 34
                        radius: Appearance.rounding.full
                        color: Appearance.colors.colLayer2
                        clip: true

                        StyledText {
                            anchors.centerIn: parent
                            visible: roomAvatar.status !== Image.Ready
                            text: (roomEntry.modelData.name ?? "?").substring(0, 1).toUpperCase()
                            font.pixelSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colOnLayer2
                        }

                        StyledImage {
                            id: roomAvatar
                            anchors.fill: parent
                            source: roomEntry.modelData.avatar ?? ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            visible: source.toString().length > 0 && status === Image.Ready
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: roomEntry.modelData.name ?? ""
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnLayer1
                            elide: Text.ElideRight
                        }
                        StyledText {
                            Layout.fillWidth: true
                            visible: (roomEntry.modelData.lastBody ?? "").length > 0
                            text: roomEntry.modelData.lastBody ?? ""
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
                    }

                    // Sin leer
                    Rectangle {
                        visible: (roomEntry.modelData.unread ?? 0) > 0
                        implicitWidth: Math.max(18, unreadText.implicitWidth + 8)
                        implicitHeight: 18
                        radius: Appearance.rounding.full
                        color: Appearance.colors.colPrimary

                        StyledText {
                            id: unreadText
                            anchors.centerIn: parent
                            text: String(roomEntry.modelData.unread ?? 0)
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnPrimary
                        }
                    }
                }
            }

            StyledText {
                anchors.centerIn: parent
                width: parent.width - 16
                visible: MatrixService.rooms.length === 0
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                text: MatrixService.lastSync === 0
                    ? Translation.tr("Sincronizando por primera vez…")
                    : Translation.tr("No hay chats todavía.\nSi esperabas WhatsApp, falta vincularlo:\nescribile a @whatsappbot y mandá \"login qr\".")
            }
        }

        // ---------------- Conversación abierta ---------------- //

        StyledListView {
            id: timeline
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: MatrixService.openRoomId.length > 0
            spacing: 4
            clip: true
            model: MatrixService.openMessages

            // Al llegar algo nuevo el chat baja solo, salvo que estés leyendo arriba
            property bool atBottom: timeline.contentY >= timeline.contentHeight - timeline.height - 40
            onCountChanged: if (timeline.atBottom || !timeline.moving) timeline.positionViewAtEnd()

            delegate: Item {
                id: messageItem
                required property var modelData

                width: ListView.view.width
                implicitHeight: bubble.implicitHeight

                Rectangle {
                    id: bubble
                    anchors.right: messageItem.modelData.mine ? parent.right : undefined
                    anchors.left: messageItem.modelData.mine ? undefined : parent.left
                    width: Math.min(messageItem.width * 0.85, bubbleColumn.implicitWidth + 20)
                    implicitHeight: bubbleColumn.implicitHeight + 12
                    radius: Appearance.rounding.small
                    color: messageItem.modelData.mine
                        ? Appearance.colors.colSecondaryContainer
                        : Appearance.colors.colLayer2

                    ColumnLayout {
                        id: bubbleColumn
                        anchors {
                            left: parent.left
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                            margins: 10
                        }
                        spacing: 1

                        StyledText {
                            Layout.fillWidth: true
                            // En un grupo hace falta saber quién habló; en el chat
                            // propio el remitente es obvio
                            visible: !messageItem.modelData.mine
                            text: (messageItem.modelData.sender ?? "").replace(/^@/, "").split(":")[0]
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colPrimary
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: messageItem.modelData.body ?? ""
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnLayer1
                            wrapMode: Text.Wrap
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignRight
                            text: Qt.formatTime(new Date(messageItem.modelData.ts ?? 0), "HH:mm")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: MatrixService.openRoomId.length > 0
            spacing: 4

            MaterialTextField {
                id: messageField
                Layout.fillWidth: true
                placeholderText: Translation.tr("Escribí un mensaje")
                onAccepted: {
                    MatrixService.sendMessage(messageField.text);
                    messageField.text = "";
                }
            }

            RippleButton {
                implicitHeight: 34
                implicitWidth: 34
                buttonRadius: Appearance.rounding.small
                enabled: messageField.text.trim().length > 0
                colBackground: Appearance.colors.colPrimary
                colBackgroundHover: Appearance.colors.colPrimaryHover
                onClicked: {
                    MatrixService.sendMessage(messageField.text);
                    messageField.text = "";
                }

                contentItem: MaterialSymbol {
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: "send"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnPrimary
                }
            }
        }
    }
}
