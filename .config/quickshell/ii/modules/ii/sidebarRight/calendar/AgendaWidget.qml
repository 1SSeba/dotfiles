import qs.services
import qs.modules.common
import qs.modules.common.widgets
import Quickshell
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/**
 * "Lo que viene": los próximos eventos de la cuenta, en lista.
 *
 * Vive en una pestaña propia y no colgado abajo de la grilla porque el grupo de
 * widgets tiene altura fija (350px en BottomWidgetGroup) y el calendario ya la
 * llena casi entera. Acá la lista tiene todo el alto para ella.
 *
 * Lee de Calendars.upcoming, que es una forma normalizada de la shell: el
 * día que sumemos iCloud por CalDAV, este archivo no se toca.
 */
Item {
    id: root

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Lo que viene")
                font.pixelSize: Appearance.font.pixelSize.large
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnLayer1
                elide: Text.ElideRight
            }

            CalendarHeaderButton {
                forceCircle: true
                enabled: Calendars.enabled && !Calendars.loading
                downAction: () => Calendars.refresh()
                contentItem: MaterialSymbol {
                    text: "refresh"
                    iconSize: Appearance.font.pixelSize.larger
                    horizontalAlignment: Text.AlignHCenter
                    color: Appearance.colors.colOnLayer1
                    opacity: Calendars.loading ? 0.4 : 1
                }
            }
        }

        /**
         * PagePlaceholder hace anchors.fill de su padre, así que no puede colgar
         * directo de un ColumnLayout — va dentro de este Item, que sí es hijo del
         * layout. Lo mismo la lista.
         */
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Sin cuenta conectada esto no es una agenda vacía, es una agenda
            // ausente: conviene decirlo y no dejar un placeholder que parezca
            // "no tenés nada".
            PagePlaceholder {
                shown: !Calendars.enabled
                icon: "link_off"
                title: Translation.tr("Sin cuenta conectada")
                description: Translation.tr("Conectá tu cuenta de Google o de iCloud en Ajustes → Perfil → Cuentas")
                descriptionHorizontalAlignment: Text.AlignHCenter
            }

            PagePlaceholder {
                shown: Calendars.enabled && Calendars.upcoming.length === 0
                icon: Calendars.lastError.length > 0 ? "error" : "event_available"
                title: Calendars.lastError.length > 0
                    ? Translation.tr("No se pudo leer el calendario")
                    : Translation.tr("Nada a la vista")
                description: Calendars.lastError.length > 0
                    ? Calendars.lastError
                    : Translation.tr("No hay eventos próximos en tus calendarios")
                descriptionHorizontalAlignment: Text.AlignHCenter
            }

            StyledListView {
                id: eventList
                anchors.fill: parent
                visible: Calendars.enabled && Calendars.upcoming.length > 0
                clip: true
                spacing: 4
                model: Calendars.upcoming

                delegate: RippleButton {
                    required property var modelData
                    width: eventList.width
                    implicitHeight: eventRow.implicitHeight + 8 * 2
                    buttonRadius: Appearance.rounding.small
                    colBackground: Appearance.colors.colLayer2
                    enabled: (modelData.htmlLink ?? "").length > 0
                    onClicked: Quickshell.execDetached(["xdg-open", modelData.htmlLink])

                    contentItem: RowLayout {
                        id: eventRow
                        spacing: 10

                        // Barrita del color del calendario al que pertenece
                        Rectangle {
                            Layout.fillHeight: true
                            Layout.minimumHeight: 30
                            implicitWidth: 3
                            radius: 1.5
                            color: (modelData.color ?? "").length > 0
                                ? modelData.color
                                : Appearance.m3colors.m3primary
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            StyledText {
                                Layout.fillWidth: true
                                text: modelData.summary
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colOnLayer2
                                elide: Text.ElideRight
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: {
                                    const d = modelData.start;
                                    const hoy = new Date();
                                    const mismoDia = d.getFullYear() === hoy.getFullYear()
                                        && d.getMonth() === hoy.getMonth()
                                        && d.getDate() === hoy.getDate();
                                    const fecha = mismoDia
                                        ? Translation.tr("Hoy")
                                        : d.toLocaleDateString(Qt.locale(), "ddd d MMM");
                                    const hora = modelData.allDay
                                        ? Translation.tr("todo el día")
                                        : d.toLocaleTimeString(Qt.locale(), "HH:mm");
                                    const lugar = (modelData.location ?? "").length > 0
                                        ? `  ·  ${modelData.location}` : "";
                                    return `${fecha}  ·  ${hora}${lugar}`;
                                }
                                font.pixelSize: Appearance.font.pixelSize.smaller
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
