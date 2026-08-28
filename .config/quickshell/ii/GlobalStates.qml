import qs.modules.common
import qs.services
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
pragma Singleton
pragma ComponentBehavior: Bound

Singleton {
    id: root
    property bool barOpen: true
    property bool crosshairOpen: false
    property bool sidebarLeftOpen: false
    /**
     * Barra de historial de chats, pegada a la derecha del sidebar izquierdo.
     *
     * Vive acá y no adentro de AiChat porque la dibuja la ventana del sidebar:
     * es una superficie aparte, fuera del recuadro del panel, y la página del
     * chat no tiene forma de pintar ahí.
     */
    property bool aiHistoryOpen: false
    property bool sidebarRightOpen: false
    property bool mediaControlsOpen: false
    property bool osdBrightnessOpen: false
    property bool osdVolumeOpen: false
    property bool oskOpen: false
    property bool overlayOpen: false
    property bool overviewOpen: false
    // Lanzador de apps a pantalla completa (tecla Super sola)
    property bool appLauncherOpen: false
    property bool regionSelectorOpen: false
    property bool searchOpen: false
    property bool screenLocked: false
    property bool screenLockContainsCharacters: false
    property bool screenUnlockFailed: false
    property bool screenTranslatorOpen: false
    property bool sessionOpen: false
    property bool superDown: false
    property bool superReleaseMightTrigger: true
    property bool wallpaperSelectorOpen: false
    /**
     * Sólo tiene sentido dentro del proceso de la app de settings (`qs -p settings.qml`),
     * que la observa para cerrarse. En el proceso de la shell no la mira nadie: para
     * ABRIR settings desde la shell hay que lanzar el proceso con execDetached, no
     * prender este flag.
     */
    property bool settingsOpen: false
    /**
     * Los widgets del fondo (Notas, ajustes del reloj mundial) lo prenden mientras
     * necesitan escribir: la capa del fondo sólo toma foco de teclado cuando esto
     * está en true, si no se comería los atajos del compositor.
     */
    property bool desktopWidgetKeyboardFocus: false
    // Menú contextual del escritorio (click derecho sobre el fondo)
    property bool desktopMenuOpen: false
    property var desktopMenuScreen: null
    property real desktopMenuX: 0
    property real desktopMenuY: 0
    // Bandeja de arrastre: dónde apareció y si está abierta
    property bool dropShelfOpen: false
    property real dropShelfX: 0
    property real dropShelfY: 0
    property bool workspaceShowNumbers: false
    // Puntos de cava compartidos: los consumen widgets fuera de MediaControls
    // (visualizer de la barra y del fondo), que no pueden ver su estado interno.
    property list<real> visualizerPoints: []

    onSidebarRightOpenChanged: {
        if (GlobalStates.sidebarRightOpen) {
            Notifications.timeoutAll();
            Notifications.markAllRead();
        }
    }

    GlobalShortcut {
        name: "workspaceNumber"
        description: "Hold to show workspace numbers, release to show icons"

        onPressed: {
            root.superDown = true
        }
        onReleased: {
            root.superDown = false
        }
    }
}