import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Qt.labs.folderlistmodel
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.common.models

ColumnLayout {
    id: root
    Layout.fillWidth: true
    width: parent.width
    spacing: 4

    // El campo de comando tiene un debounce de 3s antes de guardar (si escribiera
    // en Config en cada tecla, la lista se reasigna entera y el Repeater reconstruye
    // todos los delegates, así que perderías el foco a mitad de escribir). El
    // problema es que agregar/borrar/mover otra fila también reasigna la lista
    // entera — y si eso pasaba antes de que el debounce disparara, se reconstruía
    // con el valor viejo y lo recién tipeado en la fila de arriba desaparecía.
    // Por eso toda mutación pasa por acá: lee la lista pisando cualquier campo
    // que todavía esté esperando su debounce, para no perderlo nunca.
    function snapshotWithPending() {
        let list = []
        for (let i = 0; i < Config.options.hyprland.autostartApps.apps.length; i++) {
            let o = Config.options.hyprland.autostartApps.apps[i]
            list.push({ cmd: o.cmd, workspace: o.workspace, delay: o.delay })
        }
        for (let i = 0; i < appsRepeater.count; i++) {
            const item = appsRepeater.itemAt(i)
            const pending = item?.pendingCmd
            if (pending !== undefined && list[i]) list[i].cmd = pending
        }
        return list
    }

    // Plano y sin "icon": si se le pasan los DesktopEntry tal cual, el combo
    // intenta pintar entry.icon (nombre de ícono del sistema, ej. "firefox")
    // como si fuera un glifo Material Symbol y muestra basura al lado de cada app.
    readonly property var appPickerModel: AppSearch.list.map(e => ({
        name: e.name,
        cmd: e.command.join(" ")
    }))

    function addEntry() {
        let list = root.snapshotWithPending()
        list.push({ cmd: "", workspace: 1, delay: 0 })
        Config.options.hyprland.autostartApps.apps = list
    }

    function removeEntry(index) {
        let list = root.snapshotWithPending()
        list.splice(index, 1)
        Config.options.hyprland.autostartApps.apps = list
    }

    function updateEntry(index, key, value) {
        let list = root.snapshotWithPending()
        list[index][key] = value
        Config.options.hyprland.autostartApps.apps = list
    }

    RowLayout {
        Layout.fillWidth: true
        GroupedList {
            Layout.fillWidth: true
            ConfigSwitch {
                buttonIcon: "check"
                text: Translation.tr("Enable")
                checked: Config.options.hyprland.autostartApps.enable
                onCheckedChanged: {
                    Config.options.hyprland.autostartApps.enable = checked
                }
            }
        }

        RippleButton {
            Layout.preferredWidth: 36
            Layout.preferredHeight: 36
            visible: Config.options.hyprland.autostartApps.enable
            buttonRadius: implicitWidth / 2
            colBackground: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.85)
            colBackgroundHover: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.6)
            colRipple: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.5)
            onClicked: {
                Quickshell.execDetached(["python3", `${Directories.scriptPath}/hyprland/autostart.py`])
            }
            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                horizontalAlignment: Text.AlignHCenter
                text: "motion_play"
                iconSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colPrimary
            }
        }
    }

    Item {
        Layout.fillWidth: true
        Layout.bottomMargin: -4
        height: 24
        visible: Config.options.hyprland.autostartApps.apps.length > 0 && Config.options.hyprland.autostartApps.enable

        Row {
            id: headerRightGroup
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            StyledText {
                width: 118
                horizontalAlignment: Text.AlignHCenter
                text: Translation.tr("Workspace")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.Medium
            }

            StyledText {
                width: 118
                horizontalAlignment: Text.AlignHCenter
                text: Translation.tr("Delay")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.Medium
            }

            Item { width: 36; height: 1 }
        }

        StyledText {
            anchors.left: parent.left
            anchors.right: headerRightGroup.left
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            text: Translation.tr("App or Command")
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.Medium
        }
    }

    Repeater {
        id: appsRepeater
        model: Config.options.hyprland.autostartApps.apps

        delegate: Item {
            id: entryRow
            required property var modelData
            required property int index
            Layout.fillWidth: true
            implicitHeight: fieldsColumn.implicitHeight
            visible: Config.options.hyprland.autostartApps.enable

            // undefined = nada pendiente; lo lee root.snapshotWithPending() antes
            // de reconstruir la lista para no pisar un cambio recién tipeado.
            readonly property var pendingCmd: cmdDebounceTimer.running ? cmdArea.text : undefined

            Row {
                id: rightGroup
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                ConfigSpinBox {
                    width: 118
                    value: entryRow.modelData.workspace ?? 1
                    from: 1
                    to: 20

                    property bool ready: false
                    Component.onCompleted: ready = true

                    onValueChanged: {
                        if (!ready) return
                        root.updateEntry(entryRow.index, "workspace", value)
                    }
                }

                ConfigSpinBox {
                    width: 118
                    value: entryRow.modelData.delay ?? 0
                    from: 0
                    to: 60
                    stepSize: 1

                    property bool ready: false
                    Component.onCompleted: ready = true

                    onValueChanged: {
                        if (!ready) return
                        root.updateEntry(entryRow.index, "delay", value)
                    }
                }

                RippleButton {
                    width: 36
                    height: 36
                    buttonRadius: width / 2
                    colBackground: ColorUtils.transparentize(Appearance.colors.colError, 0.85)
                    colBackgroundHover: ColorUtils.transparentize(Appearance.colors.colError, 0.6)
                    colRipple: ColorUtils.transparentize(Appearance.colors.colError, 0.5)
                    onClicked: root.removeEntry(entryRow.index)
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        text: "delete"
                        iconSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colError
                    }
                }
            }

            ColumnLayout {
                id: fieldsColumn
                anchors.left: parent.left
                anchors.right: rightGroup.left
                anchors.rightMargin: 6
                spacing: 4

                // Elegir de la lista de apps instaladas en vez de escribir el
                // comando a mano; el campo de abajo sigue editable por si hace
                // falta ajustar argumentos o poner un comando propio.
                StyledComboBoxSearch {
                    Layout.fillWidth: true
                    buttonIcon: "apps"
                    textRole: "name"
                    model: root.appPickerModel
                    currentIndex: -1
                    displayText: Translation.tr("Elegir una app instalada…")
                    onActivated: idx => {
                        const picked = root.appPickerModel[idx]
                        if (!picked) return
                        cmdDebounceTimer.stop()
                        cmdArea.text = picked.cmd
                        root.updateEntry(entryRow.index, "cmd", picked.cmd)
                    }
                }

                MaterialTextArea {
                    id: cmdArea
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Comando (o elegí una app arriba)")
                    text: entryRow.modelData.cmd ?? ""
                    wrapMode: TextEdit.Wrap
                    font.pixelSize: Appearance.font.pixelSize.normal

                    property bool ready: false
                    Component.onCompleted: ready = true

                    onTextChanged: {
                        if (!ready) return
                        cmdDebounceTimer.restart()
                    }
                    onActiveFocusChanged: {
                        // Guarda apenas se va el foco en vez de esperar los 3s,
                        // así clickear afuera nunca deja un cambio a mitad de guardar.
                        if (!activeFocus && cmdDebounceTimer.running) {
                            cmdDebounceTimer.stop()
                            root.updateEntry(entryRow.index, "cmd", cmdArea.text)
                        }
                    }

                    Timer {
                        id: cmdDebounceTimer
                        interval: 3000
                        repeat: false
                        onTriggered: {
                            root.updateEntry(entryRow.index, "cmd", cmdArea.text)
                        }
                    }
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 4

        Item { Layout.fillWidth: true }

        ToolbarPairedFab {
            visible: Config.options.hyprland.autostartApps.enable
            iconText: "add"
            onClicked: root.addEntry()
        }
    }
}
