import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Hyprland

/**
 * Un tile de la grilla de Inspo. La altura sale del aspect ratio, así la
 * columna queda tipo masonry sin huecos.
 */
Rectangle {
    id: root
    required property var itemData
    property real imageRadius: Appearance.rounding.small
    property bool showActions: false

    // StyledToolTip se muestra siempre si el padre no expone `hovered`
    // (mirá su internalVisibleCondition). Sin esto, todos los tooltips de la
    // grilla quedan flotando en pantalla a la vez.
    //
    // Va con HoverHandler y no con mouseArea.containsMouse: los botones que
    // flotan arriba del tile son Controls y le roban el hover al MouseArea, así
    // que containsMouse se apagaba justo al ir a apretarlos. Eso escondía el
    // botón, el mouse volvía al MouseArea, se prendía de nuevo... y parpadeaba.
    // El HoverHandler mira el tile entero, hijos incluidos.
    readonly property bool hovered: hoverHandler.hovered

    HoverHandler {
        id: hoverHandler
    }

    // Si la fuente no informó tamaño, asumimos vertical (lo típico en inspo)
    readonly property real ratio: (itemData.aspect_ratio > 0.05 && itemData.aspect_ratio < 20)
        ? itemData.aspect_ratio : 0.75
    readonly property string fileName: {
        const url = String(root.itemData.full_url ?? "");
        const clean = url.split("?")[0];
        const base = clean.substring(clean.lastIndexOf("/") + 1);
        return base.length > 0 ? base : `inspo-${root.itemData.id}.jpg`;
    }

    implicitHeight: width / root.ratio
    radius: root.imageRadius
    color: Appearance.colors.colLayer2
    // Sin clip: el menú de acciones cuelga por debajo del botón y en las imágenes
    // apaisadas (tiles bajos) quedaba cortado. La imagen ya tiene sus esquinas
    // redondeadas por el OpacityMask, así que el clip no hacía falta.
    clip: false
    // Y mientras el menú está abierto, este tile va por encima de sus vecinos
    z: root.showActions ? 10 : 0

    StyledImage {
        id: image
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        source: root.itemData.thumb_url
        sourceSize.width: Math.round(root.width)

        // Si la miniatura no carga, probamos la imagen original antes de
        // mostrar el ícono de rota. Una sola vez, para no quedar en loop.
        property bool triedFullSize: false
        onStatusChanged: {
            if (status !== Image.Error || triedFullSize) return;
            const full = root.itemData.full_url ?? "";
            if (full.length === 0 || full === source) return;
            triedFullSize = true;
            source = full;
        }

        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: root.width
                height: root.height
                radius: root.imageRadius
            }
        }
    }

    // Mientras carga, algo que no sea un rectángulo muerto
    MaterialLoadingIndicator {
        anchors.centerIn: parent
        visible: image.status === Image.Loading
    }

    MaterialSymbol {
        anchors.centerIn: parent
        visible: image.status === Image.Error
        iconSize: 28
        color: Appearance.colors.colOnLayer2Disabled
        text: "broken_image"
    }

    // Degradado abajo para que el texto se lea sobre cualquier imagen
    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: Math.min(root.height * 0.5, 64)
        visible: root.hovered && root.itemData.title.length > 0
        radius: root.imageRadius
        gradient: Gradient {
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 1.0; color: ColorUtils.transparentize(Appearance.m3colors.m3surface, 0.15) }
        }

        StyledText {
            anchors {
                left: parent.left; right: parent.right; bottom: parent.bottom
                margins: 8
            }
            elide: Text.ElideRight
            maximumLineCount: 2
            wrapMode: Text.Wrap
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.m3colors.m3onSurface
            text: root.itemData.author.length > 0
                ? `${root.itemData.title} · ${root.itemData.author}`
                : root.itemData.title
        }
    }

    StyledToolTip {
        text: root.itemData.title.length > 0 ? root.itemData.title : Translation.tr("Abrir la fuente")
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                root.showActions = !root.showActions;
                return;
            }
            const url = root.itemData.source_url.length > 0
                ? root.itemData.source_url : root.itemData.full_url;
            if (url.length === 0) return;
            // Sin esto el cursor salta al abrir el navegador
            Hyprland.dispatch("keyword cursor:no_warps true");
            Qt.openUrlExternally(url);
            Hyprland.dispatch("keyword cursor:no_warps false");
        }
    }

    /**
     * Baja la imagen a ~/Pictures/Inspo y la deja de fondo.
     * switchwall.sh necesita un archivo local, por eso el curl primero.
     */
    function setAsWallpaper() {
        const dir = Directories.inspoDownloads;
        const path = `${dir}/${root.fileName}`;
        const safePath = StringUtils.shellSingleQuoteEscape(path);
        // El aviso de "bajando" va con `;` y no con `&&`: si notify-send no está
        // o falla, el fondo se tiene que poner igual.
        Quickshell.execDetached(["bash", "-c",
            `mkdir -p '${StringUtils.shellSingleQuoteEscape(dir)}' || exit 1; `
            + `notify-send '${Translation.tr("Poniendo de fondo…")}' -a 'Shell'; `
            + `curl -sL '${StringUtils.shellSingleQuoteEscape(root.itemData.full_url)}' -o '${safePath}' `
            + `&& '${Directories.wallpaperSwitchScriptPath}' --image '${safePath}' `
            + `|| notify-send '${Translation.tr("No se pudo poner de fondo")}' '${safePath}' -a 'Shell'`]);
    }

    // Acceso directo: un clic y queda de fondo, sin abrir el menú
    RippleButton {
        id: wallpaperButton
        anchors { top: parent.top; right: menuButton.left; margins: 6; rightMargin: 4 }
        implicitWidth: 28
        implicitHeight: 28
        visible: root.hovered || root.showActions
        buttonRadius: Appearance.rounding.full
        colBackground: ColorUtils.transparentize(Appearance.m3colors.m3surface, 0.25)
        colBackgroundHover: ColorUtils.transparentize(Appearance.m3colors.m3surface, 0.05)

        contentItem: MaterialSymbol {
            horizontalAlignment: Text.AlignHCenter
            iconSize: Appearance.font.pixelSize.normal
            color: Appearance.m3colors.m3onSurface
            text: "wallpaper"
        }
        onClicked: root.setAsWallpaper()

        StyledToolTip {
            text: Translation.tr("Poner de fondo")
        }
    }

    // Botón de acciones, sólo cuando el mouse está encima (o el menú abierto)
    RippleButton {
        id: menuButton
        anchors { top: parent.top; right: parent.right; margins: 6 }
        implicitWidth: 28
        implicitHeight: 28
        visible: root.hovered || root.showActions
        buttonRadius: Appearance.rounding.full
        colBackground: ColorUtils.transparentize(Appearance.m3colors.m3surface, 0.25)
        colBackgroundHover: ColorUtils.transparentize(Appearance.m3colors.m3surface, 0.05)

        contentItem: MaterialSymbol {
            horizontalAlignment: Text.AlignHCenter
            iconSize: Appearance.font.pixelSize.normal
            color: Appearance.m3colors.m3onSurface
            text: "more_vert"
        }
        onClicked: root.showActions = !root.showActions
    }

    Loader {
        active: root.showActions
        anchors { top: menuButton.bottom; right: parent.right; margins: 6 }
        z: 10

        sourceComponent: Rectangle {
            radius: Appearance.rounding.small
            color: Appearance.m3colors.m3surfaceContainer
            implicitWidth: actionsColumn.implicitWidth
            implicitHeight: actionsColumn.implicitHeight + radius

            ColumnLayout {
                id: actionsColumn
                anchors.centerIn: parent
                spacing: 0

                // Primero lo que más se usa
                MenuButton {
                    Layout.fillWidth: true
                    buttonText: Translation.tr("Poner de fondo")
                    onClicked: {
                        root.showActions = false;
                        root.setAsWallpaper();
                    }
                }
                MenuButton {
                    Layout.fillWidth: true
                    buttonText: Translation.tr("Descargar")
                    onClicked: {
                        root.showActions = false;
                        const dir = Directories.inspoDownloads;
                        const path = `${dir}/${root.fileName}`;
                        const safePath = StringUtils.shellSingleQuoteEscape(path);
                        Quickshell.execDetached(["bash", "-c",
                            `mkdir -p '${StringUtils.shellSingleQuoteEscape(dir)}' `
                            + `&& curl -sL '${StringUtils.shellSingleQuoteEscape(root.itemData.full_url)}' -o '${safePath}' `
                            + `&& notify-send '${Translation.tr("Descarga lista")}' '${safePath}' -a 'Shell' `
                            + `|| notify-send '${Translation.tr("No se pudo descargar")}' '${safePath}' -a 'Shell'`]);
                    }
                }
                MenuButton {
                    Layout.fillWidth: true
                    buttonText: Translation.tr("Abrir imagen")
                    onClicked: {
                        root.showActions = false;
                        Qt.openUrlExternally(root.itemData.full_url);
                    }
                }
                MenuButton {
                    Layout.fillWidth: true
                    visible: root.itemData.source_url.length > 0
                    buttonText: Translation.tr("Ir a la fuente")
                    onClicked: {
                        root.showActions = false;
                        Qt.openUrlExternally(root.itemData.source_url);
                    }
                }
            }
        }
    }
}
