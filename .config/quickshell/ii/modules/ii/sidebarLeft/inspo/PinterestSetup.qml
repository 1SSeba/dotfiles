import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

/**
 * Panel de conexión de Pinterest.
 *
 * Pinterest no deja usar su API con usuario y contraseña: hay que crear una app
 * de developer y pegar acá su App ID y su secret. Este panel es el instructivo
 * y el formulario a la vez, para no tener que ir a buscar los pasos afuera.
 */
Flickable {
    id: root
    contentHeight: column.implicitHeight
    clip: true

    ColumnLayout {
        id: column
        width: root.width
        spacing: 12

        MaterialSymbol {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 10
            iconSize: 48
            color: Appearance.colors.colOnLayer1
            text: "push_pin"
        }

        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: Appearance.font.pixelSize.large
            color: Appearance.colors.colOnLayer1
            text: Translation.tr("Conectá tu Pinterest")
        }

        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
            text: Translation.tr("Vas a ver tus boards y buscar entre tus pines guardados. La API de Pinterest no permite búsqueda global, así que para descubrir cosas nuevas usá Wallhaven u Openverse.")
        }

        // ---------------- Instructivo ----------------
        Rectangle {
            Layout.fillWidth: true
            radius: Appearance.rounding.small
            color: Appearance.colors.colLayer2
            implicitHeight: stepsColumn.implicitHeight + 20

            ColumnLayout {
                id: stepsColumn
                anchors.centerIn: parent
                width: parent.width - 20
                spacing: 6

                StyledText {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnLayer2
                    textFormat: Text.MarkdownText
                    text: Translation.tr("**1.** Tu cuenta tiene que ser *business* (es gratis, se convierte desde los ajustes de Pinterest).\n\n"
                        + "**2.** Entrá a developers.pinterest.com → *My apps* → creá una app.\n\n"
                        + "**3.** En la app, agregá este redirect URI **exacto**:")
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 30
                    radius: Appearance.rounding.verysmall
                    color: Appearance.colors.colLayer1

                    StyledText {
                        anchors.centerIn: parent
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnLayer1
                        text: "http://localhost:8085/"
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnLayer2
                    textFormat: Text.MarkdownText
                    text: Translation.tr("**4.** Pedí los scopes `boards:read` y `pins:read`.\n\n"
                        + "**5.** Copiá el *App ID* y el *App secret* y pegalos acá abajo.")
                }

                RippleButton {
                    Layout.alignment: Qt.AlignHCenter
                    implicitHeight: 30
                    buttonRadius: Appearance.rounding.small
                    onClicked: Qt.openUrlExternally("https://developers.pinterest.com/apps/")
                    contentItem: StyledText {
                        horizontalAlignment: Text.AlignHCenter
                        leftPadding: 12; rightPadding: 12
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnLayer1
                        text: Translation.tr("Abrir developers.pinterest.com")
                    }
                }
            }
        }

        // ---------------- Credenciales ----------------
        ToolbarTextField {
            id: appIdField
            Layout.fillWidth: true
            Layout.fillHeight: false
            colBackground: Appearance.colors.colLayer2
            placeholderText: Translation.tr("App ID")
            text: InspoService.pinterestAuth.client_id ?? ""
        }

        ToolbarTextField {
            id: appSecretField
            Layout.fillWidth: true
            Layout.fillHeight: false
            colBackground: Appearance.colors.colLayer2
            echoMode: TextInput.Password
            placeholderText: Translation.tr("App secret")
            text: InspoService.pinterestAuth.client_secret ?? ""
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            RippleButton {
                Layout.fillWidth: true
                implicitHeight: 38
                buttonRadius: Appearance.rounding.small
                enabled: appIdField.text.length > 0 && appSecretField.text.length > 0
                onClicked: InspoService.setPinterestApp(appIdField.text, appSecretField.text)
                contentItem: StyledText {
                    horizontalAlignment: Text.AlignHCenter
                    color: Appearance.colors.colOnLayer1
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    text: Translation.tr("Guardar app")
                }
            }

            RippleButton {
                Layout.fillWidth: true
                implicitHeight: 38
                buttonRadius: Appearance.rounding.small
                toggled: InspoService.pinterestConfigured
                enabled: InspoService.pinterestConfigured
                onClicked: InspoService.loginPinterest()
                contentItem: StyledText {
                    horizontalAlignment: Text.AlignHCenter
                    color: InspoService.pinterestConfigured
                        ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer1Inactive
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    text: Translation.tr("Conectar")
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.bottomMargin: 10
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            visible: InspoService.message.length > 0
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
            text: InspoService.message
        }
    }
}
