pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Wayland
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

/**
 * Lienzo de composición de una escena: cada fuente es una caja que se arrastra
 * y se redimensiona, y se guarda como fracción 0-1 del lienzo (así la escena
 * vale igual en 1080p que en 1440p).
 *
 * Al mover una fuente se imanta a los bordes y al centro del lienzo y a los
 * bordes de las otras fuentes, con líneas guía, y muestra a cuántos píxeles
 * reales de salida está de los bordes más cercanos.
 *
 * Lo usan el editor flotante de Super+G y la ventana Studio.
 */
Item {
    id: root

    property bool editable: true
    /** Preview en vivo de pantallas/ventanas. Apagalo si molesta el consumo. */
    property bool livePreviews: true
    /** Distancia (en px del lienzo mostrado) a la que se imanta una fuente. */
    property real snapThreshold: 8

    readonly property real canvasAspect: Scenes.canvasWidth / Math.max(1, Scenes.canvasHeight)
    /** Factor lienzo-mostrado → píxeles reales de salida. */
    readonly property real pixelScale: canvas.width > 0 ? Scenes.canvasWidth / canvas.width : 1

    // Se dimensiona solo dentro de un Layout: sin esto el Item queda con
    // implicitHeight 0 y el lienzo desaparece.
    implicitWidth: 480
    implicitHeight: root.width > 0 ? Math.round(root.width / Math.max(0.1, root.canvasAspect)) : 270

    Rectangle {
        id: canvas
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height * root.canvasAspect)
        height: width / root.canvasAspect
        color: Appearance.colors.colLayer2
        border.color: Appearance.colors.colOutlineVariant
        border.width: 1
        radius: Appearance.rounding.small
        clip: true

        /** Índice de la fuente que se está arrastrando, -1 = ninguna. */
        property int draggingIndex: -1
        property rect draggingRect: Qt.rect(0, 0, 0, 0)

        /**
         * Posiciones a las que se imanta el borde inicial de una caja: bordes y
         * centro del lienzo, y bordes/centro de las demás fuentes.
         */
        function snapCandidates(size, axis, excludeIndex) {
            const total = axis === "x" ? canvas.width : canvas.height;
            const out = [0, (total - size) / 2, total - size];
            const sources = Scenes.activeScene?.sources ?? [];
            for (let i = 0; i < sources.length; i++) {
                if (i === excludeIndex) continue;
                const s = sources[i];
                if ((s.visible ?? true) === false) continue;
                const pos = (axis === "x" ? (s.x ?? 0) : (s.y ?? 0)) * total;
                const len = (axis === "x" ? (s.width ?? 0) : (s.height ?? 0)) * total;
                out.push(pos, pos + len - size, pos + (len - size) / 2);
            }
            return out;
        }

        function snap(raw, size, axis, excludeIndex) {
            const total = axis === "x" ? canvas.width : canvas.height;
            let best = raw;
            let bestDist = root.snapThreshold;
            for (const c of canvas.snapCandidates(size, axis, excludeIndex)) {
                const d = Math.abs(raw - c);
                if (d < bestDist) {
                    bestDist = d;
                    best = c;
                }
            }
            return Math.max(0, Math.min(total - size, best));
        }

        /**
         * Posiciones a las que se imanta un BORDE suelto (al redimensionar):
         * bordes y centro del lienzo, y bordes/centro de las otras fuentes.
         */
        function edgeCandidates(axis, excludeIndex) {
            const total = axis === "x" ? canvas.width : canvas.height;
            const out = [0, total / 2, total];
            const sources = Scenes.activeScene?.sources ?? [];
            for (let i = 0; i < sources.length; i++) {
                if (i === excludeIndex) continue;
                const s = sources[i];
                if ((s.visible ?? true) === false) continue;
                const pos = (axis === "x" ? (s.x ?? 0) : (s.y ?? 0)) * total;
                const len = (axis === "x" ? (s.width ?? 0) : (s.height ?? 0)) * total;
                out.push(pos, pos + len / 2, pos + len);
            }
            return out;
        }

        function snapEdge(raw, axis, excludeIndex) {
            const total = axis === "x" ? canvas.width : canvas.height;
            let best = raw;
            let bestDist = root.snapThreshold;
            for (const c of canvas.edgeCandidates(axis, excludeIndex)) {
                const d = Math.abs(raw - c);
                if (d < bestDist) {
                    bestDist = d;
                    best = c;
                }
            }
            return Math.max(0, Math.min(total, best));
        }

        /** Líneas guía a dibujar: las que coinciden con la caja que se arrastra. */
        function guides(axis) {
            if (canvas.draggingIndex < 0) return [];
            const r = canvas.draggingRect;
            const pos = axis === "x" ? r.x : r.y;
            const size = axis === "x" ? r.width : r.height;
            const edges = [pos, pos + size / 2, pos + size];
            const out = [];
            for (const c of canvas.snapCandidates(size, axis, canvas.draggingIndex)) {
                for (const e of [c, c + size / 2, c + size]) {
                    if (edges.some(edge => Math.abs(edge - e) < 0.75) && !out.some(o => Math.abs(o - e) < 0.75)) {
                        out.push(e);
                    }
                }
            }
            return out;
        }

        TapHandler {
            enabled: root.editable
            onTapped: Scenes.selectedSourceIndex = -1
        }

        StyledText {
            anchors.centerIn: parent
            visible: (Scenes.activeScene?.sources?.length ?? 0) === 0
            text: Translation.tr("Escena vacía — agregá una fuente")
            color: Appearance.colors.colSubtext
            opacity: 0.7
        }

        Repeater {
            // El modelo es la cantidad y no el array: reasignar el array entero
            // en cada cambio (que es como se persiste) recrearía los delegates
            // en medio de un arrastre.
            model: Scenes.activeScene?.sources?.length ?? 0

            delegate: SourceBox {
                required property int index
                sourceIndex: index
                canvas: canvas
            }
        }

        // ── Guías de alineación ─────────────────────────────────────────
        Repeater {
            model: canvas.guides("x")
            delegate: Rectangle {
                required property real modelData
                x: Math.round(modelData)
                y: 0
                width: 1
                height: canvas.height
                color: Appearance.colors.colPrimary
                opacity: 0.9
                z: 999
            }
        }
        Repeater {
            model: canvas.guides("y")
            delegate: Rectangle {
                required property real modelData
                x: 0
                y: Math.round(modelData)
                width: canvas.width
                height: 1
                color: Appearance.colors.colPrimary
                opacity: 0.9
                z: 999
            }
        }

        // ── Distancia a los bordes mientras se arrastra ──────────────────
        Rectangle {
            id: distanceBadge
            visible: canvas.draggingIndex >= 0
            z: 1000
            radius: Appearance.rounding.unsharpenmore
            color: Appearance.colors.colPrimary
            implicitWidth: distanceText.implicitWidth + 12
            implicitHeight: distanceText.implicitHeight + 6

            readonly property rect r: canvas.draggingRect
            // Distancia en píxeles REALES de salida al borde más cercano de cada eje.
            readonly property int leftPx: Math.round(distanceBadge.r.x * root.pixelScale)
            readonly property int rightPx: Math.round((canvas.width - distanceBadge.r.x - distanceBadge.r.width) * root.pixelScale)
            readonly property int topPx: Math.round(distanceBadge.r.y * root.pixelScale)
            readonly property int bottomPx: Math.round((canvas.height - distanceBadge.r.y - distanceBadge.r.height) * root.pixelScale)

            x: Math.max(2, Math.min(canvas.width - width - 2, distanceBadge.r.x + distanceBadge.r.width / 2 - width / 2))
            y: Math.max(2, distanceBadge.r.y - height - 4)

            StyledText {
                id: distanceText
                anchors.centerIn: parent
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.features: { "tnum": 1 }
                color: Appearance.colors.colOnPrimary
                text: {
                    const dx = Math.min(distanceBadge.leftPx, distanceBadge.rightPx);
                    const dy = Math.min(distanceBadge.topPx, distanceBadge.bottomPx);
                    const hArrow = distanceBadge.leftPx <= distanceBadge.rightPx ? "←" : "→";
                    const vArrow = distanceBadge.topPx <= distanceBadge.bottomPx ? "↑" : "↓";
                    return `${hArrow} ${dx} px   ${vArrow} ${dy} px`;
                }
            }
        }
    }

    component SourceBox: Rectangle {
        id: box
        required property int sourceIndex
        required property Item canvas

        readonly property var source: Scenes.activeScene?.sources?.[box.sourceIndex] ?? null
        readonly property bool selected: Scenes.selectedSourceIndex === box.sourceIndex
        readonly property bool shown: box.source?.visible ?? true
        readonly property var captureable: Scenes.captureSourceFor(box.source)

        z: box.source?.z ?? 0
        visible: box.source !== null
        opacity: (box.shown ? (box.source?.opacity ?? 1) : 0.25)

        /**
         * Que el Loader esté activo no garantiza imagen: una ventana en otro
         * workspace, o minimizada, entrega captura vacía. Sin esto la caja
         * quedaba transparente y sin placeholder, o sea invisible.
         */
        readonly property bool previewShowing: livePreview.item?.hasContent ?? false

        color: (box.source?.type === "image" || box.previewShowing)
            ? "transparent"
            : ColorUtils.transparentize(Appearance.colors.colPrimary, 0.72)
        border.color: box.selected ? Appearance.colors.colPrimary : Appearance.colors.colOutlineVariant
        border.width: box.selected ? 2 : 1
        radius: Appearance.rounding.unsharpenmore

        x: Math.round((box.source?.x ?? 0) * box.canvas.width)
        y: Math.round((box.source?.y ?? 0) * box.canvas.height)
        width: Math.round((box.source?.width ?? 0.3) * box.canvas.width)
        height: Math.round((box.source?.height ?? 0.3) * box.canvas.height)

        StyledImage {
            anchors.fill: parent
            anchors.margins: 1
            visible: box.source?.type === "image" && (box.source?.path ?? "").length > 0
            source: (box.source?.path ?? "").length > 0 ? `file://${box.source.path}` : ""
            fillMode: Image.PreserveAspectFit
        }

        // Preview real de pantallas y ventanas, con el mismo mecanismo que las
        // miniaturas del overview. La cámara no tiene preview y queda como
        // placeholder con su ícono.
        Loader {
            id: livePreview
            anchors.fill: parent
            anchors.margins: 1
            active: root.livePreviews && box.captureable !== null
            sourceComponent: ScreencopyView {
                captureSource: box.captureable
                live: true
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 2
            visible: box.source?.type !== "image" && !box.previewShowing

            MaterialSymbol {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Scenes.sourceIcon(box.source)
                iconSize: Appearance.font.pixelSize.huge
                color: Appearance.colors.colOnLayer2
            }
            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.max(0, box.width - 12)
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideMiddle
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnLayer2
                text: Scenes.sourceLabel(box.source)
            }
        }

        // Etiqueta flotante con el nombre, para saber qué es cuando el preview
        // en vivo ocupa toda la caja.
        Rectangle {
            visible: box.previewShowing && box.selected
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.margins: 2
            radius: Appearance.rounding.unsharpenmore
            color: ColorUtils.transparentize(Appearance.colors.colLayer1, 0.15)
            implicitWidth: previewLabel.implicitWidth + 8
            implicitHeight: previewLabel.implicitHeight + 4

            StyledText {
                id: previewLabel
                anchors.centerIn: parent
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnLayer1
                text: Scenes.sourceLabel(box.source)
            }
        }

        HoverHandler {
            enabled: root.editable && box.shown
            cursorShape: Qt.SizeAllCursor
        }

        TapHandler {
            enabled: root.editable
            onTapped: Scenes.selectedSourceIndex = box.sourceIndex
        }

        // ── Mover ───────────────────────────────────────────────────────
        DragHandler {
            id: moveDrag
            enabled: root.editable && box.shown
            target: null
            property real startX: 0
            property real startY: 0

            readonly property real rawX: moveDrag.startX + moveDrag.translation.x
            readonly property real rawY: moveDrag.startY + moveDrag.translation.y
            readonly property real snappedX: box.canvas.snap(moveDrag.rawX, box.width, "x", box.sourceIndex)
            readonly property real snappedY: box.canvas.snap(moveDrag.rawY, box.height, "y", box.sourceIndex)

            onActiveChanged: {
                if (active) {
                    Scenes.selectedSourceIndex = box.sourceIndex;
                    moveDrag.startX = box.x;
                    moveDrag.startY = box.y;
                    box.canvas.draggingIndex = box.sourceIndex;
                } else {
                    box.canvas.draggingIndex = -1;
                    Scenes.updateSource(box.sourceIndex, {
                        x: moveDrag.snappedX / box.canvas.width,
                        y: moveDrag.snappedY / box.canvas.height
                    });
                }
            }
        }
        Binding { target: box; property: "x"; when: moveDrag.active; value: moveDrag.snappedX }
        Binding { target: box; property: "y"; when: moveDrag.active; value: moveDrag.snappedY }

        // Mientras se arrastra o redimensiona, el lienzo necesita la geometría
        // en vivo para dibujar las guías y la distancia a los bordes.
        Binding {
            target: box.canvas
            property: "draggingRect"
            when: moveDrag.active || box.resizing
            value: Qt.rect(box.x, box.y, box.width, box.height)
        }

        // ── Redimensionar ───────────────────────────────────────────────
        // Ocho tiradores (4 esquinas + 4 lados), como cualquier editor: agarrar
        // solo por una esquina obligaba a adivinar dónde estaba el punto.
        property bool resizing: false
        property rect resizeRect: Qt.rect(0, 0, 0, 0)

        Repeater {
            model: [
                { h: -1, v: -1 }, { h: 0, v: -1 }, { h: 1, v: -1 },
                { h: -1, v: 0 },                   { h: 1, v: 0 },
                { h: -1, v: 1 },  { h: 0, v: 1 },  { h: 1, v: 1 }
            ]
            delegate: ResizeGrip {
                required property var modelData
                gripH: modelData.h
                gripV: modelData.v
                box: box
            }
        }

        Binding { target: box; property: "x"; when: box.resizing; value: box.resizeRect.x }
        Binding { target: box; property: "y"; when: box.resizing; value: box.resizeRect.y }
        Binding { target: box; property: "width"; when: box.resizing; value: box.resizeRect.width }
        Binding { target: box; property: "height"; when: box.resizing; value: box.resizeRect.height }
    }

    component ResizeGrip: Rectangle {
        id: grip
        /** -1 = borde izquierdo/superior, 0 = centro, 1 = derecho/inferior. */
        required property int gripH
        required property int gripV
        required property Rectangle box

        readonly property bool corner: grip.gripH !== 0 && grip.gripV !== 0
        readonly property real grabSize: 14

        visible: root.editable && grip.box.selected
        color: grip.corner ? Appearance.colors.colPrimary : ColorUtils.transparentize(Appearance.colors.colPrimary, 0.35)
        radius: Appearance.rounding.unsharpenmore
        z: 10

        // Los tiradores de los lados son barras finas; los de esquina, cuadrados.
        width: grip.gripH === 0 ? Math.max(8, grip.box.width - grip.grabSize * 2) : grip.grabSize
        height: grip.gripV === 0 ? Math.max(8, grip.box.height - grip.grabSize * 2) : grip.grabSize
        x: grip.gripH < 0 ? -width / 2 : (grip.gripH > 0 ? grip.box.width - width / 2 : (grip.box.width - width) / 2)
        y: grip.gripV < 0 ? -height / 2 : (grip.gripV > 0 ? grip.box.height - height / 2 : (grip.box.height - height) / 2)

        // MouseArea y no DragHandler a propósito: hace falta leer si Shift está
        // apretado DURANTE el arrastre (para mantener la relación de aspecto),
        // y los PointerHandler no exponen los modificadores en vivo.
        MouseArea {
            id: gripArea
            anchors.fill: parent
            anchors.margins: -3 // un poco más de área agarrable que la visible
            hoverEnabled: true
            cursorShape: {
                if (grip.gripH === 0) return Qt.SizeVerCursor;
                if (grip.gripV === 0) return Qt.SizeHorCursor;
                return (grip.gripH === grip.gripV) ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor;
            }

            property rect start: Qt.rect(0, 0, 0, 0)
            property point startPoint: Qt.point(0, 0)
            property real startAspect: 1

            function resolve(mouseX, mouseY, keepAspect) {
                const canvasItem = grip.box.canvas;
                const minSize = 32;
                const s = gripArea.start;
                // En coordenadas del lienzo: la caja se mueve mientras se
                // arrastra, así que las coordenadas locales no sirven.
                const p = gripArea.mapToItem(canvasItem, mouseX, mouseY);
                const tx = p.x - gripArea.startPoint.x;
                const ty = p.y - gripArea.startPoint.y;

                let left = s.x;
                let top = s.y;
                let right = s.x + s.width;
                let bottom = s.y + s.height;

                if (grip.gripH < 0) left = canvasItem.snapEdge(s.x + tx, "x", grip.box.sourceIndex);
                else if (grip.gripH > 0) right = canvasItem.snapEdge(s.x + s.width + tx, "x", grip.box.sourceIndex);
                if (grip.gripV < 0) top = canvasItem.snapEdge(s.y + ty, "y", grip.box.sourceIndex);
                else if (grip.gripV > 0) bottom = canvasItem.snapEdge(s.y + s.height + ty, "y", grip.box.sourceIndex);

                left = Math.max(0, Math.min(left, right - minSize));
                top = Math.max(0, Math.min(top, bottom - minSize));
                right = Math.min(canvasItem.width, Math.max(right, left + minSize));
                bottom = Math.min(canvasItem.height, Math.max(bottom, top + minSize));

                if (keepAspect && gripArea.startAspect > 0) {
                    let w = right - left;
                    let h = bottom - top;
                    // Manda el eje que más se movió, para que no "pelee" con el mouse.
                    if (grip.gripH === 0) {
                        w = h * gripArea.startAspect;
                    } else if (grip.gripV === 0) {
                        h = w / gripArea.startAspect;
                    } else if (Math.abs(w - s.width) >= Math.abs(h - s.height)) {
                        h = w / gripArea.startAspect;
                    } else {
                        w = h * gripArea.startAspect;
                    }
                    w = Math.max(minSize, w);
                    h = Math.max(minSize, h);
                    // Los bordes que no se agarraron quedan clavados.
                    if (grip.gripH < 0) left = right - w; else right = left + w;
                    if (grip.gripV < 0) top = bottom - h; else bottom = top + h;
                }

                return Qt.rect(left, top, right - left, bottom - top);
            }

            onPressed: mouse => {
                gripArea.start = Qt.rect(grip.box.x, grip.box.y, grip.box.width, grip.box.height);
                gripArea.startPoint = gripArea.mapToItem(grip.box.canvas, mouse.x, mouse.y);
                gripArea.startAspect = grip.box.height > 0 ? grip.box.width / grip.box.height : 1;
                Scenes.selectedSourceIndex = grip.box.sourceIndex;
                grip.box.resizing = true;
                grip.box.canvas.draggingIndex = grip.box.sourceIndex;
            }

            onPositionChanged: mouse => {
                if (!grip.box.resizing) return;
                grip.box.resizeRect = gripArea.resolve(mouse.x, mouse.y, (mouse.modifiers & Qt.ShiftModifier) !== 0);
            }

            onReleased: mouse => {
                if (!grip.box.resizing) return;
                const r = gripArea.resolve(mouse.x, mouse.y, (mouse.modifiers & Qt.ShiftModifier) !== 0);
                grip.box.resizing = false;
                grip.box.canvas.draggingIndex = -1;
                Scenes.updateSource(grip.box.sourceIndex, {
                    x: r.x / grip.box.canvas.width,
                    y: r.y / grip.box.canvas.height,
                    width: r.width / grip.box.canvas.width,
                    height: r.height / grip.box.canvas.height
                });
            }
        }
    }
}
