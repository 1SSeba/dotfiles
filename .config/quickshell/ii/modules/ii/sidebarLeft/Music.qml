pragma ComponentBehavior: Bound

import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.ii.sidebarLeft.music
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

/**
 * Pestaña de música: reproductor de lo que esté sonando (por MPRIS) más la letra
 * sincronizada de LRCLIB.
 *
 * No reproduce nada por sí misma: controla el reproductor que ya tengas abierto
 * (Spotify, un navegador, mpd…), igual que el widget de la barra, pero con lugar
 * para carátula grande y letra.
 */
Item {
    id: root
    property real padding: 4

    readonly property var player: MprisController.activePlayer
    readonly property var players: MprisController.players

    /** Volumen de antes de silenciar, para poder devolverlo igual. */
    property real volumeBeforeMute: 1

    /** off → toda la lista → sólo este tema → off, como en cualquier reproductor. */
    function cycleLoop() {
        if (!root.player) return;
        const order = [MprisLoopState.None, MprisLoopState.Playlist, MprisLoopState.Track];
        const next = order[(order.indexOf(root.player.loopState) + 1) % order.length];
        root.player.loopState = next;
    }

    function toggleMute() {
        if (!root.player) return;
        if (root.player.volume > 0) {
            root.volumeBeforeMute = root.player.volume;
            root.player.volume = 0;
        } else {
            root.player.volume = root.volumeBeforeMute > 0 ? root.volumeBeforeMute : 1;
        }
    }

    ColumnLayout {
        anchors {
            fill: parent
            margins: root.padding
        }
        spacing: 8

        // Selector de reproductor, sólo si hay más de uno
        Flow {
            Layout.fillWidth: true
            spacing: 4
            visible: root.players.length > 1

            Repeater {
                model: root.players

                delegate: RippleButton {
                    id: playerChip
                    required property var modelData

                    implicitHeight: 30
                    implicitWidth: playerChipRow.implicitWidth + 12 * 2
                    buttonRadius: Appearance.rounding.small
                    colBackground: Appearance.colors.colLayer2
                    toggled: playerChip.modelData === root.player
                    onClicked: MprisController.trackedPlayer = playerChip.modelData

                    contentItem: RowLayout {
                        id: playerChipRow
                        spacing: 6

                        MaterialSymbol {
                            text: playerChip.modelData?.isPlaying ? "play_circle" : "pause_circle"
                            iconSize: Appearance.font.pixelSize.large
                            color: playerChip.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer2
                        }
                        StyledText {
                            text: playerChip.modelData?.identity ?? "?"
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: playerChip.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer2
                        }
                    }
                }
            }
        }

        // Reproductor en horizontal: la carátula al costado en vez de arriba, así
        // deja de comerse el alto y queda lugar para la letra y para Spotify.
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            visible: root.player !== null

            Rectangle {
                // 110 y no más: la columna de al lado (título, barra, transporte)
                // mide más o menos eso, así que la carátula crece sin estirar la fila.
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: 110
                Layout.preferredHeight: 110
                radius: Appearance.rounding.small
                color: Appearance.colors.colLayer2

                StyledImage {
                    id: albumArt
                    anchors.fill: parent
                    source: root.player?.trackArtUrl ?? ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: source.toString().length > 0 && status === Image.Ready

                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: albumArt.width
                            height: albumArt.height
                            radius: Appearance.rounding.small
                        }
                    }
                }

                MaterialSymbol {
                    anchors.centerIn: parent
                    visible: !albumArt.visible
                    text: "music_note"
                    iconSize: 42
                    color: Appearance.colors.colOnLayer2Disabled
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 2

                StyledText {
                    Layout.fillWidth: true
                    text: StringUtils.cleanMusicTitle(root.player?.trackTitle) || Translation.tr("Sin título")
                    font.pixelSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colOnLayer1
                    elide: Text.ElideRight
                }
                StyledText {
                    Layout.fillWidth: true
                    visible: (root.player?.trackArtist ?? "").length > 0
                    text: root.player?.trackArtist ?? ""
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    elide: Text.ElideRight
                }

                StyledSlider {
                    id: seekSlider
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    from: 0
                    to: Math.max(root.player?.length ?? 1, 1)
                    // Mientras lo arrastrás manda vos, si no manda el reproductor
                    value: seekSlider.pressed ? seekSlider.value : (root.player?.position ?? 0)
                    enabled: root.player?.canSeek ?? false
                    onMoved: if (root.player) root.player.position = seekSlider.value
                }

                RowLayout {
                    Layout.fillWidth: true

                    StyledText {
                        text: StringUtils.friendlyTimeForSeconds(root.player?.position ?? 0)
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                    }
                    Item { Layout.fillWidth: true }
                    StyledText {
                        text: StringUtils.friendlyTimeForSeconds(root.player?.length ?? 0)
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                    }
                }

                // Todo el transporte vive acá arriba: aleatorio y repetir a los
                // costados del play, como en cualquier reproductor. Los dos salen
                // de MPRIS, así que andan con el reproductor que sea y no sólo con
                // Spotify Premium. Se esconden si el reproductor no los soporta.
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 6

                    MusicControlButton {
                        small: true
                        symbol: "shuffle"
                        visible: root.player?.shuffleSupported ?? false
                        symbolActive: root.player?.shuffle ?? false
                        onClicked: if (root.player) root.player.shuffle = !root.player.shuffle
                        StyledToolTip { text: Translation.tr("Aleatorio") }
                    }

                    MusicControlButton {
                        symbol: "skip_previous"
                        enabled: root.player?.canGoPrevious ?? false
                        onClicked: root.player?.previous()
                    }

                    MusicControlButton {
                        big: true
                        symbol: root.player?.isPlaying ? "pause" : "play_arrow"
                        onClicked: root.player?.togglePlaying()
                    }

                    MusicControlButton {
                        symbol: "skip_next"
                        enabled: root.player?.canGoNext ?? false
                        onClicked: root.player?.next()
                    }

                    MusicControlButton {
                        small: true
                        symbol: root.player?.loopState === MprisLoopState.Track ? "repeat_one" : "repeat"
                        visible: root.player?.loopSupported ?? false
                        symbolActive: (root.player?.loopState ?? MprisLoopState.None) !== MprisLoopState.None
                        onClicked: root.cycleLoop()
                        StyledToolTip {
                            text: {
                                switch (root.player?.loopState) {
                                case MprisLoopState.Track: return Translation.tr("Repetir este tema");
                                case MprisLoopState.Playlist: return Translation.tr("Repetir la lista");
                                default: return Translation.tr("Sin repetir");
                                }
                            }
                        }
                    }

                    // Volumen sin barra: el ícono ya dice en qué anda y la rueda
                    // lo cambia, que es el mismo gesto que usa la barra de arriba.
                    // Una fila entera para un slider era mucho lugar para esto.
                    MusicControlButton {
                        small: true
                        visible: root.player?.volumeSupported ?? false
                        symbol: {
                            const vol = root.player?.volume ?? 0;
                            if (vol <= 0) return "volume_off";
                            return vol < 0.5 ? "volume_down" : "volume_up";
                        }
                        onClicked: root.toggleMute()

                        WheelHandler {
                            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                            onWheel: event => {
                                if (!root.player) return;
                                const step = event.angleDelta.y > 0 ? 0.05 : -0.05;
                                root.player.volume = Math.max(0, Math.min(1, root.player.volume + step));
                            }
                        }

                        StyledToolTip {
                            text: Translation.tr("Volumen %1% · rueda para cambiar, clic para silenciar")
                                .arg(Math.round((root.player?.volume ?? 0) * 100))
                        }
                    }
                }

            }
        }

        // Sin reproductor: aviso compacto en el lugar de los controles.
        // No va anclado a toda la pestaña porque entonces tapa el panel de abajo,
        // y Spotify sirve igual aunque no haya nada sonando.
        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: 16
            Layout.bottomMargin: 16
            spacing: 6
            visible: root.player === null

            MaterialSymbol {
                Layout.alignment: Qt.AlignHCenter
                text: "music_note"
                iconSize: 32
                color: Appearance.colors.colSubtext
            }
            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: Translation.tr("No hay nada sonando")
                font.pixelSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colSubtext
            }
            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: Translation.tr("Poné música en cualquier reproductor y aparece acá")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
            }
        }

        // Un solo panel abajo. La letra dejó de ser un modo aparte: ahora es una
        // sección más adentro de Spotify, al lado de Inicio, Biblioteca y Buscar,
        // que es donde uno la va a buscar.
        SpotifySection {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

    }


    // El reproductor no avisa cada segundo: hay que pedirle la posición.
    // Sin esto la barra no se mueve y la letra no sigue el tiempo.
    Timer {
        running: root.player?.isPlaying ?? false
        interval: 500
        repeat: true
        onTriggered: root.player?.positionChanged()
    }
}
