import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import Quickshell

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

    // El eje de scroll queda bien más ancho que el ícono: con solo icono+10px
    // (~26-30px), cualquier microtemblor de la mano al girar la rueda saca el
    // cursor del widget, y ahí Qt deja de mandarle más wheel events a este
    // MouseArea — el volumen/brillo dejaba de cambiar aunque se siguiera
    // scrolleando. No hay forma confiable de "seguir recibiendo" eventos de
    // rueda fuera de los bounds del item, así que el área tiene que ser
    // generosa desde el vamos.
    readonly property real scrollAxisPadding: 30

    implicitWidth: root.vertical ? Appearance.sizes.verticalBarWidth : content.implicitWidth + root.scrollAxisPadding
    implicitHeight: root.vertical ? content.implicitHeight + root.scrollAxisPadding : Appearance.sizes.barHeight

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

    // Las flechitas van superpuestas sobre el ícono central en vez de apiladas en
    // un Column: el alto real de un glifo de texto (ascent/descent de la fuente)
    // no es predecible, así que apilar 3 con spacing negativo "ajustado a ojo"
    // quedaba recortado por el clip del contenedor apenas cambiaba la métrica de
    // fuente/escala. Acá `content` solo mide el ícono central, y las flechas se
    // anclan relativas a su centro, así que nunca empujan el alto real por fuera
    // de los 40px de la barra.
    Item {
        id: content
        anchors.centerIn: parent
        implicitWidth: mainIcon.implicitWidth
        implicitHeight: mainIcon.implicitHeight

        Chevron {
            text: "keyboard_arrow_up"
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: mainIcon.verticalCenter
            anchors.bottomMargin: 7
        }

        MaterialSymbol {
            id: mainIcon
            anchors.centerIn: parent
            text: root.icon
            iconSize: 16
            color: root.accentColor
        }

        Chevron {
            text: "keyboard_arrow_down"
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: mainIcon.verticalCenter
            anchors.topMargin: 7
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
        // Sin esto el tooltip usa el default (Edges.Top) y, con la barra
        // arriba de la pantalla, el popup intenta abrirse hacia arriba y
        // termina reposicionado encima del cursor: tapa el mouse, el hover
        // se pierde, el tooltip se cierra, el cursor vuelve a quedar sobre
        // el widget, hover vuelve a activarse... y así en loop (parpadeo),
        // comiéndose además los wheel events que llegan durante el loop.
        // Mismo fix que ya tiene SysTrayItem.qml.
        anchorEdges: (!Config.options.bar.bottom && !Config.options.bar.vertical) ? Edges.Bottom : Edges.Top
    }
}
