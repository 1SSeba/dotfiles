pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.common.functions as CF
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

import qs.modules.ii.background.widgets
import qs.modules.ii.background.widgets.clock
import qs.modules.ii.background.widgets.weather
import qs.modules.ii.background.widgets.calendar
import qs.modules.ii.background.widgets.resources
import qs.modules.ii.background.widgets.usercard
import qs.modules.ii.background.widgets.media
import qs.modules.ii.background.widgets.visualizer
import qs.modules.ii.background.widgets.images
import qs.modules.ii.background.widgets.notes
import qs.modules.ii.background.widgets.worldclock

Variants {
    id: root
    model: Quickshell.screens

    function getShapeFromName(name) {
        switch (name) {
            case "Circle":        return MaterialShape.Shape.Circle
            case "Square":        return MaterialShape.Shape.Square
            case "Slanted":       return MaterialShape.Shape.Slanted
            case "Arch":          return MaterialShape.Shape.Arch
            case "Fan":           return MaterialShape.Shape.Fan
            case "Arrow":         return MaterialShape.Shape.Arrow
            case "SemiCircle":    return MaterialShape.Shape.SemiCircle
            case "Oval":          return MaterialShape.Shape.Oval
            case "Pill":          return MaterialShape.Shape.Pill
            case "Triangle":      return MaterialShape.Shape.Triangle
            case "Diamond":       return MaterialShape.Shape.Diamond
            case "ClamShell":     return MaterialShape.Shape.ClamShell
            case "Pentagon":      return MaterialShape.Shape.Pentagon
            case "Gem":           return MaterialShape.Shape.Gem
            case "Sunny":         return MaterialShape.Shape.Sunny
            case "VerySunny":     return MaterialShape.Shape.VerySunny
            case "Cookie4Sided":  return MaterialShape.Shape.Cookie4Sided
            case "Cookie6Sided":  return MaterialShape.Shape.Cookie6Sided
            case "Cookie7Sided":  return MaterialShape.Shape.Cookie7Sided
            case "Cookie9Sided":  return MaterialShape.Shape.Cookie9Sided
            case "Cookie12Sided": return MaterialShape.Shape.Cookie12Sided
            case "Ghostish":      return MaterialShape.Shape.Ghostish
            case "Clover4Leaf":   return MaterialShape.Shape.Clover4Leaf
            case "Clover8Leaf":   return MaterialShape.Shape.Clover8Leaf
            case "Burst":         return MaterialShape.Shape.Burst
            case "SoftBurst":     return MaterialShape.Shape.SoftBurst
            case "Boom":          return MaterialShape.Shape.Boom
            case "SoftBoom":      return MaterialShape.Shape.SoftBoom
            case "Flower":        return MaterialShape.Shape.Flower
            case "Puffy":         return MaterialShape.Shape.Puffy
            case "PuffyDiamond":  return MaterialShape.Shape.PuffyDiamond
            case "PixelCircle":   return MaterialShape.Shape.PixelCircle
            case "PixelTriangle": return MaterialShape.Shape.PixelTriangle
            case "Bun":           return MaterialShape.Shape.Bun
            case "Heart":         return MaterialShape.Shape.Heart
            default:              return MaterialShape.Shape.Cookie7Sided
        }
    }

    /**
     * Si `entry` (el JsonObject de un widget del fondo) tiene un override de
     * `enable` para `screenName`, ese manda; si no, el enable global de siempre.
     * Así "widgets distintos en cada pantalla" es tan simple como destildar uno
     * en una pantalla puntual, sin tocar las demás.
     */
    function widgetEnabledOn(entry, screenName) {
        try {
            const override = entry?.screens?.[screenName]?.enable;
            return override !== undefined ? override : (entry?.enable ?? false);
        } catch (e) {
            return entry?.enable ?? false;
        }
    }

    function getColorFromName(name) {
        switch (name) {
            case "primary":            return Appearance.colors.colPrimary
            case "secondary":          return Appearance.colors.colSecondary
            case "tertiary":           return Appearance.colors.colTertiary
            case "primaryContainer":   return Appearance.colors.colPrimaryContainer
            case "secondaryContainer": return Appearance.colors.colSecondaryContainer
            case "tertiaryContainer":  return Appearance.colors.colTertiaryContainer
            case "layer0":             return Appearance.colors.colLayer0
            case "layer1":             return Appearance.colors.colLayer1
            default:                  return Appearance.colors.colPrimaryContainer
        }
    }

    PanelWindow {
        id: bgRoot

        required property var modelData
        // Lista vacía = los widgets del fondo se dibujan en todos los monitores.
        readonly property bool widgetsOnThisScreen: Config.options.background.screenList.length === 0
            || Config.options.background.screenList.includes(bgRoot.screen?.name ?? "")

        // Hide when fullscreen
        property list<HyprlandWorkspace> workspacesForMonitor: Hyprland.workspaces.values.filter(workspace => workspace.monitor && workspace.monitor.name == monitor.name)
        property var activeWorkspaceWithFullscreen: workspacesForMonitor.filter(workspace => ((workspace.toplevels.values.filter(window => window.wayland?.fullscreen)[0] != undefined) && workspace.active))[0]
        visible: GlobalStates.screenLocked || (!(activeWorkspaceWithFullscreen != undefined)) || !Config?.options.background.hideWhenFullscreen

        // Workspaces
        property HyprlandMonitor monitor: Hyprland.monitorFor(modelData)
        property list<var> relevantWindows: HyprlandData.windowList.filter(win => win.monitor == monitor?.id && win.workspace.id >= 0).sort((a, b) => a.workspace.id - b.workspace.id)
        property int firstWorkspaceId: relevantWindows[0]?.workspace.id || 1
        property int lastWorkspaceId: relevantWindows[relevantWindows.length - 1]?.workspace.id || 10
        property int workspaceChunkSize: Config?.options.bar.workspaces.shown ?? 10
        property int totalWorkspaces: Math.ceil(lastWorkspaceId / workspaceChunkSize) * workspaceChunkSize
        // Wallpaper
        property bool wallpaperIsVideo: Config.options.background.wallpaperPath.endsWith(".mp4") || Config.options.background.wallpaperPath.endsWith(".webm") || Config.options.background.wallpaperPath.endsWith(".mkv") || Config.options.background.wallpaperPath.endsWith(".avi") || Config.options.background.wallpaperPath.endsWith(".mov")
        // Con la previsualización activada, pasar el mouse por una miniatura del
        // selector cambia lo que se ve acá sin tocar el wallpaper de verdad.
        // `background.enableWallpaperPreview` tenía control en Settings y ningún lector.
        property string wallpaperPath: (Config.options.background.enableWallpaperPreview && Wallpapers.previewPath.length > 0)
            ? Wallpapers.previewPath
            : (wallpaperIsVideo ? Config.options.background.thumbnailPath : Config.options.background.wallpaperPath)

        // ---- Wallpaper centrado ----
        // En vez de cubrir la pantalla, recorta el wallpaper dentro de una figura en el medio.
        readonly property bool centeredWallpaperEnabled: Config.options.background.centeredWallpaper
            && (!Config.options.background.centeredWallpaperOnlyWhenLocked || GlobalStates.screenLocked)
        readonly property int centeredWallpaperShape: root.getShapeFromName(Config.options.background.centeredWallpaperShape)
        readonly property int centeredWallpaperSize: Config.options.background.centeredWallpaperSize
        readonly property color centeredWallpaperColor: root.getColorFromName(Config.options.background.centeredWallpaperColor)

        // ---- Transición de wallpaper con shaders ----
        // Los .qsb viven en modules/ii/background/shaders/. Si `wallpaperAnimation` está en ""
        // nada de esto se activa y el fondo se comporta como siempre.
        readonly property var shaderList: ["circlePit", "circleSelect", "magic", "Doom", "Peel", "transition", "pixelate", "stripes", "crt", "dissolve", "glitch", "ripple", "shatter"]
        property string currentShader: "pixelate"
        readonly property string wallpaperAnimation: Config.options.background.wallpaperAnimation ?? ""
        // 1.0 = transición terminada. Baja a 0 al cambiar de wallpaper y la anima de vuelta.
        property real transitionProgress: 1.0
        // Path del wallpaper anterior, para que el shader tenga de dónde salir.
        property string previousWallpaperSource: ""
        // Espejo del path actual: `onWallpaperPathChanged` corre DESPUÉS del cambio, así que
        // sin esta copia no habría manera de saber cuál era el de antes.
        property string lastWallpaperPath: ""

        // Hay transición en curso: el shader tiene de dónde y a dónde ir.
        readonly property bool transitionActive: bgRoot.wallpaperAnimation !== ""
            && bgRoot.transitionProgress < 1.0
            && bgRoot.previousWallpaperSource !== ""

        function pickShader() {
            if (bgRoot.wallpaperAnimation === "")
                return;
            bgRoot.currentShader = bgRoot.wallpaperAnimation === "random"
                ? bgRoot.shaderList[Math.floor(Math.random() * bgRoot.shaderList.length)]
                : bgRoot.wallpaperAnimation;
        }
        property bool wallpaperSafetyTriggered: {
            const enabled = Config.options.workSafety.enable.wallpaper;
            const sensitiveWallpaper = (CF.StringUtils.stringListContainsSubstring(wallpaperPath.toLowerCase(), Config.options.workSafety.triggerCondition.fileKeywords));
            const sensitiveNetwork = (CF.StringUtils.stringListContainsSubstring(Network.networkName.toLowerCase(), Config.options.workSafety.triggerCondition.networkNameKeywords));
            return enabled && sensitiveWallpaper && sensitiveNetwork;
        }
        readonly property real parallaxRation: Config.options.background.parallax.workspaceZoom
        property real minSuitableScale: 1 // Some reasonable init, to be updated
        property real effectiveWallpaperScale: minSuitableScale * parallaxRation
        property int wallpaperWidth: modelData.width // Some reasonable init value, to be updated
        property int wallpaperHeight: modelData.height // Some reasonable init value, to be updated
        property real scaledWallpaperWidth: wallpaperWidth * effectiveWallpaperScale
        property real scaledWallpaperHeight: wallpaperHeight * effectiveWallpaperScale
        property real parallaxTotalPixelsX: Math.max(0, scaledWallpaperWidth - screen.width)
        property real parallaxTotalPixelsY: Math.max(0, scaledWallpaperHeight - screen.height)
        readonly property bool verticalParallax: (Config.options.background.parallax.autoVertical && wallpaperHeight > wallpaperWidth) || Config.options.background.parallax.vertical
        // Colors
        property bool shouldBlur: (GlobalStates.screenLocked && Config.options.lock.blur.enable)
        property color dominantColor: Appearance.colors.colPrimary // Default, to be changed
        property bool dominantColorIsDark: dominantColor.hslLightness < 0.5
        property color colText: {
            if (wallpaperSafetyTriggered)
                return CF.ColorUtils.mix(Appearance.colors.colOnLayer0, Appearance.colors.colPrimary, 0.75);
            return (GlobalStates.screenLocked && shouldBlur) ? Appearance.colors.colOnLayer0 : CF.ColorUtils.colorWithLightness(Appearance.colors.colPrimary, (dominantColorIsDark ? 0.8 : 0.12));
        }
        Behavior on colText {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }

        // Layer props
        screen: modelData
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: (GlobalStates.screenLocked && !scaleAnim.running) ? WlrLayer.Overlay : WlrLayer.Bottom
        // WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "quickshell:background"
        // Sin esto los widgets del fondo no reciben teclado y no se puede escribir
        // en las Notas ni en los ajustes del reloj mundial.
        WlrLayershell.keyboardFocus: GlobalStates.desktopWidgetKeyboardFocus
            ? WlrKeyboardFocus.OnDemand
            : WlrKeyboardFocus.None
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        color: {
            if (!bgRoot.wallpaperSafetyTriggered || bgRoot.wallpaperIsVideo)
                return "transparent";
            return CF.ColorUtils.mix(Appearance.colors.colLayer0, Appearance.colors.colPrimary, 0.75);
        }
        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }

        Component.onCompleted: {
            bgRoot.lastWallpaperPath = bgRoot.wallpaperPath;
            bgRoot.pickShader();
        }

        onWallpaperPathChanged: {
            bgRoot.updateZoomScale();
            // Clock position gets updated after zoom scale is updated

            const previous = bgRoot.lastWallpaperPath;
            bgRoot.lastWallpaperPath = bgRoot.wallpaperPath;

            if (bgRoot.wallpaperAnimation === "" || bgRoot.wallpaperSafetyTriggered
                || bgRoot.wallpaperIsVideo || previous === "" || previous === bgRoot.wallpaperPath) {
                bgRoot.transitionProgress = 1.0;
                return;
            }

            bgRoot.previousWallpaperSource = previous;
            bgRoot.pickShader();
            // El arranque real de la animación ocurre en wallpaper.onStatusChanged, cuando la
            // imagen nueva terminó de cargar. Si arrancáramos acá el shader mostraría un frame vacío.
            bgRoot.transitionProgress = 0.0;
        }

        // Rotación automática de wallpaper.
        // Corre en una sola pantalla: si lo dejáramos por monitor, con dos pantallas el
        // wallpaper cambiaría al doble de velocidad y peleándose entre sí.
        Timer {
            interval: Math.max(1000, Config.options.wallpaperSelector.changeInterval)
            running: Config.options.wallpaperSelector.changeInterval > 0
                && bgRoot.modelData === Quickshell.screens[0]
            repeat: true
            onTriggered: {
                if (Wallpapers.folderModel.count > 0)
                    Wallpapers.randomFromCurrentFolder();
            }
        }

        NumberAnimation {
            id: transitionAnim
            target: bgRoot
            property: "transitionProgress"
            from: 0.0
            to: 1.0
            duration: Config.options.background.wallpaperAnimationDuration
            easing.type: Easing.InOutCubic
            onFinished: {
                bgRoot.previousWallpaperSource = "";
                bgRoot.transitionProgress = 1.0;
            }
        }

        // Wallpaper zoom scale
        function updateZoomScale() {
            getWallpaperSizeProc.path = bgRoot.wallpaperPath;
            getWallpaperSizeProc.running = true;
        }
        Process {
            id: getWallpaperSizeProc
            property string path: bgRoot.wallpaperPath
            command: ["magick", "identify", "-format", "%w %h", path]
            stdout: StdioCollector {
                id: wallpaperSizeOutputCollector
                onStreamFinished: {
                    const output = wallpaperSizeOutputCollector.text;
                    const [width, height] = output.split(" ").map(Number);
                    const [screenWidth, screenHeight] = [bgRoot.screen.width, bgRoot.screen.height];
                    bgRoot.wallpaperWidth = width;
                    bgRoot.wallpaperHeight = height;

                    // Perfect image; scale = 1
                    // Small picture; scale > 1; will zoom in the picture
                    // Big picture; scale < 1; will zoom out the picture
                    // Choose max number so every side will fit
                    bgRoot.minSuitableScale = Math.max(screenWidth / width, screenHeight / height);
                }
            }
        }

        Item {
            anchors.fill: parent

            // Wallpaper saliente. Queda DEBAJO del actual, tapado por él, así que no se ve
            // salvo mientras el nuevo todavía carga. Vive visible a propósito: un Item invisible
            // no se dibuja, y entonces su textura de layer no le serviría al ShaderEffect.
            Image {
                id: previousWallpaper
                source: bgRoot.previousWallpaperSource
                visible: bgRoot.transitionActive
                x: wallpaper.x
                y: wallpaper.y
                width: wallpaper.width
                height: wallpaper.height
                fillMode: Image.PreserveAspectCrop
                cache: true
                smooth: true
                asynchronous: true
                layer.enabled: bgRoot.transitionActive
            }

            // Wallpaper
            StyledImage {
                id: wallpaper
                visible: opacity > 0 && !blurLoader.active && !bgRoot.centeredWallpaperEnabled
                opacity: (status === Image.Ready && !bgRoot.wallpaperIsVideo) ? 1 : 0
                cache: false
                smooth: false
                layer.enabled: bgRoot.transitionActive
                onStatusChanged: {
                    // Recién cuando la imagen nueva está lista arranca la animación; si no,
                    // el shader interpolaría hacia una textura todavía vacía.
                    if (status === Image.Ready && bgRoot.transitionActive && !transitionAnim.running)
                        transitionAnim.restart();
                }

                property int workspaceIndex: (bgRoot.monitor.activeWorkspace?.id ?? 1) - 1
                property real middleFraction: 0.5
                property real fraction: {
                    // 0 - start of the picture
                    // 1 - end of the picture
                    if (bgRoot.totalWorkspaces <= 1) {
                        return middleFraction;
                    }
                    return Math.max(0, Math.min(1, workspaceIndex / (bgRoot.totalWorkspaces - 1)));
                }

                property real usedFractionX: {
                    let usedFraction = middleFraction;
                    if (Config.options.background.parallax.enableWorkspace && !bgRoot.verticalParallax) {
                        usedFraction = fraction;
                    }
                    if (Config.options.background.parallax.enableSidebar) {
                        let sidebarFraction = bgRoot.parallaxRation / bgRoot.workspaceChunkSize / 2;
                        usedFraction += (sidebarFraction * GlobalStates.sidebarRightOpen - sidebarFraction * GlobalStates.sidebarLeftOpen);
                    }
                    return Math.max(0, Math.min(1, usedFraction));
                }
                property real usedFractionY: {
                    let usedFraction = middleFraction;
                    if (Config.options.background.parallax.enableWorkspace && bgRoot.verticalParallax) {
                        usedFraction = fraction;
                    }
                    return Math.max(0, Math.min(1, usedFraction));
                }

                x: {
                    if (bgRoot.screen.width > width) {
                        // Center the picture
                        return (bgRoot.screen.width - width) / 2;
                    }
                    return - bgRoot.parallaxTotalPixelsX * usedFractionX;
                }
                y: {
                    if (bgRoot.screen.height > height) {
                        // Center the picture
                        return (bgRoot.screen.height - height) / 2;
                    }
                    return - bgRoot.parallaxTotalPixelsY * usedFractionY;
                }

                source: bgRoot.wallpaperSafetyTriggered ? "" : bgRoot.wallpaperPath
                fillMode: Image.PreserveAspectCrop
                Behavior on x {
                    NumberAnimation {
                        duration: 600
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on y {
                    NumberAnimation {
                        duration: 600
                        easing.type: Easing.OutCubic
                    }
                }
                width: bgRoot.scaledWallpaperWidth
                height: bgRoot.scaledWallpaperHeight
            }

            // Mezcla del wallpaper viejo con el nuevo. Va encima de los dos y con la misma
            // geometría, así que mientras dura los tapa por completo.
            // El Loader importa: un ShaderEffect sin `fragmentShader` cae en el shader por
            // defecto de Qt, que pide un sampler `source` y llena el log de warnings. Con la
            // feature apagada directamente no existe.
            Loader {
                id: transitionLoader
                active: bgRoot.wallpaperAnimation !== ""
                x: wallpaper.x
                y: wallpaper.y
                width: wallpaper.width
                height: wallpaper.height
                sourceComponent: ShaderEffect {
                    id: transitionEffect
                    visible: bgRoot.transitionActive && !blurLoader.active && !bgRoot.centeredWallpaperEnabled

                    property var fromImage: previousWallpaper
                    property var toImage: wallpaper
                    property var source1: previousWallpaper
                    property var source2: wallpaper
                    property real time: 0.0
                    property real progress: bgRoot.transitionProgress
                    property real aspectX: width / Math.max(1, height)
                    property real aspectY: 1.0
                    property vector2d aspectRatio: Qt.vector2d(aspectX, aspectY)
                    property vector2d origin: Qt.vector2d(0.5, 0.5)

                    fragmentShader: Qt.resolvedUrl(`shaders/${bgRoot.currentShader}.frag.qsb`)

                    Timer {
                        interval: 16
                        repeat: true
                        running: transitionEffect.visible
                        onTriggered: transitionEffect.time += interval / 1000.0
                    }
                    onVisibleChanged: if (!visible) transitionEffect.time = 0.0
                }
            }

            Loader {
                id: blurLoader
                active: Config.options.lock.blur.enable && (GlobalStates.screenLocked || scaleAnim.running)
                anchors.fill: wallpaper
                scale: GlobalStates.screenLocked ? Config.options.lock.blur.extraZoom : 1
                Behavior on scale {
                    NumberAnimation {
                        id: scaleAnim
                        duration: 400
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Appearance.animationCurves.expressiveDefaultSpatial
                    }
                }
                sourceComponent: GaussianBlur {
                    source: wallpaper
                    radius: GlobalStates.screenLocked ? Config.options.lock.blur.radius : 0
                    // `lock.blur.size` tenía control en Settings y ningún lector.
                    // 1 (el default) = automático, o sea lo que ya se hacía; por
                    // encima de eso el usuario fija las muestras a mano.
                    samples: Config.options.lock.blur.size > 1 ? Config.options.lock.blur.size : (radius * 2 + 1)

                    Rectangle {
                        opacity: GlobalStates.screenLocked ? 1 : 0
                        anchors.fill: parent
                        color: CF.ColorUtils.transparentize(Appearance.colors.colLayer0, 0.7)
                    }
                }
            }

            Rectangle {
                id: centeredWallpaperBg
                anchors.fill: parent
                color: bgRoot.centeredWallpaperColor
                opacity: bgRoot.centeredWallpaperEnabled ? 1 : 0
                visible: opacity > 0

                Behavior on opacity {
                    animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
                }
            }

            MaterialShape {
                id: centeredWallpaperShapeItem
                anchors.centerIn: parent
                width: bgRoot.centeredWallpaperSize
                height: bgRoot.centeredWallpaperSize
                color: bgRoot.centeredWallpaperColor
                shape: bgRoot.centeredWallpaperShape
                transformOrigin: Item.Center
                visible: opacity > 0

                state: bgRoot.centeredWallpaperEnabled ? "shown" : "hidden"

                states: [
                    State {
                        name: "shown"
                        PropertyChanges { target: centeredWallpaperShapeItem; scale: 1; opacity: 1 }
                    },
                    State {
                        name: "hidden"
                        PropertyChanges { target: centeredWallpaperShapeItem; scale: 1.4; opacity: 0 }
                    }
                ]

                transitions: [
                    Transition {
                        to: "shown"
                        ParallelAnimation {
                            NumberAnimation { target: centeredWallpaperShapeItem; property: "scale"; from: 0; duration: Appearance.animation.elementMove.duration; easing.type: Easing.InOutCubic }
                            NumberAnimation { target: centeredWallpaperShapeItem; property: "opacity"; duration: Appearance.animation.elementMove.duration; easing.type: Easing.InOutCubic }
                        }
                    },
                    Transition {
                        to: "hidden"
                        ParallelAnimation {
                            NumberAnimation { target: centeredWallpaperShapeItem; property: "scale"; duration: Appearance.animation.elementMove.duration; easing.type: Easing.InOutCubic }
                            NumberAnimation { target: centeredWallpaperShapeItem; property: "opacity"; duration: Appearance.animation.elementMove.duration; easing.type: Easing.InOutCubic }
                        }
                    }
                ]

                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: MaterialShape {
                        width: centeredWallpaperShapeItem.width
                        height: centeredWallpaperShapeItem.height
                        shape: bgRoot.centeredWallpaperShape
                    }
                }

                StyledImage {
                    anchors.fill: parent
                    source: bgRoot.wallpaperPath
                    fillMode: Image.PreserveAspectCrop
                    cache: false
                    antialiasing: true
                    sourceSize.width: parent.width
                    sourceSize.height: parent.height
                }
            }

            // Click derecho sobre el fondo abre el menú del escritorio.
            // z negativo a propósito: los widgets del canvas ya usan el click derecho para
            // trabarse/destrabarse, y ese gesto tiene que seguir ganando sobre este.
            MouseArea {
                id: desktopRightClickArea
                anchors.fill: parent
                z: -2
                enabled: Config.options.desktopMenu.enable
                acceptedButtons: Qt.RightButton
                onClicked: mouse => {
                    GlobalStates.desktopMenuScreen = bgRoot.screen;
                    GlobalStates.desktopMenuX = mouse.x;
                    GlobalStates.desktopMenuY = mouse.y;
                    GlobalStates.desktopMenuOpen = true;
                }
            }

            // Arrastrar archivos al escritorio.
            // Una imagen sola se pone de wallpaper; cualquier otra cosa (o varias) cae en la
            // bandeja. El DropArea sólo reacciona a arrastres, así que no le roba el mouse a
            // los widgets del fondo.
            DropArea {
                id: wallpaperDropArea
                anchors.fill: parent
                enabled: Config.options.dropShelf.enable
                keys: ["text/uri-list"]

                property var currentUrls: []

                readonly property var imageExtensions: /\.(png|jpe?g|webp|bmp|gif)$/i

                onEntered: drag => {
                    drag.accepted = drag.hasUrls;
                    wallpaperDropArea.currentUrls = drag.hasUrls ? drag.urls : [];
                }
                onExited: wallpaperDropArea.currentUrls = []

                onDropped: drop => {
                    if (!drop.hasUrls) {
                        drop.accepted = false;
                        wallpaperDropArea.currentUrls = [];
                        return;
                    }
                    const single = drop.urls.length === 1
                        ? CF.FileUtils.trimFileProtocol(decodeURIComponent(drop.urls[0].toString()))
                        : "";
                    if (single !== "" && wallpaperDropArea.imageExtensions.test(single)) {
                        Wallpapers.select(single, Appearance.m3colors.darkmode);
                    } else {
                        const globalPos = wallpaperDropArea.mapToGlobal(drop.x, drop.y);
                        DropShelf.show(drop.urls, globalPos.x, globalPos.y);
                    }
                    drop.accept();
                    wallpaperDropArea.currentUrls = [];
                }

                Rectangle {
                    id: dropOverlay
                    anchors.fill: parent
                    visible: wallpaperDropArea.containsDrag
                    color: CF.ColorUtils.transparentize(Appearance.colors.colPrimary, 0.6)

                    readonly property bool isSingleImage: wallpaperDropArea.currentUrls.length === 1
                        && wallpaperDropArea.imageExtensions.test(
                            CF.FileUtils.trimFileProtocol(wallpaperDropArea.currentUrls[0].toString()))

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 8
                        MaterialSymbol {
                            Layout.alignment: Qt.AlignHCenter
                            text: dropOverlay.isSingleImage ? "wallpaper" : "stacks"
                            iconSize: 64
                            color: Appearance.colors.colOnPrimary
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: dropOverlay.isSingleImage
                                ? Translation.tr("Drop to set as wallpaper")
                                : Translation.tr("Drop to add to shelf")
                            font.pixelSize: Appearance.font.pixelSize.large
                            color: Appearance.colors.colOnPrimary
                        }
                    }
                }
            }

            WidgetCanvas {
                id: widgetCanvas
                width: parent.width
                height: parent.height
                readonly property real parallaxFactor: {
                    var f = Config.options.background.parallax.widgetsFactor;
                    return f / bgRoot.parallaxRation;
                }
                readonly property real baseWallpaperOffsetX: (bgRoot.screen.width - wallpaper.width) / 2
                readonly property real baseWallpaperOffsetY: (bgRoot.screen.height - wallpaper.height) / 2
                readonly property real wallpaperTotalOffsetX: wallpaper.x - baseWallpaperOffsetX
                readonly property real wallpaperTotalOffsetY: wallpaper.y - baseWallpaperOffsetY
                readonly property bool locked: GlobalStates.screenLocked
                x: wallpaperTotalOffsetX * parallaxFactor * !locked
                y: wallpaperTotalOffsetY * parallaxFactor * !locked

                transitions: Transition {
                    PropertyAnimation {
                        properties: "width,height"
                        duration: Appearance.animation.elementMove.duration
                        easing.type: Appearance.animation.elementMove.type
                        easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
                    }
                    AnchorAnimation {
                        duration: Appearance.animation.elementMove.duration
                        easing.type: Appearance.animation.elementMove.type
                        easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
                    }
                }

                FadeLoader {
                    shown: root.widgetEnabledOn(Config.options.background.widgets.weather, bgRoot.screen?.name ?? "") && bgRoot.widgetsOnThisScreen
                    sourceComponent: WeatherWidget {
                        screenName: bgRoot.screen?.name ?? ""
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: 1
                    }
                }

                FadeLoader {
                    shown: root.widgetEnabledOn(Config.options.background.widgets.calendar, bgRoot.screen?.name ?? "") && bgRoot.widgetsOnThisScreen
                    sourceComponent: CalendarWidget {
                        screenName: bgRoot.screen?.name ?? ""
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: 1
                    }
                }

                FadeLoader {
                    shown: root.widgetEnabledOn(Config.options.background.widgets.resources, bgRoot.screen?.name ?? "") && bgRoot.widgetsOnThisScreen
                    sourceComponent: ResourcesWidget {
                        screenName: bgRoot.screen?.name ?? ""
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: 1
                    }
                }

                FadeLoader {
                    shown: root.widgetEnabledOn(Config.options.background.widgets.userCard, bgRoot.screen?.name ?? "") && bgRoot.widgetsOnThisScreen
                    sourceComponent: UserCardWidget {
                        screenName: bgRoot.screen?.name ?? ""
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: 1
                    }
                }

                FadeLoader {
                    shown: root.widgetEnabledOn(Config.options.background.widgets.media, bgRoot.screen?.name ?? "") && bgRoot.widgetsOnThisScreen
                    sourceComponent: MediaWidget {
                        screenName: bgRoot.screen?.name ?? ""
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: 1
                    }
                }

                FadeLoader {
                    shown: root.widgetEnabledOn(Config.options.background.widgets.visualizer, bgRoot.screen?.name ?? "") && bgRoot.widgetsOnThisScreen
                    sourceComponent: VisualizerWidget {
                        screenName: bgRoot.screen?.name ?? ""
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: 1
                    }
                }

                FadeLoader {
                    shown: root.widgetEnabledOn(Config.options.background.widgets.customImage, bgRoot.screen?.name ?? "") && bgRoot.widgetsOnThisScreen
                    sourceComponent: CustomImage {
                        screenName: bgRoot.screen?.name ?? ""
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: 1
                    }
                }

                FadeLoader {
                    shown: root.widgetEnabledOn(Config.options.background.widgets.images, bgRoot.screen?.name ?? "") && bgRoot.widgetsOnThisScreen
                    sourceComponent: ImageConverterWidget {
                        screenName: bgRoot.screen?.name ?? ""
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: 1
                    }
                }

                FadeLoader {
                    shown: root.widgetEnabledOn(Config.options.background.widgets.notes, bgRoot.screen?.name ?? "") && bgRoot.widgetsOnThisScreen
                    sourceComponent: NotesWidget {
                        screenName: bgRoot.screen?.name ?? ""
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: 1
                    }
                }

                FadeLoader {
                    shown: root.widgetEnabledOn(Config.options.background.widgets.worldClock, bgRoot.screen?.name ?? "") && bgRoot.widgetsOnThisScreen
                    sourceComponent: WorldClockWidget {
                        screenName: bgRoot.screen?.name ?? ""
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: 1
                    }
                }

                FadeLoader {
                    shown: root.widgetEnabledOn(Config.options.background.widgets.clock, bgRoot.screen?.name ?? "") && bgRoot.widgetsOnThisScreen
                    sourceComponent: ClockWidget {
                        screenName: bgRoot.screen?.name ?? ""
                        screenWidth: bgRoot.screen.width
                        screenHeight: bgRoot.screen.height
                        scaledScreenWidth: bgRoot.screen.width
                        scaledScreenHeight: bgRoot.screen.height
                        wallpaperScale: 1
                        wallpaperSafetyTriggered: bgRoot.wallpaperSafetyTriggered
                    }
                }
            }
        }
    }
}
