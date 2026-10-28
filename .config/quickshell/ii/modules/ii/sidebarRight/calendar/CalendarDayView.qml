import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

/**
 * Lo que hay organizado un día, en lista. Lo abre CalendarWidget al tocar un
 * casillero; la navegación (volver, día anterior/siguiente) vive en su
 * encabezado, acá sólo se muestra.
 *
 * Lee de Calendars.eventsByDate, la forma normalizada de la shell, así que da
 * igual si el evento vino de Google o de iCloud.
 */
Item {
    id: root
    property var date: new Date()
    property string dateKey: ""
    property var events: []
    /** Sin cuenta no es un día libre, es un día que no se puede leer. */
    property bool accountConnected: Calendars.enabled

    function sameDay(a, b) {
        return a.getFullYear() === b.getFullYear()
            && a.getMonth() === b.getMonth()
            && a.getDate() === b.getDate();
    }

    /** "10:00 – 11:30", "Todo el día", o con fecha si el evento cruza días. */
    function timeText(ev) {
        if (ev.allDay) return Translation.tr("Todo el día");
        const start = ev.start;
        const end = ev.end ?? ev.start;
        const hhmm = d => d.toLocaleTimeString(Qt.locale(), "HH:mm");
        const withDay = d => d.toLocaleDateString(Qt.locale(), "d MMM") + " " + hhmm(d);
        const startText = root.sameDay(start, root.date) ? hhmm(start) : withDay(start);
        if (end.getTime() === start.getTime()) return startText;
        const endText = root.sameDay(end, root.date) ? hhmm(end) : withDay(end);
        return `${startText} – ${endText}`;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 6

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            PagePlaceholder {
                shown: !root.accountConnected
                icon: "link_off"
                title: Translation.tr("Sin cuenta conectada")
                description: Translation.tr("Conectá tu cuenta de Google o de iCloud en Ajustes → Perfil → Cuentas")
                descriptionHorizontalAlignment: Text.AlignHCenter
            }

            PagePlaceholder {
                shown: root.accountConnected && root.events.length === 0
                icon: Calendars.loading ? "hourglass_empty"
                    : Calendars.lastError.length > 0 ? "error" : "event_available"
                title: Calendars.loading ? Translation.tr("Cargando…")
                    : Calendars.lastError.length > 0 ? Translation.tr("No se pudo leer el calendario")
                    : Translation.tr("Día libre")
                description: (!Calendars.loading && Calendars.lastError.length > 0)
                    ? Calendars.lastError
                    : Translation.tr("No tenés nada organizado para este día")
                descriptionHorizontalAlignment: Text.AlignHCenter
            }

            StyledListView {
                id: eventList
                anchors.fill: parent
                visible: root.accountConnected && root.events.length > 0
                clip: true
                spacing: 4
                model: root.events

                delegate: RippleButton {
                    id: eventButton
                    required property var modelData
                    width: eventList.width
                    implicitHeight: eventRow.implicitHeight + 8 * 2
                    buttonRadius: Appearance.rounding.small
                    colBackground: Appearance.colors.colLayer2
                    onClicked: Calendars.open(eventButton.modelData)

                    contentItem: RowLayout {
                        id: eventRow
                        spacing: 10

                        // Barrita del color del calendario al que pertenece
                        Rectangle {
                            Layout.fillHeight: true
                            Layout.minimumHeight: 30
                            implicitWidth: 3
                            radius: 1.5
                            color: (eventButton.modelData.color ?? "").length > 0
                                ? eventButton.modelData.color
                                : Appearance.m3colors.m3primary
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            StyledText {
                                Layout.fillWidth: true
                                text: eventButton.modelData.summary
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colOnLayer2
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: root.timeText(eventButton.modelData)
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colSubtext
                                elide: Text.ElideRight
                            }
                            StyledText {
                                Layout.fillWidth: true
                                visible: text.length > 0
                                text: [eventButton.modelData.location ?? "", eventButton.modelData.calendarName ?? ""]
                                    .filter(s => s.length > 0).join("  ·  ")
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colSubtext
                                elide: Text.ElideRight
                            }
                        }
                    }

                    StyledToolTip {
                        text: Translation.tr("Abrir en el navegador")
                    }
                }
            }
        }

        // Pie: cuántos hay y el día completo en la web del proveedor
        RowLayout {
            Layout.fillWidth: true
            visible: root.accountConnected && root.events.length > 0
            spacing: 5

            StyledText {
                Layout.fillWidth: true
                text: root.events.length === 1
                    ? Translation.tr("1 evento")
                    : Translation.tr("%1 eventos").arg(root.events.length)
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
            }
            CalendarHeaderButton {
                buttonText: Translation.tr("Abrir día")
                downAction: () => Calendars.openDay(root.dateKey)
                contentItem: RowLayout {
                    spacing: 4
                    MaterialSymbol {
                        text: "open_in_new"
                        iconSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colOnLayer1
                    }
                    StyledText {
                        text: Translation.tr("Abrir día")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnLayer1
                    }
                }
            }
        }
    }
}
