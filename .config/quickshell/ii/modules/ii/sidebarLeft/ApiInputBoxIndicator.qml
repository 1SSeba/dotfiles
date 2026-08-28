import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

Item { // Model indicator
    id: root
    property string icon: "api"
    property string text: ""
    property string tooltipText: ""
    /** Si se setea, el indicador se vuelve un botón (cursor de mano y fondo al pasar por encima). */
    property var clickAction: null
    /** El panel que abre este indicador está desplegado. */
    property bool active: false
    readonly property bool clickable: root.clickAction !== null

    implicitHeight: rowLayout.implicitHeight + 4 * 2
    implicitWidth: rowLayout.implicitWidth + 4 * 2

    // El chip cambia de ancho al cambiar la etiqueta (Default → low → xhigh);
    // sin esto el salto es brusco y se nota el reacomodo de toda la fila.
    Behavior on implicitWidth {
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
    }

    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.small
        visible: root.clickable
        color: root.active ? Appearance.colors.colSecondaryContainer
            : (interactionLoader.item?.containsMouse ? Appearance.colors.colLayer2Hover : "transparent")

        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }
    }

    RowLayout {
        id: rowLayout
        anchors.centerIn: parent

        MaterialSymbol {
            text: root.icon
            iconSize: Appearance.font.pixelSize.normal
        }
        StyledText {
            id: providerName
            // Sin visible, un texto vacío igual deja el spacing del RowLayout y el
            // indicador ocupa de más. Con texto vacío queda sólo el icono.
            visible: root.text.length > 0
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.m3colors.m3onSurface
            elide: Text.ElideRight
            text: root.text
            // Sin animateChange: anima la x del texto al cambiar, y como el fondo
            // resaltado no se mueve con él, la etiqueta queda corrida fuera del chip.
            animateChange: false
        }

        MaterialSymbol {
            id: chevron
            visible: root.clickable
            text: root.active ? "expand_less" : "expand_more"
            iconSize: Appearance.font.pixelSize.normal
            color: Appearance.m3colors.m3onSurface
        }
    }

    Loader {
        id: interactionLoader
        active: root.tooltipText?.length > 0 || root.clickable
        anchors.fill: parent
        sourceComponent: MouseArea {
            id: mouseArea
            hoverEnabled: true
            cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
            acceptedButtons: root.clickable ? Qt.LeftButton : Qt.NoButton
            onClicked: if (root.clickAction) root.clickAction()

            StyledToolTip {
                id: toolTip
                extraVisibleCondition: false
                alternativeVisibleCondition: mouseArea.containsMouse && root.tooltipText?.length > 0
                text: root.tooltipText
            }
        }
    }
}
