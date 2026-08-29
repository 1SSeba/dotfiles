import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.ii.background.widgets

/**
 * Notas locales del escritorio. No hay API de Apple para iCloud Notes (Apple
 * no la expone a apps de terceros bajo ningún concepto -- ni siquiera con
 * contraseña de aplicación, a diferencia de Calendario/Recordatorios que sí
 * hablan CalDAV), así que esto vive únicamente en Notes.qml/notes.json. Lo
 * más cercano a "notas conectadas a la nube" es el widget de Tareas
 * (../tasks/TasksWidget.qml), que sí sincroniza con Google Tasks y Apple
 * Reminders de verdad.
 */
AbstractBackgroundWidget {
    id: root
    configEntryName: "notes"
    hoverEnabled: true

    implicitWidth: 276
    implicitHeight: 252

    property string mode: "list" // "list" | "edit"
    property var pendingNoteId: null
    property string editingText: ""
    property string searchQuery: ""
    onModeChanged: {
        GlobalStates.desktopWidgetKeyboardFocus = (mode === "edit")
        // Entrar a editar arranca escribiendo directo, sin tener que clickear
        // el textarea. El timer espera a que termine la animación de flip; si
        // no, el foco no prende porque el textarea todavía no es visible.
        if (mode === "edit") editFocusTimer.start()
    }

    function toggleFlip() { flipAnim.start() }

    function openNewNote() {
        root.pendingNoteId = null
        root.editingText = ""
        toggleFlip()
    }

    function openNote(note) {
        root.pendingNoteId = note.id
        root.editingText = note.content
        toggleFlip()
    }

    function saveAndBack() {
        if (root.editingText.length > 0) {
            if (root.pendingNoteId) {
                Notes.updateNote(root.pendingNoteId, root.editingText)
            } else {
                Notes.addNote(root.editingText)
            }
        }
        toggleFlip()
    }

    function deleteEditingNote() {
        if (root.pendingNoteId) Notes.deleteNote(root.pendingNoteId)
        toggleFlip()
    }

    /** Más nuevas primero (por edición si la tiene, si no por creación), filtradas por búsqueda. */
    readonly property var visibleNotes: {
        const query = root.searchQuery.trim().toLowerCase()
        let items = Notes.list.slice()
        items.sort((a, b) => (b.updatedAt ?? b.createdAt ?? 0) - (a.updatedAt ?? a.createdAt ?? 0))
        if (query.length > 0)
            items = items.filter(n => (n.content ?? "").toLowerCase().includes(query))
        return items
    }

    /** Color estable por nota (según su id, no su posición): que no rote todo al borrar una de arriba. */
    function colorIndexFor(id) {
        let hash = 0
        const s = String(id)
        for (let i = 0; i < s.length; i++)
            hash = (hash * 31 + s.charCodeAt(i)) % 3
        return hash
    }

    /** "Ahora" / "Hace 5 min" / "Ayer" / "12 ago", para no mostrar timestamps crudos. */
    function formatRelative(ms) {
        if (!ms) return ""
        const diff = Date.now() - ms
        const minute = 60000, hour = 3600000, day = 86400000
        if (diff < minute) return Translation.tr("Ahora")
        if (diff < hour) return Translation.tr("Hace %1 min").arg(Math.max(1, Math.floor(diff / minute)))
        if (diff < day) return Translation.tr("Hace %1 h").arg(Math.floor(diff / hour))
        const days = Math.floor(diff / day)
        if (days === 1) return Translation.tr("Ayer")
        if (days < 7) return Translation.tr("Hace %1 días").arg(days)
        return new Date(ms).toLocaleDateString(Qt.locale(), "d MMM")
    }

    Item {
        id: cardWrapper
        anchors.fill: parent

        transform: Scale {
            id: flipScale
            origin.x: cardWrapper.width  / 2
            origin.y: cardWrapper.height / 2
            xScale: 1
        }

        SequentialAnimation {
            id: flipAnim
            NumberAnimation {
                target: flipScale; property: "xScale"
                to: 0; duration: 150; easing.type: Easing.InQuad
            }
            ScriptAction {
                script: root.mode = (root.mode === "list" ? "edit" : "list")
            }
            NumberAnimation {
                target: flipScale; property: "xScale"
                to: 1; duration: 150; easing.type: Easing.OutQuad
            }
        }

        StyledDropShadow { target: contentRect }

        Rectangle {
            id: contentRect
            anchors.fill: parent
            color: Appearance.colors.colPrimaryContainer
            radius: Appearance.rounding?.verylarge ?? 30

            // List
            ColumnLayout {
                id: listPage
                anchors { fill: parent; margins: 12 }
                spacing: 8
                visible: root.mode === "list"

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    StyledText {
                        Layout.topMargin: -4
                        Layout.leftMargin: 8
                        font.pixelSize: Appearance.font.pixelSize.huge
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnPrimaryContainer
                        text: "Notes"
                    }
                    StyledText {
                        Layout.leftMargin: 2
                        visible: Notes.list.length > 0
                        text: Notes.list.length
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnPrimaryContainer
                        opacity: 0.6
                    }
                    Item { Layout.fillWidth: true }

                    ToolbarPairedFab {
                        Layout.rightMargin: 4
                        Layout.alignment: Qt.AlignVCenter
                        baseSize: 38
                        iconText: "add"
                        onClicked: root.openNewNote()
                    }
                }

                // Buscador: sólo estorba cuando hay bastantes notas como para
                // que valga la pena filtrar en vez de scrollear.
                Rectangle {
                    Layout.fillWidth: true
                    visible: Notes.list.length > 3
                    implicitHeight: 32
                    radius: Appearance.rounding.full
                    color: ColorUtils.transparentize(Appearance.colors.colOnPrimaryContainer, 0.85)

                    RowLayout {
                        anchors {
                            fill: parent
                            leftMargin: 10
                            rightMargin: 10
                        }
                        spacing: 6

                        MaterialSymbol {
                            text: "search"
                            iconSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.6
                        }
                        TextField {
                            id: searchField
                            Layout.fillWidth: true
                            text: root.searchQuery
                            onTextChanged: root.searchQuery = text
                            placeholderText: Translation.tr("Buscar notas…")
                            placeholderTextColor: ColorUtils.transparentize(Appearance.colors.colOnPrimaryContainer, 0.55)
                            color: Appearance.colors.colOnPrimaryContainer
                            font.pixelSize: Appearance.font.pixelSize.small
                            background: null
                            leftPadding: 0
                            topPadding: 0
                            bottomPadding: 0
                        }
                        MaterialSymbol {
                            visible: root.searchQuery.length > 0
                            text: "close"
                            iconSize: Appearance.font.pixelSize.normal
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.6
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -4
                                cursorShape: Qt.PointingHandCursor
                                onClicked: searchField.text = ""
                            }
                        }
                    }
                }

                StyledListView {
                    id: notesListView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 6
                    model: root.visibleNotes

                    delegate: SwipeDelegate {
                        id: noteCard
                        required property var modelData
                        required property int index

                        width: notesListView.width
                        implicitHeight: 55
                        padding: 0
                        background: null
                        clip: true

                        // Por id, no por posición en la lista: así no rota todo al borrar una de arriba.
                        readonly property int colorIndex: root.colorIndexFor(noteCard.modelData.id)
                        property color bg: {
                            if (noteCard.colorIndex === 0) return Appearance.colors.colPrimary
                            if (noteCard.colorIndex === 1) return Appearance.colors.colSecondary
                            return Appearance.colors.colTertiary
                        }
                        property color fg: {
                            if (noteCard.colorIndex === 0) return Appearance.colors.colOnPrimary
                            if (noteCard.colorIndex === 1) return Appearance.colors.colOnSecondary
                            return Appearance.colors.colOnTertiary
                        }

                        onClicked: root.openNote(noteCard.modelData)

                        contentItem: Rectangle {
                            radius: Appearance.rounding.normal
                            color: noteCard.bg
                            width: parent.width - Math.abs(noteCard.swipe.position) * 6

                            ColumnLayout {
                                anchors {
                                    left: parent.left; right: parent.right
                                    verticalCenter: parent.verticalCenter
                                    leftMargin: 12; rightMargin: 12
                                }
                                spacing: 1

                                StyledText {
                                    Layout.fillWidth: true
                                    color: noteCard.fg
                                    text: noteCard.modelData.content
                                    elide: Text.ElideRight
                                    wrapMode: Text.Wrap
                                    maximumLineCount: 2
                                    font.pixelSize: Appearance.font.pixelSize.small
                                }
                                StyledText {
                                    text: root.formatRelative(noteCard.modelData.updatedAt ?? noteCard.modelData.createdAt)
                                    color: noteCard.fg
                                    opacity: 0.7
                                    font.pixelSize: Appearance.font.pixelSize.smallest
                                }
                            }
                        }

                        swipe.right: Rectangle {
                            width: 64
                            anchors.right: parent.right
                            height: parent.height
                            radius: Appearance.rounding.normal
                            color: Appearance.colors.colError

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "delete"
                                iconSize: Appearance.font.pixelSize.larger
                                color: Appearance.colors.colOnError
                            }

                            SwipeDelegate.onClicked: Notes.deleteNote(noteCard.modelData.id)
                        }
                    }
                }

                // Estados vacíos: "no hay nada" es distinto de "no hay resultados".
                ColumnLayout {
                    Layout.alignment: Qt.AlignCenter
                    Layout.fillHeight: true
                    visible: root.visibleNotes.length === 0
                    spacing: 4

                    MaterialSymbol {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.searchQuery.length > 0 ? "search_off" : "note_add"
                        iconSize: 28
                        color: Appearance.colors.colOnPrimaryContainer
                        opacity: 0.4
                    }
                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.searchQuery.length > 0
                            ? Translation.tr("Sin resultados")
                            : Translation.tr("Sin notas todavía")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnPrimaryContainer
                        opacity: 0.6
                    }
                }
            }

            // Edit
            ColumnLayout {
                id: editPage
                anchors { fill: parent; margins: 12 }
                spacing: 10
                visible: root.mode === "edit"

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Rectangle {
                        radius: Appearance.rounding.full
                        color: "transparent"
                        implicitWidth: 28; implicitHeight: 28
                        MaterialSymbol {
                            anchors.centerIn: parent
                            iconSize: Appearance.font.pixelSize.normal
                            text: "arrow_back"
                            color: Appearance.colors.colOnPrimaryContainer
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleFlip()
                        }
                    }

                    // Sólo tiene sentido borrar una nota que ya existe.
                    Rectangle {
                        visible: root.pendingNoteId !== null
                        radius: Appearance.rounding.full
                        color: "transparent"
                        implicitWidth: 28; implicitHeight: 28
                        MaterialSymbol {
                            anchors.centerIn: parent
                            iconSize: Appearance.font.pixelSize.normal
                            text: "delete"
                            color: Appearance.colors.colError
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.deleteEditingNote()
                        }
                    }

                    Item { Layout.fillWidth: true }

                    StyledText {
                        visible: root.pendingNoteId !== null
                        text: {
                            const note = Notes.list.find(n => n.id === root.pendingNoteId)
                            if (!note) return ""
                            return note.updatedAt
                                ? Translation.tr("Editado %1").arg(root.formatRelative(note.updatedAt))
                                : Translation.tr("Creado %1").arg(root.formatRelative(note.createdAt))
                        }
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: Appearance.colors.colOnPrimaryContainer
                        opacity: 0.6
                    }

                    ToolbarPairedFab {
                        Layout.rightMargin: 4
                        Layout.alignment: Qt.AlignVCenter
                        baseSize: 38
                        iconText: "save"
                        onClicked: root.saveAndBack()
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Appearance.rounding.normal
                    color: Appearance.colors.colSurfaceContainerLow

                    TextArea {
                        id: editTextArea
                        anchors.fill: parent
                        anchors.margins: 8
                        text: root.editingText
                        wrapMode: TextArea.Wrap
                        placeholderText: "Type your note..."
                        color: Appearance.colors.colOnLayer0
                        background: null
                        onTextChanged: root.editingText = text
                    }
                }
            }
        }
    }

    Timer {
        id: editFocusTimer
        interval: 160 // después de la animación de flip, si no el foco no prende
        onTriggered: editTextArea.forceActiveFocus()
    }
}
