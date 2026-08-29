import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    forceWidth: true

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
        icon: "wallpaper"
        title: Translation.tr("Wallpaper")

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
        id: settingsClock
        icon: "clock_loader_40"
        title: Translation.tr("Widget: Clock")

        function stylePresent(styleName) {
            if (!Config.options.background.widgets.clock.showOnlyWhenLocked && Config.options.background.widgets.clock.style === styleName) {
                return true;
            }
            if (Config.options.background.widgets.clock.styleLocked === styleName) {
                return true;
            }
            return false;
        }

        readonly property bool digitalPresent: stylePresent("digital")
        readonly property bool cookiePresent: stylePresent("cookie")
        readonly property bool pixelPresent: stylePresent("pixel")

        /**
         * Un estilo puede estar presente por el reloj normal o por el de la pantalla
         * bloqueada. Cuando aparece sólo por el segundo conviene decirlo, si no parece
         * que las opciones no reaccionan al selector de arriba.
         */
        function onlyForLock(styleName) {
            return Config.options.background.widgets.clock.styleLocked === styleName
                && (Config.options.background.widgets.clock.showOnlyWhenLocked
                    || Config.options.background.widgets.clock.style !== styleName);
        }

        ConfigRow {
            Layout.fillWidth: true

            ConfigSwitch {
                Layout.fillWidth: false
                buttonIcon: "check"
                text: Translation.tr("Enable")
                checked: Config.options.background.widgets.clock.enable
                onCheckedChanged: {
                    Config.options.background.widgets.clock.enable = checked;
                }
            }
            Item {
                Layout.fillWidth: true
            }
            ConfigSelectionArray {
                Layout.fillWidth: false
                currentValue: Config.options.background.widgets.clock.placementStrategy
                onSelected: newValue => {
                    Config.options.background.widgets.clock.placementStrategy = newValue;
                }
                options: [
                    {
                        displayName: Translation.tr("Draggable"),
                        icon: "drag_pan",
                        value: "free"
                    },
                    {
                        displayName: Translation.tr("Least busy"),
                        icon: "category",
                        value: "leastBusy"
                    },
                    {
                        displayName: Translation.tr("Most busy"),
                        icon: "shapes",
                        value: "mostBusy"
                    },
                ]
            }
        }

        ContentSubsection {
            title: Translation.tr("Mostrar en")
            PerScreenEnableList {
                configEntry: Config.options.background.widgets.clock
            }
        }

        ContentSubsection {
            title: Translation.tr("Color del reloj")

            // Vacío = sigue la paleta del wallpaper; el switch es la forma de volver a eso
            ConfigSwitch {
                id: clockAutoColorSwitch
                buttonIcon: "auto_awesome"
                text: Translation.tr("Color automático")
                checked: Config.options.background.widgets.clock.color === ""
                onCheckedChanged: {
                    if (checked) {
                        Config.options.background.widgets.clock.color = "";
                    }
                }
            }

            ColorSelectionArray {
                icon: "palette"
                text: Translation.tr("Color fijo")
                currentValue: Config.options.background.widgets.clock.color
                onSelected: newValue => {
                    Config.options.background.widgets.clock.color = newValue;
                    clockAutoColorSwitch.checked = false;
                }
            }
        }

        ConfigSwitch {
            buttonIcon: "lock_clock"
            text: Translation.tr("Show only when locked")
            checked: Config.options.background.widgets.clock.showOnlyWhenLocked
            onCheckedChanged: {
                Config.options.background.widgets.clock.showOnlyWhenLocked = checked;
            }
        }

        ConfigRow {
            ContentSubsection {
                visible: !Config.options.background.widgets.clock.showOnlyWhenLocked
                title: Translation.tr("Clock style")
                Layout.fillWidth: true
                ConfigSelectionArray {
                    currentValue: Config.options.background.widgets.clock.style
                    onSelected: newValue => {
                        Config.options.background.widgets.clock.style = newValue;
                    }
                    options: [
                        {
                            displayName: Translation.tr("Digital"),
                            icon: "timer_10",
                            value: "digital"
                        },
                        {
                            displayName: Translation.tr("Cookie"),
                            icon: "cookie",
                            value: "cookie"
                        },
                        {
                            displayName: Translation.tr("Pixel"),
                            icon: "grid_on",
                            value: "pixel"
                        }
                    ]
                }
            }

            ContentSubsection {
                title: Translation.tr("Clock style (locked)")
                Layout.fillWidth: false
                ConfigSelectionArray {
                    currentValue: Config.options.background.widgets.clock.styleLocked
                    onSelected: newValue => {
                        Config.options.background.widgets.clock.styleLocked = newValue;
                    }
                    options: [
                        {
                            displayName: Translation.tr("Digital"),
                            icon: "timer_10",
                            value: "digital"
                        },
                        {
                            displayName: Translation.tr("Cookie"),
                            icon: "cookie",
                            value: "cookie"
                        },
                        {
                            displayName: Translation.tr("Pixel"),
                            icon: "grid_on",
                            value: "pixel"
                        }
                    ]
                }
            }
        }

        ContentSubsection {
            visible: settingsClock.digitalPresent
            title: settingsClock.onlyForLock("digital")
                ? Translation.tr("Reloj digital (pantalla bloqueada)")
                : Translation.tr("Digital clock settings")
            tooltip: Translation.tr("Font width and roundness settings are only available for some fonts like Google Sans Flex")

            ConfigRow {
                uniform: true
                ConfigSwitch {
                    buttonIcon: "vertical_distribute"
                    text: Translation.tr("Vertical")
                    checked: Config.options.background.widgets.clock.digital.vertical
                    onCheckedChanged: {
                        Config.options.background.widgets.clock.digital.vertical = checked;
                    }
                }
                ConfigSwitch {
                    buttonIcon: "animation"
                    text: Translation.tr("Animate time change")
                    checked: Config.options.background.widgets.clock.digital.animateChange
                    onCheckedChanged: {
                        Config.options.background.widgets.clock.digital.animateChange = checked;
                    }
                }
            }

            ConfigRow {
                uniform: true

                ConfigSwitch {
                    buttonIcon: "date_range"
                    text: Translation.tr("Show date")
                    checked: Config.options.background.widgets.clock.digital.showDate
                    onCheckedChanged: {
                        Config.options.background.widgets.clock.digital.showDate = checked;
                    }
                }
                ConfigSwitch {
                    buttonIcon: "activity_zone"
                    text: Translation.tr("Use adaptive alignment")
                    checked: Config.options.background.widgets.clock.digital.adaptiveAlignment
                    onCheckedChanged: {
                        Config.options.background.widgets.clock.digital.adaptiveAlignment = checked;
                    }
                    StyledToolTip {
                        text: Translation.tr("Aligns the date and quote to left, center or right depending on its position on the screen.")
                    }
                }
            }

            MaterialTextArea {
                Layout.fillWidth: true
                placeholderText: Translation.tr("Font family")
                text: Config.options.background.widgets.clock.digital.font.family
                wrapMode: TextEdit.Wrap
                onTextChanged: {
                    Config.options.background.widgets.clock.digital.font.family = text;
                }
            }

            ConfigSlider {
                text: Translation.tr("Font weight")
                value: Config.options.background.widgets.clock.digital.font.weight
                usePercentTooltip: false
                buttonIcon: "format_bold"
                from: 1
                to: 1000
                stopIndicatorValues: [350]
                onValueChanged: {
                    Config.options.background.widgets.clock.digital.font.weight = value;
                }
            }

            ConfigSlider {
                text: Translation.tr("Font size")
                value: Config.options.background.widgets.clock.digital.font.size
                usePercentTooltip: false
                buttonIcon: "format_size"
                from: 50
                to: 700
                stopIndicatorValues: [90]
                onValueChanged: {
                    Config.options.background.widgets.clock.digital.font.size = value;
                }
            }

            ConfigSlider {
                text: Translation.tr("Font width")
                value: Config.options.background.widgets.clock.digital.font.width
                usePercentTooltip: false
                buttonIcon: "fit_width"
                from: 25
                to: 125
                stopIndicatorValues: [100]
                onValueChanged: {
                    Config.options.background.widgets.clock.digital.font.width = value;
                }
            }
            ConfigSlider {
                text: Translation.tr("Font roundness")
                value: Config.options.background.widgets.clock.digital.font.roundness
                usePercentTooltip: false
                buttonIcon: "line_curve"
                from: 0
                to: 100
                onValueChanged: {
                    Config.options.background.widgets.clock.digital.font.roundness = value;
                }
            }
        }

        ContentSubsection {
            visible: settingsClock.cookiePresent
            title: settingsClock.onlyForLock("cookie")
                ? Translation.tr("Reloj cookie (pantalla bloqueada)")
                : Translation.tr("Cookie clock settings")

            ConfigSwitch {
                buttonIcon: "wand_stars"
                text: Translation.tr("Auto styling with Gemini")
                checked: Config.options.background.widgets.clock.cookie.aiStyling
                onCheckedChanged: {
                    Config.options.background.widgets.clock.cookie.aiStyling = checked;
                }
                StyledToolTip {
                    text: Translation.tr("Uses Gemini to categorize the wallpaper then picks a preset based on it.\nYou'll need to set Gemini API key on the left sidebar first.\nImages are downscaled for performance, but just to be safe,\ndo not select wallpapers with sensitive information.")
                }
            }

            ConfigSwitch {
                buttonIcon: "airwave"
                text: Translation.tr("Use old sine wave cookie implementation")
                checked: Config.options.background.widgets.clock.cookie.useSineCookie
                onCheckedChanged: {
                    Config.options.background.widgets.clock.cookie.useSineCookie = checked;
                }
                StyledToolTip {
                    text: Translation.tr("Looks a bit softer and more consistent with different number of sides,\nbut has less impressive morphing")
                }
            }

            ConfigSpinBox {
                icon: "add_triangle"
                text: Translation.tr("Sides")
                value: Config.options.background.widgets.clock.cookie.sides
                from: 0
                to: 40
                stepSize: 1
                onValueChanged: {
                    Config.options.background.widgets.clock.cookie.sides = value;
                }
            }

            ConfigSwitch {
                buttonIcon: "autoplay"
                text: Translation.tr("Constantly rotate")
                checked: Config.options.background.widgets.clock.cookie.constantlyRotate
                onCheckedChanged: {
                    Config.options.background.widgets.clock.cookie.constantlyRotate = checked;
                }
                StyledToolTip {
                    text: Translation.tr("Makes the clock always rotate. This is extremely expensive\n(expect 50% usage on Intel UHD Graphics) and thus impractical.")
                }
            }

            ConfigRow {

                ConfigSwitch {
                    enabled: Config.options.background.widgets.clock.cookie.dialNumberStyle === "dots" || Config.options.background.widgets.clock.cookie.dialNumberStyle === "full"
                    buttonIcon: "brightness_7"
                    text: Translation.tr("Hour marks")
                    checked: Config.options.background.widgets.clock.cookie.hourMarks
                    onEnabledChanged: {
                        checked = Config.options.background.widgets.clock.cookie.hourMarks;
                    }
                    onCheckedChanged: {
                        Config.options.background.widgets.clock.cookie.hourMarks = checked;
                    }
                    StyledToolTip {
                        text: Translation.tr("Can only be turned on using the 'Dots' or 'Full' dial style for aesthetic reasons")
                    }
                }

                ConfigSwitch {
                    enabled: Config.options.background.widgets.clock.cookie.dialNumberStyle !== "numbers"
                    buttonIcon: "timer_10"
                    text: Translation.tr("Digits in the middle")
                    checked: Config.options.background.widgets.clock.cookie.timeIndicators
                    onEnabledChanged: {
                        checked = Config.options.background.widgets.clock.cookie.timeIndicators;
                    }
                    onCheckedChanged: {
                        Config.options.background.widgets.clock.cookie.timeIndicators = checked;
                    }
                    StyledToolTip {
                        text: Translation.tr("Can't be turned on when using 'Numbers' dial style for aesthetic reasons")
                    }
                }
            }
        }

        ContentSubsection {
            visible: settingsClock.cookiePresent
            title: Translation.tr("Dial style")
            ConfigSelectionArray {
                currentValue: Config.options.background.widgets.clock.cookie.dialNumberStyle
                onSelected: newValue => {
                    Config.options.background.widgets.clock.cookie.dialNumberStyle = newValue;
                    if (newValue !== "dots" && newValue !== "full") {
                        Config.options.background.widgets.clock.cookie.hourMarks = false;
                    }
                    if (newValue === "numbers") {
                        Config.options.background.widgets.clock.cookie.timeIndicators = false;
                    }
                }
                options: [
                    {
                        displayName: "",
                        icon: "block",
                        value: "none"
                    },
                    {
                        displayName: Translation.tr("Dots"),
                        icon: "graph_6",
                        value: "dots"
                    },
                    {
                        displayName: Translation.tr("Full"),
                        icon: "history_toggle_off",
                        value: "full"
                    },
                    {
                        displayName: Translation.tr("Numbers"),
                        icon: "counter_1",
                        value: "numbers"
                    }
                ]
            }
        }

        ContentSubsection {
            visible: settingsClock.cookiePresent
            title: Translation.tr("Hour hand")
            ConfigSelectionArray {
                currentValue: Config.options.background.widgets.clock.cookie.hourHandStyle
                onSelected: newValue => {
                    Config.options.background.widgets.clock.cookie.hourHandStyle = newValue;
                }
                options: [
                    {
                        displayName: "",
                        icon: "block",
                        value: "hide"
                    },
                    {
                        displayName: Translation.tr("Classic"),
                        icon: "radio",
                        value: "classic"
                    },
                    {
                        displayName: Translation.tr("Hollow"),
                        icon: "circle",
                        value: "hollow"
                    },
                    {
                        displayName: Translation.tr("Fill"),
                        icon: "eraser_size_5",
                        value: "fill"
                    },
                ]
            }
        }

        ContentSubsection {
            visible: settingsClock.cookiePresent
            title: Translation.tr("Minute hand")

            ConfigSelectionArray {
                currentValue: Config.options.background.widgets.clock.cookie.minuteHandStyle
                onSelected: newValue => {
                    Config.options.background.widgets.clock.cookie.minuteHandStyle = newValue;
                }
                options: [
                    {
                        displayName: "",
                        icon: "block",
                        value: "hide"
                    },
                    {
                        displayName: Translation.tr("Classic"),
                        icon: "radio",
                        value: "classic"
                    },
                    {
                        displayName: Translation.tr("Thin"),
                        icon: "line_end",
                        value: "thin"
                    },
                    {
                        displayName: Translation.tr("Medium"),
                        icon: "eraser_size_2",
                        value: "medium"
                    },
                    {
                        displayName: Translation.tr("Bold"),
                        icon: "eraser_size_4",
                        value: "bold"
                    },
                ]
            }
        }

        ContentSubsection {
            visible: settingsClock.cookiePresent
            title: Translation.tr("Second hand")

            ConfigSelectionArray {
                currentValue: Config.options.background.widgets.clock.cookie.secondHandStyle
                onSelected: newValue => {
                    Config.options.background.widgets.clock.cookie.secondHandStyle = newValue;
                }
                options: [
                    {
                        displayName: "",
                        icon: "block",
                        value: "hide"
                    },
                    {
                        displayName: Translation.tr("Classic"),
                        icon: "radio",
                        value: "classic"
                    },
                    {
                        displayName: Translation.tr("Line"),
                        icon: "line_end",
                        value: "line"
                    },
                    {
                        displayName: Translation.tr("Dot"),
                        icon: "adjust",
                        value: "dot"
                    },
                ]
            }
        }

        ContentSubsection {
            visible: settingsClock.cookiePresent
            title: Translation.tr("Date style")

            ConfigSelectionArray {
                currentValue: Config.options.background.widgets.clock.cookie.dateStyle
                onSelected: newValue => {
                    Config.options.background.widgets.clock.cookie.dateStyle = newValue;
                }
                options: [
                    {
                        displayName: "",
                        icon: "block",
                        value: "hide"
                    },
                    {
                        displayName: Translation.tr("Bubble"),
                        icon: "bubble_chart",
                        value: "bubble"
                    },
                    {
                        displayName: Translation.tr("Border"),
                        icon: "rotate_right",
                        value: "border"
                    },
                    {
                        displayName: Translation.tr("Rect"),
                        icon: "rectangle",
                        value: "rect"
                    }
                ]
            }
        }

        ContentSubsection {
            visible: settingsClock.pixelPresent
            title: settingsClock.onlyForLock("pixel")
                ? Translation.tr("Reloj pixel (pantalla bloqueada)")
                : Translation.tr("Reloj pixel")
            Layout.fillWidth: true

            ConfigSelectionArray {
                currentValue: Config.options.background.widgets.clock.pixel.orientation
                onSelected: newValue => {
                    Config.options.background.widgets.clock.pixel.orientation = newValue;
                }
                options: [
                    {
                        displayName: Translation.tr("Vertical"),
                        icon: "swap_vert",
                        value: "vertical"
                    },
                    {
                        displayName: Translation.tr("Horizontal"),
                        icon: "swap_horiz",
                        value: "horizontal"
                    }
                ]
            }
        }

        ContentSubsection {
            title: Translation.tr("Quote")

            ConfigSwitch {
                buttonIcon: "check"
                text: Translation.tr("Enable")
                checked: Config.options.background.widgets.clock.quote.enable
                onCheckedChanged: {
                    Config.options.background.widgets.clock.quote.enable = checked;
                }
            }

            // El reloj pixel no tiene familia tipográfica propia, así que no hay qué seguir
            ConfigSwitch {
                buttonIcon: "font_download"
                text: Translation.tr("Usar la tipografía del reloj")
                enabled: Config.options.background.widgets.clock.quote.enable
                    && Config.options.background.widgets.clock.style !== "pixel"
                checked: Config.options.background.widgets.clock.quote.followClock
                onCheckedChanged: {
                    Config.options.background.widgets.clock.quote.followClock = checked;
                }
            }

            MaterialTextArea {
                Layout.fillWidth: true
                placeholderText: Translation.tr("Quote")
                text: Config.options.background.widgets.clock.quote.text
                wrapMode: TextEdit.Wrap
                onTextChanged: {
                    Config.options.background.widgets.clock.quote.text = text;
                }
            }
        }
    }

    ContentSection {
        icon: "weather_mix"
        title: Translation.tr("Widget: Weather")

        ConfigRow {
            Layout.fillWidth: true

            ConfigSwitch {
                Layout.fillWidth: false
                buttonIcon: "check"
                text: Translation.tr("Enable")
                checked: Config.options.background.widgets.weather.enable
                onCheckedChanged: {
                    Config.options.background.widgets.weather.enable = checked;
                }
            }
            Item {
                Layout.fillWidth: true
            }
            ConfigSelectionArray {
                Layout.fillWidth: false
                currentValue: Config.options.background.widgets.weather.placementStrategy
                onSelected: newValue => {
                    Config.options.background.widgets.weather.placementStrategy = newValue;
                }
                options: [
                    {
                        displayName: Translation.tr("Draggable"),
                        icon: "drag_pan",
                        value: "free"
                    },
                    {
                        displayName: Translation.tr("Least busy"),
                        icon: "category",
                        value: "leastBusy"
                    },
                    {
                        displayName: Translation.tr("Most busy"),
                        icon: "shapes",
                        value: "mostBusy"
                    },
                ]
            }
        }

        ContentSubsection {
            title: Translation.tr("Tamaño")
            tooltip: Translation.tr("Cuánta info entra en la tarjeta: lo mismo que se logra estirándola con el mouse")

            ConfigSelectionArray {
                Layout.fillWidth: false
                currentValue: Config.options.background.widgets.weather.sizeMode
                onSelected: newValue => {
                    Config.options.background.widgets.weather.sizeMode = newValue;
                }
                options: [
                    {
                        displayName: Translation.tr("Compacto"),
                        icon: "crop_square",
                        value: "1x1"
                    },
                    {
                        displayName: Translation.tr("Mediano"),
                        icon: "crop_5_4",
                        value: "1x2"
                    },
                    {
                        displayName: Translation.tr("Ancho"),
                        icon: "crop_16_9",
                        value: "1x3"
                    },
                ]
            }
        }

        ContentSubsection {
            title: Translation.tr("Mostrar en")
            PerScreenEnableList {
                configEntry: Config.options.background.widgets.weather
            }
        }
    }

    ContentSection {
        icon: "calendar_month"
        title: Translation.tr("Widget: Calendario")

        ConfigRow {
            Layout.fillWidth: true

            ConfigSwitch {
                Layout.fillWidth: false
                buttonIcon: "check"
                text: Translation.tr("Activar")
                checked: Config.options.background.widgets.calendar.enable
                onCheckedChanged: {
                    Config.options.background.widgets.calendar.enable = checked;
                }
            }
            Item {
                Layout.fillWidth: true
            }
            ConfigSelectionArray {
                Layout.fillWidth: false
                currentValue: Config.options.background.widgets.calendar.placementStrategy
                onSelected: newValue => {
                    Config.options.background.widgets.calendar.placementStrategy = newValue;
                }
                options: [
                    {
                        displayName: Translation.tr("Arrastrable"),
                        icon: "drag_pan",
                        value: "free"
                    },
                    {
                        displayName: Translation.tr("Zona despejada"),
                        icon: "category",
                        value: "leastBusy"
                    },
                    {
                        displayName: Translation.tr("Zona cargada"),
                        icon: "shapes",
                        value: "mostBusy"
                    },
                ]
            }
        }

        ContentSubsection {
            title: Translation.tr("Mostrar en")
            PerScreenEnableList {
                configEntry: Config.options.background.widgets.calendar
            }
        }
    }

    ContentSection {
        icon: "monitor_heart"
        title: Translation.tr("Widget: Recursos")

        ConfigRow {
            Layout.fillWidth: true

            ConfigSwitch {
                Layout.fillWidth: false
                buttonIcon: "check"
                text: Translation.tr("Activar")
                checked: Config.options.background.widgets.resources.enable
                onCheckedChanged: {
                    Config.options.background.widgets.resources.enable = checked;
                }
            }
            Item {
                Layout.fillWidth: true
            }
            ConfigSwitch {
                Layout.fillWidth: false
                buttonIcon: "swap_vert"
                text: Translation.tr("En vertical")
                checked: Config.options.background.widgets.resources.vertical
                onCheckedChanged: {
                    Config.options.background.widgets.resources.vertical = checked;
                }
            }
        }

        ConfigSelectionArray {
            Layout.fillWidth: false
            currentValue: Config.options.background.widgets.resources.placementStrategy
            onSelected: newValue => {
                Config.options.background.widgets.resources.placementStrategy = newValue;
            }
            options: [
                {
                    displayName: Translation.tr("Arrastrable"),
                    icon: "drag_pan",
                    value: "free"
                },
                {
                    displayName: Translation.tr("Zona despejada"),
                    icon: "category",
                    value: "leastBusy"
                },
                {
                    displayName: Translation.tr("Zona cargada"),
                    icon: "shapes",
                    value: "mostBusy"
                },
            ]
        }

        ContentSubsection {
            title: Translation.tr("Mostrar en")
            PerScreenEnableList {
                configEntry: Config.options.background.widgets.resources
            }
        }
    }

    /**
     * Estos widgets ya viven en el escritorio (Background.qml los instancia) pero hasta
     * ahora sólo se prendían desde el click derecho. Acá van sólo los interruptores:
     * la posición y el tamaño se ajustan arrastrándolos.
     *
     * Bajo cada uno, la misma lista de monitores que en las secciones de arriba: sin
     * marcar ninguno el widget sigue el switch de "Enable" en todas las pantallas;
     * destildar una la apaga sólo ahí, para tener widgets distintos por monitor.
     */
    ContentSection {
        icon: "dashboard_customize"
        title: Translation.tr("Otros widgets del fondo")

        ConfigSwitch {
            buttonIcon: "music_note"
            text: Translation.tr("Reproductor")
            checked: Config.options.background.widgets.media.enable
            onCheckedChanged: {
                Config.options.background.widgets.media.enable = checked;
            }
        }
        PerScreenEnableList {
            configEntry: Config.options.background.widgets.media
        }

        ConfigSwitch {
            buttonIcon: "graphic_eq"
            text: Translation.tr("Visualizador de audio")
            checked: Config.options.background.widgets.visualizer.enable
            onCheckedChanged: {
                Config.options.background.widgets.visualizer.enable = checked;
            }
        }
        PerScreenEnableList {
            configEntry: Config.options.background.widgets.visualizer
        }

        ConfigSwitch {
            buttonIcon: "person"
            text: Translation.tr("Tarjeta de usuario")
            checked: Config.options.background.widgets.userCard.enable
            onCheckedChanged: {
                Config.options.background.widgets.userCard.enable = checked;
            }
        }
        PerScreenEnableList {
            configEntry: Config.options.background.widgets.userCard
        }

        ConfigSwitch {
            buttonIcon: "public"
            text: Translation.tr("Reloj mundial")
            checked: Config.options.background.widgets.worldClock.enable
            onCheckedChanged: {
                Config.options.background.widgets.worldClock.enable = checked;
            }
        }
        PerScreenEnableList {
            configEntry: Config.options.background.widgets.worldClock
        }

        ConfigSwitch {
            buttonIcon: "note_stack_add"
            text: Translation.tr("Notas")
            checked: Config.options.background.widgets.notes.enable
            onCheckedChanged: {
                Config.options.background.widgets.notes.enable = checked;
            }
        }
        PerScreenEnableList {
            configEntry: Config.options.background.widgets.notes
        }

        // La imagen se elige desde el propio widget (arrastrándola o con el selector);
        // la forma del recorte sólo se puede cambiar desde acá.
        ConfigSwitch {
            buttonIcon: "image"
            text: Translation.tr("Imagen personalizada")
            checked: Config.options.background.widgets.customImage.enable
            onCheckedChanged: {
                Config.options.background.widgets.customImage.enable = checked;
            }
        }
        PerScreenEnableList {
            configEntry: Config.options.background.widgets.customImage
        }

        ContentSubsection {
            title: Translation.tr("Forma de la imagen personalizada")
            visible: Config.options.background.widgets.customImage.enable

            ConfigSelectionShapeArray {
                Layout.fillWidth: true
                currentValue: Config.options.background.widgets.customImage.shape
                shapeColor: Appearance.colors.colPrimary
                backgroundColor: Appearance.colors.colPrimaryContainer
                options: ["Circle", "Square", "Cookie4Sided", "Cookie12Sided", "Clover4Leaf", "Pill", "Heart"]
                onSelected: newValue => {
                    Config.options.background.widgets.customImage.shape = newValue;
                }
            }
        }

        ConfigSwitch {
            buttonIcon: "photo_library"
            text: Translation.tr("Conversor de imágenes")
            checked: Config.options.background.widgets.images.enable
            onCheckedChanged: {
                Config.options.background.widgets.images.enable = checked;
            }
        }
        PerScreenEnableList {
            configEntry: Config.options.background.widgets.images
        }
    }

    ContentSection {
        icon: "widgets"
        title: Translation.tr("Comportamiento de los widgets")

        ContentSubsection {
            title: Translation.tr("Mostrarlos en")
            tooltip: Translation.tr("Sin ninguno marcado se dibujan en todos los monitores")

            WidgetsMonitorSelector {
                configEntry: Config.options.background
            }
        }

        ConfigSwitch {
            buttonIcon: "lock"
            text: Translation.tr("Fijar los widgets en su lugar")
            checked: Config.options.background.widgetsLocked
            onCheckedChanged: {
                Config.options.background.widgetsLocked = checked;
            }
        }

        ConfigSwitch {
            buttonIcon: "straighten"
            text: Translation.tr("Líneas guía al alinear")
            checked: Config.options.background.showSnapLines
            onCheckedChanged: {
                Config.options.background.showSnapLines = checked;
            }
        }

        ConfigSwitch {
            buttonIcon: "grid_4x4"
            text: Translation.tr("Grilla mientras arrastrás")
            checked: Config.options.background.showGrid
            onCheckedChanged: {
                Config.options.background.showGrid = checked;
            }
        }

        ConfigSwitch {
            buttonIcon: "shadow"
            text: Translation.tr("Sombra bajo los widgets")
            checked: Config.options.background.widgets.enableShadows
            onCheckedChanged: {
                Config.options.background.widgets.enableShadows = checked;
            }
        }

        ConfigSwitch {
            buttonIcon: "visibility"
            text: Translation.tr("Mostrarlos con la pantalla bloqueada")
            checked: Config.options.lock.showWidgets
            onCheckedChanged: {
                Config.options.lock.showWidgets = checked;
            }
        }
    }

}
