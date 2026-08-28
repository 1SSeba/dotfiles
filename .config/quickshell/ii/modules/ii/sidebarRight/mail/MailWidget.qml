import qs.services
import qs.modules.common
// CalendarHeaderButton vive ahi; es el boton redondo chico de la barra de widgets
import qs.modules.ii.sidebarRight.calendar
import qs.modules.common.widgets
import Quickshell
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/**
 * Los mails sin leer de todas tus cuentas, mezclados y con los más nuevos arriba.
 *
 * Sólo lectura y a propósito: abrir un mensaje abre el webmail en el navegador.
 * Un cliente de correo dentro de la barra es otro proyecto — acá lo que sirve es
 * saber cuántos hay y de quién sin cambiar de ventana.
 */
Item {
    id: root

    /** El botón de arriba abre el webmail de la primera cuenta; cada mensaje, el suyo. */
    readonly property string webmailUrl: MailService.accounts.length > 0
        ? MailService.webmailFor(MailService.accounts[0].host, MailService.accounts[0].user)
        : "https://mail.google.com/mail/u/0/#search/is:unread"

    /** Con una sola cuenta, decir de cuál es cada mail sería ruido. */
    readonly property bool showAccounts: MailService.accounts.length > 1

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            StyledText {
                Layout.fillWidth: true
                text: MailService.unreadCount > 0
                    ? Translation.tr("%1 sin leer").arg(MailService.unreadCount)
                    : Translation.tr("Correo")
                font.pixelSize: Appearance.font.pixelSize.large
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnLayer1
                elide: Text.ElideRight
            }

            CalendarHeaderButton {
                forceCircle: true
                enabled: MailService.enabled && !MailService.loading
                downAction: () => MailService.refresh()
                contentItem: MaterialSymbol {
                    text: "refresh"
                    iconSize: Appearance.font.pixelSize.larger
                    horizontalAlignment: Text.AlignHCenter
                    color: Appearance.colors.colOnLayer1
                    opacity: MailService.loading ? 0.4 : 1
                }
            }

            CalendarHeaderButton {
                forceCircle: true
                downAction: () => Quickshell.execDetached(["xdg-open", root.webmailUrl])
                contentItem: MaterialSymbol {
                    text: "open_in_new"
                    iconSize: Appearance.font.pixelSize.larger
                    horizontalAlignment: Text.AlignHCenter
                    color: Appearance.colors.colOnLayer1
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            PagePlaceholder {
                shown: !MailService.enabled
                icon: "mail_lock"
                title: Translation.tr("Correo sin configurar")
                description: Translation.tr("Conectá una cuenta en Ajustes → Perfil → Cuentas.\n"
                    + "Se abre el navegador y se verifica sola.")
                descriptionHorizontalAlignment: Text.AlignHCenter
            }

            // Con varias cuentas, que una falle no puede tapar los mails de las
            // otras: el error sólo ocupa la pantalla cuando no hay nada que mostrar.
            PagePlaceholder {
                shown: MailService.enabled && MailService.lastError.length > 0
                    && MailService.recent.length === 0
                icon: "error"
                title: Translation.tr("No se pudo leer el correo")
                description: MailService.lastError
                descriptionHorizontalAlignment: Text.AlignHCenter
            }

            PagePlaceholder {
                shown: MailService.enabled && MailService.lastError.length === 0
                    && MailService.recent.length === 0
                icon: "mark_email_read"
                title: Translation.tr("Bandeja al día")
                description: Translation.tr("No tenés mensajes sin leer")
                descriptionHorizontalAlignment: Text.AlignHCenter
            }

            StyledListView {
                id: mailList
                anchors.fill: parent
                visible: MailService.enabled && MailService.recent.length > 0
                clip: true
                spacing: 4
                model: MailService.recent

                delegate: RippleButton {
                    required property var modelData
                    width: mailList.width
                    implicitHeight: mailRow.implicitHeight + 8 * 2
                    buttonRadius: Appearance.rounding.small
                    colBackground: Appearance.colors.colLayer2
                    onClicked: Quickshell.execDetached(["xdg-open",
                        modelData.webmail ?? root.webmailUrl])

                    contentItem: RowLayout {
                        id: mailRow
                        spacing: 10

                        MaterialSymbol {
                            Layout.alignment: Qt.AlignTop
                            Layout.topMargin: 2
                            text: "mail"
                            iconSize: Appearance.font.pixelSize.larger
                            color: Appearance.m3colors.m3primary
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                StyledText {
                                    Layout.fillWidth: true
                                    text: modelData.from
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    font.weight: Font.DemiBold
                                    color: Appearance.colors.colOnLayer2
                                    elide: Text.ElideRight
                                }
                                StyledText {
                                    // timestamp 0 = el mensaje traía una fecha
                                    // que no se pudo parsear; mejor no mostrar nada
                                    visible: modelData.timestamp > 0
                                    text: {
                                        const d = new Date(modelData.timestamp * 1000);
                                        const hoy = new Date();
                                        const mismoDia = d.getFullYear() === hoy.getFullYear()
                                            && d.getMonth() === hoy.getMonth()
                                            && d.getDate() === hoy.getDate();
                                        return mismoDia
                                            ? d.toLocaleTimeString(Qt.locale(), "HH:mm")
                                            : d.toLocaleDateString(Qt.locale(), "d MMM");
                                    }
                                    font.pixelSize: Appearance.font.pixelSize.smallest
                                    color: Appearance.colors.colSubtext
                                }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                StyledText {
                                    Layout.fillWidth: true
                                    text: modelData.subject
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colSubtext
                                    elide: Text.ElideRight
                                }
                                // De qué cuenta salió. Con varias conectadas, sin
                                // esto no hay forma de saber cuál te está hablando.
                                StyledText {
                                    visible: root.showAccounts
                                    text: modelData.accountLabel ?? ""
                                    font.pixelSize: Appearance.font.pixelSize.smallest
                                    color: Appearance.colors.colSubtext
                                    elide: Text.ElideRight
                                    Layout.maximumWidth: mailList.width * 0.35
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
