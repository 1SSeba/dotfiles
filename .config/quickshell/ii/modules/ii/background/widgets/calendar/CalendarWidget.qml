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

    property string sizeMode: root.configEntry.sizeMode ?? "2x2"

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

    // Misma clave que usa Calendars.eventsByDate (services/Calendars.qml):
    // YYYY-MM-DD en hora local. A mano y no con toISOString() porque ese
    // convierte a UTC y corre el día (ver calendar_layout.js).
    function localDateKey(d) {
        const month = String(d.getMonth() + 1).padStart(2, '0')
        const day = String(d.getDate()).padStart(2, '0')
        return d.getFullYear() + '-' + month + '-' + day
    }

    function getMonthMatrix(date) {
        const year  = date.getFullYear()
        const month = date.getMonth()
        const firstOfMonth   = new Date(year, month, 1)
        const startOffset    = (firstOfMonth.getDay() + 6) % 7
        const daysInMonth    = new Date(year, month + 1, 0).getDate()

        let cells = []
        // El día 0 (y negativos) de un mes es el último (y anteriores) del
        // mes de antes: Date los normaliza solo, no hace falta calcular
        // cuántos días tenía el mes anterior a mano.
        for (let i = startOffset; i > 0; i--) {
            const d = new Date(year, month, 1 - i, 12)
            cells.push({ day: d.getDate(), currentMonth: false, isToday: false, dateKey: root.localDateKey(d) })
        }

        for (let day = 1; day <= daysInMonth; day++) {
            const d = new Date(year, month, day, 12)
            const isToday = monthShift === 0
                && day === today.getDate()
                && month === today.getMonth()
                && year  === today.getFullYear()
            cells.push({ day: day, currentMonth: true, isToday: isToday, dateKey: root.localDateKey(d) })
        }

        let nextDay = 1
        while (cells.length < 42) {
            const d = new Date(year, month + 1, nextDay, 12)
            cells.push({ day: d.getDate(), currentMonth: false, isToday: false, dateKey: root.localDateKey(d) })
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

    // Nombres cortos ("ene", "feb"...) para que entren en la grilla del
    // selector; con el nombre completo no cabían tres por fila.
    readonly property var monthNames: {
        let names = []
        for (let m = 0; m < 12; m++) names.push(Qt.locale().monthName(m, Locale.ShortFormat))
        return names
    }

    // Salta directo a un mes/año en vez de ir de a uno con las flechas.
    function goToMonth(year, month) {
        const t = new Date()
        root.monthShift = (year - t.getFullYear()) * 12 + (month - t.getMonth())
    }

    property bool showMonthYearPicker: false
    property int pickerYear: today.getFullYear()

    function openMonthYearPicker() {
        root.pickerYear = root.viewingDate.getFullYear()
        root.showMonthYearPicker = true
    }

    // Los widgets del escritorio pueden desbloquearse en cualquier momento
    // (para reacomodarlos); si eso pasa con el selector abierto, mejor
    // cerrarlo que dejarlo compitiendo con el arrastre del widget.
    readonly property bool widgetsLocked: Config.options.background.widgetsLocked
    onWidgetsLockedChanged: if (!widgetsLocked) root.showMonthYearPicker = false

    /**
     * Al cambiar de mes hay que asegurarse de que Calendars ya tenga esos
     * eventos. `ensureWindow` no pide nada si la ventana actual ya los
     * cubría, así que se puede llamar sin miedo en cada cambio.
     */
    function syncEventWindow() {
        if (!Calendars.enabled) return
        const first = new Date(root.viewingDate.getFullYear(), root.viewingDate.getMonth() - 1, 1)
        const last = new Date(root.viewingDate.getFullYear(), root.viewingDate.getMonth() + 2, 1)
        Calendars.ensureWindow(first, last)
    }
    onViewingDateChanged: root.syncEventWindow()
    Component.onCompleted: root.syncEventWindow()

    implicitWidth:  card.implicitWidth
    implicitHeight: card.implicitHeight

    Behavior on widgetWidth {
        animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
    }

    component DayCell: Rectangle {
        id: cell
        property int day: 0
        property bool currentMonth: true
        property bool isToday: false
        property bool bold: false
        property string dateKey: ""
        property var events: []
        readonly property int eventCount: cell.events?.length ?? 0

        implicitWidth: 28
        implicitHeight: 28
        radius: 14
        color: isToday ? Appearance.colors.colPrimary : "transparent"

        StyledText {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: cell.eventCount > 0 ? -3 : 0
            text: cell.day
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: cell.bold || cell.isToday ? Font.Bold : Font.Normal
            color: cell.isToday
                ? Appearance.colors.colOnPrimary
                : Appearance.colors.colOnLayer0
            opacity: cell.currentMonth ? 1.0 : 0.3
        }

        // Un punto por evento, hasta tres. Igual que en el calendario del
        // sidebar (CalendarDayButton): más que eso no se distingue.
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 4
            spacing: 2
            visible: cell.eventCount > 0

            Repeater {
                model: Math.min(cell.eventCount, 3)
                delegate: Rectangle {
                    width: 3; height: 3; radius: 1.5
                    color: cell.isToday
                        ? Appearance.colors.colOnPrimary
                        : (cell.events[index]?.color || Appearance.colors.colPrimary)
                    opacity: cell.currentMonth ? 1.0 : 0.3
                }
            }
        }

        // Igual que en el sidebar: un día con eventos se abre en el
        // calendario web de un clic. Deshabilitado desbloqueado para no
        // pisar el arrastre del widget.
        MouseArea {
            anchors.fill: parent
            enabled: cell.eventCount > 0 && Config.options.background.widgetsLocked
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: Calendars.openDay(cell.dateKey)
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

        // Selector de mes/año. Se dibuja acá arriba (no adentro de
        // twoByTwoContent) para que quede por encima de todo el contenido, y
        // a propósito NO usa QtQuick.Controls.Popup: en esta ventana de fondo
        // (capa "background" de wlr-layer-shell) los popups de Controls no
        // son confiables — por eso los demás popups de la shell (ver
        // StyledPopupMenu) tiran su propia PanelWindow en vez de un Popup.
        // Acá alcanza con un Rectangle más, tapando la grilla mientras está
        // abierto.
        Rectangle {
            id: monthYearFlyout
            anchors.fill: parent
            z: 10
            radius: card.radius
            color: Appearance.colors.colPrimaryContainer
            visible: root.showMonthYearPicker && root.sizeMode === "2x2"

            // Que un clic "atraviese" hacia la grilla de abajo mientras el
            // selector está abierto sería peor que no tener selector.
            MouseArea { anchors.fill: parent }

            ColumnLayout {
                anchors { fill: parent; margins: 16 }
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

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
                            onClicked: root.pickerYear--
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        font.pixelSize: Appearance.font.pixelSize.large
                        font.weight: Font.Bold
                        color: Appearance.colors.colOnPrimaryContainer
                        text: root.pickerYear
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
                            onClicked: root.pickerYear++
                        }
                    }

                    Rectangle {
                        implicitWidth: 26; implicitHeight: 26; radius: 13
                        color: "transparent"
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "close"
                            iconSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colOnPrimaryContainer
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.showMonthYearPicker = false
                        }
                    }
                }

                Grid {
                    id: monthGrid
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    columns: 3
                    rowSpacing: 6
                    columnSpacing: 6

                    Repeater {
                        model: root.monthNames
                        delegate: Rectangle {
                            id: monthCell
                            required property string modelData
                            required property int index
                            readonly property bool selected: index === root.viewingDate.getMonth()
                                && root.pickerYear === root.viewingDate.getFullYear()

                            width: (monthGrid.width - monthGrid.columnSpacing * 2) / 3
                            height: 30
                            radius: Appearance.rounding.small
                            color: monthCell.selected
                                ? Appearance.colors.colPrimary
                                : ColorUtils.transparentize(Appearance.colors.colLayer0, 0.8)

                            StyledText {
                                anchors.centerIn: parent
                                text: monthCell.modelData
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: monthCell.selected
                                    ? Appearance.colors.colOnPrimary
                                    : Appearance.colors.colOnPrimaryContainer
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.goToMonth(root.pickerYear, monthCell.index)
                                    root.showMonthYearPicker = false
                                }
                            }
                        }
                    }
                }
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
                            required property var modelData
                            implicitWidth: (card.implicitWidth - 28) / 7
                            implicitHeight: 28

                            Rectangle {
                                id: weekDayCell
                                anchors.centerIn: parent
                                width: 28; height: 28
                                radius: 14
                                color: modelData.isToday ? Appearance.colors.colPrimary : "transparent"

                                readonly property int eventCount: (Calendars.eventsByDate[modelData.dateKey] ?? []).length

                                StyledText {
                                    anchors.centerIn: parent
                                    anchors.verticalCenterOffset: weekDayCell.eventCount > 0 ? -2 : 0
                                    text: modelData.day
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    font.weight: modelData.isToday ? Font.Bold : Font.Normal
                                    color: modelData.isToday
                                        ? Appearance.colors.colOnPrimary
                                        : Appearance.colors.colOnPrimaryContainer
                                    opacity: modelData.currentMonth ? 1.0 : 0.3
                                }

                                Rectangle {
                                    visible: weekDayCell.eventCount > 0
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 4
                                    width: 3; height: 3; radius: 1.5
                                    color: modelData.isToday
                                        ? Appearance.colors.colOnPrimary
                                        : Appearance.colors.colPrimary
                                    opacity: modelData.currentMonth ? 1.0 : 0.3
                                }
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

                    // El texto + flecha son un solo botón que abre el selector de
                    // mes/año. Se deshabilita mientras los widgets están
                    // desbloqueados: si no, arrastrar el widget desde acá termina
                    // abriendo el selector en vez de moverlo.
                    Item {
                        id: monthYearButton
                        Layout.fillWidth: true
                        implicitWidth: monthYearRow.implicitWidth
                        implicitHeight: monthYearRow.implicitHeight
                        opacity: monthYearArea.enabled ? 1 : 0.4

                        RowLayout {
                            id: monthYearRow
                            spacing: 2
                            StyledText {
                                font.pixelSize: Appearance.font.pixelSize.normal
                                font.weight: Font.Medium
                                color: Appearance.colors.colOnPrimaryContainer
                                text: root.viewingDate.toLocaleDateString(Qt.locale(), "MMMM yyyy")
                            }
                            MaterialSymbol {
                                text: "arrow_drop_down"
                                iconSize: Appearance.font.pixelSize.large
                                color: Appearance.colors.colOnPrimaryContainer
                            }
                        }

                        MouseArea {
                            id: monthYearArea
                            anchors.fill: parent
                            enabled: Config.options.background.widgetsLocked
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.openMonthYearPicker()
                        }
                    }

                    Rectangle {
                        implicitWidth: 26; implicitHeight: 26; radius: 13
                        color: "transparent"
                        border.width: 1
                        border.color: Appearance.colors.colPrimary
                        enabled: Config.options.background.widgetsLocked
                        opacity: enabled ? 1 : 0.4
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
                        enabled: Config.options.background.widgetsLocked
                        opacity: enabled ? 1 : 0.4
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
                                        // eventsByDate cambia entero al refrescar, así que
                                        // este binding se re-evalúa solo cuando llegan
                                        // eventos nuevos.
                                        events: Calendars.eventsByDate[modelData.dateKey] ?? []
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
                root.configEntry.sizeMode = root.sizeMode
            }
        }
    }
}
