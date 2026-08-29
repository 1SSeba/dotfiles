import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import "calendar_layout.js" as CalendarLayout
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    // Layout.topMargin: 10
    anchors.topMargin: 10
    property int monthShift: 0
    property int yearShift: 0
    // "month": grilla del mes de siempre. "year": mapa de calor de los 12 meses.
    property string viewMode: "month"
    property var viewingDate: CalendarLayout.getDateInXMonthsTime(monthShift)
    property var calendarLayout: CalendarLayout.getCalendarLayout(viewingDate, monthShift === 0)
    readonly property var today: new Date()
    readonly property int yearViewYear: root.today.getFullYear() + root.yearShift
    width: calendarColumn.width
    implicitHeight: calendarColumn.height + 10 * 2

    /**
     * Al moverse de mes (o de año, en la vista de año) hay que asegurarse de que
     * Calendars ya tenga esos eventos. `ensureWindow` no pide nada si la ventana
     * actual ya los cubría, así que se puede llamar sin miedo en cada cambio.
     */
    function syncEventWindow() {
        if (!Calendars.enabled) return;
        if (root.viewMode === "year") {
            Calendars.ensureWindow(new Date(root.yearViewYear, 0, 1), new Date(root.yearViewYear + 1, 0, 1));
            return;
        }
        const first = new Date(viewingDate.getFullYear(), viewingDate.getMonth() - 1, 1);
        const last = new Date(viewingDate.getFullYear(), viewingDate.getMonth() + 2, 1);
        Calendars.ensureWindow(first, last);
    }
    onMonthShiftChanged: root.syncEventWindow()
    onYearShiftChanged: root.syncEventWindow()
    onViewModeChanged: root.syncEventWindow()
    Component.onCompleted: root.syncEventWindow()

    /** Cuántos eventos hay cada mes de `year`, para el mapa de calor. */
    function monthCountsForYear(year) {
        const counts = new Array(12).fill(0);
        Object.keys(Calendars.eventsByDate).forEach(key => {
            if (!key.startsWith(`${year}-`)) return;
            const monthIndex = Number(key.slice(5, 7)) - 1;
            if (monthIndex >= 0 && monthIndex < 12)
                counts[monthIndex] += Calendars.eventsByDate[key].length;
        });
        return counts;
    }
    readonly property var yearMonthCounts: root.monthCountsForYear(root.yearViewYear)
    readonly property real yearMonthCountsMax: Math.max(1, ...root.yearMonthCounts)

    /** Salta al mes elegido en el mapa de calor y vuelve a la vista de mes. */
    function goToMonth(year, monthIndex0) {
        root.monthShift = (year - root.today.getFullYear()) * 12 + (monthIndex0 - root.today.getMonth());
        root.viewMode = "month";
    }

    Keys.onPressed: (event) => {
        if ((event.key === Qt.Key_PageDown || event.key === Qt.Key_PageUp)
            && event.modifiers === Qt.NoModifier) {
            const step = (event.key === Qt.Key_PageDown) ? 1 : -1;
            if (root.viewMode === "year") root.yearShift += step;
            else root.monthShift += step;
            event.accepted = true;
        }
    }
    MouseArea {
        anchors.fill: parent
        onWheel: (event) => {
            const step = event.angleDelta.y > 0 ? -1 : (event.angleDelta.y < 0 ? 1 : 0);
            if (step === 0) return;
            if (root.viewMode === "year") root.yearShift += step;
            else root.monthShift += step;
        }
    }

    /** Una celda del mapa de calor: mes + intensidad según cuántos eventos tiene. */
    component MonthHeatCell: RippleButton {
        id: cell
        required property int monthIndex
        required property int year
        required property int count
        required property real maxCount
        required property bool isCurrent
        property var activate: () => {}

        Layout.fillWidth: true
        implicitHeight: 56
        buttonRadius: Appearance.rounding.normal
        downAction: () => cell.activate()

        readonly property real heat: cell.maxCount > 0 ? Math.min(1, cell.count / cell.maxCount) : 0
        // ColorUtils.mix(a, b, p) = p*a + (1-p)*b: a mayor 'p', más pesa 'a' (primaryContainer).
        colBackground: ColorUtils.mix(Appearance.colors.colPrimaryContainer, Appearance.colors.colLayer2, cell.isCurrent ? 1 : cell.heat)
        colBackgroundHover: ColorUtils.mix(Appearance.colors.colPrimaryContainer, Appearance.colors.colLayer2Hover, cell.isCurrent ? 1 : Math.max(cell.heat, 0.35))

        contentItem: ColumnLayout {
            anchors.centerIn: parent
            spacing: 2
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: new Date(cell.year, cell.monthIndex, 1).toLocaleDateString(Qt.locale(), "MMM")
                font.weight: cell.isCurrent ? Font.Bold : Font.Normal
                font.pixelSize: Appearance.font.pixelSize.small
                color: cell.isCurrent ? Appearance.m3colors.m3onPrimaryContainer : Appearance.colors.colOnLayer1
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                visible: cell.count > 0
                text: cell.count
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: cell.isCurrent ? Appearance.m3colors.m3onPrimaryContainer : Appearance.colors.colOnLayer1
                opacity: 0.7
            }
        }
    }

    /** Una fila de "Próximos eventos": franja de color del calendario + resumen + fecha. */
    component UpcomingEventRow: RippleButton {
        id: eventRow
        required property var event

        Layout.fillWidth: true
        implicitHeight: 40
        buttonRadius: Appearance.rounding.small
        colBackground: "transparent"
        colBackgroundHover: Appearance.colors.colLayer2Hover
        downAction: () => Calendars.open(eventRow.event)

        contentItem: RowLayout {
            spacing: 8
            Rectangle {
                Layout.preferredWidth: 4
                Layout.fillHeight: true
                Layout.topMargin: 4
                Layout.bottomMargin: 4
                radius: 2
                color: (eventRow.event.color?.length > 0) ? eventRow.event.color : Appearance.colors.colPrimary
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                StyledText {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: eventRow.event.summary ?? ""
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnLayer1
                }
                StyledText {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: {
                        const dateLabel = eventRow.event.start.toLocaleDateString(Qt.locale(), "ddd d MMM");
                        const timeLabel = eventRow.event.allDay
                            ? Translation.tr("Todo el día")
                            : eventRow.event.start.toLocaleTimeString(Qt.locale(), "HH:mm");
                        return `${dateLabel} · ${timeLabel}`;
                    }
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnLayer1
                    opacity: 0.7
                }
            }
        }
    }

    ColumnLayout {
        id: calendarColumn
        anchors.centerIn: parent
        spacing: 5

        // Calendar header
        RowLayout {
            Layout.fillWidth: true
            spacing: 5
            CalendarHeaderButton {
                clip: true
                buttonText: root.viewMode === "year"
                    ? `${root.yearShift != 0 ? "• " : ""}${root.yearViewYear}`
                    : `${monthShift != 0 ? "• " : ""}${viewingDate.toLocaleDateString(Qt.locale(), "MMMM yyyy")}`
                tooltipText: (root.viewMode === "year" ? root.yearShift === 0 : monthShift === 0) ? "" : Translation.tr("Jump to current month")
                downAction: () => {
                    root.monthShift = 0;
                    root.yearShift = 0;
                }
            }
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: false
            }
            CalendarHeaderButton {
                forceCircle: true
                toggled: root.viewMode === "year"
                tooltipText: root.viewMode === "year" ? Translation.tr("Volver al mes") : Translation.tr("Ver el año completo")
                downAction: () => {
                    root.viewMode = (root.viewMode === "year") ? "month" : "year";
                }
                contentItem: MaterialSymbol {
                    text: "calendar_view_month"
                    iconSize: Appearance.font.pixelSize.larger
                    horizontalAlignment: Text.AlignHCenter
                    color: root.viewMode === "year" ? Appearance.m3colors.m3onSecondaryContainer : Appearance.colors.colOnLayer1
                }
            }
            CalendarHeaderButton {
                forceCircle: true
                downAction: () => {
                    if (root.viewMode === "year") root.yearShift--;
                    else monthShift--;
                }
                contentItem: MaterialSymbol {
                    text: "chevron_left"
                    iconSize: Appearance.font.pixelSize.larger
                    horizontalAlignment: Text.AlignHCenter
                    color: Appearance.colors.colOnLayer1
                }
            }
            CalendarHeaderButton {
                forceCircle: true
                downAction: () => {
                    if (root.viewMode === "year") root.yearShift++;
                    else monthShift++;
                }
                contentItem: MaterialSymbol {
                    text: "chevron_right"
                    iconSize: Appearance.font.pixelSize.larger
                    horizontalAlignment: Text.AlignHCenter
                    color: Appearance.colors.colOnLayer1
                }
            }
        }

        // ---- Vista de mes ----
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 5
            visible: root.viewMode === "month"

            // Week days row
            RowLayout {
                id: weekDaysRow
                Layout.alignment: Qt.AlignHCenter
                Layout.fillHeight: false
                spacing: 5
                Repeater {
                    model: CalendarLayout.weekDays
                    delegate: CalendarDayButton {
                        day: Translation.tr(modelData.day)
                        isToday: modelData.today
                        bold: true
                        enabled: false
                    }
                }
            }

            // Real week rows
            Repeater {
                id: calendarRows
                // model: calendarLayout
                model: 6
                delegate: RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillHeight: false
                    spacing: 5
                    Repeater {
                        model: Array(7).fill(modelData)
                        delegate: CalendarDayButton {
                            day: calendarLayout[modelData][index].day
                            isToday: calendarLayout[modelData][index].today
                            // eventsByDate cambia entero al refrescar, así que este
                            // binding se re-evalúa solo cuando llegan eventos nuevos
                            dateKey: calendarLayout[modelData][index].dateKey
                            events: Calendars.eventsByDate[calendarLayout[modelData][index].dateKey] ?? []
                        }
                    }
                }
            }
        }

        // ---- Vista de año: mapa de calor de 12 meses, 3 columnas x 4 filas ----
        GridLayout {
            id: yearGrid
            Layout.fillWidth: true
            visible: root.viewMode === "year"
            columns: 3
            rowSpacing: 6
            columnSpacing: 6

            Repeater {
                model: 12
                delegate: MonthHeatCell {
                    required property int index
                    monthIndex: index
                    year: root.yearViewYear
                    count: root.yearMonthCounts[index]
                    maxCount: root.yearMonthCountsMax
                    isCurrent: root.yearViewYear === root.today.getFullYear() && index === root.today.getMonth()
                    activate: () => root.goToMonth(root.yearViewYear, index)
                }
            }
        }

        // ---- Próximos eventos ----
        ColumnLayout {
            id: upcomingSection
            Layout.fillWidth: true
            Layout.topMargin: 6
            spacing: 2
            visible: root.viewMode === "month" && Calendars.enabled && Calendars.upcoming.length > 0

            Rectangle {
                Layout.fillWidth: true
                Layout.bottomMargin: 4
                implicitHeight: 1
                color: Appearance.colors.colOutlineVariant
                opacity: 0.4
            }

            Repeater {
                model: Calendars.upcoming
                delegate: UpcomingEventRow {
                    required property var modelData
                    event: modelData
                }
            }
        }
    }
}
