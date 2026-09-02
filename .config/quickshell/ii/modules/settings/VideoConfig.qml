import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.models.hyprland

ContentPage {
    forceWidth: true

    MonitorConfigOption { id: monitorConfig }

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
                    model: (monitorConfig.monitors[monitorCanvas.selectedIndex]?.availableModes ?? [])
                        .map(mode => ({ display: mode, value: mode }))
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
