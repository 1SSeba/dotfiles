pragma ComponentBehavior: Bound

import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

/**
 * Una fila de la biblioteca: tema, playlist, álbum o artista.
 *
 * Un tema se toca; una colección se abre para ver qué tiene adentro, con un botón
 * aparte para tocarla entera. Es la diferencia que hace Spotify y sin ella no se
 * puede llegar a un tema suelto de una playlist.
 */
RippleButton {
    id: root

    required property var entry
    /** URI de la playlist/álbum donde vive el tema, para que siga sonando la lista */
    property string contextUri: ""
    /**
     * Numerito de posición, para las listas de temas.
     * No se llama `index` porque el ListView ya inyecta uno con ese nombre en el
     * delegate y no se puede declarar dos veces.
     */
    property int position: -1

    readonly property bool isTrack: root.entry?.type === "track"
    readonly property bool isCurrent: root.isTrack && root.entry?.uri === SpotifyService.currentTrackUri

    implicitHeight: 46
    buttonRadius: Appearance.rounding.small
    colBackground: "transparent"
    colBackgroundHover: Appearance.colors.colLayer1Hover

    onClicked: {
        if (root.isTrack) SpotifyService.playTrack(root.entry.uri, root.contextUri);
        else SpotifyService.openCollection(root.entry);
    }

    contentItem: RowLayout {
        spacing: 8

        StyledText {
            visible: root.position >= 0
            Layout.preferredWidth: 16
            horizontalAlignment: Text.AlignRight
            text: String(root.position + 1)
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
        }

        Rectangle {
            implicitWidth: 36
            implicitHeight: 36
            radius: root.entry?.type === "artist" ? 18 : (Appearance.rounding.verysmall ?? 4)
            color: Appearance.colors.colLayer1
            clip: true

            StyledImage {
                anchors.fill: parent
                source: root.entry?.image ?? ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: source.toString().length > 0
            }

            MaterialSymbol {
                anchors.centerIn: parent
                visible: (root.entry?.image ?? "").length === 0
                text: {
                    switch (root.entry?.type) {
                    case "playlist": return "queue_music";
                    case "album": return "album";
                    case "artist": return "person";
                    default: return "music_note";
                    }
                }
                iconSize: Appearance.font.pixelSize.large
                color: Appearance.colors.colOnLayer2Disabled
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                text: root.entry?.name ?? ""
                font.pixelSize: Appearance.font.pixelSize.small
                // Lo que está sonando se marca con el color de acento, como en Spotify
                color: root.isCurrent ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer2
                elide: Text.ElideRight
            }
            StyledText {
                Layout.fillWidth: true
                visible: (root.entry?.subtitle ?? "").length > 0
                text: root.entry?.subtitle ?? ""
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                elide: Text.ElideRight
            }
        }

        // Barritas de "sonando" en vez de un icono estático
        MaterialSymbol {
            visible: root.isCurrent && SpotifyService.isPlaying
            text: "graphic_eq"
            iconSize: Appearance.font.pixelSize.normal
            color: Appearance.colors.colPrimary
        }

        // En una colección el clic entra; para tocarla entera está este botón
        RippleButton {
            visible: !root.isTrack
            implicitWidth: 30
            implicitHeight: 30
            buttonRadius: Appearance.rounding.full
            colBackground: "transparent"
            colBackgroundHover: Appearance.colors.colLayer2Hover
            onClicked: SpotifyService.playContext(root.entry.uri)

            contentItem: MaterialSymbol {
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: "play_arrow"
                iconSize: Appearance.font.pixelSize.large
                color: Appearance.colors.colPrimary
            }

            StyledToolTip {
                text: Translation.tr("Reproducir")
            }
        }

        MaterialSymbol {
            visible: !root.isTrack
            text: "chevron_right"
            iconSize: Appearance.font.pixelSize.normal
            color: Appearance.colors.colSubtext
        }
    }
}
