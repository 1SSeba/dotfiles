import qs.services
import qs.modules.common
import qs.modules.common.widgets
import "calendar_layout.js" as CalendarLayout
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    // Layout.topMargin: 10
    anchors.topMargin: 10
    property int monthShift: 0
    property var viewingDate: CalendarLayout.getDateInXMonthsTime(monthShift)
    property var calendarLayout: CalendarLayout.getCalendarLayout(viewingDate, monthShift === 0)
    width: calendarColumn.width
    implicitHeight: calendarColumn.height + 10 * 2

    /**
     * Qué se está mirando:
     *  - "days":   la grilla del mes, como siempre
     *  - "day":    lo que tenés organizado un día puntual
     *  - "months": elegir un mes del año que se está viendo
     *  - "years":  elegir el año, de a doce
     * Todas comparten el mismo lugar (`body`), así el grupo de widgets de abajo
     * no cambia de alto al pasar de una a otra.
     */
    property string view: "days"
    /** El día abierto en la vista "day", a las 12 para esquivar cambios de hora. */
    property var selectedDate: new Date()
    readonly property string selectedDateKey: CalendarLayout.localDateKey(root.selectedDate)
    readonly property var selectedEvents: Calendars.eventsByDate[root.selectedDateKey] ?? []
    /** Primer año de la página de doce que muestra la vista "years". */
    property int yearPageStart: root.viewingDate.getFullYear() - 4

    readonly property int cellSize: 38
    readonly property int cellSpacing: 5

    /**
     * Al moverse de mes hay que asegurarse de que Calendars ya tenga esos
     * eventos. `ensureWindow` no pide nada si la ventana actual ya los cubría,
     * así que se puede llamar sin miedo en cada cambio.
     */
    function syncEventWindow() {
        if (!Calendars.enabled) return;
        const first = new Date(viewingDate.getFullYear(), viewingDate.getMonth() - 1, 1);
        const last = new Date(viewingDate.getFullYear(), viewingDate.getMonth() + 2, 1);
        Calendars.ensureWindow(first, last);
    }
    onMonthShiftChanged: root.syncEventWindow()
    Component.onCompleted: root.syncEventWindow()

    /** Lleva la grilla a ese mes (0-based) de ese año. */
    function goToMonth(year, month) {
        const now = new Date();
        root.monthShift = (year - now.getFullYear()) * 12 + (month - now.getMonth());
    }

    function openDay(dateKey) {
        const parts = String(dateKey).split("-").map(Number);
        root.selectedDate = new Date(parts[0], parts[1] - 1, parts[2], 12);
        // Si tocaste un día gris del mes de al lado, al volver te deja en ese mes
        root.goToMonth(parts[0], parts[1] - 1);
        root.view = "day";
    }

    function shiftDay(delta) {
        const d = root.selectedDate;
        root.selectedDate = new Date(d.getFullYear(), d.getMonth(), d.getDate() + delta, 12);
        root.goToMonth(root.selectedDate.getFullYear(), root.selectedDate.getMonth());
    }

    function openMonthPicker() {
        root.view = "months";
    }

    function openYearPicker() {
        root.yearPageStart = root.viewingDate.getFullYear() - 4;
        root.view = "years";
    }

    /** Las flechas, la rueda y PageUp/PageDown hacen lo mismo según la vista. */
    function step(delta) {
        switch (root.view) {
        case "day":
            root.shiftDay(delta);
            break;
        case "months":
            root.monthShift += 12 * delta;
            break;
        case "years":
            root.yearPageStart += 12 * delta;
            break;
        default:
            root.monthShift += delta;
        }
    }

    function goToday() {
        root.monthShift = 0;
        if (root.view === "day") root.selectedDate = new Date();
        else root.view = "days";
    }

    readonly property bool showingToday: root.view === "day"
        ? root.selectedDateKey === CalendarLayout.localDateKey(new Date())
        : (root.monthShift === 0 && root.view === "days")

    Keys.onPressed: (event) => {
        if ((event.key === Qt.Key_PageDown || event.key === Qt.Key_PageUp)
            && event.modifiers === Qt.NoModifier) {
            root.step(event.key === Qt.Key_PageDown ? 1 : -1);
            event.accepted = true;
        } else if ((event.key === Qt.Key_Escape || event.key === Qt.Key_Backspace)
            && root.view !== "days") {
            root.view = "days";
            event.accepted = true;
        }
    }
    MouseArea {
        anchors.fill: parent
        onWheel: (event) => {
            // En la vista del día la rueda es para la lista de eventos
            if (root.view === "day") return;
            if (event.angleDelta.y > 0) {
                root.step(-1);
            } else if (event.angleDelta.y < 0) {
                root.step(1);
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

            // Volver a la grilla desde cualquier otra vista
            CalendarHeaderButton {
                visible: root.view !== "days"
                forceCircle: true
                tooltipText: Translation.tr("Volver al mes")
                downAction: () => {
                    root.view = "days";
                }
                contentItem: MaterialSymbol {
                    text: "arrow_back"
                    iconSize: Appearance.font.pixelSize.larger
                    horizontalAlignment: Text.AlignHCenter
                    color: Appearance.colors.colOnLayer1
                }
            }

            CalendarHeaderButton {
                id: titleButton
                clip: true
                // Lo que dejan libre los botones redondos que estén a la vista
                Layout.maximumWidth: calendarBody.width
                    - (30 + 5) * (2 + (root.view !== "days" ? 1 : 0) + (root.showingToday ? 0 : 1))
                buttonText: {
                    switch (root.view) {
                    case "day":
                        return root.selectedDate.toLocaleDateString(Qt.locale(),
                            root.selectedDate.getFullYear() === new Date().getFullYear()
                                ? "ddd d MMM" : "d MMM yyyy");
                    case "months":
                        return root.viewingDate.getFullYear().toString();
                    case "years":
                        return `${root.yearPageStart} – ${root.yearPageStart + 11}`;
                    default:
                        return root.viewingDate.toLocaleDateString(Qt.locale(), "MMMM yyyy");
                    }
                }
                tooltipText: {
                    switch (root.view) {
                    case "days": return Translation.tr("Elegir mes y año");
                    case "months": return Translation.tr("Elegir año");
                    case "day": return Translation.tr("Elegir mes y año");
                    default: return "";
                    }
                }
                downAction: () => {
                    if (root.view === "months") root.openYearPicker();
                    else if (root.view === "years") root.view = "months";
                    else root.openMonthPicker();
                }
                contentItem: RowLayout {
                    spacing: 2
                    StyledText {
                        Layout.fillWidth: true
                        text: titleButton.buttonText
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                        font.pixelSize: Appearance.font.pixelSize.larger
                        color: Appearance.colors.colOnLayer1
                    }
                    MaterialSymbol {
                        visible: root.view !== "years"
                        text: "arrow_drop_down"
                        iconSize: Appearance.font.pixelSize.larger
                        color: Appearance.colors.colOnLayer1
                    }
                }
            }
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: false
            }
            CalendarHeaderButton {
                visible: !root.showingToday
                forceCircle: true
                tooltipText: Translation.tr("Ir a hoy")
                downAction: () => root.goToday()
                contentItem: MaterialSymbol {
                    text: "today"
                    iconSize: Appearance.font.pixelSize.larger
                    horizontalAlignment: Text.AlignHCenter
                    color: Appearance.colors.colOnLayer1
                }
            }
            CalendarHeaderButton {
                forceCircle: true
                downAction: () => root.step(-1)
                contentItem: MaterialSymbol {
                    text: "chevron_left"
                    iconSize: Appearance.font.pixelSize.larger
                    horizontalAlignment: Text.AlignHCenter
                    color: Appearance.colors.colOnLayer1
                }
            }
            CalendarHeaderButton {
                forceCircle: true
                downAction: () => root.step(1)
                contentItem: MaterialSymbol {
                    text: "chevron_right"
                    iconSize: Appearance.font.pixelSize.larger
                    horizontalAlignment: Text.AlignHCenter
                    color: Appearance.colors.colOnLayer1
                }
            }
        }

        /**
         * Tamaño fijo, el de la grilla de días (fila de nombres + 6 semanas):
         * las otras vistas se dibujan encima en el mismo lugar.
         */
        Item {
            id: calendarBody
            implicitWidth: 7 * root.cellSize + 6 * root.cellSpacing
            implicitHeight: 7 * root.cellSize + 6 * root.cellSpacing

            // ---------------------------------------------------------- //
            // Grilla del mes
            // ---------------------------------------------------------- //
            ColumnLayout {
                id: daysView
                anchors.fill: parent
                spacing: root.cellSpacing
                opacity: root.view === "days" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }

                // Week days row
                RowLayout {
                    id: weekDaysRow
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillHeight: false
                    spacing: root.cellSpacing
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
                        spacing: root.cellSpacing
                        Repeater {
                            model: Array(7).fill(modelData)
                            delegate: CalendarDayButton {
                                day: calendarLayout[modelData][index].day
                                isToday: calendarLayout[modelData][index].today
                                // eventsByDate cambia entero al refrescar, así que este
                                // binding se re-evalúa solo cuando llegan eventos nuevos
                                dateKey: calendarLayout[modelData][index].dateKey
                                events: Calendars.eventsByDate[calendarLayout[modelData][index].dateKey] ?? []
                                onClicked: root.openDay(dateKey)
                            }
                        }
                    }
                }
            }

            // ---------------------------------------------------------- //
            // Un día: lo que tenés organizado
            // ---------------------------------------------------------- //
            CalendarDayView {
                anchors.fill: parent
                opacity: root.view === "day" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
                date: root.selectedDate
                dateKey: root.selectedDateKey
                events: root.selectedEvents
            }

            // ---------------------------------------------------------- //
            // Elegir mes
            // ---------------------------------------------------------- //
            GridLayout {
                id: monthsView
                anchors.fill: parent
                columns: 3
                rowSpacing: root.cellSpacing
                columnSpacing: root.cellSpacing
                opacity: root.view === "months" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }

                Repeater {
                    model: 12
                    delegate: CalendarPickerButton {
                        required property int index
                        readonly property var monthDate: new Date(root.viewingDate.getFullYear(), index, 1, 12)
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        label: monthDate.toLocaleDateString(Qt.locale(), "MMM")
                        current: {
                            const now = new Date();
                            return now.getFullYear() === monthDate.getFullYear() && now.getMonth() === index;
                        }
                        selected: root.viewingDate.getMonth() === index
                        onClicked: {
                            root.goToMonth(root.viewingDate.getFullYear(), index);
                            root.view = "days";
                        }
                    }
                }
            }

            // ---------------------------------------------------------- //
            // Elegir año
            // ---------------------------------------------------------- //
            GridLayout {
                id: yearsView
                anchors.fill: parent
                columns: 3
                rowSpacing: root.cellSpacing
                columnSpacing: root.cellSpacing
                opacity: root.view === "years" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }

                Repeater {
                    model: 12
                    delegate: CalendarPickerButton {
                        required property int index
                        readonly property int year: root.yearPageStart + index
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        label: year.toString()
                        current: new Date().getFullYear() === year
                        selected: root.viewingDate.getFullYear() === year
                        onClicked: {
                            // Mismo mes, otro año: después elegís el mes
                            root.goToMonth(year, root.viewingDate.getMonth());
                            root.view = "months";
                        }
                    }
                }
            }
        }
    }
}
