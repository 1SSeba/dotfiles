import qs.modules.common
import qs.modules.common.widgets
import QtQuick

/**
 * Botón redondo de transporte (anterior / play / siguiente).
 *
 * Tres tamaños: `big` es el del medio, que se destaca; `small` es para los
 * secundarios (aleatorio, repetir, volumen), que van sin fondo para no competir
 * con el play. `symbolActive` los prende en color de acento cuando están puestos.
 */
RippleButton {
    id: root

    // `icon` no se puede: Button ya lo define como FINAL
    property string symbol: ""
    property bool big: false
    property bool small: false
    // No se llama `active` ni `toggled` porque los dos ya existen más arriba
    property bool symbolActive: false

    implicitWidth: root.big ? 52 : (root.small ? 32 : 40)
    implicitHeight: root.big ? 52 : (root.small ? 32 : 40)
    buttonRadius: Appearance.rounding.full

    colBackground: root.big ? Appearance.colors.colPrimary
        : (root.small ? "transparent" : Appearance.colors.colLayer2)
    colBackgroundHover: root.big ? Appearance.colors.colPrimaryHover : Appearance.colors.colLayer2Hover

    contentItem: MaterialSymbol {
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: root.symbol
        iconSize: root.big ? 28 : (root.small ? 19 : 22)
        fill: (root.big || !root.small || root.symbolActive) ? 1 : 0
        color: root.big ? Appearance.colors.colOnPrimary
            : (root.symbolActive ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer2)
    }
}
