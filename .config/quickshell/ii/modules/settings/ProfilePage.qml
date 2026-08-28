import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Qt.labs.folderlistmodel
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.common.models

ContentPage {
    id: page
    property string descriptionMode: {
        if (Config.options.profile.descriptionText === "::uptime::") return "uptime"
        return "distro"
    }
    property string hostnameInput: SystemInfo.hostname

    FolderListModel {
        id: avatarFolderModel
        folder: Config.options.profile.avatarPath !== "" ? Qt.resolvedUrl(Config.options.profile.avatarPath) : ""
        showDirs: false
        nameFilters: ["*.png", "*.svg", "*.jpg", "*.jpeg", "*.webp"]
    }

    Process {
        id: hostnameSetProc
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                SystemInfo.refreshHostname()
            }
        }
    }

    function applyHostname() {
        const newName = page.hostnameInput.trim()
        if (newName.length === 0 || newName === SystemInfo.hostname) return
        hostnameSetProc.command = ["hostnamectl", "set-hostname", newName]
        hostnameSetProc.running = true
    }

    Connections {
        target: SystemInfo
        function onHostnameChanged() {
            hostnameField.value = Qt.binding(() => SystemInfo.hostname)
        }
    }

    ColumnLayout {
        id: mainLayout
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 20

        ContentSection {
            icon: "person"
            shape: MaterialShape.Shape.Circle
            title: Translation.tr("Avatar")

            GroupedList {
                ConfigTextArea {
                    id: avatarField
                    Layout.fillWidth: true
                    buttonIcon: "folder_open"
                    text: Translation.tr("Avatar path")
                    placeholderText: Translation.tr("Leave empty to use ~/.face, e.g. /home/youruser/Pictures/avatar")
                    value: Config.options.profile.avatarPath
                    onValueChanged: {
                        avatarDebounceTimer.restart()
                    }

                    Timer {
                        id: avatarDebounceTimer
                        interval: 1000
                        repeat: false
                        onTriggered: {
                            Config.options.profile.avatarPath = avatarField.value
                        }
                    }

                    confirmButtonVisible: Config.options.profile.avatarPath !== ""
                    confirmButtonIcon: "add"
                    onConfirmClicked: {
                        GlobalStates.settingsOpen = false
                        if (Config.options.profile.avatarPath !== "") {
                            Quickshell.execDetached(["dolphin", Config.options.profile.avatarPath])
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                    implicitHeight: Config.options.profile.avatarPath === "" ? placeholderCol.implicitHeight : avatarFlow.implicitHeight

                    Flow {
                        id: avatarFlow
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8

                        Repeater {
                            model: avatarFolderModel
                            delegate: Rectangle {
                                required property string fileName
                                required property string filePath
                                width: 64
                                height: 64
                                radius: width / 2
                                color: Appearance.colors.colLayer2

                                property bool isSelected: FileUtils.trimFileProtocol(filePath.toString()) === Config.options.profile.avatarPicture

                                Image {
                                    id: avatarImage
                                    anchors.fill: parent
                                    source: filePath
                                    fillMode: Image.PreserveAspectCrop
                                    sourceSize.width: avatarImage.width * 2
                                    sourceSize.height: avatarImage.height * 2
                                    layer.enabled: true
                                    layer.effect: OpacityMask {
                                        maskSource: Rectangle {
                                            width: 64; height: width; radius: width / 2 
                                        }
                                    }
                                }

                                Rectangle {
                                    visible: parent.isSelected
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    anchors.rightMargin: 2
                                    anchors.bottomMargin: 2
                                    width: 20
                                    height: width
                                    radius: width / 2
                                    color: Appearance.colors.colPrimary

                                    MaterialSymbol {
                                        anchors.centerIn: parent
                                        text: "check"
                                        iconSize: Appearance.font.pixelSize.small
                                        color: Appearance.colors.colOnPrimary
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Config.options.profile.avatarPicture = FileUtils.trimFileProtocol(filePath.toString())
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        id: placeholderCol
                        visible: Config.options.profile.avatarPath === ""
                        anchors.centerIn: parent
                        z: 1
                        spacing: 4

                        MaterialSymbol {
                            Layout.alignment: Qt.AlignHCenter
                            text: "image"
                            iconSize: 32
                            color: Appearance.colors.colSubtext
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: Translation.tr("Pick a folder above to see avatars here")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                        }
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Identity")

                GroupedList {
                    ConfigTextArea {
                        id: displayNameField
                        buttonIcon: "badge"
                        placeholderText: SystemInfo.username
                        text: Translation.tr("Display name")
                        value: Config.options.profile.displayName

                        Timer {
                            id: displayNameDebounceTimer
                            interval: 800
                            running: false
                            onTriggered: {
                                Config.options.profile.displayName = displayNameField.value
                            }
                        }
                        onValueChanged: displayNameDebounceTimer.restart()
                    }

                    ConfigTextArea {
                        id: hostnameField
                        Layout.fillWidth: true
                        buttonIcon: "dns"
                        placeholderText: SystemInfo.hostname
                        text: Translation.tr("Hostname")
                        description: Translation.tr("Requires authentication to change")
                        value: page.hostnameInput
                        onValueChanged: page.hostnameInput = value

                        confirmButtonVisible: page.hostnameInput.trim() !== "" && page.hostnameInput.trim() !== SystemInfo.hostname
                        onConfirmClicked: {
                            page.applyHostname();
                        }
                    }

                    // El `ConfigSelectionArray` de `ii` es un Flow de botones y no acepta
                    // `text`/`icon` como el del fork: la etiqueta va aparte.
                    ContentSubsectionLabel {
                        text: Translation.tr("Description text")
                    }

                    ConfigSelectionArray {
                        currentValue: page.descriptionMode
                        onSelected: newValue => {
                            page.descriptionMode = newValue
                            if (newValue === "distro") Config.options.profile.descriptionText = "::distro::"
                            if (newValue === "uptime") Config.options.profile.descriptionText = "::uptime::"
                        }
                        options: [
                            { displayName: Translation.tr("Distro"), icon: "deployed_code", value: "distro" },
                            { displayName: Translation.tr("Uptime"), icon: "timelapse",     value: "uptime" },
                        ]
                    }
                }
            }
        }

        ContentSection {
            icon: "cloud_done"
            shape: MaterialShape.Shape.Clover4Leaf
            title: Translation.tr("Cuentas")

            ContentSubsection {
                title: Translation.tr("Google")
                tooltip: Translation.tr("Alimenta los eventos del calendario y las tareas del widget de To Do.\n\n"
                    + "«Conectar cuenta» abre el navegador y te guía paso a paso, con un link a cada\n"
                    + "pantalla. Google no deja usar sus APIs sin un cliente propio, así que la primera\n"
                    + "vez hay que crearlo — son cuatro pantallas y no se repite nunca más.")

                NoticeBox {
                    Layout.fillWidth: true
                    materialIcon: GoogleAccount.needsReauth ? "error"
                        : GoogleAccount.healthy && GoogleAccount.connected ? "check_circle"
                        : "info"
                    text: GoogleAccount.status
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    // Con el cliente ya guardado, reconectar salta la guía y va
                    // directo al permiso; la primera vez abre la página que guía.
                    RippleButtonWithIcon {
                        materialIcon: GoogleAccount.state === "waiting" ? "hourglass_top" : "link"
                        mainText: GoogleAccount.state === "waiting" ? Translation.tr("Esperando al navegador…")
                            : GoogleAccount.connected ? Translation.tr("Volver a conectar")
                            : Translation.tr("Conectar cuenta")
                        enabled: GoogleAccount.state !== "waiting" && GoogleAccount.state !== "working"
                        onClicked: GoogleAccount.connected ? GoogleAccount.relogin() : GoogleAccount.login()
                    }

                    RippleButtonWithIcon {
                        visible: GoogleAccount.connected && GoogleAccount.configured
                            && GoogleAccount.state !== "waiting"
                        materialIcon: "tune"
                        mainText: Translation.tr("Cambiar el cliente")
                        onClicked: GoogleAccount.login()
                    }

                    RippleButtonWithIcon {
                        visible: GoogleAccount.state === "waiting"
                        materialIcon: "close"
                        mainText: Translation.tr("Cancelar")
                        onClicked: GoogleAccount.cancelLogin()
                    }

                    RippleButtonWithIcon {
                        visible: GoogleAccount.connected && GoogleAccount.state !== "waiting"
                        materialIcon: "link_off"
                        mainText: Translation.tr("Desconectar")
                        onClicked: GoogleAccount.logout()
                    }

                    Item { Layout.fillWidth: true }
                }

                ConfigSwitch {
                    buttonIcon: "calendar_month"
                    text: Translation.tr("Eventos en el calendario")
                    checked: Config.options.services.google.calendar.enable
                    onCheckedChanged: {
                        Config.options.services.google.calendar.enable = checked;
                    }
                }
                ConfigSpinBox {
                    icon: "av_timer"
                    text: Translation.tr("Refrescar el calendario cada (min)")
                    enabled: Config.options.services.google.calendar.enable
                    value: Config.options.services.google.calendar.refreshMinutes
                    from: 1
                    to: 120
                    stepSize: 1
                    onValueChanged: {
                        Config.options.services.google.calendar.refreshMinutes = value;
                    }
                }
                ConfigSpinBox {
                    icon: "format_list_numbered"
                    text: Translation.tr("Eventos en «lo que viene»")
                    enabled: Config.options.services.google.calendar.enable
                    value: Config.options.services.google.calendar.upcomingCount
                    from: 1
                    to: 20
                    stepSize: 1
                    onValueChanged: {
                        Config.options.services.google.calendar.upcomingCount = value;
                    }
                }

                ConfigSwitch {
                    buttonIcon: "checklist"
                    text: Translation.tr("Google Tasks en el To Do")
                    checked: Config.options.services.google.tasks.enable
                    onCheckedChanged: {
                        Config.options.services.google.tasks.enable = checked;
                    }
                }
                ConfigSwitch {
                    buttonIcon: "cloud_upload"
                    text: Translation.tr("Las tareas nuevas van a Google")
                    enabled: Config.options.services.google.tasks.enable
                    checked: Config.options.services.google.tasks.addNewTasksToGoogle
                    onCheckedChanged: {
                        Config.options.services.google.tasks.addNewTasksToGoogle = checked;
                    }
                }
                ConfigSpinBox {
                    icon: "av_timer"
                    text: Translation.tr("Refrescar las tareas cada (min)")
                    enabled: Config.options.services.google.tasks.enable
                    value: Config.options.services.google.tasks.refreshMinutes
                    from: 1
                    to: 120
                    stepSize: 1
                    onValueChanged: {
                        Config.options.services.google.tasks.refreshMinutes = value;
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("iCloud")
                tooltip: Translation.tr("Calendario, Recordatorios y correo de iCloud.\n\n"
                    + "Apple no tiene OAuth para esto: «Iniciar sesión con Apple» te loguea en OTROS\n"
                    + "sitios, no da acceso a tus datos. Lo único que existe para un cliente de\n"
                    + "terceros es CalDAV/IMAP con una contraseña de aplicación.\n\n"
                    + "Igual no tenés que buscar nada: «Conectar cuenta» abre el navegador, te linkea\n"
                    + "directo a donde se genera y verifica la credencial antes de guardarla.\n"
                    + "Se revoca cuando quieras desde account.apple.com.")

                NoticeBox {
                    Layout.fillWidth: true
                    materialIcon: AppleAccount.needsReauth ? "error"
                        : AppleAccount.healthy && AppleAccount.connected ? "check_circle"
                        : "info"
                    text: AppleAccount.status
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    RippleButtonWithIcon {
                        materialIcon: AppleAccount.state === "waiting" ? "hourglass_top" : "link"
                        mainText: AppleAccount.state === "waiting" ? Translation.tr("Esperando al navegador…")
                            : AppleAccount.connected ? Translation.tr("Volver a conectar")
                            : Translation.tr("Conectar cuenta")
                        enabled: AppleAccount.state !== "waiting" && AppleAccount.state !== "working"
                        onClicked: AppleAccount.login()
                    }

                    RippleButtonWithIcon {
                        visible: AppleAccount.state === "waiting"
                        materialIcon: "close"
                        mainText: Translation.tr("Cancelar")
                        onClicked: AppleAccount.cancelLogin()
                    }

                    RippleButtonWithIcon {
                        visible: AppleAccount.connected && AppleAccount.state !== "waiting"
                        materialIcon: "link_off"
                        mainText: Translation.tr("Desconectar")
                        onClicked: AppleAccount.logout()
                    }

                    Item { Layout.fillWidth: true }
                }

                ConfigSwitch {
                    buttonIcon: "calendar_month"
                    text: Translation.tr("Eventos de iCloud en el calendario")
                    checked: Config.options.services.apple.calendar.enable
                    onCheckedChanged: {
                        Config.options.services.apple.calendar.enable = checked;
                    }
                }
                ConfigSpinBox {
                    icon: "av_timer"
                    text: Translation.tr("Refrescar el calendario cada (min)")
                    enabled: Config.options.services.apple.calendar.enable
                    value: Config.options.services.apple.calendar.refreshMinutes
                    from: 1
                    to: 120
                    stepSize: 1
                    onValueChanged: {
                        Config.options.services.apple.calendar.refreshMinutes = value;
                    }
                }

                ConfigSwitch {
                    buttonIcon: "checklist"
                    text: Translation.tr("Recordatorios de iCloud en el To Do")
                    checked: Config.options.services.apple.reminders.enable
                    onCheckedChanged: {
                        Config.options.services.apple.reminders.enable = checked;
                    }
                }
                ConfigSwitch {
                    buttonIcon: "cloud_upload"
                    text: Translation.tr("Las tareas nuevas van a iCloud")
                    enabled: Config.options.services.apple.reminders.enable
                        && !Config.options.services.google.tasks.addNewTasksToGoogle
                    checked: Config.options.services.apple.reminders.addNewTasksToApple
                    onCheckedChanged: {
                        Config.options.services.apple.reminders.addNewTasksToApple = checked;
                    }
                }
                ConfigSpinBox {
                    icon: "av_timer"
                    text: Translation.tr("Refrescar los recordatorios cada (min)")
                    enabled: Config.options.services.apple.reminders.enable
                    value: Config.options.services.apple.reminders.refreshMinutes
                    from: 1
                    to: 120
                    stepSize: 1
                    onValueChanged: {
                        Config.options.services.apple.reminders.refreshMinutes = value;
                    }
                }
            }

            ContentSubsection {
                title: Translation.tr("Correo")
                tooltip: Translation.tr("Cuántos mails sin leer tenés y de quién, de todas tus cuentas juntas.\n\n"
                    + "Va por IMAP y no por OAuth a propósito: una contraseña de aplicación no vence\n"
                    + "nunca y el mismo lector sirve para Gmail, iCloud y Proton.\n\n"
                    + "Proton necesita Proton Mail Bridge corriendo: tu correo está cifrado y no hay\n"
                    + "IMAP público. La página de conexión te explica cómo y te avisa si no está.\n\n"
                    + "«Agregar» abre el navegador, te linkea directo a donde se genera la contraseña\n"
                    + "y la verifica antes de guardarla. El buzón se abre en modo lectura, así que\n"
                    + "mirar el widget no te marca nada como leído.")

                NoticeBox {
                    Layout.fillWidth: true
                    materialIcon: MailService.connectError.length > 0 || MailService.lastError.length > 0 ? "error"
                        : MailService.enabled ? "check_circle"
                        : "info"
                    text: MailService.connectError.length > 0 ? MailService.connectError : MailService.status
                }

                ConfigSwitch {
                    buttonIcon: "mail"
                    text: Translation.tr("Mostrar el correo")
                    checked: Config.options.services.mail.enable
                    onCheckedChanged: {
                        Config.options.services.mail.enable = checked;
                    }
                }

                // Una fila por cuenta. La contraseña no se muestra ni se edita acá:
                // para cambiarla se vuelve a conectar, que además la verifica.
                Repeater {
                    model: MailService.allAccounts

                    RowLayout {
                        id: mailAccountRow
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 8

                        MaterialSymbol {
                            text: MailService.passwordFor(mailAccountRow.modelData.id).length > 0
                                ? "mark_email_read" : "key_off"
                            iconSize: Appearance.font.pixelSize.larger
                            color: MailService.passwordFor(mailAccountRow.modelData.id).length > 0
                                ? Appearance.m3colors.m3primary
                                : Appearance.colors.colSubtext
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            StyledText {
                                Layout.fillWidth: true
                                text: mailAccountRow.modelData.label
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colOnLayer1
                                elide: Text.ElideRight
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: {
                                    const id = mailAccountRow.modelData.id;
                                    if (MailService.passwordFor(id).length === 0)
                                        return Translation.tr("Sin contraseña — volvé a conectarla");
                                    const resultado = MailService.results[id];
                                    if (resultado?.error) return resultado.error;
                                    if (resultado === undefined) return mailAccountRow.modelData.host;
                                    return Translation.tr("%1 sin leer").arg(resultado.unread ?? 0);
                                }
                                font.pixelSize: Appearance.font.pixelSize.smallest
                                color: Appearance.colors.colSubtext
                                elide: Text.ElideRight
                            }
                        }

                        ConfigSwitch {
                            checked: mailAccountRow.modelData.enable
                            onCheckedChanged: {
                                if (checked === mailAccountRow.modelData.enable) return;
                                MailService.upsertAccount(Object.assign({},
                                    mailAccountRow.modelData, ({ "enable": checked })));
                            }
                        }

                        RippleButton {
                            implicitHeight: 34
                            implicitWidth: 34
                            buttonRadius: Appearance.rounding.small
                            onClicked: MailService.removeAccount(mailAccountRow.modelData.id)
                            contentItem: MaterialSymbol {
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                text: "delete"
                                iconSize: Appearance.font.pixelSize.large
                                color: Appearance.colors.colOnLayer1
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    RippleButtonWithIcon {
                        materialIcon: MailService.connecting === "gmail" ? "hourglass_top" : "add"
                        mainText: MailService.connecting === "gmail"
                            ? Translation.tr("Esperando al navegador…")
                            : Translation.tr("Agregar Gmail")
                        enabled: MailService.connectState !== "waiting" && MailService.connectState !== "working"
                        onClicked: MailService.connectAccount("gmail")
                    }

                    RippleButtonWithIcon {
                        materialIcon: MailService.connecting === "icloud" ? "hourglass_top" : "add"
                        mainText: MailService.connecting === "icloud"
                            ? Translation.tr("Esperando al navegador…")
                            : Translation.tr("Agregar iCloud")
                        enabled: MailService.connectState !== "waiting" && MailService.connectState !== "working"
                        onClicked: MailService.connectAccount("icloud")
                    }

                    RippleButtonWithIcon {
                        materialIcon: MailService.connecting === "proton" ? "hourglass_top" : "add"
                        mainText: MailService.connecting === "proton"
                            ? Translation.tr("Esperando al navegador…")
                            : Translation.tr("Agregar Proton")
                        enabled: MailService.connectState !== "waiting" && MailService.connectState !== "working"
                        onClicked: MailService.connectAccount("proton")
                    }

                    RippleButtonWithIcon {
                        visible: MailService.connectState === "waiting"
                        materialIcon: "close"
                        mainText: Translation.tr("Cancelar")
                        onClicked: MailService.cancelConnect()
                    }

                    Item { Layout.fillWidth: true }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    RippleButtonWithIcon {
                        materialIcon: "sync"
                        mainText: Translation.tr("Revisar ahora")
                        enabled: MailService.configured && !MailService.loading
                        onClicked: MailService.refresh()
                    }
                    Item { Layout.fillWidth: true }
                }

                ConfigSpinBox {
                    icon: "av_timer"
                    text: Translation.tr("Revisar cada (min)")
                    value: Config.options.services.mail.refreshMinutes
                    from: 1
                    to: 120
                    stepSize: 1
                    onValueChanged: {
                        Config.options.services.mail.refreshMinutes = value;
                    }
                }
            }
        }

        ContentSection {
            icon: "wall_art"
            shape: MaterialShape.Shape.Pentagon
            title: Translation.tr("Presets")

            GroupedList {
                ConfigTextArea {
                    id: presetNameField
                    Layout.fillWidth: true
                    fieldWidth: 300
                    buttonIcon: "newsmode"
                    text: Translation.tr("Save as")
                    placeholderText: Translation.tr("Name, description (optional)")

                    confirmButtonVisible: presetNameField.value.trim() !== ""
                    confirmButtonIcon: "save"
                    onConfirmClicked: {
                        Presets.save(presetNameField.value)
                        presetNameField.value = ""
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                Layout.topMargin: 40
                visible: Presets.folderModel.count === 0
                horizontalAlignment: Text.AlignHCenter
                text: Translation.tr("No presets yet")
                color: Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.normal
            }

            Flow {
                Layout.topMargin: 10
                Layout.fillWidth: true
                width: parent.width
                spacing: 12
                visible: Presets.folderModel.count > 0

                Repeater {
                    model: Presets.folderModel
                    delegate: PresetsCard {
                        id: presetDelegate
                        required property string fileName
                        required property string filePath

                        property string presetName: fileName.replace(".json", "")
                        property string presetWallpaper: ""
                        property string presetDescription: ""

                        FileView {
                            path: presetDelegate.filePath
                            onLoaded: {
                                try {
                                    const data = JSON.parse(text())
                                    const rawWallpaper = data?.background?.wallpaperPath ?? ""
                                    const isVideo = /\.(mp4|webm|mkv|avi|mov)$/i.test(rawWallpaper)
                                    presetDelegate.presetWallpaper = isVideo
                                        ? (data?.background?.thumbnailPath ?? "")
                                        : rawWallpaper
                                    presetDelegate.presetDescription = data?._presetMeta?.description ?? ""
                                } catch (e) {
                                    console.log("Failed to parse preset:", e)
                                }
                            }
                        }

                        imageSource: presetDelegate.presetWallpaper
                        title: presetDelegate.presetName
                        description: presetDelegate.presetDescription !== "" ? presetDelegate.presetDescription : Translation.tr("Saved preset")
                        onApply: () => Presets.apply(presetDelegate.presetName)
                        onRemove: () => Presets.remove(presetDelegate.presetName)
                    }
                }
            }
        }
    }
}
