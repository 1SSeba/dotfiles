import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root

    Loader {
        id: wallpaperSelectorLoader
        active: GlobalStates.wallpaperSelectorOpen

        sourceComponent: PanelWindow {
            id: panelWindow
            readonly property HyprlandMonitor monitor: Hyprland.monitorFor(panelWindow.screen)
            property bool monitorIsFocused: (Hyprland.focusedMonitor?.id == monitor?.id)

            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:wallpaperSelector"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            color: "transparent"

            anchors.top: true
            margins {
                top: Config?.options.bar.vertical ? Appearance.sizes.hyprlandGapsOut : Appearance.sizes.barHeight + Appearance.sizes.hyprlandGapsOut
            }

            mask: Region {
                item: content
            }

            implicitHeight: Appearance.sizes.wallpaperSelectorHeight
            implicitWidth: Appearance.sizes.wallpaperSelectorWidth

            Component.onCompleted: {
                GlobalFocusGrab.addDismissable(panelWindow);
            }
            Component.onDestruction: {
                GlobalFocusGrab.removeDismissable(panelWindow);
            }
            Connections {
                target: GlobalFocusGrab
                function onDismissed() {
                    GlobalStates.wallpaperSelectorOpen = false;
                }
            }

            WallpaperSelectorContent {
                id: content
                anchors {
                    fill: parent
                }
            }
        }
    }

    function toggleWallpaperSelector() {
        if (Config.options.wallpaperSelector.useSystemFileDialog) {
            Wallpapers.openFallbackPicker(Appearance.m3colors.darkmode);
            return;
        }
        const opening = !GlobalStates.wallpaperSelectorOpen;
        // Abrir desde el atajo/la barra no apunta a ningún monitor en particular:
        // por defecto aplica a todos. (El menú de escritorio, en cambio, precarga
        // el monitor sobre el que se hizo click derecho antes de abrir el selector.)
        if (opening) GlobalStates.wallpaperSelectorTargetMonitor = "";
        GlobalStates.wallpaperSelectorOpen = opening
    }

    IpcHandler {
        target: "wallpaperSelector"

        function toggle(): void {
            root.toggleWallpaperSelector();
        }

        function random(): void {
            Wallpapers.randomFromCurrentFolder();
        }
    }

    GlobalShortcut {
        name: "wallpaperSelectorToggle"
        description: "Toggle wallpaper selector"
        onPressed: {
            root.toggleWallpaperSelector();
        }
    }

    GlobalShortcut {
        name: "wallpaperSelectorRandom"
        description: "Select random wallpaper in current folder"
        onPressed: {
            Wallpapers.randomFromCurrentFolder();
        }
    }
}
