import QtQuick

/**
 * Estirar un widget de tamaños fijos (1x1, 1x2, 2x2...) como se estira el de
 * notas: la tarjeta sigue al mouse de forma continua, enganchada a la grilla,
 * el contenido pasa al modo más cercano al tamaño que va teniendo, y al soltar
 * la tarjeta se acomoda al tamaño exacto de ese modo.
 *
 * Antes estos widgets no se movían mientras arrastrabas y saltaban de golpe de
 * un modo al otro al pasar cierto umbral.
 *
 * Uso, desde el widget:
 *
 *     ElasticResize {
 *         id: elastic
 *         widget: root
 *         mode: root.sizeMode
 *         modes: [{ "mode": "1x1", "width": 132, "height": 120 }, ...]
 *     }
 *     property real widgetWidth: elastic.resizing ? elastic.dragWidth : <ancho del modo>
 *     Behavior on widgetWidth { enabled: !elastic.resizing; ... }
 *
 *     ResizeHandler {
 *         onResizedXY: (dx, dy, startWidth) => root.sizeMode = elastic.update(dx, dy, startWidth)
 *         onResizeFinished: { elastic.finish(); root.configEntry.sizeMode = root.sizeMode }
 *     }
 */
QtObject {
    id: elastic

    /** El AbstractBackgroundWidget: pone la grilla y sabe dónde está en el escritorio. */
    required property Item widget
    /** Los tamaños posibles: [{ mode, width, height }, ...] */
    property var modes: []
    /** El modo actual (el widget lo liga a su sizeMode). */
    property string mode: ""

    property bool resizing: false
    property real dragWidth: 0
    property real dragHeight: 0
    property real startHeight: -1

    // Cuánto se deja estirar más allá del modo más chico y del más grande: un
    // poco de elástico en los extremos se siente mejor que un tope seco.
    property real slack: 36

    readonly property var current: elastic.modes.find(m => m.mode === elastic.mode) ?? elastic.modes[0]
    readonly property real minWidth: Math.min(...elastic.modes.map(m => m.width)) - elastic.slack
    readonly property real minHeight: Math.min(...elastic.modes.map(m => m.height)) - elastic.slack
    readonly property real maxWidth: Math.max(...elastic.modes.map(m => m.width)) + elastic.slack
    readonly property real maxHeight: Math.max(...elastic.modes.map(m => m.height)) + elastic.slack

    /** El modo cuyo tamaño queda más cerca de w×h. */
    function nearest(w, h) {
        let best = elastic.modes[0]
        let bestDistance = Infinity
        elastic.modes.forEach(m => {
            const d = (m.width - w) * (m.width - w) + (m.height - h) * (m.height - h)
            if (d < bestDistance) {
                best = m
                bestDistance = d
            }
        })
        return best
    }

    /** Llamar en cada movimiento de la manija; devuelve el modo a usar. */
    function update(dx, dy, startWidth) {
        if (!elastic.resizing) {
            // ResizeHandler sólo informa el ancho inicial; el alto sale del modo.
            elastic.startHeight = elastic.current.height
            elastic.resizing = true
        }
        const size = elastic.widget.snapSizeToGrid(startWidth + dx, elastic.startHeight + dy,
            elastic.minWidth, elastic.minHeight, elastic.maxWidth, elastic.maxHeight)
        elastic.dragWidth = size.width
        elastic.dragHeight = size.height
        return elastic.nearest(size.width, size.height).mode
    }

    /** Al soltar: la tarjeta vuelve al tamaño exacto del modo elegido (animado por el widget). */
    function finish() {
        elastic.resizing = false
        elastic.startHeight = -1
        const size = elastic.current
        if (size) elastic.widget.flashEdges(size.width, size.height)
    }
}
