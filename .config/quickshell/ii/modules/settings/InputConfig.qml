import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    forceWidth: true

    Component.onCompleted: {
        const h = Config.options.hyprland
        HyprlandConfig.setMany({
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

    ContentSection {
        icon: "trackpad_input"
        shape: MaterialShape.Shape.Pentagon
        title: Translation.tr("Input")

        ContentSubsection {
            title: Translation.tr("Keyboard")

            GroupedList {
                ConfigTextArea {
                    id: kbLayoutField
                    Layout.fillWidth: true
                    buttonIcon: "keyboard"
                    text: Translation.tr("Keyboard layout")
                    placeholderText: Translation.tr("e.g., us, es, latam")
                    Component.onCompleted: value = Config.options.hyprland.input.kbLayout
                    onValueChanged: kbLayoutDebounceTimer.restart()

                    Timer {
                        id: kbLayoutDebounceTimer
                        interval: 1000
                        repeat: false
                        onTriggered: {
                            Config.options.hyprland.input.kbLayout = kbLayoutField.value
                            HyprlandConfig.set("input:kb_layout", kbLayoutField.value)
                        }
                    }
                }
                ConfigTextArea {
                    id: kbVariantField
                    Layout.fillWidth: true
                    buttonIcon: "keyboard_alt"
                    text: Translation.tr("Keyboard variant")
                    placeholderText: Translation.tr("e.g., dvorak, colemak (optional)")
                    Component.onCompleted: value = Config.options.hyprland.input.kbVariant
                    onValueChanged: kbVariantDebounceTimer.restart()

                    Timer {
                        id: kbVariantDebounceTimer
                        interval: 1000
                        repeat: false
                        onTriggered: {
                            Config.options.hyprland.input.kbVariant = kbVariantField.value
                            HyprlandConfig.set("input:kb_variant", kbVariantField.value)
                        }
                    }
                }
                ConfigTextArea {
                    id: kbOptionsField
                    Layout.fillWidth: true
                    buttonIcon: "tune"
                    text: Translation.tr("Keyboard options")
                    placeholderText: Translation.tr("e.g., caps:swapescape, compose:ralt")
                    Component.onCompleted: value = Config.options.hyprland.input.kbOptions
                    onValueChanged: kbOptionsDebounceTimer.restart()

                    Timer {
                        id: kbOptionsDebounceTimer
                        interval: 1000
                        repeat: false
                        onTriggered: {
                            Config.options.hyprland.input.kbOptions = kbOptionsField.value
                            HyprlandConfig.set("input:kb_options", kbOptionsField.value)
                        }
                    }
                }
                ConfigSwitch {
                    buttonIcon: "numbers"
                    text: Translation.tr("Numlock by default")
                    checked: Config.options.hyprland.input.numlock
                    onCheckedChanged: {
                        if (checked === Config.options.hyprland.input.numlock) return
                        Config.options.hyprland.input.numlock = checked
                        HyprlandConfig.set("input:numlock_by_default", checked ? 1 : 0)
                    }
                }

                ConfigSpinBox {
                    icon: "keyboard_return"
                    text: Translation.tr("Repeat delay (ms)")
                    value: Config.options.hyprland.input.repeatDelay
                    from: 100; to: 1000; stepSize: 10
                    onValueChanged: {
                        if (value === Config.options.hyprland.input.repeatDelay) return
                        Config.options.hyprland.input.repeatDelay = value
                        HyprlandConfig.set("input:repeat_delay", value)
                    }
                }

                ConfigSpinBox {
                    icon: "speed"
                    text: Translation.tr("Repeat rate")
                    value: Config.options.hyprland.input.repeatRate
                    from: 10; to: 100; stepSize: 1
                    onValueChanged: {
                        if (value === Config.options.hyprland.input.repeatRate) return
                        Config.options.hyprland.input.repeatRate = value
                        HyprlandConfig.set("input:repeat_rate", value)
                    }
                }
                ContentSubsection {
                    title: Translation.tr("Follow mouse")
                    Layout.fillWidth: true

                    ConfigSelectionArray {
                        currentValue: Config.options.hyprland.input.followMouse
                        onSelected: newValue => {
                            Config.options.hyprland.input.followMouse = newValue
                            HyprlandConfig.set("input:follow_mouse", newValue)
                        }
                        options: [
                            { displayName: Translation.tr("Disabled"), icon: "mouse",     value: 0 },
                            { displayName: Translation.tr("Full"),     icon: "open_with",  value: 1 },
                            { displayName: Translation.tr("Loose"),    icon: "drag_pan",   value: 2 },
                            { displayName: Translation.tr("Explicit"), icon: "ads_click",  value: 3 },
                        ]
                    }
                }
            }
        }

        ContentSubsection {
            title: Translation.tr("Mouse")
            GroupedList {
                ConfigSwitch {
                    buttonIcon: "swap_vert"
                    text: Translation.tr("Natural scroll")
                    checked: Config.options.hyprland.input.mouse.naturalScroll
                    onCheckedChanged: {
                        if (checked === Config.options.hyprland.input.mouse.naturalScroll) return
                        Config.options.hyprland.input.mouse.naturalScroll = checked
                        HyprlandConfig.set("input:natural_scroll", checked ? 1 : 0)
                    }
                }

                ConfigSwitch {
                    buttonIcon: "back_hand"
                    text: Translation.tr("Left-handed mode")
                    checked: Config.options.hyprland.input.mouse.leftHanded
                    onCheckedChanged: {
                        if (checked === Config.options.hyprland.input.mouse.leftHanded) return
                        Config.options.hyprland.input.mouse.leftHanded = checked
                        HyprlandConfig.set("input:left_handed", checked ? 1 : 0)
                    }
                }

                ConfigSlider {
                    id: sensitivitySlider
                    buttonIcon: "speed"
                    text: Translation.tr("Sensitivity")
                    usePercentTooltip: false
                    from: -1.0
                    to: 1.0
                    property bool initialized: false
                    Component.onCompleted: {
                        sensitivitySlider.value = Config.options.hyprland.input.mouse.sensitivity
                        sensitivitySlider.initialized = true
                    }
                    onValueChanged: {
                        if (!sensitivitySlider.initialized) return
                        const newVal = Math.round(sensitivitySlider.value * 100) / 100
                        if (newVal === Config.options.hyprland.input.mouse.sensitivity) return
                        Config.options.hyprland.input.mouse.sensitivity = newVal
                        HyprlandConfig.set("input:sensitivity", newVal)
                    }
                }

                ContentSubsection {
                    title: Translation.tr("Acceleration profile")
                    Layout.fillWidth: true

                    ConfigSelectionArray {
                        currentValue: Config.options.hyprland.input.mouse.accelProfile
                        onSelected: newValue => {
                            Config.options.hyprland.input.mouse.accelProfile = newValue
                            HyprlandConfig.set("input:accel_profile", newValue)
                        }
                        options: [
                            { displayName: Translation.tr("Default"),  icon: "settings_suggest", value: ""         },
                            { displayName: Translation.tr("Adaptive"), icon: "trending_up",       value: "adaptive" },
                            { displayName: Translation.tr("Flat"),     icon: "horizontal_rule",   value: "flat"     },
                        ]
                    }
                }
            }
        }

        ContentSubsection {
            title: Translation.tr("Touchpad")
            GroupedList {
                ConfigSwitch {
                    buttonIcon: "swap_vert"
                    text: Translation.tr("Natural scroll")
                    checked: Config.options.hyprland.input.touchpad.naturalScroll
                    onCheckedChanged: {
                        if (checked === Config.options.hyprland.input.touchpad.naturalScroll) return
                        Config.options.hyprland.input.touchpad.naturalScroll = checked
                        HyprlandConfig.set("input:touchpad:natural_scroll", checked ? 1 : 0)
                    }
                }

                ConfigSwitch {
                    buttonIcon: "keyboard_hide"
                    text: Translation.tr("Disable while typing")
                    checked: Config.options.hyprland.input.touchpad.disableWhileTyping
                    onCheckedChanged: {
                        if (checked === Config.options.hyprland.input.touchpad.disableWhileTyping) return
                        Config.options.hyprland.input.touchpad.disableWhileTyping = checked
                        HyprlandConfig.set("input:touchpad:disable_while_typing", checked ? 1 : 0)
                    }
                }

                ConfigSwitch {
                    buttonIcon: "touch_app"
                    text: Translation.tr("Clickfinger behavior")
                    checked: Config.options.hyprland.input.touchpad.clickfingerBehavior
                    onCheckedChanged: {
                        if (checked === Config.options.hyprland.input.touchpad.clickfingerBehavior) return
                        Config.options.hyprland.input.touchpad.clickfingerBehavior = checked
                        HyprlandConfig.set("input:touchpad:clickfinger_behavior", checked ? 1 : 0)
                    }
                }

                ConfigSpinBox {
                    icon: "swipe"
                    text: Translation.tr("Scroll factor")
                    value: Math.round(Config.options.hyprland.input.touchpad.scrollFactor * 10)
                    from: 1; to: 30; stepSize: 1
                    onValueChanged: {
                        const newVal = value / 10.0
                        if (newVal === Config.options.hyprland.input.touchpad.scrollFactor) return
                        Config.options.hyprland.input.touchpad.scrollFactor = newVal
                        HyprlandConfig.set("input:touchpad:scroll_factor", newVal)
                    }
                }
            }
        }
    }
}
