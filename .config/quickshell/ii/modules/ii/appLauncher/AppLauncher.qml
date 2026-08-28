pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.ii.overview

/**
 * Lanzador de aplicaciones: una caja grande con la grilla de todas las apps.
 * Se abre con la tecla Super sola.
 *
 * Al escribir NO cambia de ventana: reutiliza el mismo SearchWidget del Overview
 * (Super+Tab), la grilla se cierra debajo y la barra sube hasta quedar igual que
 * el buscador de siempre. Es todo la misma ventana, así que no hay corte ni salto.
 */
Scope {
    id: appLauncherScope

    PanelWindow {
        id: panelWindow
        visible: GlobalStates.appLauncherOpen

        WlrLayershell.namespace: "quickshell:appLauncher"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: GlobalStates.appLauncherOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        color: "transparent"

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        readonly property string query: LauncherSearch.query
        // En modo búsqueda la grilla se va y queda sólo el buscador
        readonly property bool searching: Config.options.appLauncher.typeToSearch && panelWindow.query.length > 0

        readonly property var allApps: AppSearch.list
            .filter(app => app && !app.noDisplay)
            .sort((a, b) => a.name.localeCompare(b.name))

        readonly property var sortedApps: {
            const apps = panelWindow.allApps;
            if (!Config.options.appLauncher.pinnedFirst)
                return apps;
            const pinned = Config.options.launcher.pinnedApps;
            const rank = app => {
                const i = pinned.indexOf(app.id);
                return i === -1 ? pinned.length : i;
            };
            return apps.slice().sort((a, b) => rank(a) - rank(b));
        }

        // Con typeToSearch la grilla nunca filtra: de eso se encarga el buscador
        readonly property var gridApps: (Config.options.appLauncher.typeToSearch || panelWindow.query.length === 0) ? panelWindow.sortedApps : AppSearch.fuzzyQuery(panelWindow.query).filter(app => app && !app.noDisplay)

        function close() {
            GlobalStates.appLauncherOpen = false;
        }

        function launchCurrent() {
            const entry = appGrid.currentIndex >= 0 ? panelWindow.gridApps[appGrid.currentIndex] : null;
            if (!entry)
                return;
            panelWindow.close();
            entry.execute();
        }

        // Teclas que maneja la grilla mientras se ve. Se la pasamos a la barra del
        // buscador para poder interceptar también Left/Right, que el TextField
        // consumiría para mover el cursor.
        function gridKeyHandler(event) {
            if (event.key === Qt.Key_Escape) {
                panelWindow.close();
                return true;
            }
            if (panelWindow.searching)
                return false;
            if (event.key === Qt.Key_Down) {
                appGrid.moveCurrentIndexDown();
                return true;
            }
            if (event.key === Qt.Key_Up) {
                appGrid.moveCurrentIndexUp();
                return true;
            }
            if (event.key === Qt.Key_Left) {
                appGrid.moveCurrentIndexLeft();
                return true;
            }
            if (event.key === Qt.Key_Right) {
                appGrid.moveCurrentIndexRight();
                return true;
            }
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                panelWindow.launchCurrent();
                return true;
            }
            return false;
        }

        Connections {
            target: GlobalStates
            function onAppLauncherOpenChanged() {
                if (GlobalStates.appLauncherOpen) {
                    // cancelSearch() solo hace selectAll(), asi que el texto viejo
                    // seguia visible al reabrir. Aca lo borramos de verdad.
                    searchWidget.setSearchingText("");
                    searchWidget.cancelSearch();
                    searchWidget.focusSearchInput();
                    appGrid.currentIndex = 0;
                    appGrid.positionViewAtBeginning();
                    GlobalFocusGrab.addDismissable(panelWindow);
                } else {
                    searchWidget.cancelSearch();
                    GlobalFocusGrab.dismiss();
                }
            }
        }

        Connections {
            target: GlobalFocusGrab
            function onDismissed() {
                GlobalStates.appLauncherOpen = false;
            }
        }

        // Click fuera = cerrar
        MouseArea {
            anchors.fill: parent
            onClicked: panelWindow.close()
        }

        Rectangle { // Fondo oscurecido
            anchors.fill: parent
            color: Appearance.colors.colScrim
            visible: Config.options.appLauncher.dimBackground
            // Al pasar a búsqueda se va, para terminar igual que el Overview,
            // que no oscurece nada.
            opacity: (GlobalStates.appLauncherOpen && !panelWindow.searching) ? Config.options.appLauncher.dimStrength : 0
            Behavior on opacity {
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
            }
        }

        ColumnLayout {
            id: content
            width: Math.min(Config.options.appLauncher.maxWidth, panelWindow.width - 120)
            spacing: 0

            anchors.horizontalCenter: parent.horizontalCenter

            // Altura FIJA de la caja: no se puede usar content.implicitHeight para
            // centrar, porque cambia mientras la grilla se puebla y mientras el
            // envoltorio anima su altura; con el Behavior on y eso se veia como la
            // caja subiendo y bajando sola despues de abrir.
            readonly property int boxTargetHeight: Math.min(Config.options.appLauncher.maxHeight, panelWindow.height - 120)
            readonly property int restingHeight: searchWidget.implicitHeight + content.boxTargetHeight

            // Centrado con la grilla abierta; arriba (como el Overview) al buscar
            y: panelWindow.searching ? Appearance.sizes.elevationMargin : Math.max(Appearance.sizes.elevationMargin, (panelWindow.height - content.restingHeight) / 2)

            Behavior on y {
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
            }

            SearchWidget { // El mismo buscador que Super+Tab
                id: searchWidget
                Layout.alignment: Qt.AlignHCenter
                active: GlobalStates.appLauncherOpen
                // Siempre con su propio fondo: suelta sobre el wallpaper se veia
                // como texto flotando, y ademas evita que el fondo aparezca de
                // golpe al pasar a busqueda.
                showBackground: true
                extraKeyHandler: panelWindow.gridKeyHandler
                onRequestClose: panelWindow.close()
            }

            Item { // Envoltorio: la sombra tiene que desvanecerse JUNTO con la caja.
                // StyledRectangularShadow es un hermano que dibuja según la geometría
                // del target y no hereda su opacity: suelto, quedaba un bloque oscuro
                // flotando después de que la caja ya no se veía.
                id: boxWrapper
                Layout.fillWidth: true
                Layout.topMargin: 0
                implicitHeight: panelWindow.searching ? 0 : content.boxTargetHeight
                opacity: panelWindow.searching ? 0 : 1
                visible: opacity > 0

                Behavior on implicitHeight {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
                Behavior on opacity {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }

                StyledRectangularShadow {
                    target: launcherBox
                }

                Rectangle {
                    id: launcherBox
                    anchors.fill: parent
                    anchors.margins: Appearance.sizes.elevationMargin
                    radius: Appearance.rounding.verylarge
                    color: ColorUtils.transparentize(Appearance.colors.colBackgroundSurfaceContainer, 1 - Config.options.appLauncher.backgroundOpacity)
                    border.width: Config.options.appLauncher.showBorder ? 1 : 0
                    border.color: Appearance.colors.colLayer0Border
                    clip: true

                    // Se traga los clicks para que no cierren el panel
                    MouseArea {
                        anchors.fill: parent
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        anchors.topMargin: 16
                        spacing: 8

                        StyledText {
                            Layout.alignment: Qt.AlignRight
                            Layout.rightMargin: 6
                            visible: Config.options.appLauncher.showAppCount
                            text: Translation.tr("%1 apps").arg(panelWindow.gridApps.length)
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            GridView {
                                id: appGrid
                                anchors.fill: parent
                                clip: true
                                cacheBuffer: 400
                                boundsBehavior: Flickable.StopAtBounds
                                keyNavigationEnabled: false

                                readonly property int columns: Math.max(1, Math.floor(width / Config.options.appLauncher.cellWidth))
                                cellWidth: width / columns
                                cellHeight: Config.options.appLauncher.cellHeight

                                ScrollBar.vertical: StyledScrollBar {}

                                model: panelWindow.gridApps
                                highlightMoveDuration: 100
                                highlightFollowsCurrentItem: true

                                delegate: AppGridItem {
                                    id: gridItem
                                    required property int index
                                    required property var modelData
                                    width: appGrid.cellWidth
                                    height: appGrid.cellHeight
                                    entry: gridItem.modelData
                                    iconSize: Config.options.appLauncher.iconSize
                                    showName: Config.options.appLauncher.showAppNames
                                    selected: appGrid.currentIndex === gridItem.index
                                    onHoveredIn: appGrid.currentIndex = gridItem.index
                                    onActivated: {
                                        appGrid.currentIndex = gridItem.index;
                                        panelWindow.launchCurrent();
                                    }
                                }
                            }

                            PagePlaceholder {
                                shown: panelWindow.gridApps.length === 0
                                icon: "search_off"
                                title: Translation.tr("No apps found")
                            }
                        }
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "appLauncher"

        function toggle(): void {
            GlobalStates.appLauncherOpen = !GlobalStates.appLauncherOpen;
        }
        function open(): void {
            GlobalStates.appLauncherOpen = true;
        }
        function close(): void {
            GlobalStates.appLauncherOpen = false;
        }
    }

    GlobalShortcut {
        name: "appLauncherToggle"
        description: "Toggles the big application launcher on press"

        onPressed: {
            GlobalStates.appLauncherOpen = !GlobalStates.appLauncherOpen;
        }
    }

    GlobalShortcut {
        name: "appLauncherClose"
        description: "Closes the big application launcher"

        onPressed: {
            GlobalStates.appLauncherOpen = false;
        }
    }

    GlobalShortcut {
        name: "appLauncherToggleRelease"
        description: "Toggles the big application launcher on release (for the bare Super key). " + "Relies on quickshell:searchToggleReleaseInterrupt clearing GlobalStates.superReleaseMightTrigger " + "when Super is used as a modifier, same as the overview search does."

        // Momento del press, para distinguir un toque de un Super mantenido.
        property double pressedAt: 0

        onPressed: {
            GlobalStates.superReleaseMightTrigger = true;
            pressedAt = Date.now();
        }

        onReleased: {
            if (!GlobalStates.superReleaseMightTrigger) {
                GlobalStates.superReleaseMightTrigger = true;
                return;
            }
            // El catchall no cubre todo (arrastres con el mouse, submaps, binds que
            // cambian de submap), asi que a veces el launcher se abria igual despues
            // de usar Super como modificador. Un toque real dura poquito: si la tecla
            // estuvo mantenida mas que el umbral, no fue un toque.
            const heldMs = Date.now() - pressedAt;
            if (heldMs > Config.options.appLauncher.superTapMaxMs)
                return;
            GlobalStates.appLauncherOpen = !GlobalStates.appLauncherOpen;
        }
    }
}
