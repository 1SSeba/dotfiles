import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.common.models.hyprland

ContentPage {
    forceWidth: true

    MonitorConfigOption { id: monitorConfig }

    Process {
        id: randomWallProc
        property string status: ""
        property string scriptPath: `${Directories.scriptPath}/colors/random/random_konachan_wall.sh`
        command: ["bash", "-c", FileUtils.trimFileProtocol(randomWallProc.scriptPath)]
        stdout: SplitParser {
            onRead: data => {
                randomWallProc.status = data.trim();
            }
        }
    }

    component SmallLightDarkPreferenceButton: RippleButton {
        id: smallLightDarkPreferenceButton
        required property bool dark
        property color colText: toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer2
        padding: 5
        Layout.fillWidth: true
        toggled: Appearance.m3colors.darkmode === dark
        colBackground: Appearance.colors.colLayer2
        onClicked: {
            Quickshell.execDetached(["bash", "-c", `${Directories.wallpaperSwitchScriptPath} --mode ${dark ? "dark" : "light"} --noswitch`]);
        }
        contentItem: Item {
            anchors.centerIn: parent
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 0
                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    iconSize: 30
                    text: dark ? "dark_mode" : "light_mode"
                    color: smallLightDarkPreferenceButton.colText
                }
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: dark ? Translation.tr("Dark") : Translation.tr("Light")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: smallLightDarkPreferenceButton.colText
                }
            }
        }
    }

    ContentSection {
        icon: "wallpaper"
        title: Translation.tr("Selección")

        RowLayout {
            Layout.fillWidth: true

            Item {
                implicitWidth: 340
                implicitHeight: 200

                StyledImage {
                    id: wallpaperPreview
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    source: Config.options.background.wallpaperPath
                    cache: false
                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: 360
                            height: 200
                            radius: Appearance.rounding.normal
                        }
                    }
                }

                ToolbarPairedFab {
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    anchors.margins: 8
                    iconText: "colorize"
                    onClicked: {
                        Quickshell.execDetached([Directories.wallpaperSwitchScriptPath, "--noswitch", "--color"]);
                    }
                    StyledToolTip {
                        text: Translation.tr("Regenerate accent color")
                    }
                }
            }

            ColumnLayout {
                RippleButtonWithIcon {
                    enabled: !randomWallProc.running
                    visible: Config.options.policies.weeb === 1
                    Layout.fillWidth: true
                    buttonRadius: Appearance.rounding.small
                    materialIcon: "ifl"
                    mainText: randomWallProc.running ? Translation.tr("Be patient...") : Translation.tr("Random: Konachan")
                    onClicked: {
                        randomWallProc.scriptPath = `${Directories.scriptPath}/colors/random/random_konachan_wall.sh`;
                        randomWallProc.running = true;
                    }
                    StyledToolTip {
                        text: Translation.tr("Random SFW Anime wallpaper from Konachan\nImage is saved to ~/Pictures/wallpapers")
                    }
                }
                RippleButtonWithIcon {
                    enabled: !randomWallProc.running
                    visible: Config.options.policies.weeb === 1
                    Layout.fillWidth: true
                    buttonRadius: Appearance.rounding.small
                    materialIcon: "ifl"
                    mainText: randomWallProc.running ? Translation.tr("Be patient...") : Translation.tr("Random: osu! seasonal")
                    onClicked: {
                        randomWallProc.scriptPath = `${Directories.scriptPath}/colors/random/random_osu_wall.sh`;
                        randomWallProc.running = true;
                    }
                    StyledToolTip {
                        text: Translation.tr("Random osu! seasonal background\nImage is saved to ~/Pictures/wallpapers")
                    }
                }
                RippleButtonWithIcon {
                    Layout.fillWidth: true
                    materialIcon: "wallpaper"
                    StyledToolTip {
                        text: Translation.tr("Pick wallpaper image on your system")
                    }
                    onClicked: {
                        Quickshell.execDetached(`${Directories.wallpaperSwitchScriptPath}`);
                    }
                    mainContentComponent: Component {
                        RowLayout {
                            spacing: 10
                            StyledText {
                                font.pixelSize: Appearance.font.pixelSize.small
                                text: Translation.tr("Choose file")
                                color: Appearance.colors.colOnSecondaryContainer
                            }
                            RowLayout {
                                spacing: 3
                                KeyboardKey {
                                    key: "Ctrl"
                                }
                                KeyboardKey {
                                    key: Config.options.cheatsheet.superKey ?? "󰖳"
                                }
                                StyledText {
                                    Layout.alignment: Qt.AlignVCenter
                                    text: "+"
                                }
                                KeyboardKey {
                                    key: "T"
                                }
                            }
                        }
                    }
                }
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    uniformCellSizes: true

                    SmallLightDarkPreferenceButton {
                        Layout.fillHeight: true
                        dark: false
                    }
                    SmallLightDarkPreferenceButton {
                        Layout.fillHeight: true
                        dark: true
                    }
                }
            }
        }
    }

    ContentSection {
        icon: "monitor"
        title: Translation.tr("Wallpaper por monitor")
        visible: monitorConfig.monitors.length > 1

        StyledText {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.smaller
            text: Translation.tr("La resolución y posición de cada pantalla se configuran en Video & Pantallas. Acá solo el wallpaper de cada una.")
        }

        Repeater {
            model: monitorConfig.monitors
            ContentSubsection {
                required property var modelData
                readonly property string monitorName: modelData.name
                readonly property string monitorWallpaper: Wallpapers.effectivePathForMonitor(monitorName)
                readonly property bool monitorHasOverride: (Config.options.wallpaperPathByMonitor ?? {})[monitorName] !== undefined
                title: monitorName + " · " + (modelData.description ?? "")
                Layout.fillWidth: true

                StyledText {
                    Layout.fillWidth: true
                    Layout.leftMargin: 8
                    wrapMode: Text.Wrap
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    text: {
                        const p = monitorWallpaper;
                        if (p.length === 0)
                            return Translation.tr("No wallpaper set yet");
                        const name = p.substring(p.lastIndexOf("/") + 1);
                        return monitorHasOverride
                            ? Translation.tr("Set for this monitor: %1").arg(name)
                            : Translation.tr("Using the global wallpaper: %1").arg(name);
                    }
                }

                RippleButtonWithIcon {
                    Layout.fillWidth: true
                    buttonRadius: Appearance.rounding.small
                    materialIcon: "wallpaper"
                    mainText: Translation.tr("Choose wallpaper for this monitor…")
                    onClicked: {
                        GlobalStates.wallpaperSelectorTargetMonitor = monitorName;
                        GlobalStates.wallpaperSelectorOpen = true;
                    }
                }

                RippleButtonWithIcon {
                    Layout.fillWidth: true
                    visible: monitorHasOverride
                    buttonRadius: Appearance.rounding.small
                    materialIcon: "layers_clear"
                    mainText: Translation.tr("Use the global wallpaper here instead")
                    onClicked: Wallpapers.clearMonitorOverride(monitorName)
                }
            }
        }
    }

    ContentSection {
        icon: "transition_fade"
        title: Translation.tr("Wallpaper transition")

        ConfigComboBox {
            Layout.fillWidth: true
            buttonIcon: "animation"
            text: Translation.tr("Animation")
            description: Translation.tr("Shader used when the wallpaper changes")
            currentValue: Config.options.background.wallpaperAnimation
            model: [
                { displayName: Translation.tr("None"), value: "" },
                { displayName: Translation.tr("Random"), value: "random" },
                { displayName: "Circle pit", value: "circlePit" },
                { displayName: "Circle select", value: "circleSelect" },
                { displayName: "Magic", value: "magic" },
                { displayName: "Doom", value: "Doom" },
                { displayName: "Peel", value: "Peel" },
                { displayName: "Slide", value: "transition" },
                { displayName: "Pixelate", value: "pixelate" },
                { displayName: "Stripes", value: "stripes" },
                { displayName: "CRT", value: "crt" },
                { displayName: "Dissolve", value: "dissolve" },
                { displayName: "Glitch", value: "glitch" },
                { displayName: "Ripple", value: "ripple" },
                { displayName: "Shatter", value: "shatter" },
            ]
            onSelected: newValue => {
                Config.options.background.wallpaperAnimation = newValue;
            }
        }

        ConfigSpinBox {
            icon: "timer"
            text: Translation.tr("Duration (ms)")
            value: Config.options.background.wallpaperAnimationDuration
            from: 200
            to: 5000
            stepSize: 100
            enabled: Config.options.background.wallpaperAnimation !== ""
            onValueChanged: {
                Config.options.background.wallpaperAnimationDuration = value;
            }
        }
    }

    ContentSection {
        icon: "sync_alt"
        title: Translation.tr("Parallax")

        ConfigSwitch {
            buttonIcon: "unfold_more_double"
            text: Translation.tr("Vertical")
            checked: Config.options.background.parallax.vertical
            onCheckedChanged: {
                Config.options.background.parallax.vertical = checked;
            }
        }

        ConfigRow {
            uniform: true
            ConfigSwitch {
                buttonIcon: "counter_1"
                text: Translation.tr("Depends on workspace")
                checked: Config.options.background.parallax.enableWorkspace
                onCheckedChanged: {
                    Config.options.background.parallax.enableWorkspace = checked;
                }
            }
            ConfigSwitch {
                buttonIcon: "side_navigation"
                text: Translation.tr("Depends on sidebars")
                checked: Config.options.background.parallax.enableSidebar
                onCheckedChanged: {
                    Config.options.background.parallax.enableSidebar = checked;
                }
            }
        }
        ConfigSpinBox {
            icon: "loupe"
            text: Translation.tr("Preferred wallpaper zoom (%)")
            value: Config.options.background.parallax.workspaceZoom * 100
            from: 10
            to: 200
            stepSize: 1
            onValueChanged: {
                Config.options.background.parallax.workspaceZoom = value / 100;
            }
        }
    }

    ContentSection {
        icon: "palette"
        title: Translation.tr("Colores del wallpaper")

        ConfigSelectionArray {
            currentValue: Config.options.appearance.palette.type
            onSelected: newValue => {
                Config.options.appearance.palette.type = newValue;
                Quickshell.execDetached(["bash", "-c", `${Directories.wallpaperSwitchScriptPath} --noswitch`]);
            }
            options: [
                {
                    "value": "auto",
                    "displayName": Translation.tr("Auto")
                },
                {
                    "value": "scheme-content",
                    "displayName": Translation.tr("Content")
                },
                {
                    "value": "scheme-expressive",
                    "displayName": Translation.tr("Expressive")
                },
                {
                    "value": "scheme-fidelity",
                    "displayName": Translation.tr("Fidelity")
                },
                {
                    "value": "scheme-fruit-salad",
                    "displayName": Translation.tr("Fruit Salad")
                },
                {
                    "value": "scheme-monochrome",
                    "displayName": Translation.tr("Monochrome")
                },
                {
                    "value": "scheme-neutral",
                    "displayName": Translation.tr("Neutral")
                },
                {
                    "value": "scheme-rainbow",
                    "displayName": Translation.tr("Rainbow")
                },
                {
                    "value": "scheme-tonal-spot",
                    "displayName": Translation.tr("Tonal Spot")
                }
            ]
        }

        ConfigRow {
            MaterialTextArea {
                id: accentColorField
                Layout.fillWidth: true
                placeholderText: Translation.tr("Custom accent color (hex, e.g. #3B82F6). Empty = auto")
                text: Config.options.appearance.palette.accentColor
                wrapMode: TextEdit.NoWrap
                onTextChanged: {
                    accentColorDebounce.restart();
                }
                Timer {
                    id: accentColorDebounce
                    interval: 600
                    repeat: false
                    onTriggered: {
                        Config.options.appearance.palette.accentColor = accentColorField.text;
                        Quickshell.execDetached(["bash", "-c", `${Directories.wallpaperSwitchScriptPath} --noswitch`]);
                    }
                }
            }
        }
    }

    ContentSection {
        icon: "colors"
        title: Translation.tr("Generación de colores")

        // Cada destino se genera con un script aparte: se pueden apagar por separado
        ConfigSwitch {
            buttonIcon: "hardware"
            text: Translation.tr("Shell y utilidades")
            checked: Config.options.appearance.wallpaperTheming.enableAppsAndShell
            onCheckedChanged: {
                Config.options.appearance.wallpaperTheming.enableAppsAndShell = checked;
            }
        }

        ConfigSwitch {
            buttonIcon: "tv_options_input_settings"
            text: Translation.tr("Apps Qt")
            checked: Config.options.appearance.wallpaperTheming.enableQtApps
            onCheckedChanged: {
                Config.options.appearance.wallpaperTheming.enableQtApps = checked;
            }
        }

        ConfigSwitch {
            buttonIcon: "terminal"
            text: Translation.tr("Terminal")
            checked: Config.options.appearance.wallpaperTheming.enableTerminal
            onCheckedChanged: {
                Config.options.appearance.wallpaperTheming.enableTerminal = checked;
            }
        }

        ContentSubsection {
            title: Translation.tr("Colores de la terminal")
            tooltip: Translation.tr("Cómo se arma la paleta de 16 colores a partir del wallpaper")

            // Con wallpapers claros el tema light de la terminal suele quedar ilegible
            ConfigSwitch {
                buttonIcon: "dark_mode"
                text: Translation.tr("Forzar modo oscuro")
                enabled: Config.options.appearance.wallpaperTheming.enableTerminal
                checked: Config.options.appearance.wallpaperTheming.terminalGenerationProps.forceDarkMode
                onCheckedChanged: {
                    Config.options.appearance.wallpaperTheming.terminalGenerationProps.forceDarkMode = checked;
                }
            }

            // Cuánto se corren los colores base (rojo, verde...) hacia el tono del wallpaper
            ConfigSpinBox {
                icon: "invert_colors"
                text: Translation.tr("Armonía (%)")
                enabled: Config.options.appearance.wallpaperTheming.enableTerminal
                value: Math.round(Config.options.appearance.wallpaperTheming.terminalGenerationProps.harmony * 100)
                from: 0
                to: 100
                stepSize: 10
                onValueChanged: {
                    Config.options.appearance.wallpaperTheming.terminalGenerationProps.harmony = value / 100;
                }
            }

            // Diferencia de tono a partir de la cual ya no se armoniza, para no perder el color original
            ConfigSpinBox {
                icon: "gradient"
                text: Translation.tr("Umbral de armonización")
                enabled: Config.options.appearance.wallpaperTheming.enableTerminal
                value: Config.options.appearance.wallpaperTheming.terminalGenerationProps.harmonizeThreshold
                from: 0
                to: 100
                stepSize: 10
                onValueChanged: {
                    Config.options.appearance.wallpaperTheming.terminalGenerationProps.harmonizeThreshold = value;
                }
            }

            // Empuja el texto hacia el blanco: sube el contraste sobre el fondo
            ConfigSpinBox {
                icon: "format_color_text"
                text: Translation.tr("Realce del texto (%)")
                enabled: Config.options.appearance.wallpaperTheming.enableTerminal
                value: Math.round(Config.options.appearance.wallpaperTheming.terminalGenerationProps.termFgBoost * 100)
                from: 0
                to: 100
                stepSize: 10
                onValueChanged: {
                    Config.options.appearance.wallpaperTheming.terminalGenerationProps.termFgBoost = value / 100;
                }
            }
        }
    }

    ContentSection {
        icon: "tune"
        title: Translation.tr("Comportamiento")

        // Al pasar el mouse por la grilla del selector ya se ve puesto en el escritorio;
        // es cómodo pero recarga el wallpaper todo el tiempo, por eso viene apagado
        ConfigSwitch {
            buttonIcon: "preview"
            text: Translation.tr("Previsualizar al pasar el mouse en el selector")
            checked: Config.options.background.enableWallpaperPreview
            onCheckedChanged: {
                Config.options.background.enableWallpaperPreview = checked;
            }
        }

        ConfigSwitch {
            buttonIcon: "fullscreen"
            text: Translation.tr("Hide desktop widgets in fullscreen apps")
            checked: Config.options.background.hideWhenFullscreen
            onCheckedChanged: {
                Config.options.background.hideWhenFullscreen = checked;
            }
        }

        // El wallpaper centrado (figura, tamaño y color de fondo) se toca desde el escritorio:
        // click derecho -> submenú de wallpaper, donde se ve el cambio en vivo. No lo duplicamos acá.
        StyledText {
            Layout.leftMargin: 10
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.smallie
            text: Translation.tr("El wallpaper centrado (figura, tamaño y color) se configura con click derecho en el escritorio → Wallpaper")
        }
    }
}
