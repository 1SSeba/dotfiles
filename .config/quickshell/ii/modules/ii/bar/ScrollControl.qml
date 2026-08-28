import qs.modules.common
import qs.modules.common.widgets
import QtQuick

/**
 * Base de los widgets de barra que se controlan con la rueda del mouse.
 *
 * La barra escrita a mano ya tenía scroll para volumen y brillo, pero como zonas
 * invisibles que ocupan media barra cada una (BarContent.qml) y que se ocultan con
 * `visible: !Config.options.bar.layouts.enable`. Al pasar al layout personalizado
 * esas zonas desaparecen y no había forma de recuperarlas, porque el layout arma la
 * barra con widgets concretos. Esto empaqueta el mismo comportamiento en un widget
 * colocable.
 *
 * El indicador de scroll (flechitas arriba/abajo) es el mismo de `ScrollHint`, que
 * es lo que muestra la barra por defecto. No se puede usar ScrollHint tal cual acá
 * por dos razones: esconde también el icono cuando no hay hover, y como widget
 * suelto eso dejaría un hueco de ancho cero imposible de encontrar en la barra;
 * y además es un Revealer que anima su ancho, así que al pasar el mouse empujaría
 * al resto de la barra. Acá el icono queda siempre y las flechas aparecen por
 * opacidad, con lo cual el ancho del widget no cambia nunca.
 */
FocusedScrollMouseArea {
    id: root

    property string icon: ""
    /** 0..1. No se muestra: sirve para elegir el icono según el nivel. */
    property real value: 0
    property string tooltipText: ""
    property color accentColor: Appearance.colors.colOnLayer1

    signal increase
    signal decrease
    /** Click izquierdo. Opcional: si nadie lo conecta, no hace nada. */
    signal activated

    readonly property bool vertical: Config.options.bar.vertical

    implicitWidth: root.vertical ? Appearance.sizes.verticalBarWidth : content.implicitWidth + 10
    implicitHeight: root.vertical ? content.implicitHeight + 6 : Appearance.sizes.barHeight

    onScrollUp: root.increase()
    onScrollDown: root.decrease()
    onPressed: event => {
        if (event.button === Qt.LeftButton)
            root.activated();
    }

    component Chevron: MaterialSymbol {
        anchors.horizontalCenter: parent.horizontalCenter
        iconSize: 14
        color: Appearance.colors.colSubtext
        opacity: root.containsMouse ? 1 : 0

        Behavior on opacity {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }
    }

    // Mismo apilado que ScrollHint: el spacing negativo es a propósito, las cajas
    // de los glifos traen aire de sobra y sin eso no entra en los 40px de la barra.
    Column {
        id: content
        anchors.centerIn: parent
        spacing: -7

        Chevron {
            text: "keyboard_arrow_up"
        }

        MaterialSymbol {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.icon
            iconSize: 16
            color: root.accentColor
        }

        Chevron {
            text: "keyboard_arrow_down"
        }
    }

    // Igual que ScrollHint: el tooltip espera medio segundo para no aparecer
    // cada vez que el mouse cruza la barra de paso.
    property bool hoverTimedOut: false
    onContainsMouseChanged: root.hoverTimedOut = false

    Timer {
        running: root.containsMouse
        interval: 500
        onTriggered: root.hoverTimedOut = true
    }

    PopupToolTip {
        text: root.tooltipText
        extraVisibleCondition: root.tooltipText.length > 0 && root.hoverTimedOut
    }
}
