pragma ComponentBehavior: Bound

import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

/**
 * La letra del tema que suena.
 *
 * Si LRCLIB la tiene sincronizada, resalta el verso actual y sigue el tiempo sola.
 * Si sólo hay letra plana, la muestra como texto para leer y listo.
 */
Rectangle {
    id: root

    implicitHeight: 120
    radius: Appearance.rounding.small
    color: Appearance.colors.colLayer2
    clip: true

    // Encabezado con el estado de la búsqueda
    RowLayout {
        id: header
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: 8
        }
        spacing: 6

        MaterialSymbol {
            text: "lyrics"
            iconSize: Appearance.font.pixelSize.normal
            color: Appearance.colors.colSubtext
        }
        StyledText {
            Layout.fillWidth: true
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
            elide: Text.ElideRight
            text: {
                switch (LyricsService.state) {
                case "loading": return Translation.tr("Buscando la letra…");
                case "synced": return Translation.tr("Letra sincronizada");
                case "plain": return Translation.tr("Letra (sin sincronizar)");
                case "notfound": return Translation.tr("LRCLIB no tiene la letra de este tema");
                case "error": return Translation.tr("No se pudo buscar la letra");
                default: return Translation.tr("Letra");
                }
            }
        }
    }

    // Sincronizada: una línea por verso, la actual resaltada
    StyledListView {
        id: lyricsList
        anchors {
            top: header.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            topMargin: 4
            margins: 8
        }
        visible: LyricsService.hasSynced
        spacing: 2
        clip: true

        model: LyricsService.lines

        delegate: StyledText {
            required property var modelData
            required property int index
            readonly property bool current: index === LyricsService.currentIndex

            width: lyricsList.width
            text: modelData.text.length > 0 ? modelData.text : "·"
            wrapMode: Text.Wrap
            font.pixelSize: Appearance.font.pixelSize.small
            color: current ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
            opacity: current ? 1 : 0.65

            Behavior on color {
                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
            }
        }

        // Seguir el verso actual sin pelearle al usuario mientras scrollea a mano
        Connections {
            target: LyricsService
            function onCurrentIndexChanged() {
                if (LyricsService.currentIndex < 0 || lyricsList.moving) return;
                lyricsList.positionViewAtIndex(LyricsService.currentIndex, ListView.Center);
            }
        }
    }

    // Sin sincronizar: texto corrido
    StyledFlickable {
        anchors {
            top: header.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            topMargin: 4
            margins: 8
        }
        visible: LyricsService.state === "plain"
        contentHeight: plainText.implicitHeight
        clip: true

        StyledText {
            id: plainText
            width: parent.width
            text: LyricsService.plain
            wrapMode: Text.Wrap
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colSubtext
        }
    }
}
