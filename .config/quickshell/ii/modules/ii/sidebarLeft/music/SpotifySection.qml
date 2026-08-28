pragma ComponentBehavior: Bound

import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell

/**
 * Tu Spotify: portada, biblioteca, búsqueda y control de reproducción.
 *
 * Con Premium los botones mandan a la Web API y controlan el dispositivo que
 * elijas. Sin Premium, tocar algo lo abre en el Spotify de escritorio — la API de
 * playback exige Premium y no hay vuelta.
 */
Rectangle {
    id: root

    /** home | library | search | lyrics */
    property string section: "home"

    // Biblioteca, búsqueda y el contenido de una colección abierta comparten la
    // misma lista. Inicio y Letra tienen lo suyo.
    readonly property bool showingList: SpotifyService.openedCollection !== null
        || root.section === "library" || root.section === "search"
    property bool devicesOpen: false

    readonly property var libraryEntries: SpotifyService.playlists

    radius: Appearance.rounding.small
    color: Appearance.colors.colLayer2
    clip: true

    // Sondear el estado sólo mientras se ve esta pestaña
    Binding {
        target: SpotifyService
        property: "watching"
        value: root.visible
    }

    onVisibleChanged: if (root.visible && SpotifyService.connected) SpotifyService.fetchDevices()

    /** Guarda el Client ID en la config; de ahí lo toma SpotifyService. */
    function saveClientId() {
        const value = clientIdField.text.trim();
        if (value.length === 0) return;
        Config.options.sidebar.music.spotify.clientId = value;
    }

    // ------------------------------------------------------------------ //
    // Sin configurar / sin conectar
    // ------------------------------------------------------------------ //

    ColumnLayout {
        anchors {
            fill: parent
            margins: 12
        }
        spacing: 8
        visible: !SpotifyService.connected

        Item { Layout.fillHeight: true }

        MaterialSymbol {
            Layout.alignment: Qt.AlignHCenter
            text: "account_circle"
            iconSize: 32
            color: Appearance.colors.colSubtext
        }

        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colSubtext
            text: {
                if (SpotifyService.state === "error") return SpotifyService.lastError;
                if (SpotifyService.state === "waiting")
                    return Translation.tr("Terminá el permiso en el navegador…");
                if (!SpotifyService.configured)
                    return Translation.tr("Para conectar tu Spotify necesitás un Client ID.\nCreá una app gratis en developer.spotify.com,\nponé como Redirect URI http://127.0.0.1:8888/callback\ny pegá el Client ID acá abajo");
                return Translation.tr("Conectá tu cuenta para ver tus playlists,\nlo que escuchaste y buscar música");
            }
        }

        RippleButton {
            Layout.alignment: Qt.AlignHCenter
            visible: !SpotifyService.configured
            implicitHeight: 34
            implicitWidth: createRow.implicitWidth + 16 * 2
            buttonRadius: Appearance.rounding.full
            colBackground: Appearance.colors.colPrimary
            colBackgroundHover: Appearance.colors.colPrimaryHover
            onClicked: Quickshell.execDetached(["xdg-open", "https://developer.spotify.com/dashboard"])

            contentItem: RowLayout {
                id: createRow
                spacing: 6
                MaterialSymbol {
                    text: "open_in_new"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnPrimary
                }
                StyledText {
                    text: Translation.tr("Crear la app en Spotify")
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnPrimary
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            spacing: 4

            MaterialTextField {
                id: clientIdField
                Layout.fillWidth: true
                placeholderText: Translation.tr("Pegá tu Client ID")
                text: SpotifyService.clientId
                onAccepted: root.saveClientId()
            }

            RippleButton {
                implicitHeight: 34
                implicitWidth: 34
                buttonRadius: Appearance.rounding.small
                enabled: clientIdField.text.trim().length > 0
                colBackground: Appearance.colors.colPrimary
                colBackgroundHover: Appearance.colors.colPrimaryHover
                onClicked: root.saveClientId()

                contentItem: MaterialSymbol {
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: "save"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnPrimary
                }
            }
        }

        RippleButton {
            Layout.alignment: Qt.AlignHCenter
            visible: SpotifyService.configured && SpotifyService.state !== "waiting"
            implicitHeight: 34
            implicitWidth: connectRow.implicitWidth + 16 * 2
            buttonRadius: Appearance.rounding.full
            colBackground: Appearance.colors.colPrimary
            colBackgroundHover: Appearance.colors.colPrimaryHover
            onClicked: SpotifyService.login()

            contentItem: RowLayout {
                id: connectRow
                spacing: 6
                MaterialSymbol {
                    text: "link"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnPrimary
                }
                StyledText {
                    text: Translation.tr("Conectar Spotify")
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnPrimary
                }
            }
        }

        Item { Layout.fillHeight: true }
    }

    // ------------------------------------------------------------------ //
    // Conectado
    // ------------------------------------------------------------------ //

    ColumnLayout {
        anchors {
            fill: parent
            margins: 8
        }
        spacing: 6
        visible: SpotifyService.connected

        // ---- Barra de cuenta: estado + acciones ---- //
        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            MaterialSymbol {
                text: {
                    if (SpotifyService.state === "error") return "error";
                    if (SpotifyService.loading) return "sync";
                    if (SpotifyService.healthy) return "check_circle";
                    return "help";
                }
                iconSize: Appearance.font.pixelSize.small
                color: SpotifyService.state === "error" ? Appearance.m3colors.m3error
                    : (SpotifyService.healthy ? Appearance.colors.colPrimary : Appearance.colors.colSubtext)
            }

            StyledText {
                Layout.fillWidth: true
                text: SpotifyService.status
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: SpotifyService.state === "error" ? Appearance.m3colors.m3error : Appearance.colors.colSubtext
                elide: Text.ElideRight

                // StyledText no expone `hovered`, así que se lo damos: sin esto
                // el tooltip no se mostraría (y antes, al revés, se mostraba
                // siempre y quedaba flotando encima del sidebar).
                property alias hovered: statusHover.hovered
                HoverHandler { id: statusHover }

                StyledToolTip {
                    text: SpotifyService.lastError.length > 0 ? SpotifyService.lastError : SpotifyService.status
                }
            }

            StyledText {
                visible: SpotifyService.lastSync > 0
                text: Qt.formatTime(new Date(SpotifyService.lastSync), "HH:mm")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
            }

            // Elegir en qué parlante suena
            RippleButton {
                implicitHeight: 28
                implicitWidth: 28
                buttonRadius: Appearance.rounding.small
                colBackground: root.devicesOpen ? Appearance.colors.colSecondaryContainer : "transparent"
                colBackgroundHover: Appearance.colors.colLayer1Hover
                onClicked: {
                    root.devicesOpen = !root.devicesOpen;
                    if (root.devicesOpen) SpotifyService.fetchDevices();
                }

                contentItem: MaterialSymbol {
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: SpotifyService.hasDevice ? "devices" : "devices_off"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colOnLayer2
                }
                StyledToolTip { text: Translation.tr("Dispositivos") }
            }

            // Sync a mano: revalida el token y vuelve a bajar todo.
            // Está para cuando la lista queda vacía y no querés reiniciar la shell.
            RippleButton {
                implicitHeight: 28
                implicitWidth: 28
                buttonRadius: Appearance.rounding.small
                colBackground: "transparent"
                colBackgroundHover: Appearance.colors.colLayer1Hover
                enabled: !SpotifyService.loading
                onClicked: SpotifyService.sync()

                contentItem: MaterialSymbol {
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: "sync"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colOnLayer2

                    // Gira mientras hay peticiones en vuelo
                    RotationAnimation on rotation {
                        running: SpotifyService.loading
                        from: 0
                        to: 360
                        duration: 1000
                        loops: Animation.Infinite
                        alwaysRunToEnd: true
                    }
                }
                StyledToolTip { text: Translation.tr("Sincronizar con Spotify") }
            }

            RippleButton {
                implicitHeight: 28
                implicitWidth: 28
                buttonRadius: Appearance.rounding.small
                colBackground: "transparent"
                colBackgroundHover: Appearance.colors.colLayer1Hover
                onClicked: SpotifyService.logout()

                contentItem: MaterialSymbol {
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: "link_off"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colOnLayer2
                }
                StyledToolTip { text: Translation.tr("Desconectar la cuenta") }
            }
        }

        // ---- Dispositivos ---- //
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            visible: root.devicesOpen

            StyledText {
                Layout.fillWidth: true
                visible: SpotifyService.devices.length === 0
                text: Translation.tr("No hay dispositivos. Abrí Spotify en algún lado.")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                wrapMode: Text.Wrap
            }

            Repeater {
                model: SpotifyService.devices

                delegate: RippleButton {
                    id: deviceButton
                    required property var modelData

                    Layout.fillWidth: true
                    implicitHeight: 28
                    buttonRadius: Appearance.rounding.small
                    colBackground: deviceButton.modelData.active ? Appearance.colors.colSecondaryContainer : "transparent"
                    colBackgroundHover: Appearance.colors.colLayer1Hover
                    onClicked: {
                        SpotifyService.transferTo(deviceButton.modelData.id);
                        root.devicesOpen = false;
                    }

                    contentItem: RowLayout {
                        spacing: 6
                        MaterialSymbol {
                            text: {
                                switch (deviceButton.modelData.type) {
                                case "Smartphone": return "smartphone";
                                case "Speaker": return "speaker";
                                case "TV": return "tv";
                                default: return "computer";
                                }
                            }
                            iconSize: Appearance.font.pixelSize.normal
                            color: deviceButton.modelData.active ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer2
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: deviceButton.modelData.name
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnLayer2
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        // ---- Reconectar cuando el token murió de verdad ---- //
        RippleButton {
            Layout.fillWidth: true
            visible: SpotifyService.state === "error"
            implicitHeight: 28
            buttonRadius: Appearance.rounding.small
            colBackground: Appearance.colors.colLayer1
            onClicked: SpotifyService.login()

            contentItem: RowLayout {
                spacing: 6
                Item { Layout.fillWidth: true }
                MaterialSymbol {
                    text: "refresh"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colOnLayer2
                }
                StyledText {
                    text: Translation.tr("Volver a conectar la cuenta")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnLayer2
                }
                Item { Layout.fillWidth: true }
            }
        }

        // ---- Secciones ---- //
        RowLayout {
            Layout.fillWidth: true
            spacing: 4
            visible: SpotifyService.openedCollection === null

            Repeater {
                model: [
                    { "key": "home", "label": Translation.tr("Inicio"), "icon": "home" },
                    { "key": "library", "label": Translation.tr("Biblioteca"), "icon": "library_music" },
                    { "key": "search", "label": Translation.tr("Buscar"), "icon": "search" },
                    // La letra vive acá y no en un selector aparte: es una vista
                    // más de lo que estás escuchando, igual que Inicio o Buscar.
                    { "key": "lyrics", "label": Translation.tr("Letra"), "icon": "lyrics" }
                ]

                delegate: RippleButton {
                    id: sectionButton
                    required property var modelData

                    Layout.fillWidth: true
                    implicitHeight: 30
                    buttonRadius: Appearance.rounding.small
                    toggled: root.section === sectionButton.modelData.key
                    colBackground: Appearance.colors.colLayer1
                    onClicked: root.section = sectionButton.modelData.key

                    contentItem: RowLayout {
                        spacing: 4
                        Item { Layout.fillWidth: true }
                        MaterialSymbol {
                            text: sectionButton.modelData.icon
                            iconSize: Appearance.font.pixelSize.normal
                            color: sectionButton.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer2
                        }
                        StyledText {
                            text: sectionButton.modelData.label
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: sectionButton.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer2
                        }
                        Item { Layout.fillWidth: true }
                    }
                }
            }
        }

        // ---- Cabecera de una playlist/álbum abierto ---- //
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: SpotifyService.openedCollection !== null

            RippleButton {
                implicitWidth: 28
                implicitHeight: 28
                buttonRadius: Appearance.rounding.small
                colBackground: "transparent"
                colBackgroundHover: Appearance.colors.colLayer1Hover
                onClicked: SpotifyService.closeCollection()

                contentItem: MaterialSymbol {
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: "arrow_back"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnLayer2
                }
            }

            Rectangle {
                implicitWidth: 40
                implicitHeight: 40
                radius: Appearance.rounding.verysmall ?? 4
                color: Appearance.colors.colLayer1
                clip: true

                StyledImage {
                    anchors.fill: parent
                    source: SpotifyService.openedCollection?.image ?? ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                StyledText {
                    Layout.fillWidth: true
                    text: SpotifyService.openedCollection?.name ?? ""
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer2
                    elide: Text.ElideRight
                }
                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("%1 temas").arg(SpotifyService.collectionTracks.length)
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }
            }

            RippleButton {
                implicitWidth: 34
                implicitHeight: 34
                buttonRadius: Appearance.rounding.full
                colBackground: Appearance.colors.colPrimary
                colBackgroundHover: Appearance.colors.colPrimaryHover
                onClicked: SpotifyService.playContext(SpotifyService.openedCollection.uri)

                contentItem: MaterialSymbol {
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: "play_arrow"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnPrimary
                }
                StyledToolTip { text: Translation.tr("Reproducir todo") }
            }
        }

        MaterialTextField {
            id: searchField
            Layout.fillWidth: true
            visible: root.section === "search" && SpotifyService.openedCollection === null
            placeholderText: Translation.tr("Buscar en Spotify")
            onAccepted: SpotifyService.search(searchField.text)
        }

        // ---- Contenido ---- //
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            SpotifyHome {
                anchors.fill: parent
                visible: root.section === "home" && SpotifyService.openedCollection === null
            }

            MusicLyrics {
                anchors.fill: parent
                visible: root.section === "lyrics" && SpotifyService.openedCollection === null
                // Ya está adentro del panel, no necesita su propio fondo
                color: "transparent"
            }

            // Cambia el modelo, no el diseño.
            StyledListView {
                id: entryList
                anchors.fill: parent
                spacing: 2
                clip: true
                visible: root.showingList

                model: {
                    if (SpotifyService.openedCollection !== null) return SpotifyService.collectionTracks;
                    if (root.section === "search") return SpotifyService.searchResults;
                    return root.libraryEntries;
                }

                delegate: SpotifyRow {
                    required property var modelData
                    required property int index

                    width: ListView.view.width
                    entry: modelData
                    // Dentro de una playlist el tema se toca en contexto, así sigue la lista
                    contextUri: SpotifyService.openedCollection?.uri ?? ""
                    position: SpotifyService.openedCollection !== null ? index : -1
                }
            }

            // Fuera del ListView a propósito: adentro se lo lleva el contentItem y
            // se va scrolleando con la lista.
            StyledText {
                anchors.centerIn: parent
                width: parent.width - 16
                visible: entryList.visible && entryList.count === 0 && !SpotifyService.loading
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                text: {
                    if (SpotifyService.state === "error")
                        return Translation.tr("No se pudo traer nada.\nProbá sincronizar o reconectá la cuenta.");
                    if (SpotifyService.openedCollection !== null)
                        return Translation.tr("Esta lista está vacía");
                    if (root.section === "search")
                        return SpotifyService.searchQuery.length === 0
                            ? Translation.tr("Escribí algo y dale Enter")
                            : Translation.tr("Sin resultados");
                    return Translation.tr("No hay playlists.\nTocá sincronizar si tenés.");
                }
            }
        }

        // Sin barra de transporte acá abajo: play, saltos, aleatorio, repetir y
        // volumen viven todos en el reproductor de arriba, que además funciona
        // con cualquier reproductor y no sólo con Spotify Premium.
        // Lo único que sobrevive es el aviso de por qué no se puede controlar.
        StyledText {
            Layout.fillWidth: true
            visible: SpotifyService.knownFree
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: Translation.tr("Tu cuenta no es Premium: la reproducción se manda al Spotify que tengas abierto, sin traer la ventana al frente")
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
        }
    }
}
