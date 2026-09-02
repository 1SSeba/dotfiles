import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    forceWidth: true

    ContentSection {
        icon: "apps"
        title: Translation.tr("App launcher")

        ConfigSwitch {
            buttonIcon: "search"
            text: Translation.tr("Escribir salta al buscador")
            checked: Config.options.appLauncher.typeToSearch
            onCheckedChanged: {
                Config.options.appLauncher.typeToSearch = checked;
            }
            StyledToolTip {
                text: Translation.tr("Al escribir, la grilla se desvanece y la barra sube para convertirse en el buscador de Super+Tab, sin cambiar de ventana. Apagalo para que escribir no haga nada en el lanzador.")
            }
        }

        ConfigSpinBox {
            icon: "timer"
            text: Translation.tr("Duración máx. del toque de Super (ms)")
            value: Config.options.appLauncher.superTapMaxMs
            from: 100
            to: 1500
            stepSize: 50
            onValueChanged: {
                Config.options.appLauncher.superTapMaxMs = value;
            }
            StyledToolTip {
                text: Translation.tr("Si mantenés Super más tiempo que esto, soltarla ya no abre el lanzador. Sirve para que no se abra sola después de usar Super como modificador (arrastrar ventanas, combos). Subilo si tocás la tecla lento y no te abre.")
            }
        }

        ContentSubsection {
            title: Translation.tr("Fondo")

            ConfigSlider {
                text: Translation.tr("Opacidad de la caja")
                value: Config.options.appLauncher.backgroundOpacity
                buttonIcon: "opacity"
                from: 0
                to: 1
                stopIndicatorValues: [1]
                onValueChanged: {
                    Config.options.appLauncher.backgroundOpacity = value;
                }
                StyledToolTip {
                    text: Translation.tr("Bajala para dejar ver el fondo. Hyprland ya le aplica blur a este panel.")
                }
            }

            ConfigSwitch {
                buttonIcon: "border_style"
                text: Translation.tr("Mostrar borde")
                checked: Config.options.appLauncher.showBorder
                onCheckedChanged: {
                    Config.options.appLauncher.showBorder = checked;
                }
            }

            ConfigSwitch {
                buttonIcon: "brightness_medium"
                text: Translation.tr("Oscurecer el resto de la pantalla")
                checked: Config.options.appLauncher.dimBackground
                onCheckedChanged: {
                    Config.options.appLauncher.dimBackground = checked;
                }
            }

            ConfigSlider {
                text: Translation.tr("Cuánto oscurece")
                value: Config.options.appLauncher.dimStrength
                enabled: Config.options.appLauncher.dimBackground
                buttonIcon: "gradient"
                from: 0
                to: 1
                stopIndicatorValues: [1]
                onValueChanged: {
                    Config.options.appLauncher.dimStrength = value;
                }
            }
        }

        ContentSubsection {
            title: Translation.tr("Tamaño de la caja")

            ConfigSpinBox {
                icon: "width"
                text: Translation.tr("Ancho máximo (px)")
                value: Config.options.appLauncher.maxWidth
                from: 400
                to: 3840
                stepSize: 20
                onValueChanged: {
                    Config.options.appLauncher.maxWidth = value;
                }
            }

            ConfigSpinBox {
                icon: "height"
                text: Translation.tr("Alto máximo (px)")
                value: Config.options.appLauncher.maxHeight
                from: 300
                to: 2160
                stepSize: 20
                onValueChanged: {
                    Config.options.appLauncher.maxHeight = value;
                }
            }
        }

        ContentSubsection {
            title: Translation.tr("Grilla")

            ConfigSpinBox {
                icon: "grid_view"
                text: Translation.tr("Ancho de cada celda (px)")
                value: Config.options.appLauncher.cellWidth
                from: 70
                to: 300
                stepSize: 5
                onValueChanged: {
                    Config.options.appLauncher.cellWidth = value;
                }
                StyledToolTip {
                    text: Translation.tr("De acá sale la cantidad de columnas: cuanto más chico, más apps por fila.")
                }
            }

            ConfigSpinBox {
                icon: "density_medium"
                text: Translation.tr("Alto de cada celda (px)")
                value: Config.options.appLauncher.cellHeight
                from: 60
                to: 300
                stepSize: 5
                onValueChanged: {
                    Config.options.appLauncher.cellHeight = value;
                }
            }

            ConfigSpinBox {
                icon: "image"
                text: Translation.tr("Tamaño del ícono (px)")
                value: Config.options.appLauncher.iconSize
                from: 16
                to: 128
                stepSize: 2
                onValueChanged: {
                    Config.options.appLauncher.iconSize = value;
                }
            }

            ConfigSwitch {
                buttonIcon: "label"
                text: Translation.tr("Mostrar el nombre de las apps")
                checked: Config.options.appLauncher.showAppNames
                onCheckedChanged: {
                    Config.options.appLauncher.showAppNames = checked;
                }
            }

            ConfigSwitch {
                buttonIcon: "tag"
                text: Translation.tr("Mostrar el contador de apps")
                checked: Config.options.appLauncher.showAppCount
                onCheckedChanged: {
                    Config.options.appLauncher.showAppCount = checked;
                }
            }

            ConfigSwitch {
                buttonIcon: "keep"
                text: Translation.tr("Apps ancladas primero")
                checked: Config.options.appLauncher.pinnedFirst
                onCheckedChanged: {
                    Config.options.appLauncher.pinnedFirst = checked;
                }
                StyledToolTip {
                    text: Translation.tr("Usa la misma lista de anclados que el dock y el menú de inicio.")
                }
            }
        }
    }

    ContentSection {
        icon: "keyboard"
        title: Translation.tr("Cheat sheet")

        ContentSubsection {
            title: Translation.tr("Super key symbol")
            tooltip: Translation.tr("You can also manually edit cheatsheet.superKey")
            ConfigSelectionArray {
                currentValue: Config.options.cheatsheet.superKey
                onSelected: newValue => {
                    Config.options.cheatsheet.superKey = newValue;
                }
                // Use a nerdfont to see the icons
                options: ([
                  "󰖳", "", "󰨡", "", "󰌽", "󰣇", "", "", "", 
                  "", "", "󱄛", "", "", "", "⌘", "󰀲", "󰟍", ""
                ]).map(icon => { return {
                  displayName: icon,
                  value: icon
                  }
                })
            }
        }

        ConfigSwitch {
            buttonIcon: "󰘵"
            text: Translation.tr("Use macOS-like symbols for mods keys")
            checked: Config.options.cheatsheet.useMacSymbol
            onCheckedChanged: {
                Config.options.cheatsheet.useMacSymbol = checked;
            }
            StyledToolTip {
                text: Translation.tr("e.g. 󰘴  for Ctrl, 󰘵  for Alt, 󰘶  for Shift, etc")
            }
        }

        ConfigSwitch {
            buttonIcon: "󱊶"
            text: Translation.tr("Use symbols for function keys")
            checked: Config.options.cheatsheet.useFnSymbol
            onCheckedChanged: {
                Config.options.cheatsheet.useFnSymbol = checked;
            }
            StyledToolTip {
              text: Translation.tr("e.g. 󱊫 for F1, 󱊶  for F12")
            }
        }
        ConfigSwitch {
            buttonIcon: "󰍽"
            text: Translation.tr("Use symbols for mouse")
            checked: Config.options.cheatsheet.useMouseSymbol
            onCheckedChanged: {
                Config.options.cheatsheet.useMouseSymbol = checked;
            }
            StyledToolTip {
              text: Translation.tr("Replace 󱕐   for \"Scroll ↓\", 󱕑   \"Scroll ↑\", L󰍽   \"LMB\", R󰍽   \"RMB\", 󱕒   \"Scroll ↑/↓\" and ⇞/⇟ for \"Page_↑/↓\"")
            }
        }
        ConfigSwitch {
            buttonIcon: "highlight_keyboard_focus"
            text: Translation.tr("Split buttons")
            checked: Config.options.cheatsheet.splitButtons
            onCheckedChanged: {
                Config.options.cheatsheet.splitButtons = checked;
            }
            StyledToolTip {
                text: Translation.tr("Display modifiers and keys in multiple keycap (e.g., \"Ctrl + A\" instead of \"Ctrl A\" or \"󰘴 + A\" instead of \"󰘴 A\")")
            }

        }

        ConfigSpinBox {
            text: Translation.tr("Keybind font size")
            value: Config.options.cheatsheet.fontSize.key
            from: 8
            to: 30
            stepSize: 1
            onValueChanged: {
                Config.options.cheatsheet.fontSize.key = value;
            }
        }
        ConfigSpinBox {
            text: Translation.tr("Description font size")
            value: Config.options.cheatsheet.fontSize.comment
            from: 8
            to: 30
            stepSize: 1
            onValueChanged: {
                Config.options.cheatsheet.fontSize.comment = value;
            }
        }
    }

    ContentSection {
        icon: "lock"
        title: Translation.tr("Lock screen")

        ConfigSwitch {
            buttonIcon: "water_drop"
            text: Translation.tr('Use Hyprlock (instead of Quickshell)')
            checked: Config.options.lock.useHyprlock
            onCheckedChanged: {
                Config.options.lock.useHyprlock = checked;
            }
            StyledToolTip {
                text: Translation.tr("If you want to somehow use fingerprint unlock...")
            }
        }

        ConfigSwitch {
            buttonIcon: "account_circle"
            text: Translation.tr('Launch on startup')
            checked: Config.options.lock.launchOnStartup
            onCheckedChanged: {
                Config.options.lock.launchOnStartup = checked;
            }
        }

        ContentSubsection {
            title: Translation.tr("Security")

            ConfigSwitch {
                buttonIcon: "settings_power"
                text: Translation.tr('Require password to power off/restart')
                checked: Config.options.lock.security.requirePasswordToPower
                onCheckedChanged: {
                    Config.options.lock.security.requirePasswordToPower = checked;
                }
                StyledToolTip {
                    text: Translation.tr("Remember that on most devices one can always hold the power button to force shutdown\nThis only makes it a tiny bit harder for accidents to happen")
                }
            }

            ConfigSwitch {
                buttonIcon: "key_vertical"
                text: Translation.tr('Also unlock keyring')
                checked: Config.options.lock.security.unlockKeyring
                onCheckedChanged: {
                    Config.options.lock.security.unlockKeyring = checked;
                }
                StyledToolTip {
                    text: Translation.tr("This is usually safe and needed for your browser and AI sidebar anyway\nMostly useful for those who use lock on startup instead of a display manager that does it (GDM, SDDM, etc.)")
                }
            }
        }

        ContentSubsection {
            title: Translation.tr("Fondo del bloqueo")

            // Wallpaper propio del lock. Vacío = usa el del escritorio.
            // LockWallpaperColorGen genera la paleta a partir de esta imagen.
            MaterialTextField {
                Layout.fillWidth: true
                placeholderText: Translation.tr("Ruta de la imagen (vacío = el del escritorio)")
                text: Config.options.background.lockWall
                onAccepted: {
                    Config.options.background.lockWall = text;
                }
            }
        }

        ContentSubsection {
            title: Translation.tr("Contenido del bloqueo")

            ConfigSwitch {
                buttonIcon: "music_note"
                text: Translation.tr("Controles de música")
                checked: Config.options.lock.showMedia
                onCheckedChanged: {
                    Config.options.lock.showMedia = checked;
                }
            }

            ConfigSwitch {
                buttonIcon: "toolbar"
                text: Translation.tr("Barras de acciones")
                checked: Config.options.lock.showToolbars
                onCheckedChanged: {
                    Config.options.lock.showToolbars = checked;
                }
            }

            ConfigSwitch {
                buttonIcon: "widgets"
                text: Translation.tr("Widgets del escritorio")
                checked: Config.options.lock.showWidgets
                onCheckedChanged: {
                    Config.options.lock.showWidgets = checked;
                }
            }
        }

        ContentSubsection {
            title: Translation.tr("Style: general")

            ConfigSwitch {
                buttonIcon: "center_focus_weak"
                text: Translation.tr('Center clock')
                checked: Config.options.lock.centerClock
                onCheckedChanged: {
                    Config.options.lock.centerClock = checked;
                }
            }

            ConfigSwitch {
                buttonIcon: "info"
                text: Translation.tr('Show "Locked" text')
                checked: Config.options.lock.showLockedText
                onCheckedChanged: {
                    Config.options.lock.showLockedText = checked;
                }
            }

            ConfigSwitch {
                buttonIcon: "shapes"
                text: Translation.tr('Use varying shapes for password characters')
                checked: Config.options.lock.materialShapeChars
                onCheckedChanged: {
                    Config.options.lock.materialShapeChars = checked;
                }
            }
        }
        ContentSubsection {
            title: Translation.tr("Style: Blurred")

            ConfigSwitch {
                buttonIcon: "blur_on"
                text: Translation.tr('Enable blur')
                checked: Config.options.lock.blur.enable
                onCheckedChanged: {
                    Config.options.lock.blur.enable = checked;
                }
            }

            // Muestras del desenfoque: más alto suaviza mejor pero cuesta más GPU
            ConfigSpinBox {
                icon: "deblur"
                text: Translation.tr("Muestras del desenfoque (1 = automático)")
                enabled: Config.options.lock.blur.enable
                value: Config.options.lock.blur.size
                from: 1
                to: 200
                stepSize: 1
                onValueChanged: {
                    Config.options.lock.blur.size = value;
                }
            }

            ConfigSpinBox {
                icon: "loupe"
                text: Translation.tr("Extra wallpaper zoom (%)")
                value: Config.options.lock.blur.extraZoom * 100
                from: 1
                to: 150
                stepSize: 2
                onValueChanged: {
                    Config.options.lock.blur.extraZoom = value / 100;
                }
            }

            ConfigSpinBox {
                icon: "blur_circular"
                text: Translation.tr("Blur radius")
                enabled: Config.options.lock.blur.enable
                value: Config.options.lock.blur.radius
                from: 1
                to: 200
                stepSize: 5
                onValueChanged: {
                    Config.options.lock.blur.radius = value;
                }
            }
        }
    }

    ContentSection {
        icon: "notifications"
        title: Translation.tr("Notifications")

        ConfigSpinBox {
            icon: "av_timer"
            text: Translation.tr("Timeout duration (if not defined by notification) (ms)")
            value: Config.options.notifications.timeout
            from: 1000
            to: 60000
            stepSize: 1000
            onValueChanged: {
                Config.options.notifications.timeout = value;
            }
        }
    }

    ContentSection {
        icon: "voting_chip"
        title: Translation.tr("On-screen display")

        ConfigSpinBox {
            icon: "av_timer"
            text: Translation.tr("Timeout (ms)")
            value: Config.options.osd.timeout
            from: 100
            to: 3000
            stepSize: 100
            onValueChanged: {
                Config.options.osd.timeout = value;
            }
        }
    }

    ContentSection {
        icon: "overview_key"
        title: Translation.tr("Overview")

        ConfigSwitch {
            buttonIcon: "check"
            text: Translation.tr("Enable")
            checked: Config.options.overview.enable
            onCheckedChanged: {
                Config.options.overview.enable = checked;
            }
        }
        ConfigSwitch {
            buttonIcon: "center_focus_strong"
            text: Translation.tr("Center icons")
            checked: Config.options.overview.centerIcons
            onCheckedChanged: {
                Config.options.overview.centerIcons = checked;
            }
        }
        ConfigSpinBox {
            icon: "loupe"
            text: Translation.tr("Scale (%)")
            value: Config.options.overview.scale * 100
            from: 1
            to: 100
            stepSize: 1
            onValueChanged: {
                Config.options.overview.scale = value / 100;
            }
        }

        // El estilo "niri" muestra los workspaces en una tira horizontal en vez de la grilla
        ConfigSelectionArray {
            Layout.fillWidth: false
            currentValue: Config.options.overview.style
            onSelected: newValue => {
                Config.options.overview.style = newValue;
            }
            options: [
                {
                    displayName: Translation.tr("Grilla"),
                    icon: "grid_on",
                    value: "default"
                },
                {
                    displayName: Translation.tr("Estilo Niri"),
                    icon: "mobiledata_arrows",
                    value: "niri"
                }
            ]
        }
        ConfigRow {
            uniform: true
            ConfigSpinBox {
                icon: "splitscreen_bottom"
                text: Translation.tr("Rows")
                value: Config.options.overview.rows
                from: 1
                to: 20
                stepSize: 1
                onValueChanged: {
                    Config.options.overview.rows = value;
                }
            }
            ConfigSpinBox {
                icon: "splitscreen_right"
                text: Translation.tr("Columns")
                value: Config.options.overview.columns
                from: 1
                to: 20
                stepSize: 1
                onValueChanged: {
                    Config.options.overview.columns = value;
                }
            }
        }
        ConfigRow {
            uniform: true
            ConfigSelectionArray {
                currentValue: Config.options.overview.orderRightLeft
                onSelected: newValue => {
                    Config.options.overview.orderRightLeft = newValue
                }
                options: [
                    {
                        displayName: Translation.tr("Left to right"),
                        icon: "arrow_forward",
                        value: 0
                    },
                    {
                        displayName: Translation.tr("Right to left"),
                        icon: "arrow_back",
                        value: 1
                    }
                ]
            }
            ConfigSelectionArray {
                currentValue: Config.options.overview.orderBottomUp
                onSelected: newValue => {
                    Config.options.overview.orderBottomUp = newValue
                }
                options: [
                    {
                        displayName: Translation.tr("Top-down"),
                        icon: "arrow_downward",
                        value: 0
                    },
                    {
                        displayName: Translation.tr("Bottom-up"),
                        icon: "arrow_upward",
                        value: 1
                    }
                ]
            }
        }
    }

}
