import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    id: page
    forceWidth: true

    /**
     * Acciones que puede disparar una esquina caliente. Vive acá y no en GlobalStates
     * porque este fork todavía no la tiene centralizada; los valores son los nombres de
     * las propiedades de GlobalStates, así quien las consuma solo hace toggle por nombre.
     */
    readonly property var hotCornerActions: [
        { displayName: Translation.tr("Nada"), value: "none" },
        { displayName: Translation.tr("Sidebar izquierdo"), value: "sidebarLeftOpen" },
        { displayName: Translation.tr("Sidebar derecho"), value: "sidebarRightOpen" },
        { displayName: Translation.tr("Overview"), value: "overviewOpen" },
        { displayName: Translation.tr("Selector de wallpaper"), value: "wallpaperSelectorOpen" },
        { displayName: Translation.tr("Controles de música"), value: "mediaControlsOpen" },
        { displayName: Translation.tr("Overlay"), value: "overlayOpen" },
        { displayName: Translation.tr("Captura de región"), value: "regionSelectorOpen" },
        { displayName: Translation.tr("Traductor de pantalla"), value: "screenTranslatorOpen" },
        { displayName: Translation.tr("Teclado en pantalla"), value: "oskOpen" },
        { displayName: Translation.tr("Menú de sesión"), value: "sessionOpen" },
    ]

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

    ContentSection {
        icon: "side_navigation"
        title: Translation.tr("Sidebars")
        // Lo específico del sidebar izquierdo (pestañas, AI, traductor, inspo,
        // música, social, anime) vive en su propia página: modules/settings/SidebarConfig.qml

        // Franja con imagen arriba del sidebar derecho
        ConfigSwitch {
            buttonIcon: "planner_banner_ad_pt"
            text: Translation.tr("Banner")
            checked: Config.options.sidebar.banner
            onCheckedChanged: {
                Config.options.sidebar.banner = checked;
            }
        }

        // Vacío = la imagen que viene por defecto
        ConfigTextArea {
            id: bannerImageField
            Layout.fillWidth: true
            enabled: Config.options.sidebar.banner
            buttonIcon: "imagesmode"
            text: Translation.tr("Imagen del banner")
            placeholderText: Translation.tr("Ruta (vacío = la de siempre)")
            fieldWidth: 300
            value: Config.options.sidebar.bannerImage ?? ""
            onValueChanged: {
                bannerImageDebounce.restart();
            }
            // Escribir en cada tecla haría que Config guarde el archivo decenas de veces
            Timer {
                id: bannerImageDebounce
                interval: 1000
                onTriggered: {
                    Config.options.sidebar.bannerImage = bannerImageField.value;
                }
            }
        }

        ConfigSwitch {
            buttonIcon: "music_note"
            text: Translation.tr("Reproductor en el sidebar derecho")
            checked: Config.options.sidebar.mediaPlayer
            onCheckedChanged: {
                Config.options.sidebar.mediaPlayer = checked;
            }
        }

        ConfigSwitch {
            buttonIcon: "memory"
            text: Translation.tr('Keep right sidebar loaded')
            checked: Config.options.sidebar.keepRightSidebarLoaded
            onCheckedChanged: {
                Config.options.sidebar.keepRightSidebarLoaded = checked;
            }
            StyledToolTip {
                text: Translation.tr("When enabled keeps the content of the right sidebar loaded to reduce the delay when opening,\nat the cost of around 15MB of consistent RAM usage. Delay significance depends on your system's performance.\nUsing a custom kernel like linux-cachyos might help")
            }
        }

        ContentSubsection {
            title: Translation.tr("Quick toggles")
            
            ConfigSelectionArray {
                Layout.fillWidth: false
                currentValue: Config.options.sidebar.quickToggles.style
                onSelected: newValue => {
                    Config.options.sidebar.quickToggles.style = newValue;
                }
                options: [
                    {
                        displayName: Translation.tr("Classic"),
                        icon: "password_2",
                        value: "classic"
                    },
                    {
                        displayName: Translation.tr("Android"),
                        icon: "action_key",
                        value: "android"
                    }
                ]
            }

            ConfigSpinBox {
                enabled: Config.options.sidebar.quickToggles.style === "android"
                icon: "splitscreen_left"
                text: Translation.tr("Columns")
                value: Config.options.sidebar.quickToggles.android.columns
                from: 1
                to: 8
                stepSize: 1
                onValueChanged: {
                    Config.options.sidebar.quickToggles.android.columns = value;
                }
            }
        }

        ContentSubsection {
            title: Translation.tr("Sliders")

            ConfigSwitch {
                buttonIcon: "check"
                text: Translation.tr("Enable")
                checked: Config.options.sidebar.quickSliders.enable
                onCheckedChanged: {
                    Config.options.sidebar.quickSliders.enable = checked;
                }
            }
            
            ConfigSwitch {
                buttonIcon: "brightness_6"
                text: Translation.tr("Brightness")
                enabled: Config.options.sidebar.quickSliders.enable
                checked: Config.options.sidebar.quickSliders.showBrightness
                onCheckedChanged: {
                    Config.options.sidebar.quickSliders.showBrightness = checked;
                }
            }

            ConfigSwitch {
                buttonIcon: "volume_up"
                text: Translation.tr("Volume")
                enabled: Config.options.sidebar.quickSliders.enable
                checked: Config.options.sidebar.quickSliders.showVolume
                onCheckedChanged: {
                    Config.options.sidebar.quickSliders.showVolume = checked;
                }
            }

            ConfigSwitch {
                buttonIcon: "mic"
                text: Translation.tr("Microphone")
                enabled: Config.options.sidebar.quickSliders.enable
                checked: Config.options.sidebar.quickSliders.showMic
                onCheckedChanged: {
                    Config.options.sidebar.quickSliders.showMic = checked;
                }
            }
        }

        ContentSubsection {
            title: Translation.tr("Corner open")
            tooltip: Translation.tr("Allows you to open sidebars by clicking or hovering screen corners regardless of bar position")
            ConfigRow {
                uniform: true
                ConfigSwitch {
                    buttonIcon: "check"
                    text: Translation.tr("Enable")
                    checked: Config.options.sidebar.cornerOpen.enable
                    onCheckedChanged: {
                        Config.options.sidebar.cornerOpen.enable = checked;
                    }
                }
            }
            ConfigSwitch {
                buttonIcon: "highlight_mouse_cursor"
                text: Translation.tr("Hover to trigger")
                checked: Config.options.sidebar.cornerOpen.clickless
                onCheckedChanged: {
                    Config.options.sidebar.cornerOpen.clickless = checked;
                }

                StyledToolTip {
                    text: Translation.tr("When this is off you'll have to click")
                }
            }
            Row {
                ConfigSwitch {
                    enabled: !Config.options.sidebar.cornerOpen.clickless
                    text: Translation.tr("Force hover open at absolute corner")
                    checked: Config.options.sidebar.cornerOpen.clicklessCornerEnd
                    onCheckedChanged: {
                        Config.options.sidebar.cornerOpen.clicklessCornerEnd = checked;
                    }

                    StyledToolTip {
                        text: Translation.tr("When the previous option is off and this is on,\nyou can still hover the corner's end to open sidebar,\nand the remaining area can be used for volume/brightness scroll")
                    }
                }
                ConfigSpinBox {
                    icon: "arrow_cool_down"
                    text: Translation.tr("with vertical offset")
                    value: Config.options.sidebar.cornerOpen.clicklessCornerVerticalOffset
                    from: 0
                    to: 20
                    stepSize: 1
                    onValueChanged: {
                        Config.options.sidebar.cornerOpen.clicklessCornerVerticalOffset = value;
                    }
                    // Antes esto era un MouseArea con anchors.fill adentro de un
                    // layout (comportamiento indefinido segun Qt). ConfigSpinBox ya
                    // expone `hovered`, asi que el tooltip solo alcanza.
                    StyledToolTip {
                        text: Translation.tr("Why this is cool:\nFor non-0 values, it won't trigger when you reach the\nscreen corner along the horizontal edge, but it will when\nyou do along the vertical edge")
                    }
                }
            }
            
            ConfigRow {
                uniform: true
                ConfigSwitch {
                    buttonIcon: "vertical_align_bottom"
                    text: Translation.tr("Place at bottom")
                    checked: Config.options.sidebar.cornerOpen.bottom
                    onCheckedChanged: {
                        Config.options.sidebar.cornerOpen.bottom = checked;
                    }

                    StyledToolTip {
                        text: Translation.tr("Place the corners to trigger at the bottom")
                    }
                }
                ConfigSwitch {
                    buttonIcon: "unfold_more_double"
                    text: Translation.tr("Value scroll")
                    checked: Config.options.sidebar.cornerOpen.valueScroll
                    onCheckedChanged: {
                        Config.options.sidebar.cornerOpen.valueScroll = checked;
                    }

                    StyledToolTip {
                        text: Translation.tr("Brightness and volume")
                    }
                }
            }
            ConfigSwitch {
                buttonIcon: "visibility"
                text: Translation.tr("Visualize region")
                checked: Config.options.sidebar.cornerOpen.visualize
                onCheckedChanged: {
                    Config.options.sidebar.cornerOpen.visualize = checked;
                }
            }
            ConfigRow {
                ConfigSpinBox {
                    icon: "arrow_range"
                    text: Translation.tr("Region width")
                    value: Config.options.sidebar.cornerOpen.cornerRegionWidth
                    from: 1
                    to: 300
                    stepSize: 1
                    onValueChanged: {
                        Config.options.sidebar.cornerOpen.cornerRegionWidth = value;
                    }
                }
                ConfigSpinBox {
                    icon: "height"
                    text: Translation.tr("Region height")
                    value: Config.options.sidebar.cornerOpen.cornerRegionHeight
                    from: 1
                    to: 300
                    stepSize: 1
                    onValueChanged: {
                        Config.options.sidebar.cornerOpen.cornerRegionHeight = value;
                    }
                }
            }
        }

        ContentSubsection {
            title: Translation.tr("Esquinas de abajo")
            tooltip: Translation.tr("Qué abre cada esquina inferior cuando el corner open está abajo")

            ConfigComboBox {
                Layout.fillWidth: true
                buttonIcon: "position_bottom_left"
                text: Translation.tr("Abajo a la izquierda")
                model: page.hotCornerActions
                currentValue: Config.options.sidebar.cornerOpen.bottomLeftAction
                onSelected: newValue => {
                    Config.options.sidebar.cornerOpen.bottomLeftAction = newValue;
                }
            }

            ConfigComboBox {
                Layout.fillWidth: true
                buttonIcon: "position_bottom_right"
                text: Translation.tr("Abajo a la derecha")
                model: page.hotCornerActions
                currentValue: Config.options.sidebar.cornerOpen.bottomRightAction
                onSelected: newValue => {
                    Config.options.sidebar.cornerOpen.bottomRightAction = newValue;
                }
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

    ContentSection {
        icon: "wallpaper_slideshow"
        title: Translation.tr("Wallpaper selector")

        ConfigSwitch {
            buttonIcon: "ad"
            text: Translation.tr('Use system file picker')
            checked: Config.options.wallpaperSelector.useSystemFileDialog
            onCheckedChanged: {
                Config.options.wallpaperSelector.useSystemFileDialog = checked;
            }
        }

        ConfigSwitch {
            buttonIcon: "home"
            text: Translation.tr("Mostrar la carpeta personal en los accesos rápidos")
            checked: Config.options.wallpaperSelector.showHomePath
            onCheckedChanged: {
                Config.options.wallpaperSelector.showHomePath = checked;
            }
        }

        ConfigSwitch {
            buttonIcon: "done"
            text: Translation.tr("Cerrar al elegir un wallpaper")
            checked: Config.options.wallpaperSelector.closeAfterSelection
            onCheckedChanged: {
                Config.options.wallpaperSelector.closeAfterSelection = checked;
            }
        }

        ConfigSwitch {
            buttonIcon: "search"
            text: Translation.tr("Buscador siempre visible")
            checked: Config.options.wallpaperSelector.showSearchbar
            onCheckedChanged: {
                Config.options.wallpaperSelector.showSearchbar = checked;
            }
        }

        // Cuesta un poco de GPU, pero se lee mejor la grilla sobre wallpapers claros
        ConfigSwitch {
            buttonIcon: "blur_on"
            text: Translation.tr("Desenfocar el fondo del selector")
            checked: Config.options.wallpaperSelector.showBlurBackground
            onCheckedChanged: {
                Config.options.wallpaperSelector.showBlurBackground = checked;
            }
        }

        ConfigSpinBox {
            icon: "grid_on"
            text: Translation.tr("Columnas de la grilla")
            value: Config.options.wallpaperSelector.columns
            from: 3
            to: 10
            stepSize: 1
            onValueChanged: {
                Config.options.wallpaperSelector.columns = value;
            }
        }

        // Config guarda milisegundos, pero en minutos es mucho más cómodo de tocar. 0 = nunca
        ConfigSpinBox {
            icon: "timer"
            text: Translation.tr("Rotar el wallpaper cada (min, 0 = nunca)")
            value: Config.options.wallpaperSelector.changeInterval / 60000
            from: 0
            to: 1440
            stepSize: 5
            onValueChanged: {
                Config.options.wallpaperSelector.changeInterval = value * 60000;
            }
        }

        ContentSubsection {
            title: Translation.tr("Carpetas")

            ConfigTextArea {
                id: wallpaperUserPathField
                Layout.fillWidth: true
                buttonIcon: "folder"
                text: Translation.tr("Carpeta de wallpapers")
                placeholderText: Translation.tr("Ej: /home/usuario/Imágenes")
                fieldWidth: 300
                value: Config.options.wallpaperSelector.userPath ?? ""
                onValueChanged: {
                    wallpaperUserPathDebounce.restart();
                }
                Timer {
                    id: wallpaperUserPathDebounce
                    interval: 1000
                    onTriggered: {
                        Config.options.wallpaperSelector.userPath = wallpaperUserPathField.value;
                    }
                }
            }

            ConfigTextArea {
                id: liveWallpapersPathField
                Layout.fillWidth: true
                buttonIcon: "video_template"
                text: Translation.tr("Carpeta de wallpapers animados")
                placeholderText: Translation.tr("Ej: /home/usuario/Videos/Wallpapers")
                fieldWidth: 300
                value: Config.options.wallpaperSelector.liveWallpapersPath ?? ""
                onValueChanged: {
                    liveWallpapersPathDebounce.restart();
                }
                Timer {
                    id: liveWallpapersPathDebounce
                    interval: 1000
                    onTriggered: {
                        Config.options.wallpaperSelector.liveWallpapersPath = liveWallpapersPathField.value;
                    }
                }
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

    ContentSection {
        icon: "policy"
        title: Translation.tr("Políticas")

        ContentSubsection {
            title: Translation.tr("Inteligencia artificial")
            tooltip: Translation.tr("\"Local\" deja el chat pero solo con modelos que corran en la máquina")

            ConfigSelectionArray {
                Layout.fillWidth: false
                currentValue: Config.options.policies.ai
                onSelected: newValue => {
                    Config.options.policies.ai = newValue;
                }
                options: [
                    { displayName: Translation.tr("No"), icon: "close", value: 0 },
                    { displayName: Translation.tr("Sí"), icon: "check", value: 1 },
                    { displayName: Translation.tr("Local"), icon: "sync_saved_locally", value: 2 }
                ]
            }
        }

        ContentSubsection {
            title: Translation.tr("Contenido weeb")
            tooltip: Translation.tr("\"Placard\" lo deja disponible pero sin que salte a la vista")

            ConfigSelectionArray {
                Layout.fillWidth: false
                currentValue: Config.options.policies.weeb
                onSelected: newValue => {
                    Config.options.policies.weeb = newValue;
                }
                options: [
                    { displayName: Translation.tr("No"), icon: "close", value: 0 },
                    { displayName: Translation.tr("Sí"), icon: "check", value: 1 },
                    { displayName: Translation.tr("Placard"), icon: "ev_shadow", value: 2 }
                ]
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
        icon: "text_format"
        title: Translation.tr("Fonts")

        ContentSubsection {
            title: Translation.tr("Main font")
            tooltip: Translation.tr("Used for general UI text")

            MaterialTextArea {
                Layout.fillWidth: true
                placeholderText: Translation.tr("Font family name (e.g., Google Sans Flex)")
                text: Config.options.appearance.fonts.main
                wrapMode: TextEdit.NoWrap
                onTextChanged: {
                    Config.options.appearance.fonts.main = text;
                }
            }
        }

        ContentSubsection {
            title: Translation.tr("Numbers font")
            tooltip: Translation.tr("Used for displaying numbers")

            MaterialTextArea {
                Layout.fillWidth: true
                placeholderText: Translation.tr("Font family name")
                text: Config.options.appearance.fonts.numbers
                wrapMode: TextEdit.NoWrap
                onTextChanged: {
                    Config.options.appearance.fonts.numbers = text;
                }
            }
        }

        ContentSubsection {
            title: Translation.tr("Title font")
            tooltip: Translation.tr("Used for headings and titles")

            MaterialTextArea {
                Layout.fillWidth: true
                placeholderText: Translation.tr("Font family name")
                text: Config.options.appearance.fonts.title
                wrapMode: TextEdit.NoWrap
                onTextChanged: {
                    Config.options.appearance.fonts.title = text;
                }
            }
        }

        ContentSubsection {
            title: Translation.tr("Monospace font")
            tooltip: Translation.tr("Used for code and terminal")

            MaterialTextArea {
                Layout.fillWidth: true
                placeholderText: Translation.tr("Font family name (e.g., JetBrains Mono NF)")
                text: Config.options.appearance.fonts.monospace
                wrapMode: TextEdit.NoWrap
                onTextChanged: {
                    Config.options.appearance.fonts.monospace = text;
                }
            }
        }

        ContentSubsection {
            title: Translation.tr("Nerd font icons")
            tooltip: Translation.tr("Font used for Nerd Font icons")

            MaterialTextArea {
                Layout.fillWidth: true
                placeholderText: Translation.tr("Font family name (e.g., JetBrains Mono NF)")
                text: Config.options.appearance.fonts.iconNerd
                wrapMode: TextEdit.NoWrap
                onTextChanged: {
                    Config.options.appearance.fonts.iconNerd = text;
                }
            }
        }

        ContentSubsection {
            title: Translation.tr("Reading font")
            tooltip: Translation.tr("Used for reading large blocks of text")

            MaterialTextArea {
                Layout.fillWidth: true
                placeholderText: Translation.tr("Font family name (e.g., Readex Pro)")
                text: Config.options.appearance.fonts.reading
                wrapMode: TextEdit.NoWrap
                onTextChanged: {
                    Config.options.appearance.fonts.reading = text;
                }
            }
        }

        ContentSubsection {
            title: Translation.tr("Expressive font")
            tooltip: Translation.tr("Used for decorative/expressive text")

            MaterialTextArea {
                Layout.fillWidth: true
                placeholderText: Translation.tr("Font family name (e.g., Space Grotesk)")
                text: Config.options.appearance.fonts.expressive
                wrapMode: TextEdit.NoWrap
                onTextChanged: {
                    Config.options.appearance.fonts.expressive = text;
                }
            }
        }
    }

}
