import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.ii.sidebarLeft.inspo
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/**
 * Pestaña de inspiración.
 *
 * Dos mundos bajo la misma grilla: descubrir imágenes nuevas (Wallhaven,
 * Openverse) o mirar lo que ya guardaste en Pinterest. El selector de arriba
 * cambia la fuente; la grilla no sabe de dónde vino nada.
 */
Item {
    id: root
    property real padding: 10
    property int columnCount: Math.max(1, Config.options?.sidebar?.inspo?.columns ?? 2)
    property real gridSpacing: 8

    // Reparte los items en columnas mandando cada uno a la más corta,
    // que es lo que hace que el masonry no quede escalonado.
    property var columns: {
        const cols = [];
        const heights = [];
        for (let i = 0; i < root.columnCount; i++) { cols.push([]); heights.push(0); }
        const items = InspoService.items ?? [];
        for (let i = 0; i < items.length; i++) {
            let shortest = 0;
            for (let c = 1; c < heights.length; c++)
                if (heights[c] < heights[shortest]) shortest = c;
            cols[shortest].push(items[i]);
            const ratio = (items[i].aspect_ratio > 0.05 && items[i].aspect_ratio < 20)
                ? items[i].aspect_ratio : 0.75;
            heights[shortest] += 1 / ratio;
        }
        return cols;
    }

    Component.onCompleted: {
        if ((InspoService.items?.length ?? 0) === 0 && InspoService.currentSource !== "pinterest")
            InspoService.search("");
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.padding
        spacing: root.padding

        // ---------------- Selector de fuente ----------------
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: InspoService.sourceList
                delegate: RippleButton {
                    id: sourceButton
                    required property string modelData
                    readonly property var sourceInfo: InspoService.sources[modelData]
                    readonly property bool active: InspoService.currentSource === modelData
                    readonly property color fgColor: active
                        ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer1
                    Layout.fillWidth: true
                    implicitHeight: 34
                    buttonRadius: Appearance.rounding.small
                    toggled: sourceButton.active
                    onClicked: {
                        InspoService.setSource(sourceButton.modelData);
                        if (sourceButton.modelData !== "pinterest" || InspoService.pinterestLinked)
                            InspoService.search(searchField.text);
                    }

                    StyledToolTip { text: sourceButton.sourceInfo.description }

                    contentItem: RowLayout {
                        spacing: 4
                        MaterialSymbol {
                            Layout.alignment: Qt.AlignVCenter
                            iconSize: Appearance.font.pixelSize.normal
                            color: sourceButton.fgColor
                            text: sourceButton.sourceInfo.icon
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignVCenter
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: sourceButton.fgColor
                            text: sourceButton.sourceInfo.name
                        }
                    }
                }
            }
        }

        // ---------------- Buscador ----------------
        RowLayout {
            Layout.fillWidth: true
            spacing: 4
            visible: InspoService.currentSource !== "pinterest" || InspoService.pinterestLinked

            ToolbarTextField {
                id: searchField
                Layout.fillWidth: true
                Layout.fillHeight: false
                implicitHeight: 38
                colBackground: Appearance.colors.colLayer2
                placeholderText: InspoService.currentSource === "pinterest"
                    ? Translation.tr("Buscar en tus pines guardados…")
                    : Translation.tr("Buscar inspiración…")
                onAccepted: InspoService.search(text)
            }

            RippleButton {
                implicitWidth: 38
                implicitHeight: 38
                buttonRadius: Appearance.rounding.small
                onClicked: InspoService.search(searchField.text)
                contentItem: MaterialSymbol {
                    horizontalAlignment: Text.AlignHCenter
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnLayer1
                    text: "search"
                }
            }
        }

        // ---------------- Boards de Pinterest ----------------
        Flickable {
            Layout.fillWidth: true
            implicitHeight: 30
            visible: InspoService.currentSource === "pinterest"
                && InspoService.pinterestLinked
                && InspoService.boards.length > 0
                && searchField.text.length === 0
            contentWidth: boardRow.implicitWidth
            flickableDirection: Flickable.HorizontalFlick
            clip: true

            RowLayout {
                id: boardRow
                height: parent.height
                spacing: 5

                RippleButton {
                    implicitHeight: 28
                    buttonRadius: Appearance.rounding.full
                    toggled: InspoService.currentBoardId.length === 0
                    onClicked: InspoService.openBoard("")
                    contentItem: StyledText {
                        horizontalAlignment: Text.AlignHCenter
                        leftPadding: 10; rightPadding: 10
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: InspoService.currentBoardId.length === 0
                            ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer1
                        text: Translation.tr("Todos")
                    }
                }

                Repeater {
                    model: InspoService.boards
                    delegate: RippleButton {
                        id: boardButton
                        required property var modelData
                        readonly property bool active: InspoService.currentBoardId === modelData.id
                        implicitHeight: 28
                        buttonRadius: Appearance.rounding.full
                        toggled: boardButton.active
                        onClicked: InspoService.openBoard(boardButton.modelData.id)
                        contentItem: StyledText {
                            horizontalAlignment: Text.AlignHCenter
                            leftPadding: 10; rightPadding: 10
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: boardButton.active
                                ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer1
                            text: `${boardButton.modelData.name} · ${boardButton.modelData.pin_count}`
                        }
                    }
                }
            }
        }

        // ---------------- Contenido ----------------
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Panel de conexión: sólo cuando Pinterest está elegido y sin sesión
            Loader {
                anchors.fill: parent
                active: InspoService.currentSource === "pinterest" && !InspoService.pinterestLinked
                sourceComponent: PinterestSetup {}
            }

            StyledFlickable {
                id: flickable
                anchors.fill: parent
                visible: InspoService.currentSource !== "pinterest" || InspoService.pinterestLinked
                contentHeight: gridRow.implicitHeight
                clip: true

                // Scroll infinito: cuando faltan menos de dos pantallas, pedimos más
                onContentYChanged: {
                    if (contentHeight - (contentY + height) < height * 2)
                        InspoService.loadMore();
                }

                RowLayout {
                    id: gridRow
                    width: flickable.width
                    spacing: root.gridSpacing

                    Repeater {
                        model: root.columns
                        delegate: ColumnLayout {
                            id: gridColumn
                            required property var modelData
                            Layout.alignment: Qt.AlignTop
                            Layout.fillWidth: true
                            spacing: root.gridSpacing

                            Repeater {
                                model: gridColumn.modelData
                                delegate: InspoImage {
                                    id: gridTile
                                    required property var modelData
                                    Layout.fillWidth: true
                                    itemData: gridTile.modelData
                                }
                            }
                        }
                    }
                }
            }

            // Estado vacío / error / cargando
            ColumnLayout {
                anchors.centerIn: parent
                width: parent.width * 0.8
                spacing: 8
                visible: (InspoService.items?.length ?? 0) === 0
                    && (InspoService.currentSource !== "pinterest" || InspoService.pinterestLinked)

                MaterialLoadingIndicator {
                    Layout.alignment: Qt.AlignHCenter
                    visible: InspoService.loading
                }
                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    color: Appearance.colors.colSubtext
                    visible: !InspoService.loading && InspoService.message.length > 0
                    text: InspoService.message
                }
            }

            // Indicador de que está trayendo la página siguiente
            MaterialLoadingIndicator {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8
                visible: InspoService.loading && (InspoService.items?.length ?? 0) > 0
            }
        }
    }
}
