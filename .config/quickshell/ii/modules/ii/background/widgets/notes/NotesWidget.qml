import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root
    configEntryName: "notes"
    hoverEnabled: true

    // ------------------------------------------------------------------ //
    // Tamaño
    // ------------------------------------------------------------------ //

    // Tamaño libre: la manija de abajo a la derecha lo cambia y queda guardado.
    // Además hay dos tamaños de un clic (compacto y grande) en el encabezado.
    readonly property real minWidth: 220
    readonly property real minHeight: 180
    readonly property real maxWidth: 960
    readonly property real maxHeight: 900
    readonly property size compactSize: Qt.size(276, 252)
    readonly property size largeSize: Qt.size(640, 460)
    property real widgetWidth: root.configEntry.width ?? root.compactSize.width
    property real widgetHeight: root.configEntry.height ?? root.compactSize.height
    // Alto al empezar a arrastrar: ResizeHandler sólo informa el ancho inicial.
    property real resizeStartHeight: -1
    readonly property bool resizing: root.resizeStartHeight >= 0

    // Con este ancho ya entra la barra de carpetas al costado de la lista
    readonly property real sidebarBreakpoint: 460
    readonly property bool showSidebar: root.widgetWidth >= root.sidebarBreakpoint
    readonly property bool isLarge: root.showSidebar

    implicitWidth: root.widgetWidth
    implicitHeight: root.widgetHeight

    // Animado sólo con los botones; arrastrando la manija tiene que seguir al mouse.
    Behavior on widgetWidth {
        enabled: !root.resizing
        animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
    }
    Behavior on widgetHeight {
        enabled: !root.resizing
        animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
    }

    // Los mismos límites de la manija para el enganche a la grilla (ver
    // AbstractBackgroundWidget.snapSizeToGrid).
    function snapSizeToGridHere(rawWidth, rawHeight) {
        return root.snapSizeToGrid(rawWidth, rawHeight,
            root.minWidth, root.minHeight, root.maxWidth, root.maxHeight)
    }

    function toggleLarge() {
        const preset = root.isLarge ? root.compactSize : root.largeSize
        const target = root.snapSizeToGridHere(preset.width, preset.height)
        root.widgetWidth = target.width
        root.widgetHeight = target.height
        root.configEntry.width = target.width
        root.configEntry.height = target.height
    }

    // ------------------------------------------------------------------ //
    // Qué se ve: vistas y carpetas
    // ------------------------------------------------------------------ //

    // "all" | "pinned" | "archive" | "f:<carpeta>". Queda guardada.
    property string view: root.configEntry.view ?? "all"
    function setView(view) {
        root.view = view
        root.configEntry.view = view
    }
    readonly property string viewFolder: root.view.startsWith("f:") ? root.view.slice(2) : ""

    /** Las carpetas propias, sin el archivo (que tiene su propia entrada). */
    readonly property var userFolders: Notes.folders.filter(f =>
        f !== Notes.archiveFolder && !f.startsWith(Notes.archiveFolder + "/"))

    function inView(note, view) {
        if (view === "all") return !Notes.isArchived(note)
        if (view === "pinned") return note.pinned && !Notes.isArchived(note)
        if (view === "archive") return Notes.isArchived(note)
        return note.folder === view.slice(2)
    }

    function countFor(view) {
        return Notes.list.filter(n => root.inView(n, view)).length
    }

    function viewTitle(view) {
        if (view === "all") return "Notas"
        if (view === "pinned") return "Fijadas"
        if (view === "archive") return "Archivo"
        return view.slice(2).split("/").pop()
    }

    // Si la carpeta que se estaba mirando desaparece (la borraste, acá o en
    // Obsidian), volver a Todas en vez de quedarse mirando la nada.
    Connections {
        target: Notes
        function onFoldersChanged() {
            if (root.viewFolder.length > 0 && Notes.loaded && !Notes.folders.includes(root.viewFolder))
                root.setView("all")
        }
    }

    readonly property var notesById: {
        const byId = ({})
        Notes.list.forEach(n => byId[n.id] = n)
        return byId
    }
    // Fijadas primero; después las más nuevas (o recién tocadas) arriba.
    // La lista es de ids y no de notas porque ScriptModel compara strings por
    // valor: así agregar, borrar o mover una nota es una inserción/remoción de
    // verdad (con su animación) y no un reseteo del modelo entero.
    readonly property var sortedIds: Notes.list
        .filter(n => root.inView(n, root.view))
        .sort((a, b) => (b.pinned - a.pinned) || ((b.createdAt ?? 0) - (a.createdAt ?? 0)))
        .map(n => n.id)

    /** 0, 1 o 2: el color sale del título, así no cambia al moverla ni cuando entra otra arriba. */
    function toneFor(title) {
        let sum = 0
        for (let i = 0; i < title.length; i++) sum += title.charCodeAt(i)
        return sum % 3
    }

    // ------------------------------------------------------------------ //
    // Teclado
    // ------------------------------------------------------------------ //

    property bool creatingFolder: false
    // La capa del escritorio sólo recibe teclado mientras se escribe algo.
    readonly property bool wantsKeyboard: root.mode === "edit" || root.creatingFolder
    onWantsKeyboardChanged: GlobalStates.desktopWidgetKeyboardFocus = root.wantsKeyboard

    // ------------------------------------------------------------------ //
    // Cambio entre la lista y el editor
    // ------------------------------------------------------------------ //

    property string mode: "list" // "list" | "edit"
    property var pendingNoteId: null
    property string editingTitle: ""
    property string editingText: ""
    property string editingFolder: ""
    property bool editingPinned: false
    property bool folderPickerOpen: false

    // 0 = lista, 1 = editor. Las dos páginas salen de este número: la que se
    // va se corre un poco y se desvanece rápido, y la que llega entra desde el
    // otro lado (el "eje compartido" de Material).
    property real pageProgress: 0
    // Cuánto se corre cada página, en px
    readonly property real pageShift: 36
    // Lo que hay que hacer cuando la transición termine (guardar, borrar).
    // Esperar deja ver la nota entrando o yéndose de la lista, en vez de que
    // pase mientras la lista todavía no se ve.
    property var afterTransition: null

    function switchPage() {
        // Un segundo clic en plena transición la dejaba a mitad de camino.
        if (pageAnim.running) return
        root.folderPickerOpen = false
        root.mode = root.mode === "list" ? "edit" : "list"
        pageAnim.to = root.mode === "edit" ? 1 : 0
        pageAnim.start()
    }

    function openNewNote() {
        if (pageAnim.running) return
        root.pendingNoteId = null
        root.editingTitle = ""
        root.editingText = ""
        // Nace donde estás mirando: en la carpeta abierta, o fijada si estás en Fijadas.
        root.editingFolder = root.viewFolder
        root.editingPinned = root.view === "pinned"
        switchPage()
    }

    function openNote(id) {
        if (pageAnim.running) return
        const note = root.notesById[id]
        if (!note) return
        root.pendingNoteId = note.id
        root.editingTitle = note.title
        root.editingText = note.content
        root.editingFolder = note.folder
        root.editingPinned = note.pinned
        switchPage()
    }

    function saveAndBack() {
        if (pageAnim.running) return
        const id = root.pendingNoteId
        const title = root.editingTitle.trim()
        const content = root.editingText
        const folder = root.editingFolder
        const pinned = root.editingPinned
        const empty = title.length === 0 && content.trim().length === 0

        if (!id) {
            if (!empty) root.afterTransition = () => {
                notesListView.positionViewAtBeginning()
                Notes.addNote(title, content, folder, pinned)
            }
        } else if (empty) {
            // Vaciaste una nota que ya existía: borrarla, no dejarla como estaba.
            root.afterTransition = () => Notes.deleteNote(id)
        } else {
            const before = root.notesById[id]
            root.afterTransition = () => {
                // En este orden: fijar y mover usan el id actual, y guardar
                // (que puede renombrar por el título) va último con el id ya movido.
                if (before && before.pinned !== pinned) Notes.setPinned(id, pinned)
                let current = id
                if (before && before.folder !== folder) {
                    Notes.moveNote(id, folder)
                    const name = id.split("/").pop()
                    current = folder ? `${folder}/${name}` : name
                }
                if (!before || before.title !== title || before.content !== content)
                    Notes.updateNote(current, title, content)
            }
        }
        switchPage()
    }

    function deleteAndBack() {
        if (pageAnim.running) return
        const id = root.pendingNoteId
        if (id) root.afterTransition = () => Notes.deleteNote(id)
        switchPage()
    }

    NumberAnimation {
        id: pageAnim
        target: root; property: "pageProgress"
        duration: 350
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Appearance.animationCurves.emphasizedDecel
        onFinished: {
            // Recién ahora el editor es visible y puede tomar el foco: una nota
            // nueva empieza por el título, una existente por el texto.
            if (root.mode === "edit") {
                if (root.pendingNoteId) editTextArea.forceActiveFocus()
                else titleField.forceActiveFocus()
            }
            const pending = root.afterTransition
            root.afterTransition = null
            if (pending) pending()
        }
    }

    /** Lo que pasa al soltar una nota arrastrada sobre una entrada de la barra. */
    function dropOn(view, noteId) {
        const note = root.notesById[noteId]
        if (!note) return
        if (view === "pinned") {
            if (!note.pinned) Notes.setPinned(noteId, true)
        } else if (view === "archive") {
            Notes.setArchived(noteId, true)
        } else if (view === "all") {
            // "Todas" = la raíz de la vault: la saca de su carpeta (o del archivo)
            Notes.moveNote(noteId, "")
        } else {
            Notes.moveNote(noteId, view.slice(2))
        }
    }

    // ------------------------------------------------------------------ //
    // Piezas
    // ------------------------------------------------------------------ //

    component FadeBehavior: Behavior {
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
    }

    // Botón redondo con ícono, para los encabezados y las acciones de las notas.
    component IconButton: Rectangle {
        id: iconButton
        property string icon: ""
        property color iconColor: Appearance.colors.colOnPrimaryContainer
        property color hoverColor: ColorUtils.transparentize(iconButton.iconColor, 0.88)
        property string tooltip: ""
        property bool filled: false
        property real size: 30
        readonly property bool hovered: iconArea.containsMouse
        signal clicked()

        implicitWidth: iconButton.size; implicitHeight: iconButton.size
        radius: Appearance.rounding.full
        color: iconArea.containsMouse ? iconButton.hoverColor : "transparent"
        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }
        enabled: Config.options.background.widgetsLocked
        opacity: enabled ? 1 : 0.4
        FadeBehavior on opacity {}

        MaterialSymbol {
            anchors.centerIn: parent
            iconSize: iconButton.size * 0.6
            text: iconButton.icon
            fill: iconButton.filled ? 1 : 0
            color: iconButton.iconColor
        }
        MouseArea {
            id: iconArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: iconButton.clicked()
        }
        StyledToolTip {
            visible: iconButton.tooltip.length > 0 && iconArea.containsMouse
            text: iconButton.tooltip
        }
    }

    // Una entrada de la barra de carpetas. También es donde se sueltan las notas.
    component SidebarItem: Rectangle {
        id: sidebarItem
        property string viewKey: "all"
        property string icon: "notes"
        property string label: ""
        property bool deletable: false
        readonly property bool selected: root.view === sidebarItem.viewKey
        readonly property bool dropHover: sidebarDrop.containsDrag
        readonly property bool armed: root.armedFolder === sidebarItem.viewKey

        Layout.fillWidth: true
        implicitHeight: 32
        radius: Appearance.rounding.small
        color: sidebarItem.dropHover ? Appearance.colors.colPrimary
            : sidebarItem.selected ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.7)
            : sidebarArea.containsMouse ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.88)
            : "transparent"
        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }
        scale: sidebarItem.dropHover ? 1.04 : 1
        Behavior on scale {
            animation: Appearance.animation.elementMoveSmall.numberAnimation.createObject(this)
        }
        readonly property color fg: sidebarItem.dropHover
            ? Appearance.colors.colOnPrimary
            : Appearance.colors.colOnPrimaryContainer

        MouseArea {
            id: sidebarArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.setView(sidebarItem.viewKey)
        }

        DropArea {
            id: sidebarDrop
            anchors.fill: parent
            keys: ["note"]
            onDropped: drop => {
                root.dropOn(sidebarItem.viewKey, drop.source.noteId)
                drop.accept()
            }
        }

        RowLayout {
            anchors { fill: parent; leftMargin: 8; rightMargin: 4 }
            spacing: 6

            MaterialSymbol {
                text: sidebarItem.icon
                iconSize: Appearance.font.pixelSize.large
                fill: sidebarItem.selected ? 1 : 0
                color: sidebarItem.fg
            }
            StyledText {
                Layout.fillWidth: true
                text: sidebarItem.label
                elide: Text.ElideRight
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: sidebarItem.selected ? Font.Medium : Font.Normal
                color: sidebarItem.fg
            }
            StyledText {
                visible: !(sidebarItem.deletable && (sidebarArea.containsMouse || deleteFolderButton.hovered || sidebarItem.armed))
                text: root.countFor(sidebarItem.viewKey)
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: sidebarItem.fg
                opacity: 0.6
                Layout.rightMargin: 4
            }
            // Borrar la carpeta: dos clics, porque se lleva todo lo que tiene adentro.
            IconButton {
                id: deleteFolderButton
                visible: sidebarItem.deletable && (sidebarArea.containsMouse || deleteFolderButton.hovered || sidebarItem.armed)
                size: 24
                icon: sidebarItem.armed ? "delete_forever" : "delete"
                iconColor: sidebarItem.armed ? Appearance.colors.colError : sidebarItem.fg
                tooltip: sidebarItem.armed ? "Otro clic: la carpeta y sus notas van a la papelera" : "Borrar carpeta"
                onClicked: {
                    if (sidebarItem.armed) {
                        root.armedFolder = ""
                        Notes.deleteFolder(sidebarItem.viewKey.slice(2))
                    } else {
                        root.armedFolder = sidebarItem.viewKey
                        disarmTimer.restart()
                    }
                }
            }
        }
    }

    property string armedFolder: ""
    Timer {
        id: disarmTimer
        interval: 3000
        onTriggered: root.armedFolder = ""
    }

    // Un chip del editor (carpeta, fijada)
    component Chip: Rectangle {
        id: chip
        property string icon: ""
        property string label: ""
        property bool active: false
        property bool filledIcon: false
        signal clicked()

        implicitHeight: 28
        implicitWidth: chipRow.implicitWidth + 20
        radius: Appearance.rounding.full
        color: chip.active ? Appearance.colors.colPrimary
            : chipArea.containsMouse ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.75)
            : ColorUtils.transparentize(Appearance.colors.colPrimary, 0.88)
        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }
        enabled: Config.options.background.widgetsLocked
        readonly property color fg: chip.active ? Appearance.colors.colOnPrimary : Appearance.colors.colOnPrimaryContainer

        RowLayout {
            id: chipRow
            anchors.centerIn: parent
            spacing: 4
            MaterialSymbol {
                text: chip.icon
                iconSize: Appearance.font.pixelSize.normal
                fill: chip.filledIcon ? 1 : 0
                color: chip.fg
            }
            StyledText {
                visible: chip.label.length > 0
                text: chip.label
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: chip.fg
                Layout.maximumWidth: 140
                elide: Text.ElideRight
            }
        }
        MouseArea {
            id: chipArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.clicked()
        }
    }

    // ------------------------------------------------------------------ //

    Item {
        id: cardWrapper
        anchors.fill: parent

        StyledDropShadow { target: contentRect }

        Rectangle {
            id: contentRect
            anchors.fill: parent
            color: Appearance.colors.colPrimaryContainer
            radius: Appearance.rounding?.verylarge ?? 30

            // ============================== Lista ============================== //
            RowLayout {
                id: listPage
                anchors { fill: parent; margins: 12 }
                spacing: 10
                // Se va en el primer tercio; entra en los dos últimos
                opacity: Math.max(0, 1 - root.pageProgress / 0.35)
                visible: opacity > 0
                enabled: root.mode === "list"
                transform: Translate { x: -root.pageProgress * root.pageShift }

                // ---------- Barra de carpetas (tamaño grande) ---------- //
                Item {
                    id: sidebar
                    Layout.fillHeight: true
                    Layout.preferredWidth: root.showSidebar ? 158 : 0
                    Behavior on Layout.preferredWidth {
                        animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
                    }
                    opacity: root.showSidebar ? 1 : 0
                    FadeBehavior on opacity {}
                    visible: Layout.preferredWidth > 1
                    clip: true

                    Rectangle {
                        anchors.fill: parent
                        width: 158
                        radius: Appearance.rounding.normal
                        color: ColorUtils.transparentize(Appearance.colors.colLayer0, 0.75)
                    }

                    Flickable {
                        id: sidebarFlick
                        anchors { fill: parent; margins: 6 }
                        width: 146
                        contentHeight: sidebarColumn.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        interactive: Config.options.background.widgetsLocked

                        ColumnLayout {
                            id: sidebarColumn
                            width: sidebarFlick.width
                            spacing: 2
                            enabled: Config.options.background.widgetsLocked

                            SidebarItem { viewKey: "all"; icon: "notes"; label: "Todas" }
                            SidebarItem { viewKey: "pinned"; icon: "keep"; label: "Fijadas" }

                            StyledText {
                                Layout.topMargin: 8
                                Layout.leftMargin: 8
                                Layout.bottomMargin: 2
                                visible: root.userFolders.length > 0
                                text: "Carpetas"
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                font.weight: Font.Medium
                                color: Appearance.colors.colOnPrimaryContainer
                                opacity: 0.6
                            }

                            Repeater {
                                model: root.userFolders
                                delegate: SidebarItem {
                                    required property string modelData
                                    viewKey: "f:" + modelData
                                    icon: "folder"
                                    // Las anidadas se ven con su ruta, indentadas
                                    label: modelData.split("/").pop()
                                    Layout.leftMargin: (modelData.split("/").length - 1) * 12
                                    deletable: true
                                }
                            }

                            // Nueva carpeta: un clic y se escribe el nombre acá mismo
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 32
                                radius: Appearance.rounding.small
                                color: root.creatingFolder
                                    ? ColorUtils.transparentize(Appearance.colors.colLayer0, 0.4)
                                    : newFolderArea.containsMouse ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.88)
                                    : "transparent"
                                Behavior on color {
                                    animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                                }

                                RowLayout {
                                    anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                                    spacing: 6
                                    MaterialSymbol {
                                        text: "create_new_folder"
                                        iconSize: Appearance.font.pixelSize.large
                                        color: Appearance.colors.colOnPrimaryContainer
                                        opacity: 0.7
                                    }
                                    StyledText {
                                        visible: !root.creatingFolder
                                        Layout.fillWidth: true
                                        text: "Nueva carpeta"
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        color: Appearance.colors.colOnPrimaryContainer
                                        opacity: 0.7
                                    }
                                    TextField {
                                        id: newFolderField
                                        visible: root.creatingFolder
                                        Layout.fillWidth: true
                                        padding: 0
                                        background: null
                                        placeholderText: "Nombre"
                                        placeholderTextColor: ColorUtils.transparentize(Appearance.colors.colOnPrimaryContainer, 0.5)
                                        color: Appearance.colors.colOnPrimaryContainer
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        onAccepted: {
                                            Notes.createFolder(text)
                                            root.creatingFolder = false
                                        }
                                        Keys.onEscapePressed: root.creatingFolder = false
                                        onActiveFocusChanged: if (!activeFocus) root.creatingFolder = false
                                    }
                                }

                                MouseArea {
                                    id: newFolderArea
                                    anchors.fill: parent
                                    visible: !root.creatingFolder
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        newFolderField.text = ""
                                        root.creatingFolder = true
                                        newFolderField.forceActiveFocus()
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.topMargin: 4
                                Layout.bottomMargin: 4
                                implicitHeight: 1
                                color: Appearance.colors.colOnPrimaryContainer
                                opacity: 0.12
                            }

                            SidebarItem { viewKey: "archive"; icon: "inventory_2"; label: "Archivo" }
                        }
                    }
                }

                // ---------- Notas ---------- //
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        StyledText {
                            Layout.topMargin: -4
                            Layout.leftMargin: 8
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            font.pixelSize: Appearance.font.pixelSize.huge
                            font.weight: Font.Medium
                            color: Appearance.colors.colOnPrimaryContainer
                            text: root.viewTitle(root.view)
                        }

                        IconButton {
                            Layout.alignment: Qt.AlignVCenter
                            icon: root.isLarge ? "close_fullscreen" : "open_in_full"
                            tooltip: root.isLarge ? "Achicar" : "Agrandar y ver carpetas"
                            onClicked: root.toggleLarge()
                        }
                        IconButton {
                            Layout.alignment: Qt.AlignVCenter
                            icon: "folder_open"
                            tooltip: "Abrir la vault en Obsidian"
                            onClicked: Notes.openInObsidian("")
                        }

                        ToolbarPairedFab {
                            Layout.leftMargin: 2
                            Layout.rightMargin: 4
                            Layout.alignment: Qt.AlignVCenter
                            enabled: Config.options.background.widgetsLocked && root.view !== "archive"
                            opacity: enabled ? 1 : 0.4
                            FadeBehavior on opacity {}
                            baseSize: 38
                            iconText: "add"
                            onClicked: root.openNewNote()
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        StyledListView {
                            id: notesListView
                            anchors.fill: parent
                            // Desbloqueado, la lista no debe comerse el gesto de
                            // arrastre del widget (ni scrolleando ni abriendo una nota).
                            interactive: Config.options.background.widgetsLocked
                            clip: true
                            spacing: 6
                            model: ScriptModel {
                                values: root.sortedIds
                            }

                            delegate: Item {
                                id: noteCard
                                required property string modelData
                                readonly property string noteId: modelData

                                // Mientras sale de la lista la nota ya no existe en
                                // Notes (o ya no está en esta vista): se queda con lo
                                // último que mostró para no irse en blanco.
                                readonly property var liveNote: root.notesById[noteCard.noteId] ?? null
                                property string shownTitle: ""
                                property string shownContent: ""
                                property bool shownPinned: false
                                property bool shownArchived: false
                                function syncShown() {
                                    if (!noteCard.liveNote) return
                                    noteCard.shownTitle = noteCard.liveNote.title
                                    noteCard.shownContent = noteCard.liveNote.content.trim()
                                    noteCard.shownPinned = noteCard.liveNote.pinned
                                    noteCard.shownArchived = Notes.isArchived(noteCard.liveNote)
                                }
                                onLiveNoteChanged: syncShown()
                                Component.onCompleted: syncShown()

                                readonly property int tone: root.toneFor(noteCard.shownTitle)
                                readonly property color bg: tone === 0 ? Appearance.colors.colPrimary
                                    : tone === 1 ? Appearance.colors.colSecondary
                                    : Appearance.colors.colTertiary
                                readonly property color fg: tone === 0 ? Appearance.colors.colOnPrimary
                                    : tone === 1 ? Appearance.colors.colOnSecondary
                                    : Appearance.colors.colOnTertiary
                                readonly property bool hovered: cardArea.containsMouse
                                    || pinButton.hovered || archiveButton.hovered || trashButton.hovered

                                enabled: Config.options.background.widgetsLocked
                                opacity: enabled ? 1 : 0.5
                                FadeBehavior on opacity {}
                                width: notesListView.width
                                implicitHeight: Math.max(48, noteTexts.implicitHeight + 22)

                                Rectangle {
                                    id: noteBody
                                    // Para que la barra sepa qué nota le soltaron
                                    readonly property string noteId: noteCard.noteId
                                    // Sin anchors: mientras se arrastra se muda a la
                                    // capa de arriba y se mueve con el mouse.
                                    width: noteCard.width
                                    height: noteCard.height
                                    radius: Appearance.rounding.normal
                                    color: noteCard.bg
                                    // Se hunde al presionarla; arrastrándola, se levanta
                                    scale: cardArea.drag.active ? 1.04 : cardArea.pressed ? 0.97 : 1
                                    Behavior on scale {
                                        animation: Appearance.animation.clickBounce.numberAnimation.createObject(this)
                                    }

                                    Drag.active: cardArea.drag.active
                                    Drag.keys: ["note"]
                                    Drag.hotSpot.x: cardArea.mouseX
                                    Drag.hotSpot.y: cardArea.mouseY

                                    states: State {
                                        when: cardArea.drag.active
                                        ParentChange { target: noteBody; parent: dragLayer }
                                        PropertyChanges { target: noteBody; opacity: 0.92; z: 10 }
                                    }
                                    // Soltada fuera de una carpeta: vuelve a su lugar en la lista.
                                    onParentChanged: if (parent === noteCard) Qt.callLater(() => {
                                        noteBody.x = 0
                                        noteBody.y = 0
                                    })

                                    // Capa de hover, como los botones de Material
                                    Rectangle {
                                        anchors.fill: parent
                                        radius: parent.radius
                                        color: noteCard.fg
                                        opacity: noteCard.hovered && !cardArea.pressed ? 0.08 : 0
                                        FadeBehavior on opacity {}
                                    }

                                    ColumnLayout {
                                        id: noteTexts
                                        anchors {
                                            left: parent.left; right: parent.right
                                            verticalCenter: parent.verticalCenter
                                            leftMargin: 12
                                            // Deja lugar a las acciones cuando aparecen
                                            rightMargin: noteCard.hovered ? noteActions.width + 14
                                                : noteCard.shownPinned ? 30 : 12
                                        }
                                        spacing: 1

                                        StyledText {
                                            Layout.fillWidth: true
                                            color: noteCard.fg
                                            text: noteCard.shownTitle
                                            font.weight: Font.Medium
                                            elide: Text.ElideRight
                                            maximumLineCount: 1
                                        }
                                        StyledText {
                                            Layout.fillWidth: true
                                            visible: text.length > 0
                                            color: noteCard.fg
                                            opacity: 0.8
                                            text: noteCard.shownContent
                                            font.pixelSize: Appearance.font.pixelSize.small
                                            wrapMode: Text.Wrap
                                            elide: Text.ElideRight
                                            maximumLineCount: 2
                                        }
                                    }

                                    // Chinche de "fijada" cuando no hay hover
                                    MaterialSymbol {
                                        anchors { right: parent.right; top: parent.top; margins: 8 }
                                        text: "keep"
                                        fill: 1
                                        iconSize: Appearance.font.pixelSize.normal
                                        color: noteCard.fg
                                        opacity: noteCard.shownPinned && !noteCard.hovered ? 0.8 : 0
                                        visible: opacity > 0
                                        FadeBehavior on opacity {}
                                    }

                                    MouseArea {
                                        id: cardArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                                        // Arrastrar a una carpeta sólo tiene sentido con la barra a la vista
                                        drag.target: root.showSidebar ? noteBody : null
                                        drag.threshold: 8
                                        // Que la lista no se robe el arrastre para scrollear
                                        preventStealing: root.showSidebar
                                        onClicked: root.openNote(noteCard.noteId)
                                        onReleased: if (drag.active) noteBody.Drag.drop()
                                    }

                                    Row {
                                        id: noteActions
                                        anchors {
                                            right: parent.right; rightMargin: 6
                                            verticalCenter: parent.verticalCenter
                                        }
                                        spacing: 2
                                        opacity: noteCard.hovered && !cardArea.drag.active ? 1 : 0
                                        scale: noteCard.hovered ? 1 : 0.7
                                        visible: opacity > 0
                                        FadeBehavior on opacity {}
                                        Behavior on scale {
                                            animation: Appearance.animation.elementMoveSmall.numberAnimation.createObject(this)
                                        }

                                        IconButton {
                                            id: pinButton
                                            size: 28
                                            icon: "keep"
                                            filled: noteCard.shownPinned
                                            iconColor: noteCard.fg
                                            tooltip: noteCard.shownPinned ? "Desfijar" : "Fijar"
                                            onClicked: Notes.setPinned(noteCard.noteId, !noteCard.shownPinned)
                                        }
                                        IconButton {
                                            id: archiveButton
                                            size: 28
                                            icon: noteCard.shownArchived ? "unarchive" : "archive"
                                            iconColor: noteCard.fg
                                            tooltip: noteCard.shownArchived ? "Sacar del archivo" : "Archivar"
                                            onClicked: Notes.setArchived(noteCard.noteId, !noteCard.shownArchived)
                                        }
                                        IconButton {
                                            id: trashButton
                                            size: 28
                                            icon: "delete"
                                            iconColor: trashButton.hovered ? Appearance.colors.colOnError : noteCard.fg
                                            hoverColor: Appearance.colors.colError
                                            tooltip: "Borrar"
                                            onClicked: Notes.deleteNote(noteCard.noteId)
                                        }
                                    }
                                }
                            }
                        }

                        ColumnLayout {
                            anchors.centerIn: parent
                            readonly property bool shown: notesListView.count === 0
                            opacity: shown ? 1 : 0
                            scale: shown ? 1 : 0.85
                            visible: opacity > 0
                            FadeBehavior on opacity {}
                            Behavior on scale {
                                animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
                            }
                            spacing: 6

                            MaterialSymbol {
                                Layout.alignment: Qt.AlignHCenter
                                text: root.view === "archive" ? "inventory_2"
                                    : root.view === "pinned" ? "keep" : "sticky_note_2"
                                iconSize: 32
                                color: Appearance.colors.colOnPrimaryContainer
                                opacity: 0.4
                            }
                            StyledText {
                                Layout.alignment: Qt.AlignHCenter
                                text: !Notes.loaded && Notes.lastError.length === 0 ? "Cargando…"
                                    : Notes.lastError.length > 0 ? "No se pudo leer la vault"
                                    : root.view === "archive" ? "Nada archivado"
                                    : root.view === "pinned" ? "Nada fijado"
                                    : "Sin notas"
                                color: Appearance.colors.colOnPrimaryContainer
                                opacity: 0.5
                                font.pixelSize: Appearance.font.pixelSize.small
                            }
                        }
                    }
                }
            }

            // ============================= Editor ============================= //
            ColumnLayout {
                id: editPage
                anchors { fill: parent; margins: 12 }
                spacing: 8
                opacity: Math.max(0, (root.pageProgress - 0.35) / 0.65)
                visible: opacity > 0
                enabled: root.mode === "edit"
                transform: Translate { x: (1 - root.pageProgress) * root.pageShift }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    IconButton {
                        icon: "arrow_back"
                        tooltip: "Volver sin guardar"
                        onClicked: root.switchPage()
                    }
                    Item { Layout.fillWidth: true }

                    // Estos dos sólo tienen sentido con una nota que ya existe
                    IconButton {
                        visible: root.pendingNoteId !== null
                        icon: "open_in_new"
                        tooltip: "Abrir en Obsidian"
                        onClicked: Notes.openInObsidian(root.pendingNoteId)
                    }
                    IconButton {
                        visible: root.pendingNoteId !== null
                        icon: "delete"
                        iconColor: Appearance.colors.colError
                        tooltip: "Borrar nota"
                        onClicked: root.deleteAndBack()
                    }

                    ToolbarPairedFab {
                        Layout.rightMargin: 4
                        Layout.alignment: Qt.AlignVCenter
                        enabled: Config.options.background.widgetsLocked
                        opacity: enabled ? 1 : 0.4
                        FadeBehavior on opacity {}
                        baseSize: 38
                        iconText: "save"
                        onClicked: root.saveAndBack()
                    }
                }

                // Título: es el nombre del archivo en la vault
                TextField {
                    id: titleField
                    Layout.fillWidth: true
                    leftPadding: 4; rightPadding: 4; topPadding: 0; bottomPadding: 0
                    background: null
                    text: root.editingTitle
                    placeholderText: "Título"
                    placeholderTextColor: ColorUtils.transparentize(Appearance.colors.colOnPrimaryContainer, 0.5)
                    color: Appearance.colors.colOnPrimaryContainer
                    font.pixelSize: Appearance.font.pixelSize.larger
                    font.weight: Font.Medium
                    enabled: Config.options.background.widgetsLocked
                    onTextChanged: root.editingTitle = text
                    // Enter pasa al texto, como en cualquier app de notas
                    onAccepted: editTextArea.forceActiveFocus()
                }

                // Dónde vive la nota y si está fijada
                Flow {
                    Layout.fillWidth: true
                    spacing: 6

                    Chip {
                        icon: Notes.isArchived({ folder: root.editingFolder }) ? "inventory_2" : "folder"
                        label: (root.editingFolder.length > 0 ? root.editingFolder : "Sin carpeta") + "  ▾"
                        active: root.folderPickerOpen
                        onClicked: root.folderPickerOpen = !root.folderPickerOpen
                    }
                    Chip {
                        icon: "keep"
                        filledIcon: root.editingPinned
                        label: root.editingPinned ? "Fijada" : "Fijar"
                        active: root.editingPinned
                        onClicked: root.editingPinned = !root.editingPinned
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Appearance.rounding.normal
                    color: Appearance.colors.colSurfaceContainerLow
                    enabled: Config.options.background.widgetsLocked
                    opacity: enabled ? 1 : 0.5
                    FadeBehavior on opacity {}

                    ScrollView {
                        anchors.fill: parent
                        anchors.margins: 8
                        TextArea {
                            id: editTextArea
                            text: root.editingText
                            wrapMode: TextArea.Wrap
                            placeholderText: "Escribí tu nota…"
                            color: Appearance.colors.colOnLayer0
                            background: null
                            onTextChanged: root.editingText = text
                        }
                    }

                    // Elegir carpeta: la lista cae encima del texto, como un menú
                    Rectangle {
                        id: folderPicker
                        anchors { top: parent.top; left: parent.left; right: parent.right; margins: 4 }
                        height: Math.min(parent.height - 8, pickerColumn.implicitHeight + 12)
                        radius: Appearance.rounding.small
                        color: Appearance.colors.colSurfaceContainerHigh
                        z: 5
                        opacity: root.folderPickerOpen ? 1 : 0
                        scale: root.folderPickerOpen ? 1 : 0.95
                        transformOrigin: Item.Top
                        visible: opacity > 0
                        FadeBehavior on opacity {}
                        Behavior on scale {
                            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                        }

                        Flickable {
                            anchors { fill: parent; margins: 6 }
                            contentHeight: pickerColumn.implicitHeight
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            Column {
                                id: pickerColumn
                                width: parent.width
                                spacing: 2

                                Repeater {
                                    model: [""].concat(root.userFolders).concat([Notes.archiveFolder])
                                    delegate: Rectangle {
                                        id: pickerItem
                                        required property string modelData
                                        readonly property bool current: root.editingFolder === modelData
                                        width: pickerColumn.width
                                        height: 30
                                        radius: Appearance.rounding.small
                                        color: pickerItem.current ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.7)
                                            : pickerArea.containsMouse ? ColorUtils.transparentize(Appearance.colors.colPrimary, 0.88)
                                            : "transparent"

                                        RowLayout {
                                            anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                                            spacing: 6
                                            MaterialSymbol {
                                                text: pickerItem.modelData === Notes.archiveFolder ? "inventory_2"
                                                    : pickerItem.modelData.length === 0 ? "notes" : "folder"
                                                iconSize: Appearance.font.pixelSize.normal
                                                color: Appearance.colors.colOnSurface
                                            }
                                            StyledText {
                                                Layout.fillWidth: true
                                                text: pickerItem.modelData.length > 0 ? pickerItem.modelData : "Sin carpeta"
                                                elide: Text.ElideRight
                                                font.pixelSize: Appearance.font.pixelSize.small
                                                color: Appearance.colors.colOnSurface
                                            }
                                            MaterialSymbol {
                                                visible: pickerItem.current
                                                text: "check"
                                                iconSize: Appearance.font.pixelSize.normal
                                                color: Appearance.colors.colOnSurface
                                            }
                                        }
                                        MouseArea {
                                            id: pickerArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                root.editingFolder = pickerItem.modelData
                                                root.folderPickerOpen = false
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Mientras se arrastra, la nota vive acá: por encima de todo y sin el
        // recorte de la lista, así se puede llevar hasta la barra de carpetas.
        Item {
            id: dragLayer
            anchors.fill: parent
            z: 20
        }

        ResizeHandler {
            anchorItem: contentRect
            hoverActive: root.containsMouse
            locked: Config.options.background.widgetsLocked
            currentWidth: root.widgetWidth
            resizeMode: "diagonal"
            z: 25
            onResizedXY: (dx, dy, startWidth) => {
                if (root.resizeStartHeight < 0) root.resizeStartHeight = root.widgetHeight
                const size = root.snapSizeToGridHere(startWidth + dx, root.resizeStartHeight + dy)
                root.widgetWidth = size.width
                root.widgetHeight = size.height
            }
            onResizeFinished: {
                root.resizeStartHeight = -1
                root.configEntry.width = root.widgetWidth
                root.configEntry.height = root.widgetHeight
                root.flashEdges(root.widgetWidth, root.widgetHeight)
            }
        }
    }
}
