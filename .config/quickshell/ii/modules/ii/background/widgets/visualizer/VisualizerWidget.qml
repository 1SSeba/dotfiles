import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root

    configEntryName: "visualizer"

    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property bool isPlaying: activePlayer?.isPlaying ?? false
    readonly property list<real> points: GlobalStates.visualizerPoints

    property real barWidth: 4
    property real barSpacing: 8
    // Lo cambia la pastilla del borde de arriba (ver más abajo)
    property real maxBarHeight: root.configEntry.height ?? 220
    readonly property real minBarHeight: 60
    property real maxVisualizerValue: 1000
    property real smoothingDuration: 150

    readonly property int barCount: Math.max(1, Math.floor(screenWidth / (barWidth + barSpacing)))

    // Se recalcula por cada cuadro de cava, así que no puede depender de nada
    // caro. `zeroPoints` se cachea aparte para no reservar un array nuevo en
    // cada cuadro mudo.
    readonly property var zeroPoints: new Array(root.barCount).fill(0)

    readonly property var smoothedPoints: {
        let raw = points
        if (!raw || raw.length === 0) return root.zeroPoints
        let count = barCount
        let mapped = new Array(count)
        let rawLenM1 = raw.length - 1

        for (let i = 0; i < count; i++) {
            let progress = i / (count - 1 || 1)
            let relPos = progress * rawLenM1
            let low = Math.floor(relPos)
            let high = Math.ceil(relPos)
            let mix = relPos - low
            mapped[i] = (raw[low] * (1 - mix)) + (raw[high] * (high < raw.length ? mix : 0))
        }

        let smoothed = new Array(count)
        let sW = 0.2
        for (let j = 0; j < count; j++) {
            let p = mapped[Math.max(0, j - 1)]
            let n = mapped[Math.min(count - 1, j + 1)]
            smoothed[j] = (p * sW) + (mapped[j] * (1.0 - 2 * sW)) + (n * sW)
        }
        return smoothed
    }

    // Los dos extremos del degradado, leídos UNA vez por cambio de tema en vez
    // de seis lecturas de propiedad por barra y por cuadro.
    readonly property color colLow: Appearance.colors.colPrimaryContainer
    readonly property color colHigh: Appearance.colors.colPrimary

    property real activityOpacity: 0
    Behavior on activityOpacity {
        NumberAnimation { duration: 500; easing.type: Easing.OutCubic }
    }

    Timer {
        id: silenceTimer
        interval: 1000
        onTriggered: root.activityOpacity = 0
    }

    onPointsChanged: {
        // `some()` arma un closure por cuadro; un for corta en la primera barra
        // con señal, que en música normal es la primera o la segunda.
        for (let i = 0; i < points.length; i++) {
            if (points[i] > 0) {
                root.activityOpacity = 1.0
                silenceTimer.restart()
                return
            }
        }
    }

    implicitWidth: screenWidth
    implicitHeight: maxBarHeight + 20

    x: 0
    y: screenHeight - implicitHeight
    draggable: false
    hoverEnabled: true

    // ------------------------------------------------------------------ //
    // Alto
    // ------------------------------------------------------------------ //

    // El visualizador ocupa siempre todo el ancho y está pegado abajo, así que
    // escalarlo como a los demás no tiene sentido: lo flexible es el alto de las
    // barras. Una pastilla en el borde de arriba lo sube o lo baja, con la
    // grilla a la vista y el borde enganchado a ella, como al estirar los demás.
    Item {
        id: heightHandle
        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top }
        width: 72; height: 18
        z: 10
        readonly property bool shown: !Config.options.background.widgetsLocked
            && (root.containsMouse || heightArea.containsMouse || heightArea.pressed)
        opacity: shown ? 1 : 0
        visible: opacity > 0
        Behavior on opacity {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }

        Rectangle {
            anchors.centerIn: parent
            width: heightArea.pressed ? 56 : 44
            height: 6
            radius: 3
            color: Appearance.colors.colOnPrimaryContainer
            opacity: heightArea.containsMouse || heightArea.pressed ? 0.9 : 0.6
            Behavior on width {
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
            }
        }

        MouseArea {
            id: heightArea
            anchors.fill: parent
            anchors.margins: -6
            hoverEnabled: true
            preventStealing: true
            cursorShape: Qt.SizeVerCursor

            property real startGlobalY: 0
            property real startHeight: 0

            function canvas() { return root.findCanvas(root.parent) }

            onPressed: mouse => {
                startGlobalY = mapToItem(null, mouse.x, mouse.y).y
                startHeight = root.maxBarHeight
                canvas()?.setDragging(true)
            }
            onPositionChanged: mouse => {
                if (!pressed) return
                const dy = mapToItem(null, mouse.x, mouse.y).y - startGlobalY
                let barHeight = Math.max(root.minBarHeight, Math.min(root.screenHeight * 0.8, startHeight - dy))
                // El borde de arriba sobre una línea de la grilla
                const c = canvas()
                if (c && root.snapEnabled) {
                    const bottom = root.mapToItem(c, 0, root.height).y
                    const top = Math.round((bottom - barHeight - 20) / c.gridSize) * c.gridSize
                    barHeight = Math.max(root.minBarHeight, bottom - top - 20)
                }
                root.maxBarHeight = barHeight
            }
            onReleased: {
                const c = canvas()
                c?.setDragging(false)
                root.configEntry.height = root.maxBarHeight
                if (c && Config.options.background.showSnapLines)
                    c.flashLines([], [root.mapToItem(c, 0, 0).y])
            }
            onCanceled: canvas()?.setDragging(false)
        }
    }

    Row {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: root.barSpacing
        opacity: root.activityOpacity

        Behavior on opacity {
            NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
        }

        Repeater {
            model: root.barCount
            Rectangle {
                required property int index
                width: root.barWidth
                property real pointValue: {
                    const v = root.smoothedPoints[index] ?? 0
                    return Math.max(root.barWidth, (v / root.maxVisualizerValue) * root.maxBarHeight)
                }
                height: pointValue
                topLeftRadius: root.barWidth / 2
                topRightRadius: root.barWidth / 2
                anchors.bottom: parent.bottom

                property real intensity: pointValue / root.maxBarHeight
                color: Qt.rgba(root.colHigh.r * intensity + root.colLow.r * (1 - intensity), root.colHigh.g * intensity + root.colLow.g * (1 - intensity), root.colHigh.b * intensity + root.colLow.b * (1 - intensity), 1)

                // SIN `Behavior on height`: cava ya manda cuadros suavizados
                // (noise_reduction) cada ~33 ms, así que la animación de 150 ms
                // no llegaba a terminar nunca — se reiniciaba en cada cuadro,
                // una por barra (≈160 en 1080p), y eso solo era la mayor parte
                // del CPU que gastaba la shell quieta con música sonando.
            }
        }
    }
}

