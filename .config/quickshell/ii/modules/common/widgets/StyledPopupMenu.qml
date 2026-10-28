import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.modules.common.widgets // Para las sombras y estilos

Item {
    id: root

    // El root nunca dibuja nada propio (la UI real vive en el PanelWindow del
    // LazyLoader): si queda "visible" en su valor por defecto (true) y a este
    // Item lo mete un ColumnLayout/GroupedList, se lleva una fila entera con
    // su spacing sin necesidad. implicitWidth/Height ya son 0 por defecto.
    visible: false

    // Propiedades que recibe desde BarConfig.qml
    //
    // OJO: no uses "property alias model: repeater.model" acá. `repeater`
    // vive dentro del Component implícito de LazyLoader.component, y un id
    // ahí adentro no es resoluble desde este scope exterior: el motor QML
    // reporta "Invalid alias reference" y el tipo StyledPopupMenu entero
    // queda "unavailable" (rompe todo lo que lo instancie). Por eso quedó
    // sin usar tanto tiempo: nunca llegó a cargar de verdad.
    property var model: []
    property var onItemSelected: (item) => {}

    // Contenido libre: si se define, reemplaza la lista de arriba por
    // cualquier QML (ej. un formulario). El caller es responsable de
    // cerrar el popup (root.visible = false) desde dentro del contenido.
    property Component contentComponent: null
    property real popupWidth: 200

    // Item cerca del cual se ancla el popup (ej. el botón que lo abre). Si no
    // se da, cae al centro de la pantalla.
    property Item anchorItem: null

    // Control de visibilidad. OJO: no se llama "visible" porque Item ya trae
    // esa propiedad — redeclararla la sombreaba y dejaba el Item base con su
    // "visible" real siempre en true, lo que le agregaba una fila fantasma
    // (con su spacing) a cualquier ColumnLayout/GroupedList que lo contuviera.
    property bool popupVisible: false

    LazyLoader {
        id: loader
        active: root.popupVisible // Solo carga la ventana cuando popupVisible es true

        component: PanelWindow {
            id: popupWindow

            // Configuración de Wayland
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell:popup"

            color: "transparent"
            // `mask: true` (el original) no es un Region válido: PanelWindow
            // lo rechaza ("Invalid property assignment... PendingRegion*"),
            // otro motivo más por el que este tipo nunca llegó a cargar.
            mask: Region {
                item: container
            }

            // Dimensiones basadas en el contenido
            implicitWidth: container.implicitWidth + 40
            implicitHeight: container.implicitHeight + 40

            anchors.left: true
            anchors.top: true

            readonly property real anchorOffsetX: {
                const margin = 10
                const maxLeft = Math.max(margin, popupWindow.screen.width - popupWindow.implicitWidth - margin)
                if (!root.anchorItem) return (popupWindow.screen.width - popupWindow.implicitWidth) / 2
                const base = root.QsWindow?.mapFromItem(root.anchorItem, 0, root.anchorItem.height).x ?? 0
                return Math.max(margin, Math.min(base, maxLeft))
            }
            readonly property real anchorOffsetY: {
                const margin = 10
                const maxTop = Math.max(margin, popupWindow.screen.height - popupWindow.implicitHeight - margin)
                if (!root.anchorItem) return (popupWindow.screen.height - popupWindow.implicitHeight) / 2
                const base = root.QsWindow?.mapFromItem(root.anchorItem, 0, root.anchorItem.height).y ?? 0
                return Math.max(margin, Math.min(base, maxTop))
            }
            margins {
                left: anchorOffsetX
                top: anchorOffsetY
            }

            // NOTA: no hay "cerrar al clickear afuera" acá. PanelWindow no
            // expone una propiedad "active"/onActiveChanged (a diferencia de
            // Window/ApplicationWindow) — el código original la usaba y por
            // eso el motor marcaba a todo StyledPopupMenu como "Type
            // unavailable": ni siquiera compilaba. El cierre queda a cargo
            // de cada callback (el Repeater ya lo hace; VideoConfig.qml
            // también lo hace en sus botones de Apply/Restore).

            // Sombras usando tus widgets existentes
            StyledRectangularShadow {
                target: container
            }

            Rectangle {
                id: container
                anchors.centerIn: parent
                implicitWidth: root.popupWidth
                implicitHeight: (root.contentComponent ? contentLoader.implicitHeight : layout.implicitHeight) + 16

                radius: Appearance.rounding.normal
                color: Appearance.m3colors.m3surfaceContainer
                border.width: 1
                border.color: Appearance.colors.colLayer0Border

                Loader {
                    id: contentLoader
                    visible: root.contentComponent !== null
                    anchors.fill: parent
                    anchors.margins: 8
                    sourceComponent: root.contentComponent
                }

                ColumnLayout {
                    id: layout
                    visible: root.contentComponent === null
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 2

                    Repeater {
                        id: repeater
                        model: root.model
                        delegate: MouseArea {
                            Layout.fillWidth: true
                            implicitHeight: 40
                            hoverEnabled: true
                            id: itemArea

                            Rectangle {
                                anchors.fill: parent
                                radius: Appearance.rounding.small
                                color: itemArea.containsMouse ? Appearance.colors.colLayer2Hover : "transparent"
                            }

                            Text {
                                anchors.centerIn: parent
                                text: modelData.text || ""
                                font.family: Appearance.font.family.main
                                color: Appearance.m3colors.m3onSurface
                            }

                            onClicked: {
                                root.popupVisible = false
                                root.onItemSelected(modelData)
                            }
                        }
                    }
                }
            }
        }
    }
}