import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
;import qs.modules.common.functions
import qs.modules.common.widgets.widgetCanvas
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root
    configEntryName: "calendar"
    hoverEnabled: true

    readonly property real cardSpacing: 12
    readonly property real singleWidth: 132
    readonly property real cardHeight: 120

    readonly property real snapWidth1: singleWidth            
    readonly property real snapWidth2: singleWidth * 2 + cardSpacing  
    readonly property real snapWidth3: singleWidth * 2 + cardSpacing  

    property string sizeMode: root.effective("sizeMode") ?? "2x2"

    property real widgetWidth: {
        switch (root.sizeMode) {
            case "1x1": return snapWidth1
            case "1x2": return snapWidth2
            default:    return snapWidth3
        }
    }

    function modeForWidth(value) {
        var mid1 = (snapWidth1 + snapWidth2) / 2
        if (value < mid1) return "1x1"
        return root.sizeMode === "1x2" ? "1x2" : "2x2"
    }

    readonly property real heightToggleFraction: 0.3
    readonly property real heightToggleDelta: (root.cardHeight * 2 + root.cardSpacing - root.cardHeight) * root.heightToggleFraction

    function modeForDrag(dx, dy, startWidth) {
        var mid = (root.snapWidth1 + root.snapWidth2) / 2
        var newWidth = startWidth + dx

        if (newWidth < mid) return "1x1"

        if (root.sizeMode === "1x1") {
            return dy > root.heightToggleDelta ? "2x2" : "1x2"
        }
        if (dy > root.heightToggleDelta) return "2x2"
        if (dy < -root.heightToggleDelta) return "1x2"
        return root.sizeMode 
    }

    property int monthShift: 0
    readonly property var today: new Date()

    property var viewingDate: {
        let d = new Date()
        d.setDate(1)
        d.setMonth(d.getMonth() + monthShift)
        return d
    }

    /** Clave local YYYY-MM-DD, la misma forma que usa el servicio Calendars. */
    function dateKey(d) {
        const month = String(d.getMonth() + 1).padStart(2, "0")
        const day = String(d.getDate()).padStart(2, "0")
        return `${d.getFullYear()}-${month}-${day}`
    }
    readonly property string todayKey: root.dateKey(root.today)
    readonly property var todayEvents: Calendars.eventsOn(root.todayKey)

    /**
     * Al moverse de mes hay que asegurarse de que Calendars ya tenga esos
     * eventos. `ensureWindow` no pide nada si la ventana actual ya los cubría,
     * así que se puede llamar sin miedo en cada cambio (ver CalendarWidget del
     * sidebar, que usa el mismo patrón).
     */
    function syncEventWindow() {
        if (!Calendars.enabled) return;
        const first = new Date(root.viewingDate.getFullYear(), root.viewingDate.getMonth() - 1, 1);
        const last = new Date(root.viewingDate.getFullYear(), root.viewingDate.getMonth() + 2, 1);
        Calendars.ensureWindow(first, last);
    }
    onMonthShiftChanged: root.syncEventWindow()
    Component.onCompleted: root.syncEventWindow()

    function getMonthMatrix(date) {
        const year  = date.getFullYear()
        const month = date.getMonth()
        const firstOfMonth   = new Date(year, month, 1)
        const startOffset    = (firstOfMonth.getDay() + 6) % 7
        const daysInMonth    = new Date(year, month + 1, 0).getDate()
        const daysInPrevMonth = new Date(year, month, 0).getDate()

        let cells = []
        for (let i = 0; i < startOffset; i++) {
            const d = daysInPrevMonth - startOffset + i + 1
            cells.push({ day: d, currentMonth: false, isToday: false, dateKey: root.dateKey(new Date(year, month - 1, d)) })
        }

        for (let d = 1; d <= daysInMonth; d++) {
            const isToday = monthShift === 0
                && d === today.getDate()
                && month === today.getMonth()
                && year  === today.getFullYear()
            cells.push({ day: d, currentMonth: true, isToday: isToday, dateKey: root.dateKey(new Date(year, month, d)) })
        }

        let nextDay = 1
        while (cells.length < 42) {
            cells.push({ day: nextDay, currentMonth: false, isToday: false, dateKey: root.dateKey(new Date(year, month + 1, nextDay)) })
            nextDay++
        }

        let weeks = []
        for (let i = 0; i < cells.length; i += 7)
            weeks.push(cells.slice(i, i + 7))
        return weeks
    }

    function getCurrentWeek() {
        const matrix = getMonthMatrix(viewingDate)
        for (let w = 0; w < matrix.length; w++) {
            if (matrix[w].some(c => c.isToday)) return matrix[w]
        }
        return matrix[0]
    }

    property var weeks: getMonthMatrix(viewingDate)

    implicitWidth:  card.implicitWidth
    implicitHeight: card.implicitHeight

    Behavior on widgetWidth {
        animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
    }

    component DayCell: Rectangle {
        id: dayCell
        property int day: 0
        property bool currentMonth: true
        property bool isToday: false
        property bool bold: false
        // Clave YYYY-MM-DD de este día; vacía = no se puede consultar Calendars.
        property string dateKey: ""
        readonly property var dayEvents: dayCell.dateKey.length > 0 ? Calendars.eventsOn(dayCell.dateKey) : []
        readonly property int eventCount: dayCell.dayEvents.length
        readonly property color dotColor: {
            const own = dayCell.dayEvents[0]?.color ?? "";
            return own.length > 0 ? own : Appearance.colors.colPrimary;
        }

        implicitWidth: 28
        implicitHeight: 28
        radius: 14
        color: isToday ? Appearance.colors.colPrimary : "transparent"

        StyledText {
            anchors.centerIn: parent
            text: parent.day
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: parent.bold || parent.isToday ? Font.Bold : Font.Normal
            color: parent.isToday
                ? Appearance.colors.colOnPrimary
                : Appearance.colors.colOnLayer0
            opacity: parent.currentMonth ? 1.0 : 0.3
        }

        // Un punto por evento, hasta tres, igual que en el calendario del sidebar.
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 3
            spacing: 2
            visible: dayCell.eventCount > 0

            Repeater {
                model: Math.min(dayCell.eventCount, 3)
                delegate: Rectangle {
                    width: 3
                    height: 3
                    radius: 1.5
                    color: dayCell.isToday ? Appearance.colors.colOnPrimary : dayCell.dotColor
                    opacity: dayCell.currentMonth ? 1 : 0.45
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: dayCell.eventCount > 0
            cursorShape: dayCell.eventCount > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: Calendars.openDay(dayCell.dateKey)
        }

        // Qué hay ese día, sin gastar espacio de layout.
        StyledToolTip {
            extraVisibleCondition: dayCell.eventCount > 0
            text: dayCell.dayEvents.map(ev => {
                const hora = ev.allDay
                    ? Translation.tr("Todo el día")
                    : ev.start.toLocaleTimeString(Qt.locale(), "HH:mm");
                return `${hora}  ${ev.summary}`;
            }).join("\n") + "\n\n" + Translation.tr("Click para abrirlo en el navegador")
        }
    }

    Rectangle {
        id: card
        implicitWidth: root.widgetWidth
        implicitHeight: root.sizeMode === "1x1" ? root.cardHeight
                      : root.sizeMode === "1x2" ? root.cardHeight
                      : root.cardHeight * 2 + root.cardSpacing
        radius: Appearance.rounding?.verylarge ?? 30
        color: Appearance.colors.colPrimaryContainer

        StyledRectangularShadow {
            target: card
            z: -2
        }

        Loader {
            anchors.fill: parent
            sourceComponent: {
                if (root.sizeMode === "1x1") return oneByOneContent
                if (root.sizeMode === "1x2") return oneByTwoContent
                return twoByTwoContent
            }
        }

        // 1x1
        Component {
            id: oneByOneContent
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: "transparent"

                ColumnLayout {
                    anchors { fill: parent; margins: 0 }
                    spacing: 0

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: parent.height * 0.35
                        color: Appearance.colors.colPrimary
                        topLeftRadius: card.radius
                        topRightRadius: card.radius

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 4
                            StyledText {
                                text: root.today.toLocaleDateString(Qt.locale(), "MMM").toUpperCase()
                                font.pixelSize: Appearance.font.pixelSize.normal
                                font.weight: Font.Bold
                                color: Appearance.colors.colOnPrimary
                            }
                            StyledText {
                                text: root.today.toLocaleDateString(Qt.locale(), "ddd").toUpperCase()
                                font.pixelSize: Appearance.font.pixelSize.normal
                                font.weight: Font.Bold
                                color: Appearance.colors.colOnPrimary
                                opacity: 0.7
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        StyledText {
                            anchors.centerIn: parent
                            text: root.today.getDate()
                            font.pixelSize: 60
                            font.weight: Font.Bold
                            color: Appearance.colors.colOnPrimaryContainer
                        }

                        // Cuántos eventos hay hoy; sin eventos no ocupa nada.
                        StyledText {
                            anchors {
                                horizontalCenter: parent.horizontalCenter
                                bottom: parent.bottom
                                bottomMargin: 8
                            }
                            visible: root.todayEvents.length > 0
                            text: Translation.tr("%1 hoy").arg(root.todayEvents.length)
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.Medium
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.7
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: root.todayEvents.length > 0
                            cursorShape: root.todayEvents.length > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: Calendars.openDay(root.todayKey)
                        }
                    }
                }
            }
        }

        // 1x2
        Component {
            id: oneByTwoContent
            ColumnLayout {
                anchors { fill: parent; margins: 14 }
                spacing: 8

                Rectangle {
                    Layout.leftMargin: 3
                    implicitHeight: 28
                    implicitWidth: monthText.implicitWidth + 20
                    radius: Appearance.rounding.full
                    color: Appearance.colors.colPrimary

                    StyledText {
                        id: monthText
                        anchors.centerIn: parent
                        text: root.today.toLocaleDateString(Qt.locale(), "MMMM yyyy")
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Bold
                        color: Appearance.colors.colOnPrimary
                    }
                }

                Grid {
                    columns: 7
                    rowSpacing: 4
                    columnSpacing: 0
                    Layout.fillWidth: true
                    Layout.topMargin: 4

                    Repeater {
                        model: ["Mo","Tu","We","Th","Fr","Sa","Su"]
                        delegate: Item {
                            implicitWidth: (card.implicitWidth - 28) / 7
                            implicitHeight: 20
                            StyledText {
                                anchors.centerIn: parent
                                text: modelData
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                font.weight: Font.Bold
                                color: Appearance.colors.colOnPrimaryContainer
                                opacity: 0.5
                            }
                        }
                    }

                    Repeater {
                        model: root.getCurrentWeek()
                        delegate: Item {
                            id: weekCell
                            required property var modelData
                            readonly property var cellEvents: Calendars.eventsOn(modelData.dateKey)
                            implicitWidth: (card.implicitWidth - 28) / 7
                            implicitHeight: 28

                            Rectangle {
                                anchors.centerIn: parent
                                width: 28; height: 28
                                radius: 14
                                color: weekCell.modelData.isToday ? Appearance.colors.colPrimary : "transparent"

                                StyledText {
                                    anchors.centerIn: parent
                                    text: weekCell.modelData.day
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    font.weight: weekCell.modelData.isToday ? Font.Bold : Font.Normal
                                    color: weekCell.modelData.isToday
                                        ? Appearance.colors.colOnPrimary
                                        : Appearance.colors.colOnPrimaryContainer
                                    opacity: weekCell.modelData.currentMonth ? 1.0 : 0.3
                                }

                                // Un punto por evento, hasta tres.
                                Row {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 3
                                    spacing: 2
                                    visible: weekCell.cellEvents.length > 0

                                    Repeater {
                                        model: Math.min(weekCell.cellEvents.length, 3)
                                        delegate: Rectangle {
                                            width: 3; height: 3; radius: 1.5
                                            color: weekCell.modelData.isToday
                                                ? Appearance.colors.colOnPrimary
                                                : Appearance.colors.colOnPrimaryContainer
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: weekCell.cellEvents.length > 0
                                cursorShape: weekCell.cellEvents.length > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: Calendars.openDay(weekCell.modelData.dateKey)
                            }

                            StyledToolTip {
                                extraVisibleCondition: weekCell.cellEvents.length > 0
                                text: weekCell.cellEvents.map(ev => {
                                    const hora = ev.allDay
                                        ? Translation.tr("Todo el día")
                                        : ev.start.toLocaleTimeString(Qt.locale(), "HH:mm");
                                    return `${hora}  ${ev.summary}`;
                                }).join("\n") + "\n\n" + Translation.tr("Click para abrirlo en el navegador")
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }

        // 2x2
        Component {
            id: twoByTwoContent
            ColumnLayout {
                anchors { fill: parent; margins: 16 }
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    StyledText {
                        Layout.fillWidth: true
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnPrimaryContainer
                        text: root.viewingDate.toLocaleDateString(Qt.locale(), "MMMM yyyy")

                        MouseArea {
                            anchors.fill: parent
                            visible: root.monthShift !== 0
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.monthShift = 0
                        }
                    }

                    // Año anterior/siguiente, de a 12 meses -- para no tener que
                    // apretar la flecha de mes 12 veces para moverte de año.
                    Rectangle {
                        implicitWidth: 26; implicitHeight: 26; radius: 13
                        color: "transparent"
                        border.width: 1
                        border.color: Appearance.colors.colPrimary
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "keyboard_double_arrow_left"
                            iconSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnPrimaryContainer
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.monthShift -= 12
                        }
                    }

                    Rectangle {
                        implicitWidth: 26; implicitHeight: 26; radius: 13
                        color: "transparent"
                        border.width: 1
                        border.color: Appearance.colors.colPrimary
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "chevron_left"
                            iconSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colOnPrimaryContainer
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.monthShift--
                        }
                    }

                    Rectangle {
                        implicitWidth: 26; implicitHeight: 26; radius: 13
                        color: "transparent"
                        border.width: 1
                        border.color: Appearance.colors.colPrimary
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "chevron_right"
                            iconSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colOnPrimaryContainer
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.monthShift++
                        }
                    }

                    Rectangle {
                        implicitWidth: 26; implicitHeight: 26; radius: 13
                        color: "transparent"
                        border.width: 1
                        border.color: Appearance.colors.colPrimary
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "keyboard_double_arrow_right"
                            iconSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnPrimaryContainer
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.monthShift += 12
                        }
                    }
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 4
                    Repeater {
                        model: ["Mo","Tu","We","Th","Fr","Sa","Su"]
                        delegate: StyledText {
                            Layout.preferredWidth: 28
                            horizontalAlignment: Text.AlignHCenter
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.Bold
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.6
                            text: modelData
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: ColorUtils.transparentize(Appearance.colors.colLayer0, 0.8)
                    radius: (Appearance.rounding?.verylarge ?? 30) - 8

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: -3

                        Repeater {
                            model: root.weeks
                            delegate: RowLayout {
                                required property var modelData
                                spacing: 4
                                Repeater {
                                    model: parent.modelData
                                    delegate: DayCell {
                                        required property var modelData
                                        day: modelData.day
                                        currentMonth: modelData.currentMonth
                                        isToday: modelData.isToday
                                        dateKey: modelData.dateKey
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        ResizeHandler {
            anchorItem: card
            hoverActive: root.containsMouse
            locked: Config.options.background.widgetsLocked
            currentWidth: root.widgetWidth
            resizeMode: "diagonal"
            onResizedXY: (dx, dy, startWidth) => { root.sizeMode = root.modeForDrag(dx, dy, startWidth) }
            onResizeFinished: {
                root.writeOverride("sizeMode", root.sizeMode)
            }
        }
    }
}
