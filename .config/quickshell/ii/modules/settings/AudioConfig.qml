import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    forceWidth: true

    ContentSection {
        icon: "volume_up"
        title: Translation.tr("Audio")

        ConfigSwitch {
            buttonIcon: "hearing"
            text: Translation.tr("Earbang protection")
            checked: Config.options.audio.protection.enable
            onCheckedChanged: {
                Config.options.audio.protection.enable = checked;
            }
            StyledToolTip {
                text: Translation.tr("Prevents abrupt increments and restricts volume limit")
            }
        }
        ConfigRow {
            enabled: Config.options.audio.protection.enable
            ConfigSpinBox {
                icon: "arrow_warm_up"
                text: Translation.tr("Max allowed increase")
                value: Config.options.audio.protection.maxAllowedIncrease
                from: 0
                to: 100
                stepSize: 2
                onValueChanged: {
                    Config.options.audio.protection.maxAllowedIncrease = value;
                }
            }
            ConfigSpinBox {
                icon: "vertical_align_top"
                text: Translation.tr("Volume limit")
                value: Config.options.audio.protection.maxAllowed
                from: 0
                to: 154 // pavucontrol allows up to 153%
                stepSize: 2
                onValueChanged: {
                    Config.options.audio.protection.maxAllowed = value;
                }
            }
        }
    }

    ContentSection {
        icon: "notification_sound"
        title: Translation.tr("Sounds")
        ConfigRow {
            uniform: true
            ConfigSwitch {
                buttonIcon: "battery_android_full"
                text: Translation.tr("Battery")
                checked: Config.options.sounds.battery
                onCheckedChanged: {
                    Config.options.sounds.battery = checked;
                }
            }
            ConfigSwitch {
                buttonIcon: "av_timer"
                text: Translation.tr("Pomodoro")
                checked: Config.options.sounds.pomodoro
                onCheckedChanged: {
                    Config.options.sounds.pomodoro = checked;
                }
            }
        }
    }

    ContentSection {
        icon: "volume_up"
        shape: MaterialShape.Shape.Pentagon
        title: Translation.tr("Audio")

        ContentSubsection {
            title: Translation.tr("Output")
            GroupedList {
                ConfigComboBox {
                    Layout.fillWidth: true
                    buttonIcon: "speaker"
                    text: Translation.tr("Default output device")
                    textRole: "displayName"
                    model: Audio.outputDevices.map(node => ({
                        displayName: Audio.friendlyDeviceName(node),
                        value: node.name
                    }))
                    currentValue: Audio.sink?.name ?? ""
                    onSelected: newValue => {
                        const node = Audio.outputDevices.find(n => n.name === newValue)
                        if (node) Audio.setDefaultSink(node)
                    }
                }

                ConfigSwitch {
                    buttonIcon: "volume_off"
                    text: Translation.tr("Mute output")
                    checked: Audio.sink?.audio.muted ?? false
                    onCheckedChanged: {
                        if (!Audio.sink) return
                        if (checked === Audio.sink.audio.muted) return
                        Audio.sink.audio.muted = checked
                    }
                }
            }
        }

        ContentSubsection {
            title: Translation.tr("Input")
            GroupedList {
                ConfigComboBox {
                    Layout.fillWidth: true
                    buttonIcon: "mic"
                    text: Translation.tr("Default input device")
                    textRole: "displayName"
                    model: Audio.inputDevices.map(node => ({
                        displayName: Audio.friendlyDeviceName(node),
                        value: node.name
                    }))
                    currentValue: Audio.source?.name ?? ""
                    onSelected: newValue => {
                        const node = Audio.inputDevices.find(n => n.name === newValue)
                        if (node) Audio.setDefaultSource(node)
                    }
                }

                ConfigSwitch {
                    buttonIcon: "mic_off"
                    text: Translation.tr("Mute input")
                    checked: Audio.source?.audio.muted ?? false
                    onCheckedChanged: {
                        if (!Audio.source) return
                        if (checked === Audio.source.audio.muted) return
                        Audio.source.audio.muted = checked
                    }
                }
            }
        }

        GroupedList {
            Layout.topMargin: 10
            ConfigSpinBox {
                icon: "unfold_more"
                text: Translation.tr("Volume step (%)")
                value: Config.options.audio.volumeStep
                from: 1; to: 20; stepSize: 1
                onValueChanged: {
                    if (value === Config.options.audio.volumeStep) return
                    Config.options.audio.volumeStep = value
                }
            }
        }
    }
}
