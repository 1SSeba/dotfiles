import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets.widgetCanvas

AbstractWidget {
    id: root

    required property string configEntryName
    // Nombre de la pantalla donde vive esta instancia (el de 'hyprctl monitors'),
    // para saber si tiene su propio override en 'configEntry.screens'.
    required property string screenName
    required property int screenWidth
    required property int screenHeight
    required property int scaledScreenWidth
    required property int scaledScreenHeight
    required property real wallpaperScale
    property bool visibleWhenLocked: Config.options.lock.showWidgets
    property var configEntry: Config.options.background.widgets[configEntryName]

    // ---- Overrides por pantalla ----
    // El override de esta pantalla en particular, o {} si nunca se customizó acá.
    // Todo con `?.`/`try` a propósito: si `Config` quedó con una versión vieja del
    // singleton (pasa con el hot-reload de Quickshell, que no siempre reinstancia
    // los `pragma Singleton`), `configEntry.screens` puede no existir todavía. Que
    // "sin overrides" sea siempre el resultado seguro, nunca una excepción -- una
    // excepción acá tira placementStrategy/x/y a `undefined` y con eso el widget
    // deja de ser arrastrable.
    readonly property var screenOverride: {
        try {
            const screens = root.configEntry?.screens;
            return (screens && screens[root.screenName]) || ({});
        } catch (e) {
            return ({});
        }
    }
    /** El valor de 'key' para esta pantalla: el override si existe, si no el global. */
    function effective(key) {
        const own = root.screenOverride?.[key];
        return own !== undefined ? own : root.configEntry[key];
    }
    /** Guarda 'key' como override propio de esta pantalla, sin tocar las demás. */
    function writeOverride(key, value) {
        try {
            const screens = Object.assign({}, root.configEntry.screens || {});
            const entry = Object.assign({}, screens[root.screenName] || {});
            entry[key] = value;
            screens[root.screenName] = entry;
            root.configEntry.screens = screens;
        } catch (e) {
            console.warn("[Background] No se pudo guardar el override de pantalla:", e);
        }
    }

    property string placementStrategy: root.effective("placementStrategy")
    property real targetX: Math.max(0, Math.min(root.effective("x"), scaledScreenWidth - width))
    property real targetY : Math.max(0, Math.min(root.effective("y"), scaledScreenHeight - height))
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
    function restoreXYBinding() {
        root.x = Qt.binding(() => root.targetX);
        root.y = Qt.binding(() => root.targetY);
    }

    onReleased: {
        root.writeOverride("x", root.x);
        root.writeOverride("y", root.y);
        root.targetX = Qt.binding(() => Math.max(0, Math.min(root.effective("x"), scaledScreenWidth - width)));
        root.targetY = Qt.binding(() => Math.max(0, Math.min(root.effective("y"), scaledScreenHeight - height)));
        root.restoreXYBinding();
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
                root.targetX = parsedContent.center_x * root.wallpaperScale - root.width / 2;
                root.targetY  = parsedContent.center_y * root.wallpaperScale - root.height / 2;
            }
        }
    }
}