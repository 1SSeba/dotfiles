pragma ComponentBehavior: Bound

import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

/**
 * Vista avanzada del historial de chats de IA.
 *
 * Filtros arriba (todos / fijados / archivados / por proyecto), lista abajo,
 * agrupada por fecha. Cada fila se puede abrir, renombrar, fijar, archivar,
 * mandar a un proyecto o borrar.
 *
 * Abrir un chat lo CONTINÚA: la pestaña adopta el archivo y sigue guardando ahí.
 * Antes se cargaba una copia en una pestaña nueva, así que abrir la misma
 * conversación dos veces dejaba dos chats más en el historial y el original
 * quedaba congelado. Y si el chat ya está abierto en una pestaña, no se abre
 * nada: se salta a esa pestaña.
 */
Rectangle {
    id: root

    /** Filtro activo: "active" | "pinned" | "archived" | el id de un proyecto. */
    property string filterMode: "active"
    property string search: ""
    /** Chat cuyas acciones extra están desplegadas. */
    property string expandedChat: ""
    /** Chat que se está renombrando. */
    property string renamingChat: ""
    property bool creatingProject: false

    signal requestClose()

    color: Appearance.colors.colLayer1
    radius: Appearance.rounding.small

    onVisibleChanged: {
        if (root.visible) {
            AiHistory.refresh();
        } else {
            root.expandedChat = "";
            root.renamingChat = "";
            root.creatingProject = false;
        }
    }

    /** Autoguardados de las pestañas que están abiertas ahora mismo. */
    readonly property var openChatNames: Ai.sessions.map(session => session.autoSaveName)

    /** Índice de la pestaña que tiene abierto este chat, o -1. */
    function openIndexFor(chatName) {
        return root.openChatNames.indexOf(chatName);
    }

    readonly property var filteredChats: {
        const term = root.search.trim().toLowerCase();
        let list = AiHistory.chats.filter(chat => {
            // Los chats abiertos SÍ se listan, marcados como abiertos.
            //
            // Antes se escondían "porque ya se ven arriba en las pestañas", y eso
            // dejaba la conversación en curso sin forma de renombrarla, fijarla ni
            // meterla en un proyecto desde acá, que es el único lugar donde se hace.
            if (root.filterMode === "archived") {
                if (!chat.archived) return false;
            } else if (chat.archived) {
                return false;
            }
            if (root.filterMode === "pinned" && !chat.pinned) return false;
            if (root.filterMode !== "active" && root.filterMode !== "pinned" && root.filterMode !== "archived") {
                if (chat.projectId !== root.filterMode) return false;
            }
            if (term.length > 0) {
                // Se busca también DENTRO de los mensajes: acordarse del título
                // exacto de un chat de hace dos semanas no le pasa a nadie, pero
                // de una frase que apareció adentro sí.
                const hay = `${chat.title} ${chat.snippet} ${chat.haystack ?? ""}`.toLowerCase();
                if (hay.indexOf(term) === -1) return false;
            }
            return true;
        });
        // Fijados arriba, después por fecha.
        list.sort((a, b) => {
            if (a.pinned !== b.pinned) return a.pinned ? -1 : 1;
            return b.mtime - a.mtime;
        });
        return AiHistory.withGroupLabels(list);
    }

    /**
     * Abre un chat guardado, o salta a la pestaña que ya lo tiene.
     *
     * La pestaña ADOPTA el archivo: lo que escribas después se guarda encima del
     * mismo chat. Abrirlo también lo desarchiva, porque si lo estás retomando ya
     * no está guardado en un cajón.
     */
    function openChat(chat) {
        const alreadyOpen = root.openIndexFor(chat.name);
        if (alreadyOpen >= 0) {
            Ai.setActiveIndex(alreadyOpen);
            root.requestClose();
            return;
        }
        const session = Ai.newSession();
        if (!session) return;
        session.adoptChat(chat.name);
        session.title = chat.title.length > 40 ? chat.title.substring(0, 40) + "…" : chat.title;
        if (chat.archived) AiHistory.setArchived(chat.name, false);
        // El nombre adoptado se fija después de crear la pestaña, así que hay que
        // volver a persistir o un reload de la shell abriría el chat equivocado.
        Ai.persistSessions();
        root.requestClose();
    }

    component FilterChip: Rectangle {
        id: chip
        required property string mode
        property string label: ""
        property string icon: ""
        readonly property bool isActive: root.filterMode === chip.mode

        implicitWidth: chipRow.implicitWidth + 20
        implicitHeight: 30
        radius: Appearance.rounding.small
        color: chip.isActive ? Appearance.colors.colSecondaryContainer
            : (chipArea.containsMouse ? Appearance.colors.colLayer2Hover : Appearance.colors.colLayer2)

        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }

        MouseArea {
            id: chipArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.filterMode = chip.mode
        }

        RowLayout {
            id: chipRow
            anchors.centerIn: parent
            spacing: 5

            MaterialSymbol {
                visible: chip.icon.length > 0
                text: chip.icon
                iconSize: Appearance.font.pixelSize.normal
                color: chip.isActive ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer2
            }
            StyledText {
                text: chip.label
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: chip.isActive ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer2
            }
        }
    }

    component RowAction: RippleButton {
        id: action
        // No se puede llamar `icon`: Button ya trae esa propiedad y es FINAL.
        property string symbol: ""
        property bool active: false
        implicitWidth: 28
        implicitHeight: 28
        buttonRadius: Appearance.rounding.small
        colBackground: action.active ? Appearance.colors.colSecondaryContainer : "transparent"

        contentItem: MaterialSymbol {
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: action.symbol
            iconSize: Appearance.font.pixelSize.large
            color: action.active ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer2
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8
        // El panel ahora vive siempre adentro del RowLayout del sidebar (para
        // que cerrar el historial anime igual de suave que abrirlo, ver
        // SidebarLeft.qml), así que en reposo "cerrado" este ancho es 0 de
        // verdad, no un valor transitorio. Sin este visible, los 8px de
        // margins de cada lado dejan el contenido con ancho negativo todo el
        // tiempo que está cerrado y tira warnings todo el rato.
        visible: root.width > 20

        // ------------------------------ Encabezado
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            MaterialSymbol {
                text: "history"
                iconSize: Appearance.font.pixelSize.larger
                color: Appearance.colors.colOnLayer1
            }
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Historial")
                font.pixelSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colOnLayer1
            }
            RowAction {
                symbol: "create_new_folder"
                active: root.creatingProject
                onClicked: root.creatingProject = !root.creatingProject
                StyledToolTip { text: Translation.tr("Proyecto nuevo") }
            }
            RowAction {
                symbol: "refresh"
                onClicked: AiHistory.refresh()
                StyledToolTip { text: Translation.tr("Volver a leer los chats") }
            }
            RowAction {
                symbol: "close"
                onClicked: root.requestClose()
            }
        }

        ToolbarTextField {
            Layout.fillWidth: true
            // ToolbarTextField trae Layout.fillHeight prendido de fábrica: en una
            // columna se estira y empuja todo lo de abajo fuera de la vista.
            Layout.fillHeight: false
            placeholderText: Translation.tr("Buscar en el historial…")
            onTextChanged: root.search = text
        }

        // ------------------------------ Proyecto nuevo
        RowLayout {
            Layout.fillWidth: true
            visible: root.creatingProject
            spacing: 6

            ToolbarTextField {
                id: newProjectField
                Layout.fillWidth: true
                Layout.fillHeight: false
                placeholderText: Translation.tr("Nombre del proyecto")
                onAccepted: {
                    const id = AiHistory.createProject(text);
                    if (id.length > 0) {
                        root.filterMode = id;
                        text = "";
                        root.creatingProject = false;
                    }
                }
            }
            RowAction {
                symbol: "check"
                onClicked: newProjectField.accepted()
            }
        }

        // ------------------------------ Filtros
        Flow {
            Layout.fillWidth: true
            spacing: 4

            FilterChip {
                mode: "active"
                icon: "chat_bubble"
                label: Translation.tr("Todos")
            }
            FilterChip {
                mode: "pinned"
                icon: "push_pin"
                label: Translation.tr("Fijados")
            }
            FilterChip {
                mode: "archived"
                icon: "archive"
                label: Translation.tr("Archivados")
            }

            Repeater {
                model: AiHistory.projects
                delegate: FilterChip {
                    required property var modelData
                    mode: modelData.id
                    icon: modelData.icon ?? "folder"
                    label: modelData.name
                }
            }
        }

        // ------------------------------ Acciones del proyecto seleccionado
        RowLayout {
            Layout.fillWidth: true
            visible: AiHistory.projectById(root.filterMode) !== null
            spacing: 6

            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("%1 · %2 chats")
                    .arg(AiHistory.projectName(root.filterMode))
                    .arg(AiHistory.chatCountForProject(root.filterMode))
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                elide: Text.ElideRight
            }
            RowAction {
                symbol: "delete"
                onClicked: {
                    AiHistory.deleteProject(root.filterMode);
                    root.filterMode = "active";
                }
                StyledToolTip { text: Translation.tr("Borrar el proyecto (los chats quedan)") }
            }
        }

        // ------------------------------ Lista
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            StyledListView {
                id: chatList
                anchors.fill: parent
                spacing: 4
                clip: true
                model: root.filteredChats

                delegate: Item {
                    id: chatEntry
                    required property var modelData
                    readonly property bool expanded: root.expandedChat === chatEntry.modelData.name
                    readonly property bool renaming: root.renamingChat === chatEntry.modelData.name
                    readonly property int openIndex: root.openIndexFor(chatEntry.modelData.name)
                    readonly property bool isOpen: chatEntry.openIndex >= 0

                    width: chatList.width
                    implicitHeight: entryColumn.implicitHeight

                    Behavior on implicitHeight {
                        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                    }

                    ColumnLayout {
                        id: entryColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        spacing: 2

                        // Encabezado del grupo: sólo lo dibuja el primero de cada tanda.
                        StyledText {
                            Layout.fillWidth: true
                            Layout.topMargin: 6
                            Layout.bottomMargin: 2
                            visible: chatEntry.modelData.groupLabel.length > 0
                            text: chatEntry.modelData.groupLabel
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            font.weight: Font.DemiBold
                            color: Appearance.colors.colSubtext
                        }

                        Rectangle {
                            id: chatRow
                            Layout.fillWidth: true
                            implicitHeight: rowColumn.implicitHeight + 16
                            radius: Appearance.rounding.small
                            color: rowArea.containsMouse ? Appearance.colors.colLayer2Hover : Appearance.colors.colLayer2

                            MouseArea {
                                id: rowArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                enabled: !chatEntry.renaming
                                onClicked: root.openChat(chatEntry.modelData)
                            }

                            ColumnLayout {
                                id: rowColumn
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    top: parent.top
                                    margins: 8
                                }
                                spacing: 4

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    MaterialSymbol {
                                        text: chatEntry.modelData.pinned ? "push_pin"
                                            : chatEntry.isOpen ? "tab"
                                            : (chatEntry.modelData.projectId.length > 0 ? "folder" : "chat_bubble")
                                        iconSize: Appearance.font.pixelSize.large
                                        color: chatEntry.modelData.pinned ? Appearance.colors.colPrimary
                                            : chatEntry.isOpen ? Appearance.colors.colPrimary
                                            : Appearance.colors.colOnLayer2
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0

                                        // Renombrar en el lugar. El título es lo único
                                        // que hace que un chat viejo se pueda encontrar.
                                        ToolbarTextField {
                                            id: renameField
                                            Layout.fillWidth: true
                                            Layout.fillHeight: false
                                            visible: chatEntry.renaming
                                            placeholderText: Translation.tr("Nombre del chat")
                                            onVisibleChanged: if (visible) {
                                                text = chatEntry.modelData.title;
                                                selectAll();
                                                forceActiveFocus();
                                            }
                                            onAccepted: {
                                                AiHistory.setTitle(chatEntry.modelData.name, text.trim());
                                                root.renamingChat = "";
                                            }
                                            Keys.onEscapePressed: root.renamingChat = ""
                                        }

                                        StyledText {
                                            Layout.fillWidth: true
                                            visible: !chatEntry.renaming
                                            text: chatEntry.modelData.title
                                            font.pixelSize: Appearance.font.pixelSize.small
                                            color: Appearance.colors.colOnLayer2
                                            elide: Text.ElideRight
                                            maximumLineCount: 1
                                        }
                                        StyledText {
                                            Layout.fillWidth: true
                                            visible: !chatEntry.renaming
                                            text: {
                                                const parts = [
                                                    Qt.formatDateTime(new Date(chatEntry.modelData.mtime), "dd/MM HH:mm"),
                                                    Translation.tr("%1 msj").arg(chatEntry.modelData.count)
                                                ];
                                                if ((chatEntry.modelData.agents ?? 0) > 0)
                                                    parts.push(Translation.tr("%1 agentes").arg(chatEntry.modelData.agents));
                                                const projectName = AiHistory.projectName(chatEntry.modelData.projectId);
                                                if (projectName.length > 0) parts.push(projectName);
                                                if (chatEntry.isOpen) parts.push(Translation.tr("abierto"));
                                                return parts.join(" · ");
                                            }
                                            font.pixelSize: Appearance.font.pixelSize.smallest
                                            color: chatEntry.isOpen ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                                            elide: Text.ElideRight
                                            maximumLineCount: 1
                                        }
                                    }

                                    RowAction {
                                        symbol: "edit"
                                        active: chatEntry.renaming
                                        onClicked: root.renamingChat = chatEntry.renaming ? "" : chatEntry.modelData.name
                                        StyledToolTip { text: Translation.tr("Renombrar") }
                                    }
                                    RowAction {
                                        symbol: "push_pin"
                                        active: chatEntry.modelData.pinned
                                        onClicked: AiHistory.togglePinned(chatEntry.modelData.name)
                                        StyledToolTip { text: Translation.tr("Fijar") }
                                    }
                                    RowAction {
                                        symbol: chatEntry.modelData.archived ? "unarchive" : "archive"
                                        onClicked: AiHistory.toggleArchived(chatEntry.modelData.name)
                                        StyledToolTip {
                                            text: chatEntry.modelData.archived ? Translation.tr("Desarchivar") : Translation.tr("Archivar")
                                        }
                                    }
                                    RowAction {
                                        symbol: chatEntry.expanded ? "expand_less" : "more_horiz"
                                        active: chatEntry.expanded
                                        onClicked: root.expandedChat = chatEntry.expanded ? "" : chatEntry.modelData.name
                                    }
                                }

                                // Acciones extra: a qué proyecto va, y borrar.
                                Flow {
                                    Layout.fillWidth: true
                                    visible: chatEntry.expanded
                                    spacing: 4

                                    Repeater {
                                        model: chatEntry.expanded ? [{ "id": "", "name": Translation.tr("Sin proyecto") }, ...AiHistory.projects] : []

                                        delegate: Rectangle {
                                            id: projectChip
                                            required property var modelData
                                            readonly property bool isCurrent: chatEntry.modelData.projectId === projectChip.modelData.id

                                            implicitWidth: projectChipText.implicitWidth + 18
                                            implicitHeight: 26
                                            radius: Appearance.rounding.small
                                            color: projectChip.isCurrent ? Appearance.colors.colPrimary : Appearance.colors.colLayer1

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: AiHistory.setProject(chatEntry.modelData.name, projectChip.modelData.id)
                                            }

                                            StyledText {
                                                id: projectChipText
                                                anchors.centerIn: parent
                                                text: projectChip.modelData.name
                                                font.pixelSize: Appearance.font.pixelSize.smallest
                                                color: projectChip.isCurrent ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
                                            }
                                        }
                                    }

                                    Rectangle {
                                        implicitWidth: deleteChipRow.implicitWidth + 18
                                        implicitHeight: 26
                                        radius: Appearance.rounding.small
                                        // Un chat abierto no se puede borrar de abajo de los pies
                                        // de su propia pestaña: quedaría escribiendo en un archivo
                                        // que ya no existe y al guardar lo resucitaría a medias.
                                        opacity: chatEntry.isOpen ? 0.4 : 1
                                        color: Appearance.m3colors.m3errorContainer

                                        MouseArea {
                                            anchors.fill: parent
                                            enabled: !chatEntry.isOpen
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                AiHistory.deleteChat(chatEntry.modelData.name);
                                                root.expandedChat = "";
                                            }
                                        }

                                        RowLayout {
                                            id: deleteChipRow
                                            anchors.centerIn: parent
                                            spacing: 4

                                            MaterialSymbol {
                                                text: "delete"
                                                iconSize: Appearance.font.pixelSize.normal
                                                color: Appearance.m3colors.m3onErrorContainer
                                            }
                                            StyledText {
                                                text: chatEntry.isOpen ? Translation.tr("Abierto") : Translation.tr("Borrar")
                                                font.pixelSize: Appearance.font.pixelSize.smallest
                                                color: Appearance.m3colors.m3onErrorContainer
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            PagePlaceholder {
                anchors.fill: parent
                shown: root.filteredChats.length === 0
                icon: root.filterMode === "archived" ? "archive" : "history"
                title: root.search.length > 0 ? Translation.tr("Sin resultados") : Translation.tr("Nada por acá")
                description: root.search.length > 0
                    ? Translation.tr("Ningún chat coincide con la búsqueda")
                    : Translation.tr("Los chats que cierres van a aparecer acá")
            }
        }
    }
}
