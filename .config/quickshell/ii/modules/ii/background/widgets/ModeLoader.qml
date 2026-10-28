import QtQuick
import qs.modules.common

/**
 * Loader para el contenido de un widget con modos de tamaño (1x1, 2x2...).
 *
 * El contenido se arma siempre en el tamaño de su modo (naturalWidth ×
 * naturalHeight) y se escala para entrar en la tarjeta, centrado. Mientras se
 * estira con ElasticResize la tarjeta puede quedar más chica que el modo (en la
 * grilla del calendario, por ejemplo, las celdas son de tamaño fijo): sin esto
 * el contenido se salía por los costados. Así se achica en proporción y al
 * soltar, cuando la tarjeta vuelve al tamaño del modo, queda en escala 1.
 *
 * Además, el contenido de un modo nuevo entra con un fundido y una escala leve
 * en vez de aparecer de golpe.
 */
Loader {
    id: loader

    /** Tamaño del modo actual; por defecto, el de la tarjeta (sin escalar). */
    property real naturalWidth: parent ? parent.width : 0
    property real naturalHeight: parent ? parent.height : 0

    // Sólo achica: agrandar por encima de 1 haría el texto borroso, y una
    // tarjeta un poco más grande que el modo con el contenido centrado se ve bien.
    readonly property real fitScale: (loader.parent && loader.naturalWidth > 0 && loader.naturalHeight > 0)
        ? Math.min(1, loader.parent.width / loader.naturalWidth, loader.parent.height / loader.naturalHeight)
        : 1

    anchors.centerIn: parent
    width: loader.naturalWidth
    height: loader.naturalHeight
    scale: loader.fitScale

    onLoaded: entrance.restart()

    ParallelAnimation {
        id: entrance
        NumberAnimation {
            target: loader.item
            property: "opacity"
            from: 0; to: 1
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
        }
        NumberAnimation {
            target: loader.item
            property: "scale"
            from: 0.96; to: 1
            duration: Appearance.animation.elementMove.duration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
        }
    }
}
