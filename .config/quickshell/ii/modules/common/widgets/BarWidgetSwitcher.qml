import qs.modules.common
import QtQuick
import QtQuick.Layouts

/**
 * Elige la variante de un widget de barra según cómo esté configurada: en fila o
 * en columna (barra vertical), y estilo normal o Material (cornerStyle 3).
 *
 * Cada widget declara sus cuatro variantes y este se encarga de cargar la que
 * corresponde, así el widget no repite la lógica de orientación.
 * Portado del fork end4-pC.
 */
Item {
    id: root
    property bool vertical: false
    property bool isMaterial: Config.options.bar.cornerStyle === 3
    property real horizontalExtraPadding: 12

    property Component colDefault
    property Component colMaterial
    property Component rowDefault
    property Component rowMaterial

    implicitWidth: root.vertical
        ? Appearance.sizes.verticalBarWidth
        : (rowLoader.item?.implicitWidth ?? 0) + (root.isMaterial ? 0 : root.horizontalExtraPadding)
    implicitHeight: root.vertical
        ? (colLoader.item?.implicitHeight ?? 0)
        : Appearance.sizes.barHeight

    Loader {
        id: colLoader
        active: root.vertical
        visible: active
        anchors.centerIn: parent
        sourceComponent: root.isMaterial ? root.colMaterial : root.colDefault
    }

    Loader {
        id: rowLoader
        active: !root.vertical
        visible: active
        anchors.centerIn: parent
        sourceComponent: root.isMaterial ? root.rowMaterial : root.rowDefault
    }
}