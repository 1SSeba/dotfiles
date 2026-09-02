import QtQuick
import Quickshell
import Quickshell.Io
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

ContentPage {
    forceWidth: true

    Process {
        id: translationProc
        property string locale: ""
        command: [Directories.aiTranslationScriptPath, translationProc.locale]
    }

    ContentSection {
        icon: "battery_android_full"
        title: Translation.tr("Battery")

        ConfigRow {
            uniform: true
            ConfigSpinBox {
                icon: "warning"
                text: Translation.tr("Low warning")
                value: Config.options.battery.low
                from: 0
                to: 100
                stepSize: 5
                onValueChanged: {
                    Config.options.battery.low = value;
                }
            }
            ConfigSpinBox {
                icon: "dangerous"
                text: Translation.tr("Critical warning")
                value: Config.options.battery.critical
                from: 0
                to: 100
                stepSize: 5
                onValueChanged: {
                    Config.options.battery.critical = value;
                }
            }
        }
        ConfigRow {
            uniform: false
            Layout.fillWidth: false
            ConfigSwitch {
                buttonIcon: "pause"
                text: Translation.tr("Automatic suspend")
                checked: Config.options.battery.automaticSuspend
                onCheckedChanged: {
                    Config.options.battery.automaticSuspend = checked;
                }
                StyledToolTip {
                    text: Translation.tr("Automatically suspends the system when battery is low")
                }
            }
            ConfigSpinBox {
                enabled: Config.options.battery.automaticSuspend
                text: Translation.tr("at")
                value: Config.options.battery.suspend
                from: 0
                to: 100
                stepSize: 5
                onValueChanged: {
                    Config.options.battery.suspend = value;
                }
            }
        }
        ConfigRow {
            uniform: true
            ConfigSpinBox {
                icon: "charger"
                text: Translation.tr("Full warning")
                value: Config.options.battery.full
                from: 0
                to: 101
                stepSize: 5
                onValueChanged: {
                    Config.options.battery.full = value;
                }
            }
        }
    }

    ContentSection {
        icon: "language"
        title: Translation.tr("Language")

        ContentSubsection {
            title: Translation.tr("Interface Language")
            tooltip: Translation.tr("Select the language for the user interface.\n\"Auto\" will use your system's locale.")

            StyledComboBox {
                id: languageSelector
                buttonIcon: "language"
                textRole: "displayName"

                model: [
                    {
                        displayName: Translation.tr("Auto (System)"),
                        value: "auto"
                    },
                    ...Translation.allAvailableLanguages.map(lang => {
                        return {
                            displayName: lang,
                            value: lang
                        };
                    })]

                currentIndex: {
                    const index = model.findIndex(item => item.value === Config.options.language.ui);
                    return index !== -1 ? index : 0;
                }

                onActivated: index => {
                    Config.options.language.ui = model[index].value;
                }
            }
        }
        ContentSubsection {
            title: Translation.tr("Generate translation with Gemini")
            tooltip: Translation.tr("You'll need to enter your Gemini API key first.\nType /key on the sidebar for instructions.")

            ConfigRow {
                MaterialTextArea {
                    id: localeInput
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Locale code, e.g. fr_FR, de_DE, zh_CN...")
                    text: Config.options.language.ui === "auto" ? Qt.locale().name : Config.options.language.ui
                }
                RippleButtonWithIcon {
                    id: generateTranslationBtn
                    Layout.fillHeight: true
                    nerdIcon: ""
                    enabled: !translationProc.running || (translationProc.locale !== localeInput.text.trim())
                    mainText: enabled ? Translation.tr("Generate\nTypically takes 2 minutes") : Translation.tr("Generating...\nDon't close this window!")
                    onClicked: {
                        translationProc.locale = localeInput.text.trim();
                        translationProc.running = false;
                        translationProc.running = true;
                    }
                }
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
        icon: "av_timer"
        title: Translation.tr("Pomodoro timer")

        ConfigRow {
            uniform: true
            ConfigSpinBox {
                icon: "psychology"
                text: Translation.tr("Focus (min)")
                value: Math.round(Config.options.time.pomodoro.focus / 60)
                from: 1
                to: 120
                stepSize: 1
                onValueChanged: {
                    Config.options.time.pomodoro.focus = value * 60;
                }
            }
            ConfigSpinBox {
                icon: "coffee"
                text: Translation.tr("Short break (min)")
                value: Math.round(Config.options.time.pomodoro.breakTime / 60)
                from: 1
                to: 60
                stepSize: 1
                onValueChanged: {
                    Config.options.time.pomodoro.breakTime = value * 60;
                }
            }
        }
        ConfigRow {
            uniform: true
            ConfigSpinBox {
                icon: "self_improvement"
                text: Translation.tr("Long break (min)")
                value: Math.round(Config.options.time.pomodoro.longBreak / 60)
                from: 1
                to: 120
                stepSize: 1
                onValueChanged: {
                    Config.options.time.pomodoro.longBreak = value * 60;
                }
            }
            ConfigSpinBox {
                icon: "repeat"
                text: Translation.tr("Cycles before long break")
                value: Config.options.time.pomodoro.cyclesBeforeLongBreak
                from: 1
                to: 10
                stepSize: 1
                onValueChanged: {
                    Config.options.time.pomodoro.cyclesBeforeLongBreak = value;
                }
            }
        }
    }

    ContentSection {
        icon: "nest_clock_farsight_analog"
        title: Translation.tr("Time")

        Rectangle {
            id: timePreviewCard
            Layout.fillWidth: true
            implicitHeight: 180
            radius: Appearance.rounding.normal
            clip: true
            color: Appearance.colors.colLayer1

            property date now: new Date()

            Timer {
                interval: Config.options.time.secondPrecision ? 1000 : 15000
                running: true
                repeat: true
                triggeredOnStart: true
                onTriggered: timePreviewCard.now = new Date()
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 16

                ColumnLayout {
                    StyledText {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        font.family: Appearance.font.family.expressive
                        font.pixelSize: 42
                        font.letterSpacing: 1
                        font.features: { "tnum": 1 }
                        font.weight: Font.Medium
                        color: Appearance.colors.colPrimary
                        text: {
                            const fmt = Config.options.time.format;
                            if (Config.options.time.secondPrecision) {
                                if (fmt === "hh:mm") return Qt.formatTime(timePreviewCard.now, "hh:mm:ss");
                                if (fmt === "h:mm ap") return Qt.formatTime(timePreviewCard.now, "h:mm:ss ap");
                                if (fmt === "h:mm AP") return Qt.formatTime(timePreviewCard.now, "h:mm:ss AP");
                            }
                            return Qt.formatTime(timePreviewCard.now, fmt);
                        }
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: DateTime.longDate
                        horizontalAlignment: Text.AlignHCenter
                        font.pixelSize: 32
                        font.weight: Font.Normal
                        opacity: 0.6
                        color: Appearance.colors.colPrimary
                    }
                }

                AndroidClock {
                    Layout.rightMargin: 6
                    width: 130
                    height: 130
                    backgroundColor: Appearance.colors.colPrimaryContainer
                    handColor: Appearance.colors.colPrimary
                    centerDotColor: Appearance.colors.colPrimary
                }
            }
        }

        ConfigSwitch {
            buttonIcon: "pace"
            text: Translation.tr("Second precision")
            checked: Config.options.time.secondPrecision
            onCheckedChanged: {
                Config.options.time.secondPrecision = checked;
            }
            StyledToolTip {
                text: Translation.tr("Enable if you want clocks to show seconds accurately")
            }
        }

        ConfigSwitch {
            buttonIcon: "date_range"
            text: Translation.tr("Show date")
            checked: Config.options.time.showDate
            onCheckedChanged: {
                Config.options.time.showDate = checked;
            }
        }

        ContentSubsection {
            title: Translation.tr("Format")
            tooltip: ""

            ConfigSelectionArray {
                currentValue: Config.options.time.format
                onSelected: newValue => {
                    if (newValue === "hh:mm") {
                        Quickshell.execDetached(["bash", "-c", `sed -i 's/\\TIME12\\b/TIME/' '${FileUtils.trimFileProtocol(Directories.config)}/hypr/hyprlock.conf'`]);
                    } else {
                        Quickshell.execDetached(["bash", "-c", `sed -i 's/\\TIME\\b/TIME12/' '${FileUtils.trimFileProtocol(Directories.config)}/hypr/hyprlock.conf'`]);
                    }

                    Config.options.time.format = newValue;
                }
                options: [
                    {
                        displayName: Translation.tr("24h"),
                        value: "hh:mm"
                    },
                    {
                        displayName: Translation.tr("12h am/pm"),
                        value: "h:mm ap"
                    },
                    {
                        displayName: Translation.tr("12h AM/PM"),
                        value: "h:mm AP"
                    },
                ]
            }
        }

        ContentSubsection {
            title: Translation.tr("Clock string format")
            tooltip: Translation.tr("Advanced: raw Qt time format string, e.g. hh:mm")

            MaterialTextArea {
                Layout.fillWidth: true
                placeholderText: Translation.tr("Clock string format")
                text: Config.options.time.format
                wrapMode: TextEdit.NoWrap
                onTextChanged: {
                    Config.options.time.format = text;
                }
            }
        }

        ContentSubsection {
            title: Translation.tr("Date string format")
            tooltip: Translation.tr("Advanced: raw Qt date format string, e.g. ddd, dd/MM")

            MaterialTextArea {
                Layout.fillWidth: true
                placeholderText: Translation.tr("Date string format")
                text: Config.options.time.dateFormat
                wrapMode: TextEdit.NoWrap
                onTextChanged: {
                    Config.options.time.dateFormat = text;
                }
            }
        }
    }

    ContentSection {
        icon: "work_alert"
        title: Translation.tr("Work safety")

        ConfigSwitch {
            buttonIcon: "assignment"
            text: Translation.tr("Hide clipboard images copied from sussy sources")
            checked: Config.options.workSafety.enable.clipboard
            onCheckedChanged: {
                Config.options.workSafety.enable.clipboard = checked;
            }
        }
        ConfigSwitch {
            buttonIcon: "wallpaper"
            text: Translation.tr("Hide sussy/anime wallpapers")
            checked: Config.options.workSafety.enable.wallpaper
            onCheckedChanged: {
                Config.options.workSafety.enable.wallpaper = checked;
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
