pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

/**
 * Un mosaico de la grilla del lanzador: ícono grande + nombre en dos líneas.
 * El resaltado lo decide el padre (`selected`), que sigue al `currentIndex` de la
 * GridView, así el hover del mouse y las flechas del teclado no se pelean.
 */
Item {
    id: root
    required property DesktopEntry entry
    property bool selected: false
    property real iconSize: 48
    property bool showName: true
    signal activated
    signal hoveredIn

    Rectangle {
        id: background
        anchors.fill: parent
        anchors.margins: 4
        radius: Appearance.rounding.normal
        color: mouseArea.pressed ? Appearance.colors.colPrimaryContainerActive : (root.selected ? Appearance.colors.colPrimaryContainer : ColorUtils.transparentize(Appearance.colors.colPrimaryContainer, 1))

        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 6

            IconImage {
                Layout.alignment: root.showName ? Qt.AlignHCenter : Qt.AlignCenter
                Layout.topMargin: root.showName ? 4 : 0
                implicitSize: root.iconSize
                source: Quickshell.iconPath(AppSearch.guessIcon(root.entry?.id ?? ""), "image-missing")
            }

            StyledText {
                visible: root.showName
                Layout.fillWidth: true
                Layout.fillHeight: true
                text: root.entry?.name ?? ""
                font.pixelSize: Appearance.font.pixelSize.smaller
                // Mismo par de colores que SearchItem: colOnLayer1 es demasiado apagado
                // sobre un fondo translúcido y los nombres no se leían.
                color: root.selected ? Appearance.colors.colOnPrimaryContainer : Appearance.m3colors.m3onSurface
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignTop
                wrapMode: Text.Wrap
                elide: Text.ElideRight
                maximumLineCount: 2
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root.hoveredIn()
        onClicked: root.activated()

        StyledToolTip {
            extraVisibleCondition: mouseArea.containsMouse
            text: root.entry?.name ?? ""
        }
    }
}
