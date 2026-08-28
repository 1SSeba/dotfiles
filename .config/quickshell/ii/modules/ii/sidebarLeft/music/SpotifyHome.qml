pragma ComponentBehavior: Bound

import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

/**
 * La portada, como la de Spotify: lo último que escuchaste, tus temas y artistas
 * del momento, tus me gusta, tus álbumes y las novedades.
 */
Item {
    id: root

    readonly property bool empty: SpotifyService.playlists.length === 0
        && SpotifyService.recent.length === 0
        && SpotifyService.topTracks.length === 0
        && SpotifyService.topArtists.length === 0
        && SpotifyService.likedTracks.length === 0
        && SpotifyService.savedAlbums.length === 0
        && SpotifyService.followedArtists.length === 0
        && SpotifyService.newReleases.length === 0

    StyledFlickable {
        anchors.fill: parent
        contentHeight: shelves.implicitHeight
        clip: true

        ColumnLayout {
            id: shelves
            width: parent.width
            spacing: 12

            SpotifyShelf {
                Layout.fillWidth: true
                title: Translation.tr("Tus playlists")
                entries: SpotifyService.playlists
            }

            SpotifyShelf {
                Layout.fillWidth: true
                title: Translation.tr("Seguí escuchando")
                entries: SpotifyService.recent
            }

            SpotifyShelf {
                Layout.fillWidth: true
                title: Translation.tr("Tus temas del momento")
                entries: SpotifyService.topTracks
            }

            SpotifyShelf {
                Layout.fillWidth: true
                title: Translation.tr("Tus artistas")
                entries: SpotifyService.topArtists
                cardSize: 84
            }

            SpotifyShelf {
                Layout.fillWidth: true
                title: Translation.tr("Tus me gusta")
                entries: SpotifyService.likedTracks
            }

            SpotifyShelf {
                Layout.fillWidth: true
                title: Translation.tr("Tus álbumes")
                entries: SpotifyService.savedAlbums
            }

            SpotifyShelf {
                Layout.fillWidth: true
                title: Translation.tr("Artistas que seguís")
                entries: SpotifyService.followedArtists
                cardSize: 84
            }

            SpotifyShelf {
                Layout.fillWidth: true
                title: Translation.tr("Novedades")
                entries: SpotifyService.newReleases
            }
        }
    }

    StyledText {
        anchors.centerIn: parent
        width: parent.width - 16
        visible: root.empty && !SpotifyService.loading
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        font.pixelSize: Appearance.font.pixelSize.smaller
        color: Appearance.colors.colSubtext
        text: SpotifyService.state === "error"
            ? Translation.tr("No se pudo traer nada.\nProbá sincronizar o reconectá la cuenta.")
            : Translation.tr("Todavía no hay nada acá.\nTocá sincronizar.")
    }
}
