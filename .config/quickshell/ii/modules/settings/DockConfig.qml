import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    forceWidth: true

    ContentSection {
        icon: "call_to_action"
        title: Translation.tr("Dock")

        ConfigSwitch {
            buttonIcon: "check"
            text: Translation.tr("Enable")
            checked: Config.options.dock.enable
            onCheckedChanged: {
                Config.options.dock.enable = checked;
            }
        }

        // Sin fondo el dock queda flotando: los iconos se apoyan directo sobre el wallpaper
        ConfigSwitch {
            buttonIcon: "background_dot_small"
            text: Translation.tr("Mostrar fondo")
            checked: Config.options.dock.showBackground
            onCheckedChanged: {
                Config.options.dock.showBackground = checked;
            }
        }

        ConfigRow {
            uniform: true
            ConfigSwitch {
                buttonIcon: "highlight_mouse_cursor"
                text: Translation.tr("Hover to reveal")
                checked: Config.options.dock.hoverToReveal
                onCheckedChanged: {
                    Config.options.dock.hoverToReveal = checked;
                }
            }
            ConfigSwitch {
                buttonIcon: "keep"
                text: Translation.tr("Pinned on startup")
                checked: Config.options.dock.pinnedOnStartup
                onCheckedChanged: {
                    Config.options.dock.pinnedOnStartup = checked;
                }
            }
        }
        ConfigSwitch {
            buttonIcon: "colors"
            text: Translation.tr("Tint app icons")
            checked: Config.options.dock.monochromeIcons
            onCheckedChanged: {
                Config.options.dock.monochromeIcons = checked;
            }
        }

        ContentSubsection {
            title: Translation.tr("Botones y multimedia")
            tooltip: Translation.tr("Qué acompaña a los iconos de las apps en el dock")

            ConfigSwitch {
                buttonIcon: "music_note"
                text: Translation.tr("Reproductor")
                checked: Config.options.dock.showMedia
                onCheckedChanged: {
                    Config.options.dock.showMedia = checked;
                }
            }

            ConfigSwitch {
                buttonIcon: "keep"
                text: Translation.tr("Botón de fijar")
                checked: Config.options.dock.showPinButton
                onCheckedChanged: {
                    Config.options.dock.showPinButton = checked;
                }
            }

            ConfigSwitch {
                buttonIcon: "apps"
                text: Translation.tr("Botón de aplicaciones")
                checked: Config.options.dock.showAppsButton
                onCheckedChanged: {
                    Config.options.dock.showAppsButton = checked;
                }
            }
        }
    }
}
