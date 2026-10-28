import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas

AbstractWidget {
    id: root

    required property string configEntryName
    required property int screenWidth
    required property int screenHeight
    required property int scaledScreenWidth
    required property int scaledScreenHeight
    required property real wallpaperScale
    property bool visibleWhenLocked: Config.options.lock.showWidgets
    property var configEntry: Config.options.background.widgets[configEntryName]
    property string placementStrategy: configEntry.placementStrategy
    property real targetX: Math.max(0, Math.min(configEntry.x, scaledScreenWidth - root.visualWidth))
    property real targetY : Math.max(0, Math.min(configEntry.y, scaledScreenHeight - root.visualHeight))
    x: targetX
    y: targetY
    visible: opacity > 0
    opacity: (GlobalStates.screenLocked && !visibleWhenLocked) ? 0 : 1
    Behavior on opacity {
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
    }
    scale: (draggable && containsPress) ? 1.05 : 1
    Behavior on scale {
        animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
    }

    draggable: placementStrategy === "free" && !Config.options.background.widgetsLocked

    // ------------------------------------------------------------------ //
    // Tamaño por escala
    // ------------------------------------------------------------------ //

    /**
     * Para los widgets de un solo diseño (reloj, clima, recursos...): la manija
     * de la esquina los agranda o achica enteros, de forma continua y con el
     * borde derecho enganchado a la grilla, como se estiran las notas. La
     * escala queda en `<widget>.scale` de la config.
     *
     * Los widgets con modos (calendario, reproductor...) usan ElasticResize y
     * los de tamaño libre (notas) su propia manija; ésos dejan esto apagado.
     */
    property bool scalable: false
    readonly property real minUserScale: 0.5
    readonly property real maxUserScale: 2.5
    property real userScale: root.scalable ? (root.configEntry?.scale ?? 1) : 1
    property bool userResizing: false
    property real resizeStartScale: 1
    /** Lo que ocupa en pantalla, ya escalado. */
    readonly property real visualWidth: root.width * root.userScale
    readonly property real visualHeight: root.height * root.userScale

    // Desde la esquina de arriba a la izquierda, así x/y siguen siendo la
    // esquina del widget y agrandarlo empuja hacia la manija.
    transform: Scale {
        xScale: root.userScale
        yScale: root.userScale
    }
    Behavior on userScale {
        enabled: !root.userResizing
        animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
    }

    function scaleResize(dx, dy) {
        if (!root.userResizing) {
            root.resizeStartScale = root.userScale
            root.userResizing = true
        }
        const natW = Math.max(1, root.width)
        const natH = Math.max(1, root.height)
        // En diagonal: cuenta tanto lo que se mueve a lo ancho como a lo alto
        const raw = root.resizeStartScale + (dx / natW + dy / natH) / 2
        const snapped = root.snapSizeToGrid(natW * raw, natH * raw,
            natW * root.minUserScale, natH * root.minUserScale,
            natW * root.maxUserScale, natH * root.maxUserScale)
        root.userScale = snapped.width / natW
    }

    function finishScaleResize() {
        root.userResizing = false
        root.configEntry.scale = root.userScale
        root.flashEdges(root.visualWidth, root.visualHeight)
    }

    Loader {
        active: root.scalable
        z: 100
        anchors.fill: parent
        sourceComponent: Item {
            ResizeHandler {
                anchorItem: parent
                hoverActive: root.containsMouse
                locked: Config.options.background.widgetsLocked
                currentWidth: root.visualWidth
                resizeMode: "diagonal"
                // Que la manija no crezca ni se achique con el widget
                scale: 1 / root.userScale
                onResizedXY: (dx, dy, startWidth) => root.scaleResize(dx, dy)
                onResizeFinished: root.finishScaleResize()
            }
        }
    }
    function restoreXYBinding() {
        root.x = Qt.binding(() => root.targetX);
        root.y = Qt.binding(() => root.targetY);
    }

    onReleased: {
        configEntry.x = root.x;
        configEntry.y = root.y;
        root.targetX = Qt.binding(() => Math.max(0, Math.min(configEntry.x, scaledScreenWidth - root.visualWidth)));
        root.targetY = Qt.binding(() => Math.max(0, Math.min(configEntry.y, scaledScreenHeight - root.visualHeight)));
        root.restoreXYBinding();
    }

    /**
     * El tamaño que deja el borde derecho y el de abajo sobre una línea de la
     * grilla del escritorio (la que aparece al estirar), dentro de los límites
     * dados. Se calcula en coordenadas del canvas porque los widgets viven
     * adentro de un Loader, no directamente en él.
     */
    function snapSizeToGrid(rawWidth, rawHeight, minWidth, minHeight, maxWidth, maxHeight) {
        const clampW = w => Math.max(minWidth, Math.min(maxWidth, w))
        const clampH = h => Math.max(minHeight, Math.min(maxHeight, h))
        const canvas = root.findCanvas(root.parent)
        if (!root.snapEnabled || !canvas) return Qt.size(clampW(rawWidth), clampH(rawHeight))
        const g = canvas.gridSize
        const origin = root.mapToItem(canvas, 0, 0)
        const snapEdge = (start, length) => Math.round((start + length) / g) * g - start
        // Primero al rango y después a la grilla; si la línea cae fuera del
        // rango, la de al lado hacia adentro.
        let w = snapEdge(origin.x, clampW(rawWidth))
        let h = snapEdge(origin.y, clampH(rawHeight))
        if (w > maxWidth) w -= g
        if (w < minWidth) w += g
        if (h > maxHeight) h -= g
        if (h < minHeight) h += g
        return Qt.size(w, h)
    }

    /** Al soltar, las líneas de los bordes destellan, igual que al mover el widget. */
    function flashEdges(width, height) {
        const canvas = root.findCanvas(root.parent)
        if (!canvas || !Config.options.background.showSnapLines) return
        const origin = root.mapToItem(canvas, 0, 0)
        canvas.flashLines([origin.x + width], [origin.y + height])
    }

    property bool needsColText: false
    property color dominantColor: Appearance.colors.colPrimary
    property bool dominantColorIsDark: dominantColor.hslLightness < 0.5
    property color colText: {
        const onNormalBackground = (GlobalStates.screenLocked && Config.options.lock.blur.enable)
        const adaptiveColor = ColorUtils.colorWithLightness(Appearance.colors.colPrimary, (dominantColorIsDark ? 0.8 : 0.12))
        return onNormalBackground ? Appearance.colors.colOnLayer0 : adaptiveColor;
    }

    property bool wallpaperIsVideo: Config.options.background.wallpaperPath.endsWith(".mp4") || Config.options.background.wallpaperPath.endsWith(".webm") || Config.options.background.wallpaperPath.endsWith(".mkv") || Config.options.background.wallpaperPath.endsWith(".avi") || Config.options.background.wallpaperPath.endsWith(".mov")
    property string wallpaperPath: wallpaperIsVideo ? Config.options.background.thumbnailPath : Config.options.background.wallpaperPath
    
    onWallpaperPathChanged: refreshPlacementIfNeeded()
    onPlacementStrategyChanged: refreshPlacementIfNeeded()
    Connections {
        target: Config
        function onReadyChanged() { refreshPlacementIfNeeded() }
    }
    function refreshPlacementIfNeeded() {
        if (!Config.ready) return;
        if (root.placementStrategy === "free" && !root.needsColText) return;
        leastBusyRegionProc.wallpaperPath = root.wallpaperPath;
        leastBusyRegionProc.running = false;
        leastBusyRegionProc.running = true;
    }
    Process {
        id: leastBusyRegionProc
        property string wallpaperPath: root.wallpaperPath
        // TODO: make these less arbitrary
        property int contentWidth: 300
        property int contentHeight: 300
        property int horizontalPadding: 200
        property int verticalPadding: 200
        command: [Quickshell.shellPath("scripts/images/least-busy-region-venv.sh") // Comments to force the formatter to break lines
            , "--screen-width", Math.round(root.scaledScreenWidth) //
            , "--screen-height", Math.round(root.scaledScreenHeight) //
            , "--width", contentWidth //
            , "--height", contentHeight //
            , "--horizontal-padding", horizontalPadding //
            , "--vertical-padding", verticalPadding //
            , wallpaperPath //
            , ...(root.placementStrategy === "mostBusy" ? ["--busiest"] : [])
            // "--visual-output",
        ]
        stdout: StdioCollector {
            id: leastBusyRegionOutputCollector
            onStreamFinished: {
                const output = leastBusyRegionOutputCollector.text;
                // console.log("[Background] Least busy region output:", output)
                if (output.length === 0) return;
                const parsedContent = JSON.parse(output);
                root.dominantColor = parsedContent.dominant_color || Appearance.colors.colPrimary;
                if (root.placementStrategy === "free") return;
                root.targetX = parsedContent.center_x * root.wallpaperScale - root.visualWidth / 2;
                root.targetY  = parsedContent.center_y * root.wallpaperScale - root.visualHeight / 2;
            }
        }
    }
}