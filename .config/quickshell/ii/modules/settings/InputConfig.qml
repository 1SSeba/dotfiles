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
                    tooltip: Translation.tr("-1 to 1. 0 is neutral (1:1, no extra scaling) — the closest match to the default Windows pointer speed (slider position 6/11). Move right for faster, left for slower.")
                    usePercentTooltip: false
                    tooltipContent: `${Math.round(sensitivitySlider.value * 100) / 100}`
                    from: -1.0
                    to: 1.0
                    stepSize: 0.05
                    snapToStep: true
                    dividerValues: [-0.75, -0.5, -0.25, 0, 0.25, 0.5, 0.75]
                    stopIndicatorValues: [0]
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
                    tooltip: Translation.tr("Flat = no acceleration curve, movement is 1:1 — matches Windows with \"Enhance pointer precision\" turned OFF. Adaptive = libinput's own acceleration curve — closest to Windows with that option turned ON (the Windows default). Default lets the driver decide.")
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

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                Item { Layout.fillWidth: true }
                RippleButtonWithIcon {
                    id: windowsPresetButton
                    materialIcon: "history"
                    property bool justApplied: false
                    mainText: justApplied
                        ? Translation.tr("Applied: flat, sensitivity 0")
                        : Translation.tr("Match Windows default (no pointer precision, slider 6/11)")
                    onClicked: {
                        sensitivitySlider.value = 0
                        if (Config.options.hyprland.input.mouse.accelProfile !== "flat") {
                            Config.options.hyprland.input.mouse.accelProfile = "flat"
                            HyprlandConfig.set("input:accel_profile", "flat")
                        }
                        windowsPresetButton.justApplied = true
                        windowsPresetRevertTimer.restart()
                    }
                    Timer {
                        id: windowsPresetRevertTimer
                        interval: 1500
                        repeat: false
                        onTriggered: windowsPresetButton.justApplied = false
                    }
                }
            }

            NoticeBox {
                id: sensitivityCheck
                Layout.fillWidth: true
                Layout.topMargin: 4
                // Hyprland solo permite sensibilidad global o por dispositivo — nunca
                // por monitor. Si el mouse "se siente" distinto en una pantalla, no es
                // la config: son tasas de refresco distintas combinadas con cursor por
                // hardware (frecuente con NVIDIA), visibles en `hyprctl monitors -j`.
                // Forzar cursor:no_hardware_cursors iguala el comportamiento entre
                // monitores sin tocar sus Hz — por eso "todos por software" es el
                // estado sano, y lo que hay que marcar es una mezcla hw/sw.
                property var monitorRates: HyprlandData.monitors.map(m => Math.round(m.refreshRate * 100) / 100)
                property bool ratesDiffer: monitorRates.length > 1 && (Math.max(...monitorRates) - Math.min(...monitorRates) > 1)
                property var cursorModes: [...new Set(HyprlandData.monitors.map(m => m.hardwareCursorsInUse))]
                property bool cursorModeMixed: cursorModes.length > 1
                property bool allSoftwareCursor: HyprlandData.monitors.length > 0 && cursorModes.length === 1 && cursorModes[0] === false
                property bool riskyHwRateMismatch: ratesDiffer && !allSoftwareCursor
                materialIcon: (cursorModeMixed || riskyHwRateMismatch) ? "warning" : "check_circle"
                text: {
                    const sens = Config.options.hyprland.input.mouse.sensitivity
                    const prof = Config.options.hyprland.input.mouse.accelProfile || Translation.tr("default")
                    let msg = Translation.tr("Verified: sensitivity is ONE global value (%1, profile: %2) applied to every mouse on every monitor — Hyprland has no concept of per-monitor pointer sensitivity.")
                        .arg(sens).arg(prof)
                    if (sensitivityCheck.cursorModeMixed) {
                        const list = HyprlandData.monitors.map(m => `${m.name}: ${m.hardwareCursorsInUse ? "hw" : "sw"}`).join(", ")
                        msg += "\n\n" + Translation.tr("⚠ Monitors don't agree on cursor mode (%1) — that mismatch alone can make the pointer feel different per screen. Consider forcing cursor:no_hardware_cursors = true for all of them.")
                            .arg(list)
                    } else if (sensitivityCheck.riskyHwRateMismatch) {
                        const list = HyprlandData.monitors.map(m => `${m.name} (${Math.round(m.refreshRate)}Hz)`).join(", ")
                        msg += "\n\n" + Translation.tr("⚠ Your monitors run at different refresh rates (%1) using hardware cursors. That's a known Hyprland/NVIDIA quirk that can make the cursor feel faster or slower depending on which screen it's on — not the sensitivity setting. Try cursor:no_hardware_cursors = true to keep your Hz but even it out.")
                            .arg(list)
                    } else if (sensitivityCheck.allSoftwareCursor && sensitivityCheck.ratesDiffer) {
                        msg += "\n\n" + Translation.tr("✓ cursor:no_hardware_cursors is active — all monitors use software cursor uniformly, so the differing refresh rates shouldn't cause a per-monitor speed difference anymore.")
                    }
                    return msg
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
