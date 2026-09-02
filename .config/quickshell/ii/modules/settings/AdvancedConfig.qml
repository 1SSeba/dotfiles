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
        icon: "tune"
        title: Translation.tr("Panel de ajustes")

        ConfigSelectionArray {
            Layout.fillWidth: false
            currentValue: Config.options.settings.style
            onSelected: newValue => {
                Config.options.settings.style = newValue;
            }
            options: [
                {
                    displayName: Translation.tr("Completo"),
                    icon: "settings_panorama",
                    value: "default"
                },
                {
                    displayName: Translation.tr("Minimalista"),
                    icon: "settings_heart",
                    value: "minimal"
                }
            ]
        }

        ConfigSpinBox {
            icon: "border_style"
            text: Translation.tr("Grosor del borde")
            value: Config.options.settings.borderSize
            from: 0
            to: 10
            stepSize: 1
            onValueChanged: {
                Config.options.settings.borderSize = value;
            }
        }

        ColorSelectionArray {
            icon: "format_paint"
            text: Translation.tr("Color del borde")
            enabled: Config.options.settings.borderSize > 0
            options: ["primary", "secondary", "tertiary", "primaryContainer", "secondaryContainer", "tertiaryContainer", "layer0Border"]
            currentValue: Config.options.settings.borderColor
            onSelected: newValue => {
                Config.options.settings.borderColor = newValue;
            }
        }
    }

}
