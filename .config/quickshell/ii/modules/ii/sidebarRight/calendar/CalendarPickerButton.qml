import qs.modules.common
import qs.modules.common.widgets
import QtQuick

/**
 * Un casillero de los selectores de mes y de año.
 *  - `current`: es el mes/año de hoy → relleno con el color primario, como el
 *    día de hoy en la grilla.
 *  - `selected`: es el que se está mirando → fondo tenue, para saber de dónde
 *    venías.
 */
RippleButton {
    id: button
    property string label: ""
    property bool current: false
    property bool selected: false

    buttonRadius: Appearance.rounding.small
    toggled: button.current
    colBackground: button.selected ? Appearance.colors.colLayer2 : "transparent"
    colBackgroundHover: Appearance.colors.colLayer2Hover
    colRipple: Appearance.colors.colLayer2Active

    contentItem: StyledText {
        text: button.label
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        font.pixelSize: Appearance.font.pixelSize.normal
        font.weight: (button.current || button.selected) ? Font.DemiBold : Font.Normal
        color: button.current ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer1
    }
}
