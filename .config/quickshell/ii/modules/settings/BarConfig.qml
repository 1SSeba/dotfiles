import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    id: page
    forceWidth: true

    /**
     * Catálogo de widgets que la barra por configuración sabe resolver.
     *
     * El `id` no es decorativo: `BarLayoutContent` lo capitaliza y busca
     * `./<Id>.qml` en `modules/ii/bar/`, así que agregar acá un id sin archivo
     * detrás deja un hueco silencioso en la barra.
     */
    property var allWidgets: [
        { id: "leftSidebarButton",    name: Translation.tr("Left Sidebar Button"), icon: "left_panel_open" },
        { id: "workspaces",           name: Translation.tr("Workspaces"),          icon: "steppers" },
        { id: "weatherBar",           name: Translation.tr("Weather"),             icon: "flare" },
        { id: "media",                name: Translation.tr("Media"),               icon: "music_note" },
        { id: "resources",            name: Translation.tr("Resources"),           icon: "empty_dashboard" },
        { id: "systemIcons",          name: Translation.tr("System Icons"),        icon: "info" },
        { id: "networkSpeed",         name: Translation.tr("Network Speed"),       icon: "network_check" },
        { id: "clockWidget",          name: Translation.tr("Clock"),               icon: "schedule" },
        { id: "utilButtons",          name: Translation.tr("Util Buttons"),        icon: "toggle_on" },
        { id: "volumeScroll",         name: Translation.tr("Volume (scroll)"),     icon: "volume_up" },
        { id: "brightnessScroll",     name: Translation.tr("Brightness (scroll)"), icon: "brightness_medium" },
        { id: "sysTray",              name: Translation.tr("Tray"),                icon: "inbox" },
        { id: "batteryIndicator",     name: Translation.tr("Battery"),             icon: "battery_android_frame_full" },
        { id: "activeWindow",         name: Translation.tr("Active Window"),       icon: "subtitles" },
        { id: "powerButton",          name: Translation.tr("Power Button"),        icon: "power_settings_new" },
        { id: "updatesCount",         name: Translation.tr("Updates"),             icon: "deployed_code_update" },
        { id: "docktoPanel",          name: Translation.tr("Dock to Panel"),       icon: "apps" },
        { id: "visualizer",           name: Translation.tr("Visualizer"),          icon: "graphic_eq" },
        { id: "hyprlandXkbIndicator", name: Translation.tr("Keyboard Layout"),     icon: "keyboard" },
        { id: "divisor",              name: Translation.tr("Divider"),             icon: "horizontal_distribute" },
        { id: "launcherButton",       name: Translation.tr("Launcher Button"),     icon: "search" }
    ]

    /**
     * Lo que todavía se puede sumar a una sección.
     *
     * Un widget ya colocado no se vuelve a ofrecer, porque duplicarlo rompe la
     * barra (dos relojes, dos bandejas). Las excepciones son los que sí tienen
     * sentido repetidos: el visualizador se espeja de a pares y el divisor
     * existe justamente para ir varias veces.
     */
    function availableFor() {
        let used = [
            ...Config.options.bar.layouts.leftLayout,
            ...Config.options.bar.layouts.middleLayout,
            ...Config.options.bar.layouts.rightLayout
        ];
        const multipleAllowed = ["visualizer", "divisor"];
        return allWidgets.filter(w => !used.includes(w.id) || multipleAllowed.includes(w.id));
    }

    /** La config guarda ids; el usuario tiene que ver nombres. */
    function getWidgetName(id) {
        const w = allWidgets.find(w => w.id === id);
        return w ? w.name : id;
    }

    ContentSection {
        icon: "monitor"
        shape: MaterialShape.Shape.ClamShell
        title: Translation.tr("Screens")
        // Con un solo monitor la lista no decide nada: se esconde entera.
        visible: Hyprland.monitors.values.length > 1

        ContentSubsection {
            title: Translation.tr("Show bar on")

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: allSwitchItem.implicitHeight + 16 + 8
                    color: Appearance.colors.colLayer1
                    topLeftRadius: Appearance.rounding.normal
                    topRightRadius: Appearance.rounding.normal
                    bottomLeftRadius: Appearance.rounding.unsharpenmore
                    bottomRightRadius: Appearance.rounding.unsharpenmore

                    ConfigSwitch {
                        id: allSwitchItem
                        anchors {
                            fill: parent
                            margins: 8
                        }
                        buttonIcon: "tv_displays"
                        text: Translation.tr("All")
                        // La lista vacía ya significa "todas": no hace falta enumerarlas.
                        onCheckedChanged: {
                            if (checked)
                                Config.options.bar.screenList = [];
                        }

                        // Binding y no una asignación directa, así el switch vuelve a
                        // reflejar la config cuando la cambian los otros switches.
                        Binding {
                            target: allSwitchItem
                            property: "checked"
                            value: Config.options.bar.screenList.length === 0
                            restoreMode: Binding.RestoreBinding
                        }
                    }
                }

                Repeater {
                    model: Hyprland.monitors
                    delegate: Rectangle {
                        id: monitorRow
                        required property var modelData
                        required property int index
                        readonly property bool isLast: index === Hyprland.monitors.values.length - 1

                        Layout.fillWidth: true
                        implicitHeight: switchItem.implicitHeight + 16 + 8
                        color: Appearance.colors.colLayer1
                        topLeftRadius: Appearance.rounding.unsharpenmore
                        topRightRadius: Appearance.rounding.unsharpenmore
                        bottomLeftRadius: isLast ? Appearance.rounding.normal : Appearance.rounding.unsharpenmore
                        bottomRightRadius: isLast ? Appearance.rounding.normal : Appearance.rounding.unsharpenmore

                        ConfigSwitch {
                            id: switchItem
                            anchors {
                                fill: parent
                                margins: 8
                            }
                            buttonIcon: "monitor"
                            text: monitorRow.modelData.name
                            onCheckedChanged: {
                                // Se parte de la lista real de monitores cuando la config
                                // está vacía, si no destildar uno dejaría la lista en cero
                                // y volvería a significar "todas".
                                const allNames = Hyprland.monitors.values.map(m => m.name);
                                let list = Config.options.bar.screenList.length === 0 ? allNames.slice() : Config.options.bar.screenList.slice();
                                if (checked) {
                                    if (!list.includes(monitorRow.modelData.name))
                                        list.push(monitorRow.modelData.name);
                                } else {
                                    list = list.filter(s => s !== monitorRow.modelData.name);
                                }
                                // Si quedaron todas, se vuelve a la forma canónica: vacía.
                                Config.options.bar.screenList = list.length === allNames.length ? [] : list;
                            }

                            Binding {
                                target: switchItem
                                property: "checked"
                                value: Config.options.bar.screenList.length === 0 || Config.options.bar.screenList.includes(monitorRow.modelData.name)
                                restoreMode: Binding.RestoreBinding
                            }
                        }
                    }
                }
            }
        }
    }

    ContentSection {
        icon: "splitscreen_add"
        shape: MaterialShape.Shape.Cookie6Sided
        title: Translation.tr("Bar layout")

        ConfigSwitch {
            buttonIcon: "dashboard_customize"
            text: Translation.tr("Build the bar from these lists")
            checked: Config.options.bar.layouts.enable
            onCheckedChanged: {
                Config.options.bar.layouts.enable = checked;
            }
        }

        ContentSubsection {
            title: Translation.tr("Grouping")
            // Sin la barra por listas los grupos los define el QML escrito a mano.
            visible: Config.options.bar.layouts.enable

            ConfigSelectionArray {
                currentValue: Config.options.bar.layouts.grouping
                onSelected: newValue => {
                    Config.options.bar.layouts.grouping = newValue;
                }
                options: [
                    {
                        displayName: Translation.tr("Between dividers"),
                        icon: "location_chip",
                        value: "auto"
                    },
                    {
                        displayName: Translation.tr("No grouping"),
                        icon: "close",
                        value: "none"
                    }
                ]
            }

            NoticeBox {
                Layout.fillWidth: true
                materialIcon: "info"
                text: Translation.tr("Each run of widgets between two dividers becomes one pill. Its look comes from \"Group style\" and \"Group color\" below.")
            }
        }

        // El marco de pantalla lee estas listas siempre, así que editarlas sirve
        // aunque la barra por configuración esté apagada. Se avisa para que nadie
        // crea que el cambio no tuvo efecto.
        NoticeBox {
            Layout.fillWidth: true
            visible: !Config.options.bar.layouts.enable
            materialIcon: "info"
            text: Translation.tr("The handwritten bar is in use. These lists still feed the screen frame.")
        }

        GroupedList {
            LayoutSection {
                sectionTitle: Config.options.bar.vertical ? Translation.tr("Top") : Translation.tr("Left")
                layout: Config.options.bar.layouts.leftLayout
                availableWidgets: page.availableFor()
                getWidgetName: page.getWidgetName
                onUpdate: list => Config.options.bar.layouts.leftLayout = list
            }

            LayoutSection {
                sectionTitle: Translation.tr("Center")
                layout: Config.options.bar.layouts.middleLayout
                availableWidgets: page.availableFor()
                getWidgetName: page.getWidgetName
                onUpdate: list => Config.options.bar.layouts.middleLayout = list
            }

            LayoutSection {
                sectionTitle: Config.options.bar.vertical ? Translation.tr("Bottom") : Translation.tr("Right")
                layout: Config.options.bar.layouts.rightLayout
                availableWidgets: page.availableFor()
                getWidgetName: page.getWidgetName
                onUpdate: list => Config.options.bar.layouts.rightLayout = list
            }
        }
    }

    ContentSection {
        icon: "notifications"
        title: Translation.tr("Notifications")

        // Combo y no ConfigSelectionArray: seis posiciones no entran cómodas en fila.
        ConfigComboBox {
            Layout.fillWidth: true
            buttonIcon: "my_location"
            text: Translation.tr("Popup position")
            currentValue: Config.options.notifications.position
            fieldWidth: 160
            onSelected: newValue => {
                Config.options.notifications.position = newValue;
            }
            model: [
                {
                    displayName: Translation.tr("Top left"),
                    icon: "north_west",
                    value: "top_left"
                },
                {
                    displayName: Translation.tr("Top center"),
                    icon: "north",
                    value: "top_center"
                },
                {
                    displayName: Translation.tr("Top right"),
                    icon: "north_east",
                    value: "top_right"
                },
                {
                    displayName: Translation.tr("Bottom left"),
                    icon: "south_west",
                    value: "bottom_left"
                },
                {
                    displayName: Translation.tr("Bottom center"),
                    icon: "south",
                    value: "bottom_center"
                },
                {
                    displayName: Translation.tr("Bottom right"),
                    icon: "south_east",
                    value: "bottom_right"
                }
            ]
        }

        ConfigSwitch {
            buttonIcon: "counter_2"
            text: Translation.tr("Unread indicator: show count")
            checked: Config.options.bar.indicators.notifications.showUnreadCount
            onCheckedChanged: {
                Config.options.bar.indicators.notifications.showUnreadCount = checked;
            }
        }
    }

    ContentSection {
        icon: "spoke"
        title: Translation.tr("Positioning")

        ConfigRow {
            ContentSubsection {
                title: Translation.tr("Bar position")
                Layout.fillWidth: true

                ConfigSelectionArray {
                    currentValue: (Config.options.bar.bottom ? 1 : 0) | (Config.options.bar.vertical ? 2 : 0)
                    onSelected: newValue => {
                        Config.options.bar.bottom = (newValue & 1) !== 0;
                        Config.options.bar.vertical = (newValue & 2) !== 0;
                    }
                    options: [
                        {
                            displayName: Translation.tr("Top"),
                            icon: "arrow_upward",
                            value: 0 // bottom: false, vertical: false
                        },
                        {
                            displayName: Translation.tr("Left"),
                            icon: "arrow_back",
                            value: 2 // bottom: false, vertical: true
                        },
                        {
                            displayName: Translation.tr("Bottom"),
                            icon: "arrow_downward",
                            value: 1 // bottom: true, vertical: false
                        },
                        {
                            displayName: Translation.tr("Right"),
                            icon: "arrow_forward",
                            value: 3 // bottom: true, vertical: true
                        }
                    ]
                }
            }
            ContentSubsection {
                title: Translation.tr("Automatically hide")
                Layout.fillWidth: false

                ConfigSelectionArray {
                    currentValue: Config.options.bar.autoHide.enable
                    onSelected: newValue => {
                        Config.options.bar.autoHide.enable = newValue; // Update local copy
                    }
                    options: [
                        {
                            displayName: Translation.tr("No"),
                            icon: "close",
                            value: false
                        },
                        {
                            displayName: Translation.tr("Yes"),
                            icon: "check",
                            value: true
                        }
                    ]
                }
            }
        }

        ConfigRow {

            ContentSubsection {
                title: Translation.tr("Corner style")
                Layout.fillWidth: true

                ConfigSelectionArray {
                    currentValue: Config.options.bar.cornerStyle
                    onSelected: newValue => {
                        Config.options.bar.cornerStyle = newValue; // Update local copy
                    }
                    options: [
                        {
                            displayName: Translation.tr("Hug"),
                            icon: "line_curve",
                            value: 0
                        },
                        {
                            displayName: Translation.tr("Float"),
                            icon: "page_header",
                            value: 1
                        },
                        {
                            displayName: Translation.tr("Rect"),
                            icon: "toolbar",
                            value: 2
                        }
                    ]
                }
            }

            ContentSubsection {
                title: Translation.tr("Group style")
                Layout.fillWidth: false

                ConfigSelectionArray {
                    currentValue: Config.options.bar.borderless
                    onSelected: newValue => {
                        Config.options.bar.borderless = newValue; // Update local copy
                    }
                    options: [
                        {
                            displayName: Translation.tr("Pills"),
                            icon: "location_chip",
                            value: false
                        },
                        {
                            displayName: Translation.tr("Line-separated"),
                            icon: "split_scene",
                            value: true
                        }
                    ]
                }
            }
        }

        ConfigSwitch {
            buttonIcon: "variable_insert"
            text: Translation.tr("Show background")
            // En Rect la barra ya es un bloque opaco: apagarle el fondo no cambia nada.
            enabled: Config.options.bar.cornerStyle === 0 || Config.options.bar.cornerStyle === 1
            checked: Config.options.bar.showBackground
            onCheckedChanged: {
                Config.options.bar.showBackground = checked;
            }
        }

        ConfigSwitch {
            buttonIcon: "short_text"
            text: Translation.tr("Verbose (show text next to icons)")
            checked: Config.options.bar.verbose
            onCheckedChanged: {
                Config.options.bar.verbose = checked;
            }
        }

        MaterialTextArea {
            Layout.fillWidth: true
            placeholderText: Translation.tr('Top-left icon ("distro" or an icon name from assets/icons)')
            text: Config.options.bar.topLeftIcon
            wrapMode: TextEdit.NoWrap
            onTextChanged: {
                Config.options.bar.topLeftIcon = text;
            }
        }

        ColorSelectionArray {
            icon: "brush"
            text: Translation.tr("Group color")
            options: ["primaryContainer", "secondaryContainer", "tertiaryContainer", "layer1", "layer0"]
            currentValue: Config.options.bar.groupColor
            onSelected: newValue => {
                Config.options.bar.groupColor = newValue;
            }
        }

        ContentSubsection {
            title: Translation.tr("Screen frame")

            ConfigRow {
                uniform: true
                ConfigSwitch {
                    buttonIcon: "panorama_wide_angle"
                    text: Translation.tr("Show frame")
                    checked: Config.options.bar.showFrame
                    onCheckedChanged: {
                        Config.options.bar.showFrame = checked;
                    }
                }
                ConfigSwitch {
                    buttonIcon: "colors"
                    // Sin marco no hay color al que seguir.
                    enabled: Config.options.bar.showFrame
                    text: Translation.tr("Follow frame color")
                    checked: Config.options.bar.followFrameColor
                    onCheckedChanged: {
                        Config.options.bar.followFrameColor = checked;
                    }
                }
            }

            ConfigSpinBox {
                icon: "eraser_size_1"
                enabled: Config.options.bar.showFrame
                text: Translation.tr("Frame thickness")
                value: Config.options.bar.frameThickness
                from: 1
                to: 10
                stepSize: 1
                onValueChanged: {
                    Config.options.bar.frameThickness = value;
                }
            }

            // Sólo colores opacos: el marco con transparencia deja ver el borde de las
            // ventanas por debajo y queda sucio.
            ColorSelectionArray {
                icon: "imagesearch_roller"
                text: Translation.tr("Frame color")
                options: ["primaryContainer", "secondaryContainer", "tertiaryContainer", "layer0", "black"]
                currentValue: Config.options.bar.frameColor
                onSelected: newValue => {
                    Config.options.bar.frameColor = newValue;
                }
            }
        }
    }

    ContentSection {
        icon: "vertical_align_center"
        shape: MaterialShape.Shape.Diamond
        title: Translation.tr("Divider")

        ContentSubsection {
            title: Translation.tr("Style")

            ConfigSelectionArray {
                currentValue: Config.options.bar.divider.style
                onSelected: newValue => {
                    Config.options.bar.divider.style = newValue;
                }
                options: [
                    {
                        displayName: Translation.tr("Line"),
                        icon: "more_vert",
                        value: "rect"
                    },
                    {
                        displayName: Translation.tr("Dot"),
                        icon: "fiber_manual_record",
                        value: "dot"
                    },
                    {
                        displayName: Translation.tr("Space"),
                        icon: "space_bar",
                        value: "space"
                    }
                ]
            }
        }

        ConfigSpinBox {
            icon: "width"
            // Los otros dos estilos dibujan algo de ancho fijo; el hueco es lo único
            // que se mide.
            enabled: Config.options.bar.divider.style === "space"
            text: Translation.tr("Space width (px)")
            value: Config.options.bar.divider.spacing
            from: 4
            to: 400
            stepSize: 2
            onValueChanged: {
                Config.options.bar.divider.spacing = value;
            }
        }
    }

    ContentSection {
        icon: "shelf_auto_hide"
        title: Translation.tr("Tray")

        ConfigSwitch {
            buttonIcon: "keep"
            text: Translation.tr('Make icons pinned by default')
            checked: Config.options.tray.invertPinnedItems
            onCheckedChanged: {
                Config.options.tray.invertPinnedItems = checked;
            }
        }

        ConfigSwitch {
            buttonIcon: "colors"
            text: Translation.tr('Tint icons')
            checked: Config.options.tray.monochromeIcons
            onCheckedChanged: {
                Config.options.tray.monochromeIcons = checked;
            }
        }

        ConfigSwitch {
            buttonIcon: "visibility_off"
            text: Translation.tr('Hide "passive" icons')
            checked: Config.options.tray.filterPassive
            onCheckedChanged: {
                Config.options.tray.filterPassive = checked;
            }
        }

        ConfigSwitch {
            buttonIcon: "tag"
            text: Translation.tr("Show technical item ID")
            checked: Config.options.tray.showItemId
            onCheckedChanged: {
                Config.options.tray.showItemId = checked;
            }
        }
    }

    ContentSection {
        icon: "widgets"
        title: Translation.tr("Utility buttons")

        ConfigRow {
            uniform: true
            ConfigSwitch {
                buttonIcon: "content_cut"
                text: Translation.tr("Screen snip")
                checked: Config.options.bar.utilButtons.showScreenSnip
                onCheckedChanged: {
                    Config.options.bar.utilButtons.showScreenSnip = checked;
                }
            }
            ConfigSwitch {
                buttonIcon: "colorize"
                text: Translation.tr("Color picker")
                checked: Config.options.bar.utilButtons.showColorPicker
                onCheckedChanged: {
                    Config.options.bar.utilButtons.showColorPicker = checked;
                }
            }
        }
        ConfigRow {
            uniform: true
            ConfigSwitch {
                buttonIcon: "keyboard"
                text: Translation.tr("Keyboard toggle")
                checked: Config.options.bar.utilButtons.showKeyboardToggle
                onCheckedChanged: {
                    Config.options.bar.utilButtons.showKeyboardToggle = checked;
                }
            }
            ConfigSwitch {
                buttonIcon: "mic"
                text: Translation.tr("Mic toggle")
                checked: Config.options.bar.utilButtons.showMicToggle
                onCheckedChanged: {
                    Config.options.bar.utilButtons.showMicToggle = checked;
                }
            }
        }
        ConfigRow {
            uniform: true
            ConfigSwitch {
                buttonIcon: "dark_mode"
                text: Translation.tr("Dark/Light toggle")
                checked: Config.options.bar.utilButtons.showDarkModeToggle
                onCheckedChanged: {
                    Config.options.bar.utilButtons.showDarkModeToggle = checked;
                }
            }
            ConfigSwitch {
                buttonIcon: "speed"
                text: Translation.tr("Performance Profile toggle")
                checked: Config.options.bar.utilButtons.showPerformanceProfileToggle
                onCheckedChanged: {
                    Config.options.bar.utilButtons.showPerformanceProfileToggle = checked;
                }
            }
        }
        ConfigRow {
            uniform: true
            ConfigSwitch {
                buttonIcon: "videocam"
                text: Translation.tr("Record")
                checked: Config.options.bar.utilButtons.showScreenRecord
                onCheckedChanged: {
                    Config.options.bar.utilButtons.showScreenRecord = checked;
                }
            }
            ConfigSwitch {
                buttonIcon: "imagesmode"
                text: Translation.tr("Wallpaper toggle")
                checked: Config.options.bar.utilButtons.showWallpaperToggle
                onCheckedChanged: {
                    Config.options.bar.utilButtons.showWallpaperToggle = checked;
                }
            }
        }
    }

    ContentSection {
        icon: "cloud"
        title: Translation.tr("Weather")
        ConfigSwitch {
            buttonIcon: "check"
            text: Translation.tr("Enable")
            checked: Config.options.bar.weather.enable
            onCheckedChanged: {
                Config.options.bar.weather.enable = checked;
            }
        }
    }

    ContentSection {
        icon: "workspaces"
        title: Translation.tr("Workspaces")

        ConfigSwitch {
            buttonIcon: "counter_1"
            text: Translation.tr('Always show numbers')
            checked: Config.options.bar.workspaces.alwaysShowNumbers
            onCheckedChanged: {
                Config.options.bar.workspaces.alwaysShowNumbers = checked;
            }
        }

        ConfigSwitch {
            buttonIcon: "award_star"
            text: Translation.tr('Show app icons')
            checked: Config.options.bar.workspaces.showAppIcons
            onCheckedChanged: {
                Config.options.bar.workspaces.showAppIcons = checked;
            }
        }

        ConfigSwitch {
            buttonIcon: "colors"
            text: Translation.tr('Tint app icons')
            checked: Config.options.bar.workspaces.monochromeIcons
            onCheckedChanged: {
                Config.options.bar.workspaces.monochromeIcons = checked;
            }
        }

        ConfigSpinBox {
            icon: "view_column"
            text: Translation.tr("Workspaces shown")
            value: Config.options.bar.workspaces.shown
            from: 1
            to: 30
            stepSize: 1
            onValueChanged: {
                Config.options.bar.workspaces.shown = value;
            }
        }

        ConfigSpinBox {
            icon: "touch_long"
            text: Translation.tr("Number show delay when pressing Super (ms)")
            value: Config.options.bar.workspaces.showNumberDelay
            from: 0
            to: 1000
            stepSize: 50
            onValueChanged: {
                Config.options.bar.workspaces.showNumberDelay = value;
            }
        }

        ContentSubsection {
            title: Translation.tr("Number style")

            ConfigSelectionArray {
                currentValue: JSON.stringify(Config.options.bar.workspaces.numberMap)
                onSelected: newValue => {
                    Config.options.bar.workspaces.numberMap = JSON.parse(newValue)
                }
                options: [
                    {
                        displayName: Translation.tr("Normal"),
                        icon: "timer_10",
                        value: '[]'
                    },
                    {
                        displayName: Translation.tr("Han chars"),
                        icon: "square_dot",
                        value: '["一","二","三","四","五","六","七","八","九","十","十一","十二","十三","十四","十五","十六","十七","十八","十九","二十"]'
                    },
                    {
                        displayName: Translation.tr("Roman"),
                        icon: "account_balance",
                        value: '["I","II","III","IV","V","VI","VII","VIII","IX","X","XI","XII","XIII","XIV","XV","XVI","XVII","XVIII","XIX","XX"]'
                    }
                ]
            }
        }

        ContentSubsection {
            title: Translation.tr("Indicator style")

            ConfigSelectionArray {
                currentValue: Config.options.bar.workspaces.indicatorStyle
                onSelected: newValue => {
                    Config.options.bar.workspaces.indicatorStyle = newValue;
                }
                options: [
                    {
                        displayName: Translation.tr("Dots"),
                        icon: "radio_button_checked",
                        value: "dot"
                    },
                    {
                        displayName: Translation.tr("Icons"),
                        icon: "interests",
                        value: "icon"
                    }
                ]
            }
        }
    }

    ContentSection {
        icon: "empty_dashboard"
        shape: MaterialShape.Shape.Burst
        title: Translation.tr("Resources")

        ContentSubsection {
            title: Translation.tr("Always visible")

            ConfigRow {
                uniform: true
                ConfigSwitch {
                    buttonIcon: "planner_review"
                    text: Translation.tr("CPU")
                    checked: Config.options.bar.resources.alwaysShowCpu
                    onCheckedChanged: {
                        Config.options.bar.resources.alwaysShowCpu = checked;
                    }
                }
                ConfigSwitch {
                    buttonIcon: "thermostat"
                    text: Translation.tr("CPU temperature")
                    checked: Config.options.bar.resources.alwaysShowCpuTemp
                    onCheckedChanged: {
                        Config.options.bar.resources.alwaysShowCpuTemp = checked;
                    }
                }
            }
            ConfigRow {
                uniform: true
                ConfigSwitch {
                    buttonIcon: "memory"
                    text: Translation.tr("RAM")
                    checked: Config.options.bar.resources.alwaysShowRam
                    onCheckedChanged: {
                        Config.options.bar.resources.alwaysShowRam = checked;
                    }
                }
                ConfigSwitch {
                    buttonIcon: "storage"
                    text: Translation.tr("Disk")
                    checked: Config.options.bar.resources.alwaysShowDisk
                    onCheckedChanged: {
                        Config.options.bar.resources.alwaysShowDisk = checked;
                    }
                }
            }
            ConfigRow {
                uniform: true
                ConfigSwitch {
                    buttonIcon: "swap_horiz"
                    text: Translation.tr("Swap")
                    checked: Config.options.bar.resources.alwaysShowSwap
                    onCheckedChanged: {
                        Config.options.bar.resources.alwaysShowSwap = checked;
                    }
                }
            }
        }

        ContentSubsection {
            title: Translation.tr("Style")

            // La config trae "default" de fábrica, que no es ninguna de las dos
            // opciones del fork: se lee como "filled" para que el selector no
            // arranque sin nada marcado.
            ConfigSelectionArray {
                currentValue: Config.options.bar.resources.style === "outline" ? "outline" : "filled"
                onSelected: newValue => {
                    Config.options.bar.resources.style = newValue;
                }
                options: [
                    {
                        displayName: Translation.tr("Filled"),
                        icon: "incomplete_circle",
                        value: "filled"
                    },
                    {
                        displayName: Translation.tr("Outline"),
                        icon: "circles",
                        value: "outline"
                    }
                ]
            }
        }

        ConfigSwitch {
            buttonIcon: "decimal_increase"
            text: Translation.tr("Show percentage")
            checked: Config.options.bar.resources.showValue
            onCheckedChanged: {
                Config.options.bar.resources.showValue = checked;
            }
        }

        ConfigSpinBox {
            icon: "av_timer"
            text: Translation.tr("Polling interval (ms)")
            value: Config.options.resources.updateInterval
            from: 100
            to: 10000
            stepSize: 100
            onValueChanged: {
                Config.options.resources.updateInterval = value;
            }
        }

        ContentSubsection {
            title: Translation.tr("Warning thresholds (%)")

            ConfigRow {
                uniform: true
                ConfigSpinBox {
                    icon: "planner_review"
                    text: Translation.tr("CPU")
                    value: Config.options.bar.resources.cpuWarningThreshold
                    from: 1
                    to: 100
                    stepSize: 5
                    onValueChanged: {
                        Config.options.bar.resources.cpuWarningThreshold = value;
                    }
                }
                ConfigSpinBox {
                    icon: "memory"
                    text: Translation.tr("Memory")
                    value: Config.options.bar.resources.memoryWarningThreshold
                    from: 1
                    to: 100
                    stepSize: 5
                    onValueChanged: {
                        Config.options.bar.resources.memoryWarningThreshold = value;
                    }
                }
                ConfigSpinBox {
                    icon: "swap_horiz"
                    text: Translation.tr("Swap")
                    value: Config.options.bar.resources.swapWarningThreshold
                    from: 1
                    to: 100
                    stepSize: 5
                    onValueChanged: {
                        Config.options.bar.resources.swapWarningThreshold = value;
                    }
                }
            }
        }
    }

    ContentSection {
        icon: "music_note"
        shape: MaterialShape.Shape.Sunny
        title: Translation.tr("Media")

        ConfigTextArea {
            id: preferredPlayerField
            Layout.fillWidth: true
            buttonIcon: "play_circle"
            text: Translation.tr("Preferred player")
            placeholderText: Translation.tr("e.g. spotify, firefox")
            value: Config.options.bar.media.preferredPlayer
            onValueChanged: {
                mediaDebounceTimer.restart();
            }

            // Cada tecla dispararía una escritura de la config: se espera a que pare.
            Timer {
                id: mediaDebounceTimer
                interval: 600
                repeat: false
                onTriggered: {
                    Config.options.bar.media.preferredPlayer = preferredPlayerField.value;
                }
            }
        }

        ConfigSwitch {
            buttonIcon: "keep"
            text: Translation.tr("Pin media controls")
            checked: Config.options.bar.media.alwaysVisible
            onCheckedChanged: {
                Config.options.bar.media.alwaysVisible = checked;
            }
        }

        ConfigSwitch {
            buttonIcon: "titlecase"
            text: Translation.tr("Show only title")
            checked: Config.options.bar.media.onlyTitle
            onCheckedChanged: {
                Config.options.bar.media.onlyTitle = checked;
            }
        }

        ConfigRow {
            uniform: true
            ConfigSpinBox {
                icon: "width"
                text: Translation.tr("Min media width")
                value: Config.options.bar.media.minWidth
                from: 20
                to: 500
                stepSize: 10
                onValueChanged: {
                    Config.options.bar.media.minWidth = value;
                }
            }
            ConfigSpinBox {
                icon: "width"
                text: Translation.tr("Max media width")
                value: Config.options.bar.media.maxWidth
                from: 100
                to: 500
                stepSize: 10
                onValueChanged: {
                    Config.options.bar.media.maxWidth = value;
                }
            }
        }
    }

    ContentSection {
        icon: "tooltip"
        title: Translation.tr("Tooltips")
        ConfigSwitch {
            buttonIcon: "ads_click"
            text: Translation.tr("Click to show")
            checked: Config.options.bar.tooltips.clickToShow
            onCheckedChanged: {
                Config.options.bar.tooltips.clickToShow = checked;
            }
        }
    }
}
