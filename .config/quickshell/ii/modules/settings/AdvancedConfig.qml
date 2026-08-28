import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    forceWidth: true

    ContentSection {
        icon: "apps"
        title: Translation.tr("Default apps")

        StyledText {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.smallie
            text: Translation.tr("Comandos que la shell ejecuta para abrir cada herramienta del sistema.")
        }

        ContentSubsection {
            title: Translation.tr("Terminal (shell actions)")
            MaterialTextArea {
                Layout.fillWidth: true
                text: Config.options.apps.terminal
                wrapMode: TextEdit.NoWrap
                onTextChanged: { Config.options.apps.terminal = text; }
            }
        }
        ContentSubsection {
            title: Translation.tr("Network")
            MaterialTextArea {
                Layout.fillWidth: true
                text: Config.options.apps.network
                wrapMode: TextEdit.NoWrap
                onTextChanged: { Config.options.apps.network = text; }
            }
        }
        ContentSubsection {
            title: Translation.tr("Network (Ethernet)")
            MaterialTextArea {
                Layout.fillWidth: true
                text: Config.options.apps.networkEthernet
                wrapMode: TextEdit.NoWrap
                onTextChanged: { Config.options.apps.networkEthernet = text; }
            }
        }
        ContentSubsection {
            title: Translation.tr("Bluetooth")
            MaterialTextArea {
                Layout.fillWidth: true
                text: Config.options.apps.bluetooth
                wrapMode: TextEdit.NoWrap
                onTextChanged: { Config.options.apps.bluetooth = text; }
            }
        }
        ContentSubsection {
            title: Translation.tr("Volume mixer")
            MaterialTextArea {
                Layout.fillWidth: true
                text: Config.options.apps.volumeMixer
                wrapMode: TextEdit.NoWrap
                onTextChanged: { Config.options.apps.volumeMixer = text; }
            }
        }
        ContentSubsection {
            title: Translation.tr("Task manager")
            MaterialTextArea {
                Layout.fillWidth: true
                text: Config.options.apps.taskManager
                wrapMode: TextEdit.NoWrap
                onTextChanged: { Config.options.apps.taskManager = text; }
            }
        }
        ContentSubsection {
            title: Translation.tr("Change password")
            MaterialTextArea {
                Layout.fillWidth: true
                text: Config.options.apps.changePassword
                wrapMode: TextEdit.NoWrap
                onTextChanged: { Config.options.apps.changePassword = text; }
            }
        }
        ContentSubsection {
            title: Translation.tr("Manage users")
            MaterialTextArea {
                Layout.fillWidth: true
                text: Config.options.apps.manageUser
                wrapMode: TextEdit.NoWrap
                onTextChanged: { Config.options.apps.manageUser = text; }
            }
        }
        ContentSubsection {
            title: Translation.tr("System update")
            MaterialTextArea {
                Layout.fillWidth: true
                text: Config.options.apps.update
                wrapMode: TextEdit.NoWrap
                onTextChanged: { Config.options.apps.update = text; }
            }
        }
    }

    ContentSection {
        icon: "colors"
        title: Translation.tr("Color generation")

        ConfigSwitch {
            buttonIcon: "hardware"
            text: Translation.tr("Shell & utilities")
            checked: Config.options.appearance.wallpaperTheming.enableAppsAndShell
            onCheckedChanged: {
                Config.options.appearance.wallpaperTheming.enableAppsAndShell = checked;
            }
        }
        ConfigSwitch {
            buttonIcon: "tv_options_input_settings"
            text: Translation.tr("Qt apps")
            checked: Config.options.appearance.wallpaperTheming.enableQtApps
            onCheckedChanged: {
                Config.options.appearance.wallpaperTheming.enableQtApps = checked;
            }
            StyledToolTip {
                text: Translation.tr("Shell & utilities theming must also be enabled")
            }
        }
        ConfigSwitch {
            buttonIcon: "terminal"
            text: Translation.tr("Terminal")
            checked: Config.options.appearance.wallpaperTheming.enableTerminal
            onCheckedChanged: {
                Config.options.appearance.wallpaperTheming.enableTerminal = checked;
            }
            StyledToolTip {
                text: Translation.tr("Shell & utilities theming must also be enabled")
            }
        }
        ConfigRow {
            uniform: true
            ConfigSwitch {
                buttonIcon: "dark_mode"
                text: Translation.tr("Force dark mode in terminal")
                checked: Config.options.appearance.wallpaperTheming.terminalGenerationProps.forceDarkMode
                onCheckedChanged: {
                     Config.options.appearance.wallpaperTheming.terminalGenerationProps.forceDarkMode= checked;
                }
                StyledToolTip {
                    text: Translation.tr("Ignored if terminal theming is not enabled")
                }
            }
        }

        ConfigSpinBox {
            icon: "invert_colors"
            text: Translation.tr("Terminal: Harmony (%)")
            value: Config.options.appearance.wallpaperTheming.terminalGenerationProps.harmony * 100
            from: 0
            to: 100
            stepSize: 10
            onValueChanged: {
                Config.options.appearance.wallpaperTheming.terminalGenerationProps.harmony = value / 100;
            }
        }
        ConfigSpinBox {
            icon: "gradient"
            text: Translation.tr("Terminal: Harmonize threshold")
            value: Config.options.appearance.wallpaperTheming.terminalGenerationProps.harmonizeThreshold
            from: 0
            to: 100
            stepSize: 10
            onValueChanged: {
                Config.options.appearance.wallpaperTheming.terminalGenerationProps.harmonizeThreshold = value;
            }
        }
        ConfigSpinBox {
            icon: "format_color_text"
            text: Translation.tr("Terminal: Foreground boost (%)")
            value: Config.options.appearance.wallpaperTheming.terminalGenerationProps.termFgBoost * 100
            from: 0
            to: 100
            stepSize: 10
            onValueChanged: {
                Config.options.appearance.wallpaperTheming.terminalGenerationProps.termFgBoost = value / 100;
            }
        }
    }



}
