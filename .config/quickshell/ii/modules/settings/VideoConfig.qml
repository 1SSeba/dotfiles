import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.models.hyprland

ContentPage {
    id: page
    forceWidth: true

    MonitorConfigOption { id: monitorConfig }

    property int customResWidth: 1440
    property int customResHeight: 1080
    property int customResHz: 144
    property bool showCustomResForm: false

    // `parent: page` a propósito: ContentPage aliasea su default property a
    // contentColumn.data (ver ContentPage.qml), así que cualquier hijo
    // declarado normal acá adentro cae DENTRO del ColumnLayout y se lo
    // maneja como una fila más. Este modal necesita cubrir toda la página
    // (scrim + tarjeta centrada, mismo patrón que AiAddModelForm.qml/
    // AiNewChatDialog.qml en el sidebar de IA), no ser una fila del layout —
    // reasignar el parent lo saca de ese circuito y lo deja como hijo directo
    // del Flickable, con anchors.fill llenando el viewport real de la página.
    Loader {
        parent: page
        // No anchors.fill: page acá — al momento en que esta línea se evalúa
        // durante la construcción del objeto, el reparent (arriba) todavía no
        // se aplicó de verdad en el árbol de escena, y Qt tira "Cannot anchor
        // to an item that isn't a parent or sibling". width/height binder no
        // tiene ese requisito (no depende de la relación padre-hijo ya
        // establecida, solo lee una propiedad de otro objeto).
        width: page.width
        height: page.height
        z: 9999
        active: page.showCustomResForm
        visible: page.showCustomResForm

        sourceComponent: CustomResolutionDialog {
            widthValue: page.customResWidth
            heightValue: page.customResHeight
            hzValue: page.customResHz
            monitorName: monitorConfig.monitors[monitorCanvas.selectedIndex]?.name ?? ""
            customModes: monitorConfig.customModesFor(monitorConfig.monitors[monitorCanvas.selectedIndex]?.name ?? "")
            // Borrar no cierra el modal (querés poder limpiar varias de una) y
            // no destruye nada que esté manejando el click, así que va directo.
            onRemoveRequested: value => monitorConfig.removeCustomMode(
                monitorConfig.monitors[monitorCanvas.selectedIndex]?.name ?? "", value)
            onClosed: Qt.callLater(() => page.showCustomResForm = false)
            onApplyRequested: (width, height, hz) => {
                page.customResWidth = width
                page.customResHeight = height
                page.customResHz = hz
                monitorConfig.applyCustomMode(monitorCanvas.selectedIndex, width, height, hz)
                // Qt.callLater: este Loader.active=false destruye la propia
                // jerarquía de MouseArea que todavía procesa el click que
                // llegó hasta acá (ver el mismo fix en AiChat.qml — borrar el
                // "agarre" del mouse en pleno manejo de su propio evento deja
                // colgado el grab de la ventana).
                Qt.callLater(() => page.showCustomResForm = false)
            }
            onRestoreRequested: {
                monitorConfig.restoreNativeMode(monitorCanvas.selectedIndex)
                Qt.callLater(() => page.showCustomResForm = false)
            }
        }
    }

    // Declarado inline (como AiChat.qml hace con StatusItem, o
    // SidebarRightContent.qml con ToggleDialog) en vez de un .qml aparte:
    // esta página se carga dinámicamente por path de archivo (ver
    // settings.qml), y ese mecanismo no resuelve tipos hermanos del mismo
    // directorio ("VideoCustomResolutionDialog is not a type" al probarlo).
    //
    // Mismo patrón visual que AiAddModelForm.qml / AiNewChatDialog.qml en el
    // sidebar de IA: scrim + tarjeta centrada.
    component CustomResolutionDialog: Item {
        id: dialogRoot

        property int widthValue: 1440
        property int heightValue: 1080
        property real hzValue: 144
        property string monitorName: ""
        property var customModes: []

        signal applyRequested(int width, int height, real hz)
        signal restoreRequested()
        signal removeRequested(string value)
        signal closed()

        Rectangle { // Scrim
            anchors.fill: parent
            color: Appearance.colors.colScrim

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                preventStealing: true
                onClicked: dialogRoot.closed()
            }
        }

        Rectangle { // La tarjeta
            id: card
            anchors.centerIn: parent
            width: Math.min(parent.width - 32, 360)
            height: Math.min(parent.height - 32, cardColumn.implicitHeight + 32)
            radius: Appearance.rounding.normal
            color: Appearance.m3colors.m3surfaceContainerHigh
            clip: true

            // Que un click adentro de la tarjeta no se propague al scrim y la cierre
            MouseArea {
                anchors.fill: parent
            }

            Flickable {
                anchors.fill: parent
                anchors.margins: 16
                contentWidth: width
                contentHeight: cardColumn.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: cardColumn
                    width: parent.width
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        MaterialSymbol {
                            text: "add_box"
                            iconSize: Appearance.font.pixelSize.larger
                            color: Appearance.m3colors.m3onSurface
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("Custom resolution")
                            font.pixelSize: Appearance.font.pixelSize.larger
                            color: Appearance.m3colors.m3onSurface
                        }
                        RippleButton {
                            implicitWidth: 26
                            implicitHeight: 26
                            buttonRadius: Appearance.rounding.small
                            contentItem: MaterialSymbol {
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                text: "close"
                                iconSize: Appearance.font.pixelSize.normal
                                color: Appearance.m3colors.m3onSurface
                            }
                            onClicked: dialogRoot.closed()
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        color: Appearance.colors.colSubtext
                        font.pixelSize: Appearance.font.pixelSize.smallie
                        text: Translation.tr("Not advertised by the monitor's EDID, so Hyprland may reject it on some drivers (notably proprietary Nvidia). Once created it stays in the resolution list; applying from here is live-only until you pick it from that list.")
                    }

                    // Las que ya creaste para este monitor. Sin esto, una
                    // resolución mal tipeada se quedaba para siempre en la lista
                    // sin forma de sacarla.
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 2
                        spacing: 4
                        visible: dialogRoot.customModes.length > 0

                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("Saved for %1").arg(dialogRoot.monitorName)
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                        }

                        Repeater {
                            model: dialogRoot.customModes

                            delegate: Rectangle {
                                id: savedModeRow
                                required property string modelData

                                Layout.fillWidth: true
                                implicitHeight: 30
                                radius: Appearance.rounding.small
                                color: Appearance.colors.colLayer1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 4
                                    spacing: 6

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: savedModeRow.modelData
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        color: Appearance.colors.colOnLayer2
                                        elide: Text.ElideRight
                                    }

                                    RippleButton {
                                        implicitWidth: 24
                                        implicitHeight: 24
                                        buttonRadius: Appearance.rounding.small
                                        onClicked: dialogRoot.removeRequested(savedModeRow.modelData)
                                        contentItem: MaterialSymbol {
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                            text: "delete"
                                            iconSize: Appearance.font.pixelSize.normal
                                            color: Appearance.colors.colOnLayer2
                                        }
                                    }
                                }
                            }
                        }
                    }

                    ConfigSpinBox {
                        Layout.fillWidth: true
                        icon: "width"
                        text: Translation.tr("Width")
                        value: dialogRoot.widthValue
                        from: 640; to: 7680; stepSize: 10
                        onValueChanged: dialogRoot.widthValue = value
                    }
                    ConfigSpinBox {
                        Layout.fillWidth: true
                        icon: "height"
                        text: Translation.tr("Height")
                        value: dialogRoot.heightValue
                        from: 480; to: 4320; stepSize: 10
                        onValueChanged: dialogRoot.heightValue = value
                    }
                    ConfigSpinBox {
                        Layout.fillWidth: true
                        icon: "speed"
                        text: Translation.tr("Hz")
                        value: dialogRoot.hzValue
                        from: 30; to: 360; stepSize: 1
                        onValueChanged: dialogRoot.hzValue = value
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Layout.topMargin: 2

                        Item { Layout.fillWidth: true }

                        RippleButton {
                            implicitHeight: 30
                            implicitWidth: restoreLabel.implicitWidth + 20
                            buttonRadius: Appearance.rounding.small
                            colBackground: Appearance.colors.colLayer1
                            onClicked: dialogRoot.restoreRequested()
                            contentItem: StyledText {
                                id: restoreLabel
                                text: Translation.tr("Restore native")
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colOnLayer2
                            }
                        }

                        RippleButton {
                            implicitHeight: 30
                            implicitWidth: applyLabel.implicitWidth + 20
                            buttonRadius: Appearance.rounding.small
                            toggled: true
                            onClicked: dialogRoot.applyRequested(dialogRoot.widthValue, dialogRoot.heightValue, dialogRoot.hzValue)
                            contentItem: StyledText {
                                id: applyLabel
                                text: Translation.tr("Apply")
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colOnPrimary
                            }
                        }
                    }
                }
            }
        }
    }

    ContentSection {
        icon: "monitor"
        shape: MaterialShape.Shape.ClamShell
        title: Translation.tr("Displays")
        visible: monitorConfig.monitors.length > 0

        MonitorCanvas {
            id: monitorCanvas
            Layout.fillWidth: true
            monitorConfig: monitorConfig
        }

        ContentSubsection {
            id: monitorCanvasSection
            Layout.topMargin: 10
            readonly property string selectedMonitorName: monitorConfig.monitors[monitorCanvas.selectedIndex]?.name ?? ""
            readonly property string selectedMonitorWallpaper: Wallpapers.effectivePathForMonitor(selectedMonitorName)
            readonly property bool selectedMonitorHasOverride: (Config.options.wallpaperPathByMonitor ?? {})[selectedMonitorName] !== undefined
            title: selectedMonitorName
                + " · "
                + (monitorConfig.monitors[monitorCanvas.selectedIndex]?.description ?? "")

            GroupedList {
                ConfigSwitch {
                    buttonIcon: "tv_off"
                    text: Translation.tr("Enabled")
                    checked: !(monitorConfig.monitors[monitorCanvas.selectedIndex]?.disabled ?? false)
                    onCheckedChanged: {
                        if (checked === !(monitorConfig.monitors[monitorCanvas.selectedIndex]?.disabled ?? false)) return
                        monitorConfig.updateMonitor(monitorCanvas.selectedIndex, { disabled: !checked })
                        monitorConfig.applyAndSave(monitorCanvas.selectedIndex)
                    }
                }


                ConfigComboBox {
                    Layout.fillWidth: true
                    buttonIcon: "aspect_ratio"
                    text: Translation.tr("Resolution & Refresh Rate")
                    textRole: "display"
                    model: monitorConfig.sortedAvailableModes(monitorConfig.monitors[monitorCanvas.selectedIndex])
                    currentValue: monitorConfig.monitors[monitorCanvas.selectedIndex]?.currentMode ?? ""
                    onSelected: newValue => {
                        const mode = newValue
                        const parts = mode.match(/(\d+)x(\d+)@([\d.]+)Hz/)
                        monitorConfig.updateMonitor(monitorCanvas.selectedIndex, {
                            currentMode: mode,
                            width: parseInt(parts[1]),
                            height: parseInt(parts[2]),
                            refreshRate: parseFloat(parts[3])
                        })
                        monitorConfig.applyAndSave(monitorCanvas.selectedIndex)
                    }
                }

                // El driver puede rechazar una combinación resolución+Hz que el
                // EDID no anuncia; MonitorConfigOption reintenta solo con otro Hz
                // y deja acá el resultado, en vez de que el combo cambie sin
                // explicación (ver _verifyPendingMode).
                StyledText {
                    Layout.fillWidth: true
                    Layout.leftMargin: 8
                    Layout.rightMargin: 8
                    visible: monitorConfig.lastModeNotice.length > 0
                    text: monitorConfig.lastModeNotice
                    wrapMode: Text.Wrap
                    font.pixelSize: Appearance.font.pixelSize.smallie
                    color: Appearance.colors.colSubtext
                }

                RippleButtonWithIcon {
                    id: customResButton
                    Layout.fillWidth: false
                    materialIcon: "add_box"
                    mainText: Translation.tr("Create custom resolution")
                    onClicked: page.showCustomResForm = true
                }

                ContentSubsection {
                    title: Translation.tr("Orientation")
                    Layout.fillWidth: true

                    ConfigSelectionArray {
                        currentValue: monitorConfig.monitors[monitorCanvas.selectedIndex]?.transform ?? 0
                        onSelected: newValue => {
                            monitorConfig.updateMonitor(monitorCanvas.selectedIndex, { transform: newValue })
                            monitorConfig.applyAndSave(monitorCanvas.selectedIndex)
                        }
                        options: [
                            { displayName: Translation.tr("Normal"), icon: "screen_rotation_alt", value: 0 },
                            { displayName: "90°",                    icon: "rotate_90_degrees_cw",  value: 1 },
                            { displayName: "180°",                   icon: "screen_rotation",       value: 2 },
                            { displayName: "270°",                   icon: "rotate_90_degrees_ccw", value: 3 },
                        ]
                    }
                }

                ConfigSpinBox {
                    icon: "zoom_in"
                    text: Translation.tr("Scale")
                    value: Math.round((monitorConfig.monitors[monitorCanvas.selectedIndex]?.scale ?? 1.0) * 100)
                    from: 50; to: 300; stepSize: 25
                    onValueChanged: {
                        const newVal = value / 100.0
                        if (newVal === (monitorConfig.monitors[monitorCanvas.selectedIndex]?.scale ?? 1.0)) return
                        monitorConfig.updateMonitor(monitorCanvas.selectedIndex, { scale: newVal })
                        monitorConfig.applyAndSave(monitorCanvas.selectedIndex)
                    }
                }

                ConfigSpinBox {
                    icon: "swap_horiz"
                    text: Translation.tr("Position X")
                    value: monitorConfig.monitors[monitorCanvas.selectedIndex]?.x ?? 0
                    from: 0; to: 7680; stepSize: 1
                    onValueChanged: {
                        if (value === (monitorConfig.monitors[monitorCanvas.selectedIndex]?.x ?? 0)) return
                        monitorConfig.updateMonitor(monitorCanvas.selectedIndex, { x: value })
                        monitorConfig.applyAndSave(monitorCanvas.selectedIndex)
                    }
                }

                ConfigSpinBox {
                    icon: "swap_vert"
                    text: Translation.tr("Position Y")
                    value: monitorConfig.monitors[monitorCanvas.selectedIndex]?.y ?? 0
                    from: 0; to: 4320; stepSize: 1
                    onValueChanged: {
                        if (value === (monitorConfig.monitors[monitorCanvas.selectedIndex]?.y ?? 0)) return
                        monitorConfig.updateMonitor(monitorCanvas.selectedIndex, { y: value })
                        monitorConfig.applyAndSave(monitorCanvas.selectedIndex)
                    }
                }
            }        
        }
    }

    ContentSection {
        icon: "dark_mode"
        title: Translation.tr("Night light")

        // Automático/temperatura ya se editan desde el panel rápido de luz nocturna;
        // el horario del modo automático solo se puede tocar acá.
        ConfigRow {
            uniform: true
            MaterialTextArea {
                Layout.fillWidth: true
                placeholderText: Translation.tr("From (HH:mm)")
                text: Config.options.light.night.from
                wrapMode: TextEdit.NoWrap
                onTextChanged: {
                    Config.options.light.night.from = text;
                }
            }
            MaterialTextArea {
                Layout.fillWidth: true
                placeholderText: Translation.tr("To (HH:mm)")
                text: Config.options.light.night.to
                wrapMode: TextEdit.NoWrap
                onTextChanged: {
                    Config.options.light.night.to = text;
                }
            }
        }
    }

    ContentSection {
        icon: "select_window"
        title: Translation.tr("Overlay: General")

        ConfigSwitch {
            buttonIcon: "high_density"
            text: Translation.tr("Enable opening zoom animation")
            checked: Config.options.overlay.openingZoomAnimation
            onCheckedChanged: {
                Config.options.overlay.openingZoomAnimation = checked;
            }
        }
        ConfigSwitch {
            buttonIcon: "texture"
            text: Translation.tr("Darken screen")
            checked: Config.options.overlay.darkenScreen
            onCheckedChanged: {
                Config.options.overlay.darkenScreen = checked;
            }
        }
    }

    ContentSection {
        icon: "point_scan"
        title: Translation.tr("Overlay: Crosshair")

        MaterialTextArea {
            Layout.fillWidth: true
            placeholderText: Translation.tr("Crosshair code (in Valorant's format)")
            text: Config.options.crosshair.code
            wrapMode: TextEdit.Wrap
            onTextChanged: {
                Config.options.crosshair.code = text;
            }
        }

        RowLayout {
            StyledText {
                Layout.leftMargin: 10
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smallie
                text: Translation.tr("Press Super+G to open the overlay and pin the crosshair")
            }
            Item {
                Layout.fillWidth: true
            }
            RippleButtonWithIcon {
                id: editorButton
                buttonRadius: Appearance.rounding.full
                materialIcon: "open_in_new"
                mainText: Translation.tr("Open editor")
                onClicked: {
                    Qt.openUrlExternally(`https://www.vcrdb.net/builder?c=${Config.options.crosshair.code}`);
                }
                StyledToolTip {
                    text: "www.vcrdb.net"
                }
            }
        }
    }

    ContentSection {
        icon: "point_scan"
        title: Translation.tr("Overlay: Floating Image")

        MaterialTextArea {
            Layout.fillWidth: true
            placeholderText: Translation.tr("Image source")
            text: Config.options.overlay.floatingImage.imageSource
            wrapMode: TextEdit.Wrap
            onTextChanged: {
                Config.options.overlay.floatingImage.imageSource = text;
            }
        }
    }

    ContentSection {
        icon: "screenshot_frame_2"
        title: Translation.tr("Region selector (screen snipping/Google Lens)")

        ConfigSwitch {
            buttonIcon: "edit_note"
            text: Translation.tr("Open Satty to annotate after a screenshot")
            checked: Config.options.regionSelector.annotation.useSatty
            onCheckedChanged: {
                Config.options.regionSelector.annotation.useSatty = checked;
            }
            StyledToolTip {
                text: Translation.tr("Requires Satty installed")
            }
        }

        ContentSubsection {
            title: Translation.tr("Hint target regions")
            ConfigRow {
                ConfigSwitch {
                    buttonIcon: "select_window"
                    text: Translation.tr('Windows')
                    checked: Config.options.regionSelector.targetRegions.windows
                    onCheckedChanged: {
                        Config.options.regionSelector.targetRegions.windows = checked;
                    }
                }
                ConfigSwitch {
                    buttonIcon: "right_panel_open"
                    text: Translation.tr('Layers')
                    checked: Config.options.regionSelector.targetRegions.layers
                    onCheckedChanged: {
                        Config.options.regionSelector.targetRegions.layers = checked;
                    }
                }
                ConfigSwitch {
                    buttonIcon: "nearby"
                    text: Translation.tr('Content')
                    checked: Config.options.regionSelector.targetRegions.content
                    onCheckedChanged: {
                        Config.options.regionSelector.targetRegions.content = checked;
                    }
                    StyledToolTip {
                        text: Translation.tr("Could be images or parts of the screen that have some containment.\nMight not always be accurate.\nThis is done with an image processing algorithm run locally and no AI is used.")
                    }
                }
            }
        }
        
        ContentSubsection {
            title: Translation.tr("Google Lens")
            
            ConfigSelectionArray {
                currentValue: Config.options.search.imageSearch.useCircleSelection ? "circle" : "rectangles"
                onSelected: newValue => {
                    Config.options.search.imageSearch.useCircleSelection = (newValue === "circle");
                }
                options: [
                    { icon: "activity_zone", value: "rectangles", displayName: Translation.tr("Rectangular selection") },
                    { icon: "gesture", value: "circle", displayName: Translation.tr("Circle to Search") }
                ]
            }
        }

        ContentSubsection {
            title: Translation.tr("Rectangular selection")

            ConfigSwitch {
                buttonIcon: "point_scan"
                text: Translation.tr("Show aim lines")
                checked: Config.options.regionSelector.rect.showAimLines
                onCheckedChanged: {
                    Config.options.regionSelector.rect.showAimLines = checked;
                }
            }
        }

        ContentSubsection {
            title: Translation.tr("Circle selection")
            
            ConfigSpinBox {
                icon: "eraser_size_3"
                text: Translation.tr("Stroke width")
                value: Config.options.regionSelector.circle.strokeWidth
                from: 1
                to: 20
                stepSize: 1
                onValueChanged: {
                    Config.options.regionSelector.circle.strokeWidth = value;
                }
            }

            ConfigSpinBox {
                icon: "screenshot_frame_2"
                text: Translation.tr("Padding")
                value: Config.options.regionSelector.circle.padding
                from: 0
                to: 100
                stepSize: 5
                onValueChanged: {
                    Config.options.regionSelector.circle.padding = value;
                }
            }
        }
    }
}
