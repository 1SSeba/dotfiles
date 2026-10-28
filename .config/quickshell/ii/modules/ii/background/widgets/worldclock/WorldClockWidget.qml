import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.common.widgets.widgetCanvas
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root
    configEntryName: "worldClock"
    hoverEnabled: true

    property string sizeMode: root.configEntry.sizeMode ?? "2x2"

    // Estirar como las notas: la tarjeta sigue al mouse y el contenido pasa
    // al modo más cercano (ver ElasticResize).
    ElasticResize {
        id: elastic
        widget: root
        mode: root.sizeMode
        modes: [
            { "mode": "2x2", "width": 276, "height": 252 },
            { "mode": "4x1", "width": 420, "height": 120 }
        ]
    }

    property real widgetWidth:  elastic.resizing ? elastic.dragWidth : elastic.current.width
    property real widgetHeight: elastic.resizing ? elastic.dragHeight : elastic.current.height

    // Siguiendo al mouse, sin animar; al soltar, se acomoda al tamaño del modo.
    Behavior on widgetWidth {
        enabled: !elastic.resizing
        animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
    }
    Behavior on widgetHeight {
        enabled: !elastic.resizing
        animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
    }

    // Los dos modos se muestran con visible, no con un Loader: el que entra
    // aparece con un fundido, como en los widgets que usan ModeLoader.
    onSizeModeChanged: modeFade.restart()
    NumberAnimation {
        id: modeFade
        targets: [mainColumn, wideRow]
        property: "opacity"
        from: 0; to: 1
        duration: Appearance.animation.elementMoveFast.duration
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
    }

    implicitWidth:  widgetWidth
    implicitHeight: widgetHeight

    property string localCityName: Weather.data?.city ?? "..."
    property string localTime: DateTime.time
    property string localDate: Qt.locale().toString(new Date(), "dddd, MMMM dd yyyy")
    property var worldCities: WorldClock.entries
    property bool showingSettings: false

    onShowingSettingsChanged: GlobalStates.desktopWidgetKeyboardFocus = showingSettings

    function toggleFlip() { flipAnim.start() }

    Item {
        id: cardWrapper
        anchors.fill: parent

        transform: Scale {
            id: flipScale
            origin.x: cardWrapper.width  / 2
            origin.y: cardWrapper.height / 2
            xScale: 1
        }

        SequentialAnimation {
            id: flipAnim
            NumberAnimation {
                target: flipScale; property: "xScale"
                to: 0; duration: 150; easing.type: Easing.InQuad
            }
            ScriptAction {
                script: root.showingSettings = !root.showingSettings
            }
            NumberAnimation {
                target: flipScale; property: "xScale"
                to: 1; duration: 150; easing.type: Easing.OutQuad
            }
        }

        StyledDropShadow { 
            target: contentRect 
            visible: sizeMode !== "4x1"
        }

        Rectangle {
            id: contentRect
            anchors.fill: parent
            color: sizeMode === "4x1" ? "transparent" : Appearance.colors.colPrimaryContainer
            radius: Appearance.rounding?.verylarge ?? 30

            // Los tres contenidos (2x2, ajustes, 4x1) se arman en el tamaño de su
            // modo y se escalan para entrar en la tarjeta mientras se estira, como
            // hace ModeLoader en los otros widgets: si no, se salían por los costados.
            Item {
                id: modeContent
                anchors.centerIn: parent
                width: elastic.current.width
                height: elastic.current.height
                scale: Math.min(1, contentRect.width / width, contentRect.height / height)

                // 2x2
                ColumnLayout {
                    id: mainColumn
                    anchors { fill: parent; margins: 12 }
                    spacing: 10
                    visible: sizeMode === "2x2" && !root.showingSettings

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        MaterialSymbol {
                            iconSize: Appearance.font.pixelSize.hugeass
                            text: "location_on"
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.6
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: -2
                            StyledText {
                                Layout.fillWidth: true
                                font.pixelSize: Appearance.font.pixelSize.normal
                                font.weight: Font.Medium
                                color: Appearance.colors.colOnPrimaryContainer
                                text: root.localCityName
                                elide: Text.ElideRight
                            }
                        }
                        Item { Layout.fillWidth: true }
                        Rectangle {
                            radius: Appearance.rounding.full
                            color: ColorUtils.transparentize(Appearance.colors.colLayer0, 0.8)
                            implicitWidth: 28; implicitHeight: 28
                            MaterialSymbol {
                                anchors.centerIn: parent
                                iconSize: Appearance.font.pixelSize.normal
                                text: "settings"
                                color: Appearance.colors.colOnSurfaceVariant
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.toggleFlip()
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignRight
                        spacing: -4
                        StyledText {
                            Layout.alignment: Qt.AlignRight
                            font.pixelSize: 42; font.weight: Font.Bold
                            font.features: { "tnum": 1 }
                            color: Appearance.colors.colOnPrimaryContainer
                            text: root.localTime
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignRight
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.7
                            text: root.localDate
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignHCenter
                        columns: 2; rowSpacing: 6; columnSpacing: 6

                        Repeater {
                            model: root.worldCities
                            delegate: Rectangle {
                                id: cityCard
                                required property var modelData
                                required property int index
                                Layout.preferredWidth: 120; Layout.preferredHeight: 54
                                radius: Appearance.rounding.normal
                                color: modelData.isDay
                                    ? Appearance.colors.colPrimary
                                    : ColorUtils.transparentize(Appearance.colors.colLayer0, 0.8)
                                property color fg: modelData.isDay
                                    ? Appearance.colors.colOnPrimary
                                    : Appearance.colors.colOnLayer0
                                Behavior on color { ColorAnimation { duration: 400 } }

                                ColumnLayout {
                                    anchors { fill: parent; margins: 8 }
                                    spacing: 2
                                    RowLayout {
                                        Layout.fillWidth: true
                                        StyledText {
                                            Layout.fillWidth: true
                                            font.pixelSize: Appearance.font.pixelSize.smaller
                                            font.weight: Font.Medium
                                            color: cityCard.fg
                                            text: cityCard.modelData.name
                                            elide: Text.ElideRight
                                        }
                                        StyledText {
                                            font.pixelSize: Appearance.font.pixelSize.smallest
                                            color: cityCard.fg; opacity: 0.6
                                            text: cityCard.modelData.offset
                                        }
                                    }
                                    RowLayout {
                                        Layout.fillWidth: true; spacing: 4
                                        StyledText {
                                            font.pixelSize: Appearance.font.pixelSize.normal
                                            font.weight: Font.Bold
                                            font.features: { "tnum": 1 }
                                            color: cityCard.fg
                                            text: cityCard.modelData.time
                                        }
                                        Item { Layout.fillWidth: true }
                                        MaterialSymbol {
                                            iconSize: Appearance.font.pixelSize.smaller
                                            text: cityCard.modelData.isDay ? "wb_sunny" : "bedtime"
                                            color: cityCard.fg
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Item {
                    anchors.fill: parent
                    visible: sizeMode === "2x2" && root.showingSettings

                    ColumnLayout {
                        anchors { fill: parent; margins: 12 }
                        spacing: 10

                        RowLayout {
                            Layout.fillWidth: true; spacing: 8
                            Rectangle {
                                radius: Appearance.rounding.full
                                color: "transparent"
                                implicitWidth: 28; implicitHeight: 28
                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    iconSize: Appearance.font.pixelSize.normal
                                    text: "arrow_back"
                                    color: Appearance.colors.colOnSurfaceVariant
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.toggleFlip()
                                }
                            }
                            Item { Layout.fillWidth: true }
                        }

                        StyledComboBoxSearch {
                            model: WorldClock.comboModel
                            colBackground: ColorUtils.transparentize(Appearance.colors.colLayer0, 0.8)
                            textRole: "label"
                            currentIndex: WorldClock.comboModel.findIndex(m => m.tz === WorldClock.timezones[0])
                            onActivated: (idx) => WorldClock.setTimezone(0, WorldClock.comboModel[idx].tz)
                        }
                        StyledComboBoxSearch {
                            model: WorldClock.comboModel; textRole: "label"
                            colBackground: ColorUtils.transparentize(Appearance.colors.colLayer0, 0.8)
                            currentIndex: WorldClock.comboModel.findIndex(m => m.tz === WorldClock.timezones[1])
                            onActivated: (idx) => WorldClock.setTimezone(1, WorldClock.comboModel[idx].tz)
                        }
                        StyledComboBoxSearch {
                            model: WorldClock.comboModel; textRole: "label"
                            colBackground: ColorUtils.transparentize(Appearance.colors.colLayer0, 0.8)
                            currentIndex: WorldClock.comboModel.findIndex(m => m.tz === WorldClock.timezones[2])
                            onActivated: (idx) => WorldClock.setTimezone(2, WorldClock.comboModel[idx].tz)
                        }
                        StyledComboBoxSearch {
                            model: WorldClock.comboModel; textRole: "label"
                            colBackground: ColorUtils.transparentize(Appearance.colors.colLayer0, 0.8)
                            currentIndex: WorldClock.comboModel.findIndex(m => m.tz === WorldClock.timezones[3])
                            onActivated: (idx) => WorldClock.setTimezone(3, WorldClock.comboModel[idx].tz)
                        }
                    }
                }

                // 4x1
                RowLayout {
                    id: wideRow
                    anchors { fill: parent; margins: 0 }
                    spacing: 12
                    visible: sizeMode === "4x1"

                    Repeater {
                        model: Math.min(root.worldCities.length, 4)
                        delegate: AndroidClock {
                            required property int index
                            property var cityData: root.worldCities[index] ?? null

                            Layout.fillHeight: true
                            Layout.fillWidth:  true

                            backgroundColor: cityData?.isDay ?? true
                                ? Appearance.colors.colPrimary
                                : Appearance.colors.colPrimaryContainer
                            handColor: cityData?.isDay ?? true
                                ? Appearance.colors.colOnPrimary
                                : Appearance.colors.colOnLayer0
                            centerDotColor: cityData?.isDay ?? true
                                ? Appearance.colors.colOnPrimary
                                : Appearance.colors.colOnLayer0
                            label:       cityData?.name ?? ""
                            labelColor:  Qt.rgba(
                                (cityData?.isDay ?? true ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer0).r,
                                (cityData?.isDay ?? true ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer0).g,
                                (cityData?.isDay ?? true ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer0).b,
                                0.75)
                            labelSpacing: 6
                            autoTime:    false
                            hourAngle: {
                                if (!cityData?.time) return 0
                                const p = cityData.time.split(":")
                                return (parseInt(p[0]) % 12) * 30 + parseInt(p[1]) * 0.5
                            }
                            minuteAngle: {
                                if (!cityData?.time) return 0
                                const p = cityData.time.split(":")
                                return parseInt(p[1]) * 6
                            }
                        }
                    }
                }
            }

            ResizeHandler {
                anchorItem: contentRect
                hoverActive: root.containsMouse
                locked: Config.options.background.widgetsLocked || root.showingSettings
                currentWidth: root.widgetWidth
                resizeMode: "diagonal"
                onResizedXY: (dx, dy, startWidth) => { root.sizeMode = elastic.update(dx, dy, startWidth) }
                onResizeFinished: {
                    elastic.finish()
                    root.configEntry.sizeMode = root.sizeMode
                }
            }
        }
    }
}

