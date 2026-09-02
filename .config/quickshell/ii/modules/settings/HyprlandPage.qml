import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell
import qs.modules.common.functions
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.models.hyprland

ContentPage {
    id: page
    forceWidth: true

    function goTo(term) {
        const t = term.toLowerCase().trim()

        function findTarget(rootItem) {
            for (let i = 0; i < rootItem.children.length; i++) {
                let child = rootItem.children[i]
                if (child.title && child.title.toLowerCase().includes(t)) {
                    return child
                }
            }
            for (let i = 0; i < rootItem.children.length; i++) {
                let found = findTarget(rootItem.children[i])
                if (found) return found
            }
            return null
        }

        let target = findTarget(mainLayout)
        if (target) {
            let pos = target.mapToItem(mainLayout, 0, 0)
            page.contentY = Math.max(0, pos.y - 0)
        }
    }

    Component.onCompleted: {
        const h = Config.options.hyprland
        HyprlandConfig.setMany({
            "decoration:rounding":                  h.decoration.rounding,
            "decoration:blur:enabled":              h.decoration.blur.enabled ? 1 : 0,
            "decoration:blur:size":                 h.decoration.blur.size,
            "decoration:blur:passes":               h.decoration.blur.passes,
            "decoration:shadow:enabled":            h.decoration.shadow.enabled ? 1 : 0,
            "decoration:shadow:range":              h.decoration.shadow.range,
            "decoration:active_opacity":            Config.options.appearance.transparency.enable ? h.decoration.activeOpacity : 1,
            "decoration:inactive_opacity":          Config.options.appearance.transparency.enable ? h.decoration.inactiveOpacity : 1,
            "general:border_size":                  h.general.borderSize,
            "general:gaps_in":                      h.general.gapsIn,
            "general:gaps_out":                     h.general.gapsOut,
            "general:layout":                       h.general.layout,
            "animations:enabled":                   h.animations.enable ? 1 : 0,
            "input:kb_layout":                      h.input.kbLayout,
            "input:kb_variant":                     h.input.kbVariant,
            "input:kb_options":                     h.input.kbOptions,
            "input:numlock_by_default":             h.input.numlock ? 1 : 0,
            "input:repeat_delay":                   h.input.repeatDelay,
            "input:repeat_rate":                    h.input.repeatRate,
            "input:follow_mouse":                   h.input.followMouse,
            "input:natural_scroll":                 h.input.mouse.naturalScroll ? 1 : 0,
            "input:left_handed":                    h.input.mouse.leftHanded ? 1 : 0,
            "input:sensitivity":                    h.input.mouse.sensitivity,
            "input:accel_profile":                  h.input.mouse.accelProfile,
            "input:touchpad:natural_scroll":        h.input.touchpad.naturalScroll ? 1 : 0,
            "input:touchpad:disable_while_typing":  h.input.touchpad.disableWhileTyping ? 1 : 0,
            "input:touchpad:clickfinger_behavior":  h.input.touchpad.clickfingerBehavior ? 1 : 0,
            "input:touchpad:scroll_factor":         h.input.touchpad.scrollFactor
        })
    }
    MonitorConfigOption { id: monitorConfig }

    ColumnLayout {
        id: mainLayout
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 20

        // Displays

        // Layout
        ContentSection {
            icon: "auto_awesome_mosaic"
            shape: MaterialShape.Shape.Gem
            title: Translation.tr("Layout")

            GroupedList {
                ContentSubsection {
                    title: Translation.tr("Tiling Layout")
                    Layout.fillWidth: true

                    ConfigSelectionArray {
                        currentValue: Config.options.hyprland.general.layout
                        onSelected: newValue => {
                            Config.options.hyprland.general.layout = newValue
                            HyprlandConfig.set("general:layout", newValue)
                        }
                        options: [
                            { displayName: Translation.tr("Dwindle"),   icon: "browse",             value: "dwindle"   },
                            { displayName: Translation.tr("Master"),    icon: "auto_awesome_mosaic", value: "master"    },
                            { displayName: Translation.tr("Scrolling"), icon: "view_carousel",       value: "scrolling" },
                        ]
                    }
                }
            }
        }

        // Input

        // Audio

        // Visual & Aesthetics
        ContentSection {
            icon: "deblur"
            shape: MaterialShape.Shape.PixelCircle
            title: Translation.tr("Visual & Aesthetics")

            GroupedList {
                ConfigSpinBox {
                    icon: "rounded_corner"
                    text: Translation.tr("Window Rounding")
                    value: Config.options.hyprland.decoration.rounding
                    from: 0; to: 30; stepSize: 1
                    onValueChanged: {
                        if (value === Config.options.hyprland.decoration.rounding) return
                        Config.options.hyprland.decoration.rounding = value
                        HyprlandConfig.set("decoration:rounding", value)
                    }
                }

                ConfigSwitch {
                    buttonIcon: "blur_on"
                    text: Translation.tr("Blur")
                    checked: Config.options.hyprland.decoration.blur.enabled
                    onCheckedChanged: {
                        if (checked === Config.options.hyprland.decoration.blur.enabled) return
                        Config.options.hyprland.decoration.blur.enabled = checked
                        HyprlandConfig.set("decoration:blur:enabled", checked ? 1 : 0)
                    }
                }

                ConfigSpinBox {
                    icon: "blur_circular"
                    text: Translation.tr("Blur Size")
                    value: Config.options.hyprland.decoration.blur.size
                    from: 1; to: 20; stepSize: 1
                    onValueChanged: {
                        if (value === Config.options.hyprland.decoration.blur.size) return
                        Config.options.hyprland.decoration.blur.size = value
                        HyprlandConfig.set("decoration:blur:size", value)
                    }
                }

                ConfigSpinBox {
                    icon: "layers"
                    text: Translation.tr("Blur Passes")
                    value: Config.options.hyprland.decoration.blur.passes
                    from: 1; to: 6; stepSize: 1
                    onValueChanged: {
                        if (value === Config.options.hyprland.decoration.blur.passes) return
                        Config.options.hyprland.decoration.blur.passes = value
                        HyprlandConfig.set("decoration:blur:passes", value)
                    }
                }

                ConfigSwitch {
                    buttonIcon: "shadow"
                    text: Translation.tr("Shadow")
                    checked: Config.options.hyprland.decoration.shadow.enabled
                    onCheckedChanged: {
                        if (checked === Config.options.hyprland.decoration.shadow.enabled) return
                        Config.options.hyprland.decoration.shadow.enabled = checked
                        HyprlandConfig.set("decoration:shadow:enabled", checked ? 1 : 0)
                    }
                }

                ConfigSpinBox {
                    icon: "blur_circular"
                    text: Translation.tr("Shadow Range")
                    enabled: Config.options.hyprland.decoration.shadow.enabled
                    value: Config.options.hyprland.decoration.shadow.range
                    from: 1; to: 50; stepSize: 1
                    onValueChanged: {
                        if (value === Config.options.hyprland.decoration.shadow.range) return
                        Config.options.hyprland.decoration.shadow.range = value
                        HyprlandConfig.set("decoration:shadow:range", value)
                    }
                }

                ConfigSpinBox {
                    icon: "border_outer"
                    text: Translation.tr("Border Size")
                    value: Config.options.hyprland.general.borderSize
                    from: 0; to: 10; stepSize: 1
                    onValueChanged: {
                        if (value === Config.options.hyprland.general.borderSize) return
                        Config.options.hyprland.general.borderSize = value
                        HyprlandConfig.set("general:border_size", value)
                    }
                }

                ConfigSpinBox {
                    icon: "margin"
                    text: Translation.tr("Gaps In")
                    value: Config.options.hyprland.general.gapsIn
                    from: 0; to: 40; stepSize: 1
                    onValueChanged: {
                        if (value === Config.options.hyprland.general.gapsIn) return
                        Config.options.hyprland.general.gapsIn = value
                        HyprlandConfig.set("general:gaps_in", value)
                    }
                }

                ConfigSpinBox {
                    icon: "open_in_full"
                    text: Translation.tr("Gaps Out")
                    value: Config.options.hyprland.general.gapsOut
                    from: 0; to: 60; stepSize: 1
                    onValueChanged: {
                        if (value === Config.options.hyprland.general.gapsOut) return
                        Config.options.hyprland.general.gapsOut = value
                        HyprlandConfig.set("general:gaps_out", value)
                    }
                }

                ConfigRow {
                    ConfigSwitch {
                        buttonIcon: "ev_shadow"
                        text: Translation.tr("Transparency")
                        checked: Config.options.appearance.transparency.enable
                        onCheckedChanged: {
                            Config.options.appearance.transparency.enable = checked;
                            // Single master switch: also gate real window opacity in
                            // Hyprland, not just the shell's own panels.
                            HyprlandConfig.setMany({
                                "decoration:active_opacity": checked ? Config.options.hyprland.decoration.activeOpacity : 1,
                                "decoration:inactive_opacity": checked ? Config.options.hyprland.decoration.inactiveOpacity : 1
                            });
                        }
                    }
                    ConfigSwitch {
                        buttonIcon: "autofps_select"
                        enabled: Config.options.appearance.transparency.enable
                        text: Translation.tr("Automatic")
                        checked: Config.options.appearance.transparency.automatic
                        onCheckedChanged: {
                            Config.options.appearance.transparency.automatic = checked;
                        }
                    }
                }

                ConfigSlider {
                    Layout.fillWidth: true
                    buttonIcon: "opacity"
                    text: Translation.tr("Background transparency")
                    enabled: Config.options.appearance.transparency.enable && !Config.options.appearance.transparency.automatic
                    value: Config.options.appearance.transparency.backgroundTransparency
                    from: 0
                    to: 1
                    onValueChanged: {
                        Config.options.appearance.transparency.backgroundTransparency = value;
                    }
                }

                ConfigSlider {
                    Layout.fillWidth: true
                    buttonIcon: "opacity"
                    text: Translation.tr("Content transparency")
                    enabled: Config.options.appearance.transparency.enable && !Config.options.appearance.transparency.automatic
                    value: Config.options.appearance.transparency.contentTransparency
                    from: 0
                    to: 1
                    onValueChanged: {
                        Config.options.appearance.transparency.contentTransparency = value;
                    }
                }

                ConfigSpinBox {
                    icon: "opacity"
                    text: Translation.tr("Active Opacity")
                    enabled: Config.options.appearance.transparency.enable
                    value: Math.round(Config.options.hyprland.decoration.activeOpacity * 100)
                    from: 10; to: 100; stepSize: 5
                    onValueChanged: {
                        const newVal = value / 100.0
                        if (newVal === Config.options.hyprland.decoration.activeOpacity) return
                        Config.options.hyprland.decoration.activeOpacity = newVal
                        // Solo surte efecto mientras el switch maestro de arriba esté prendido.
                        if (Config.options.appearance.transparency.enable)
                            HyprlandConfig.set("decoration:active_opacity", newVal)
                    }
                }

                ConfigSpinBox {
                    icon: "opacity"
                    text: Translation.tr("Inactive Opacity")
                    enabled: Config.options.appearance.transparency.enable
                    value: Math.round(Config.options.hyprland.decoration.inactiveOpacity * 100)
                    from: 10; to: 100; stepSize: 5
                    onValueChanged: {
                        const newVal = value / 100.0
                        if (newVal === Config.options.hyprland.decoration.inactiveOpacity) return
                        Config.options.hyprland.decoration.inactiveOpacity = newVal
                        // Solo surte efecto mientras el switch maestro de arriba esté prendido.
                        if (Config.options.appearance.transparency.enable)
                            HyprlandConfig.set("decoration:inactive_opacity", newVal)
                    }
                }
            }
        }

        // Autostart Apps
        ContentSection {
            icon: "app_registration"
            shape: MaterialShape.Shape.Sunny
            title: Translation.tr("Autostart Apps")
            Layout.fillWidth: true

            AutostartApps {}
        }

        // Animations
        ContentSection {
            icon: "animation"
            shape: MaterialShape.Shape.Oval
            title: Translation.tr("Animations")
            GroupedList {
                ConfigSwitch {
                    buttonIcon: "check"
                    text: Translation.tr("Enable")
                    checked: Config.options.hyprland.animations.enable
                    onCheckedChanged: {
                        if (checked === Config.options.hyprland.animations.enable) return
                        Config.options.hyprland.animations.enable = checked
                        HyprlandConfig.set("animations:enabled", checked ? 1 : 0)
                    }
                }
                // El selector de presets de animación del fork quedó afuera a propósito:
                // escribe los presets en Lua (hl.curve/hl.animation) y esta config de
                // Hyprland es .conf, así que meterlos la rompería.
            }

            NoticeBox {
                Layout.fillWidth: true
                Layout.topMargin: 15
                text: Translation.tr("Animation presets require a require line in your hyprland.lua. Add the following line to enable presets:") + '\n\nrequire("hyprland/shellOverrides/animations")'

                Item { Layout.fillWidth: true }

                RippleButtonWithIcon {
                    id: copySourceButton
                    property bool justCopied: false
                    Layout.fillWidth: false
                    buttonRadius: Appearance.rounding.small
                    materialIcon: justCopied ? "check" : "content_copy"
                    mainText: justCopied ? Translation.tr("Copied!") : Translation.tr("Copy line")
                    onClicked: {
                        copySourceButton.justCopied = true
                        Quickshell.clipboardText = 'require("hyprland/shellOverrides/animations")'
                        revertSourceTimer.restart()
                    }
                    colBackground: ColorUtils.transparentize(Appearance.colors.colPrimaryContainer)
                    colBackgroundHover: Appearance.colors.colPrimaryContainerHover
                    colRipple: Appearance.colors.colPrimaryContainerActive
                    Timer {
                        id: revertSourceTimer
                        interval: 1500
                        onTriggered: copySourceButton.justCopied = false
                    }
                }
            }

            Process {
                id: saveAnimProc
                onRunningChanged: if (!running) reloadAnimProc.running = true
            }
            Process {
                id: reloadAnimProc
                command: ["hyprctl", "reload"]
            }
        }
    }
}