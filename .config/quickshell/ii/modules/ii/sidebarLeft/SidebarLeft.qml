import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.sidebarLeft.aiChat
import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Scope { // Scope
    id: root
    property bool detach: false
    property bool pin: false
    property Component contentComponent: SidebarLeftContent {}
    property Item sidebarContent

    function toggleDetach() {
        root.detach = !root.detach;
    }

    Process { // Dodge cursor away, pin, move cursor back
        id: pinWithFunnyHyprlandWorkaroundProc
        property var hook: null
        property int cursorX;
        property int cursorY;
        function doIt() {
            command = ["hyprctl", "cursorpos"]
            hook = (output) => {
                cursorX = parseInt(output.split(",")[0]);
                cursorY = parseInt(output.split(",")[1]);
                doIt2();
            }
            running = true;
        }
        function doIt2(output) {
            command = ["bash", "-c", "hyprctl dispatch movecursor 9999 9999"];
            hook = () => {
                doIt3();
            }
            running = true;
        }
        function doIt3(output) {
            root.pin = !root.pin;
            command = ["bash", "-c", `sleep 0.01; hyprctl dispatch movecursor ${cursorX} ${cursorY}`];
            hook = null
            running = true;
        }
        stdout: StdioCollector {
            onStreamFinished: {
                pinWithFunnyHyprlandWorkaroundProc.hook(text);
            }
        }
    }

    function togglePin() {
        if (!root.pin) pinWithFunnyHyprlandWorkaroundProc.doIt()
        else root.pin = !root.pin;
    }

    Component.onCompleted: {
        root.sidebarContent = contentComponent.createObject(null, {
            "scopeRoot": root,
        });
        sidebarLoader.item.contentParent.children = [root.sidebarContent];
    }

    onDetachChanged: {
        if (root.detach) {
            GlobalFocusGrab.removeDismissable(sidebarLoader.item) // Remove sidebar from the focus grab system
            sidebarContent.parent = null; // Detach content from sidebar
            sidebarLoader.active = false; // Unload sidebar
            detachedSidebarLoader.active = true; // Load detached window
            detachedSidebarLoader.item.contentParent.children = [sidebarContent];
        } else {
            sidebarContent.parent = null; // Detach content from window
            detachedSidebarLoader.active = false; // Unload detached window
            sidebarLoader.active = true; // Load sidebar
            sidebarLoader.item.contentParent.children = [sidebarContent];
        }
    }

    Loader {
        id: sidebarLoader
        active: true
        
        sourceComponent: PanelWindow { // Window
            id: panelWindow
            visible: GlobalStates.sidebarLeftOpen
            
            property bool extend: false
            // Anchos propios del sidebar izquierdo: el derecho sigue usando los de
            // Appearance, así que ensanchar el chat no lo arrastra a él.
            readonly property real baseWidth: Config.options?.sidebar?.leftWidth ?? Appearance.sizes.sidebarWidth
            readonly property real extendedWidth: Math.max(
                Config.options?.sidebar?.leftWidthExtended ?? Appearance.sizes.sidebarWidthExtended,
                panelWindow.baseWidth)
            property real sidebarWidth: panelWindow.extend ? panelWindow.extendedWidth : panelWindow.baseWidth
            property var contentParent: sidebarContentArea

            function hide() {
                GlobalStates.sidebarLeftOpen = false
            }

            /** Ancho del panel de historial cuando está incrustado en el sidebar. */
            readonly property real historyPanelWidth: 280
            readonly property real historyPanelGap: 8
            // El historial ya no abre una superficie propia al lado: cuando está
            // abierto, es este mismo ancho el que le suma al panel para hacerle
            // lugar adentro.
            readonly property real totalWidth: panelWindow.sidebarWidth
                + (GlobalStates.aiHistoryOpen ? panelWindow.historyPanelWidth + panelWindow.historyPanelGap : 0)

            exclusionMode: ExclusionMode.Normal
            exclusiveZone: root.pin ? panelWindow.totalWidth : 0
            // La ventana se dimensiona con el ancho MÁS grande de los posibles: el
            // contenido se recorta con `mask`, pero si la ventana fuera más
            // angosta que extendido + historial, no habría dónde crecer.
            implicitWidth: panelWindow.extendedWidth + panelWindow.historyPanelWidth
                + panelWindow.historyPanelGap + Appearance.sizes.elevationMargin
            WlrLayershell.namespace: "quickshell:sidebarLeft"
            // Hyprland 0.49: OnDemand is Exclusive, Exclusive just breaks click-outside-to-close
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            color: "transparent"

            anchors {
                top: true
                left: true
                bottom: true
            }

            mask: Region {
                item: sidebarLeftBackground
            }

            onVisibleChanged: {
                if (visible) {
                    GlobalFocusGrab.addDismissable(panelWindow);
                } else {
                    GlobalFocusGrab.removeDismissable(panelWindow);
                }
            }
            Connections {
                target: GlobalFocusGrab
                function onDismissed() {
                    panelWindow.hide();
                }
            }

            // Content
            StyledRectangularShadow {
                target: sidebarLeftBackground
                radius: sidebarLeftBackground.radius
            }

            Rectangle {
                id: sidebarLeftBackground
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.topMargin: Appearance.sizes.hyprlandGapsOut
                anchors.leftMargin: Appearance.sizes.hyprlandGapsOut
                // El historial ya no es una ventana aparte al lado: cuando está
                // abierto, este mismo panel se ensancha para mostrarlo adentro.
                width: panelWindow.totalWidth - Appearance.sizes.hyprlandGapsOut - Appearance.sizes.elevationMargin
                height: parent.height - Appearance.sizes.hyprlandGapsOut * 2
                color: Appearance.colors.colLayer0
                border.width: 1
                border.color: Appearance.colors.colLayer0Border
                radius: Appearance.rounding.screenRounding - Appearance.sizes.hyprlandGapsOut + 1
                clip: true

                Behavior on width {
                    animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
                }

                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Escape) {
                        // Con el historial abierto, Escape lo cierra primero:
                        // cerrar todo el sidebar de una sería demasiado.
                        if (GlobalStates.aiHistoryOpen) {
                            GlobalStates.aiHistoryOpen = false;
                            event.accepted = true;
                            return;
                        }
                        panelWindow.hide();
                    }
                    if (event.modifiers === Qt.ControlModifier) {
                        if (event.key === Qt.Key_O) {
                            panelWindow.extend = !panelWindow.extend;
                        } else if (event.key === Qt.Key_D) {
                            root.toggleDetach();
                        } else if (event.key === Qt.Key_P) {
                            root.togglePin();
                        }
                        event.accepted = true;
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    spacing: panelWindow.historyPanelGap

                    // El contenido normal del sidebar (pestañas, chat, etc.) vive
                    // acá adentro; `contentParent` apunta a este Item en vez de a
                    // `sidebarLeftBackground` directamente para dejarle un hueco
                    // al lado al panel de historial.
                    Item {
                        id: sidebarContentArea
                        // Ancho FIJO (el mismo que tenía el panel antes de que
                        // existiera el historial), con su propio Behavior — no
                        // fillWidth. Antes esto era fillWidth y se recalculaba cada
                        // cuadro restando DOS animaciones independientes (el fondo
                        // entero y el panel de historial), que nunca quedan
                        // perfectamente sincronizadas: el chat entero (y la barra de
                        // pestañas de arriba, que depende de este mismo ancho)
                        // temblaba durante la transición. Con ancho fijo, abrir o
                        // cerrar el historial no lo mueve ni un píxel.
                        Layout.preferredWidth: panelWindow.sidebarWidth - Appearance.sizes.hyprlandGapsOut - Appearance.sizes.elevationMargin
                        Layout.fillHeight: true

                        Behavior on Layout.preferredWidth {
                            animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
                        }
                    }

                    AiHistoryPanel {
                        id: embeddedHistoryPanel
                        // fillWidth en vez de un ancho propio animado: como el área
                        // de contenido de al lado ya tiene ancho fijo, lo único que
                        // puede crecer acá es lo que sobra del fondo (que ya se
                        // anima solo, ver `sidebarLeftBackground`), así que este
                        // panel sigue esa animación gratis, sin la suya propia.
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.topMargin: 8
                        Layout.bottomMargin: 8
                        Layout.rightMargin: 8
                        // Atado a aiHistoryOpen, NO al width propio: un RowLayout
                        // excluye del layout a los items invisibles, así que
                        // "visible: width > 20" era un candado circular (nunca
                        // recibía ancho por estar invisible, nunca era visible por
                        // no tener ancho) y el panel jamás llegaba a mostrarse.
                        visible: GlobalStates.aiHistoryOpen
                        clip: true

                        onRequestClose: GlobalStates.aiHistoryOpen = false
                    }
                }
            }
        }
    }

    Loader {
        id: detachedSidebarLoader
        active: false

        sourceComponent: FloatingWindow {
            id: detachedSidebarRoot
            property var contentParent: detachedSidebarBackground
            color: "transparent"

            visible: GlobalStates.sidebarLeftOpen
            onVisibleChanged: {
                if (!visible) GlobalStates.sidebarLeftOpen = false;
            }
            
            Rectangle {
                id: detachedSidebarBackground
                anchors.fill: parent
                color: Appearance.colors.colLayer0

                Keys.onPressed: (event) => {
                    if (event.modifiers === Qt.ControlModifier) {
                        if (event.key === Qt.Key_D) {
                            root.toggleDetach();
                        }
                        event.accepted = true;
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "sidebarLeft"

        function toggle(): void {
            GlobalStates.sidebarLeftOpen = !GlobalStates.sidebarLeftOpen
        }

        function close(): void {
            GlobalStates.sidebarLeftOpen = false
        }

        function open(): void {
            GlobalStates.sidebarLeftOpen = true
        }
    }

    GlobalShortcut {
        name: "sidebarLeftToggle"
        description: "Toggles left sidebar on press"

        onPressed: {
            GlobalStates.sidebarLeftOpen = !GlobalStates.sidebarLeftOpen;
        }
    }

    GlobalShortcut {
        name: "sidebarLeftOpen"
        description: "Opens left sidebar on press"

        onPressed: {
            GlobalStates.sidebarLeftOpen = true;
        }
    }

    GlobalShortcut {
        name: "sidebarLeftClose"
        description: "Closes left sidebar on press"

        onPressed: {
            GlobalStates.sidebarLeftOpen = false;
        }
    }

    GlobalShortcut {
        name: "sidebarLeftToggleDetach"
        description: "Detach left sidebar into a window/Attach it back"

        onPressed: {
            root.detach = !root.detach;
        }
    }

}
