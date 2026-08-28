pragma ComponentBehavior: Bound

import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

/**
 * Tarjeta de un carrusel de Inicio: tapa grande, nombre y un play que aparece al
 * pasar por encima.
 */
Item {
    id: root

    required property var entry
    property int size: 96

    readonly property bool isTrack: root.entry?.type === "track"

    implicitWidth: root.size
    implicitHeight: root.size + 34

    HoverHandler {
        id: hover
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 4

        Rectangle {
            Layout.preferredWidth: root.size
            Layout.preferredHeight: root.size
            radius: root.entry?.type === "artist" ? root.size / 2 : Appearance.rounding.small
            color: Appearance.colors.colLayer1
            clip: true

            StyledImage {
                anchors.fill: parent
                source: root.entry?.image ?? ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: source.toString().length > 0
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.isTrack) SpotifyService.playTrack(root.entry.uri);
                    else SpotifyService.openCollection(root.entry);
                }
            }

            // Play flotante, como el de Spotify
            RippleButton {
                anchors {
                    right: parent.right
                    bottom: parent.bottom
                    margins: 6
                }
                implicitWidth: 30
                implicitHeight: 30
                buttonRadius: Appearance.rounding.full
                opacity: hover.hovered ? 1 : 0
                visible: opacity > 0
                colBackground: Appearance.colors.colPrimary
                colBackgroundHover: Appearance.colors.colPrimaryHover
                onClicked: {
                    if (root.isTrack) SpotifyService.playTrack(root.entry.uri);
                    else SpotifyService.playContext(root.entry.uri);
                }

                contentItem: MaterialSymbol {
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: "play_arrow"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnPrimary
                }

                Behavior on opacity {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: root.entry?.name ?? ""
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colOnLayer2
            elide: Text.ElideRight
            horizontalAlignment: root.entry?.type === "artist" ? Text.AlignHCenter : Text.AlignLeft
        }
        StyledText {
            Layout.fillWidth: true
            visible: (root.entry?.subtitle ?? "").length > 0
            text: root.entry?.subtitle ?? ""
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
            elide: Text.ElideRight
            horizontalAlignment: root.entry?.type === "artist" ? Text.AlignHCenter : Text.AlignLeft
        }
    }
}
