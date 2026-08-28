pragma ComponentBehavior: Bound

import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Widgets

/**
 * Dock embebido en la barra, portado del fork end4-pC.
 *
 * Ojo: esto NO reemplaza al dock flotante de `modules/ii/dock/`. Es un widget de
 * barra que se resuelve por nombre (`docktoPanel`) desde `BarLayoutContent`, así
 * que se instancia solo si aparece en alguna lista de `bar.layouts`.
 *
 * Muestra primero los apps pinneados (reordenables arrastrando) y después los que
 * están abiertos pero no pinneados, separados por una rayita. El orden nuevo se
 * persiste en `Config.options.dock.pinnedApps`, o sea que se comparte con el dock
 * flotante: reordenar acá reordena allá.
 */
Item {
    id: root

    property real iconSize: 23
    property real btnSize: 28
    property real btnSpacing: 2
    /**
     * `BarLayoutContent` instancia los widgets con un Loader sin pasarles nada, por
     * eso la orientación se deduce de la config en vez de recibirse. Queda como
     * property para que quien lo instancie a mano pueda forzarla.
     */
    property bool vertical: Config.options.bar.vertical
    property bool isMaterial: Config.options.bar.cornerStyle === 3

    property var pinnedApps: Config.options?.dock.pinnedApps ?? []
    property var activeUnpinned: TaskbarApps.apps.filter(a => !a.pinned && a.appId !== "SEPARATOR" && a.toplevels.length > 0)
    property bool showSeparator: _workOrder.length > 0 && activeUnpinned.length > 0

    /**
     * Copia local del orden de pinneados. Mientras se arrastra se toca esta y no la
     * config, así el reordenamiento se ve fluido y recién al soltar se persiste.
     */
    property var _workOrder: pinnedApps.slice()

    property bool dragging: false
    property int dragSourceIndex: -1
    property int _dragTargetIndex: -1
    /** Posición del cursor sobre el eje de la barra (x si es horizontal, y si es vertical). */
    property real dragCursorPos: 0
    property real dragStartCursorPos: 0
    property real slotSize: root.btnSize + root.btnSpacing
    /**
     * Al empezar y al terminar un arrastre los íconos saltan de golpe a su lugar
     * definitivo; animar ese salto se ve como un rebote raro, así que se apagan las
     * transiciones por un tick.
     */
    property bool _suppressTranslateAnim: false

    Layout.fillHeight: !vertical
    Layout.fillWidth: vertical

    implicitWidth: vertical ? (isMaterial ? Appearance.sizes.verticalBarWidth : Appearance.sizes.verticalBarWidth - 10) : pill.implicitWidth
    implicitHeight: vertical ? pill.implicitHeight : Appearance.sizes.barHeight

    /**
     * TaskbarApps indexa por appId en minúscula, pero en la config los IDs pueden
     * venir con mayúsculas. Sin normalizar, un pinneado tipo "Spotify" nunca
     * encontraría sus ventanas abiertas.
     */
    function findAppEntry(appId) {
        if (!appId)
            return null;
        const wanted = appId.toLowerCase();
        return TaskbarApps.apps.find(a => a.appId.toLowerCase() === wanted) ?? null;
    }

    function _getPinnedItemSize(index) {
        const wrapper = pinnedRepeater.itemAt(index);
        return wrapper ? (root.vertical ? wrapper.height : wrapper.width) : root.btnSize;
    }

    /** Cuánto se puede arrastrar un ícono sin salirse de la fila de pinneados. */
    function _getMaxDragOffset(index) {
        const count = _workOrder.length;
        if (count <= 1)
            return {
                left: 0,
                right: 0
            };
        let left = 0;
        let right = 0;
        for (let i = 0; i < count; i++) {
            const size = _getPinnedItemSize(i) + root.btnSpacing;
            if (i < index)
                left += size;
            else if (i > index)
                right += size;
        }
        return {
            left: -left,
            right: right
        };
    }

    /**
     * Traduce el desplazamiento del cursor a "en qué posición caería el ícono".
     * Se avanza de a medio slot por vecino en vez de usar un ancho fijo, para que
     * también funcione si algún día los íconos dejan de ser todos iguales.
     */
    function _recomputeDragTarget() {
        const count = _workOrder.length;
        if (!dragging || count <= 1) {
            _dragTargetIndex = dragSourceIndex;
            return;
        }

        const delta = dragCursorPos - dragStartCursorPos;
        let target = dragSourceIndex;
        let pos = 0;

        if (delta > 0) {
            for (let i = dragSourceIndex + 1; i < count; ++i) {
                pos += (_getPinnedItemSize(i - 1) + root.btnSpacing) / 2;
                pos += (_getPinnedItemSize(i) + root.btnSpacing) / 2;
                if (delta >= pos)
                    target = i;
                else
                    break;
            }
        } else if (delta < 0) {
            for (let j = dragSourceIndex - 1; j >= 0; --j) {
                pos -= (_getPinnedItemSize(j + 1) + root.btnSpacing) / 2;
                pos -= (_getPinnedItemSize(j) + root.btnSpacing) / 2;
                if (delta <= pos)
                    target = j;
                else
                    break;
            }
        }

        _dragTargetIndex = target;
    }

    function _startPinnedItemDrag(index) {
        _suppressTranslateAnim = true;
        dragSourceIndex = index;
        _dragTargetIndex = index;
        slotSize = root.btnSize + root.btnSpacing;
        dragStartCursorPos = 0;
        dragCursorPos = 0;
        dragging = true;
        Qt.callLater(() => root._suppressTranslateAnim = false);
    }

    function _endPinnedItemDrag() {
        _suppressTranslateAnim = true;

        const src = dragSourceIndex;
        const tgt = _dragTargetIndex;

        if (dragging && src >= 0 && tgt >= 0 && src < _workOrder.length && tgt < _workOrder.length && src !== tgt) {
            let arr = _workOrder.slice();
            const item = arr[src];
            arr.splice(src, 1);
            arr.splice(tgt, 0, item);

            _workOrder = arr;
            Config.options.dock.pinnedApps = arr;
        }

        dragging = false;
        dragSourceIndex = -1;
        _dragTargetIndex = -1;
        dragCursorPos = 0;
        dragStartCursorPos = 0;

        Qt.callLater(() => root._suppressTranslateAnim = false);
    }

    /**
     * Si la config cambia por afuera (el dock flotante, pinnear desde otro lado) hay
     * que resincronizar, pero nunca en medio de un arrastre: pisaría el orden que el
     * usuario está armando con el mouse.
     */
    onPinnedAppsChanged: {
        if (!dragging)
            _workOrder = pinnedApps.slice();
    }

    Rectangle {
        id: pill
        anchors.centerIn: parent
        color: "transparent"
        radius: Appearance.rounding.full

        implicitWidth: root.isMaterial && !root.vertical ? flow.implicitWidth + 10 : root.vertical ? (root.isMaterial ? 32 : Appearance.sizes.verticalBarWidth - 10) : flow.implicitWidth + 4

        implicitHeight: root.isMaterial && root.vertical ? flow.implicitHeight + 10 : root.isMaterial ? 32 : root.vertical ? flow.implicitHeight + 4 : Appearance.sizes.barHeight

        Behavior on implicitWidth {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }
        Behavior on implicitHeight {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }

        Flow {
            id: flow
            anchors.centerIn: parent
            flow: root.vertical ? Flow.TopToBottom : Flow.LeftToRight
            spacing: root.btnSpacing

            Repeater {
                id: pinnedRepeater
                model: root._workOrder.length

                delegate: Item {
                    id: slotItem
                    required property int index

                    property string appId: root._workOrder[slotItem.index] ?? ""
                    property var appEntry: root.findAppEntry(slotItem.appId)
                    property var deskEntry: DesktopEntries.heuristicLookup(slotItem.appId)
                    property bool appActive: slotItem.appEntry?.toplevels?.find(t => t.activated) !== undefined
                    /** Para ciclar entre las ventanas de la misma app a cada click. */
                    property int _lastFocused: -1

                    readonly property bool isDragged: root.dragging && slotItem.index === root.dragSourceIndex
                    /**
                     * El que se arrastra sigue al cursor; los demás se corren un slot
                     * para dejarle el hueco. Nadie cambia de lugar en el Flow hasta
                     * que se suelta, así no se pelean el layout y la animación.
                     */
                    readonly property real dragTranslate: {
                        if (!root.dragging)
                            return 0;
                        if (slotItem.isDragged) {
                            const raw = root.dragCursorPos - root.dragStartCursorPos;
                            const maxOff = root._getMaxDragOffset(slotItem.index);
                            return Math.max(maxOff.left, Math.min(maxOff.right, raw));
                        }
                        const src = root.dragSourceIndex;
                        const tgt = root._dragTargetIndex;
                        const idx = slotItem.index;
                        if (src < tgt && idx > src && idx <= tgt)
                            return -root.slotSize;
                        if (src > tgt && idx >= tgt && idx < src)
                            return root.slotSize;
                        return 0;
                    }

                    width: root.btnSize
                    height: root.btnSize

                    z: slotItem.isDragged ? 100 : 0
                    opacity: slotItem.isDragged ? 0.85 : 1
                    scale: slotItem.isDragged ? 1.05 : 1

                    Behavior on opacity {
                        enabled: !root._suppressTranslateAnim
                        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                    }
                    Behavior on scale {
                        enabled: !root._suppressTranslateAnim
                        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                    }

                    transform: Translate {
                        x: root.vertical ? 0 : slotItem.dragTranslate
                        y: root.vertical ? slotItem.dragTranslate : 0
                        Behavior on x {
                            enabled: !slotItem.isDragged && !root._suppressTranslateAnim
                            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                        }
                        Behavior on y {
                            enabled: !slotItem.isDragged && !root._suppressTranslateAnim
                            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                        }
                    }

                    /** Las .desktop pueden aparecer tarde (apps recién instaladas). */
                    Connections {
                        target: DesktopEntries
                        function onApplicationsChanged() {
                            slotItem.deskEntry = DesktopEntries.heuristicLookup(slotItem.appId);
                        }
                    }

                    DragHandler {
                        id: dragHandler
                        target: null
                        grabPermissions: PointerHandler.CanTakeOverFromAnything

                        onActiveChanged: {
                            if (active) {
                                root._startPinnedItemDrag(slotItem.index);
                                const pos = root.vertical ? centroid.scenePosition.y : centroid.scenePosition.x;
                                root.dragStartCursorPos = pos;
                                root.dragCursorPos = pos;
                            } else if (root.dragging) {
                                root._endPinnedItemDrag();
                            }
                        }

                        onCentroidChanged: {
                            if (!active || !root.dragging)
                                return;
                            root.dragCursorPos = root.vertical ? centroid.scenePosition.y : centroid.scenePosition.x;
                            root._recomputeDragTarget();
                        }
                    }

                    RippleButton {
                        anchors.fill: parent
                        buttonRadius: Appearance.rounding.small
                        hoverEnabled: true

                        onClicked: {
                            // Soltar el arrastre también dispara el click del botón.
                            if (root.dragging)
                                return;
                            const entry = slotItem.appEntry;
                            if (!entry || entry.toplevels.length === 0) {
                                slotItem.deskEntry?.execute();
                                return;
                            }
                            const next = (slotItem._lastFocused + 1) % entry.toplevels.length;
                            slotItem._lastFocused = next;
                            entry.toplevels[next].activate();
                        }
                        middleClickAction: () => slotItem.deskEntry?.execute()
                        altAction: () => TaskbarApps.togglePin(slotItem.appId)

                        contentItem: Item {
                            anchors.centerIn: parent

                            IconImage {
                                id: pinnedIcon
                                anchors.centerIn: parent
                                source: Quickshell.iconPath(AppSearch.guessIcon(slotItem.appId), "image-missing")
                                implicitSize: root.iconSize
                            }

                            Loader {
                                active: Config.options.dock.monochromeIcons
                                anchors.fill: pinnedIcon
                                sourceComponent: Item {
                                    Desaturate {
                                        id: desat
                                        visible: false
                                        anchors.fill: parent
                                        source: pinnedIcon
                                        desaturation: 0.8
                                    }
                                    ColorOverlay {
                                        anchors.fill: desat
                                        source: desat
                                        color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.8)
                                    }
                                }
                            }

                            /** Puntitos: una por ventana abierta, hasta tres. */
                            Flow {
                                flow: root.vertical ? Flow.TopToBottom : Flow.LeftToRight
                                spacing: 2
                                anchors {
                                    left: root.vertical ? pinnedIcon.right : undefined
                                    top: root.vertical ? undefined : pinnedIcon.bottom
                                    leftMargin: root.vertical ? 1 : 0
                                    topMargin: root.vertical ? 0 : 1
                                    horizontalCenter: root.vertical ? undefined : parent.horizontalCenter
                                    verticalCenter: root.vertical ? parent.verticalCenter : undefined
                                }
                                Repeater {
                                    model: Math.min(slotItem.appEntry?.toplevels?.length ?? 0, 3)
                                    delegate: Rectangle {
                                        radius: Appearance.rounding.full
                                        implicitWidth: root.vertical ? 2 : ((slotItem.appEntry?.toplevels?.length ?? 0) <= 3 ? 4 : 2)
                                        implicitHeight: root.vertical ? ((slotItem.appEntry?.toplevels?.length ?? 0) <= 3 ? 4 : 2) : 2
                                        color: slotItem.appActive ? Appearance.colors.colPrimary : ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.4)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Item {
                width: root.vertical ? root.btnSize : (root.showSeparator ? (1 + root.btnSpacing * 3) : 0)
                height: root.vertical ? (root.showSeparator ? (1 + root.btnSpacing * 3) : 0) : root.btnSize
                visible: root.showSeparator

                Rectangle {
                    anchors.centerIn: parent
                    width: root.vertical ? Math.round(root.btnSize * 0.6) : 1
                    height: root.vertical ? 1 : Math.round(root.btnSize * 0.6)
                    color: root.isMaterial ? Appearance.colors.colPrimary : Appearance.colors.colOutlineVariant
                }
            }

            Repeater {
                id: activeRepeater
                model: ScriptModel {
                    values: root.activeUnpinned
                }

                delegate: Item {
                    id: activeSlot
                    required property var modelData

                    property bool appIsActive: activeSlot.modelData.toplevels.find(t => t.activated) !== undefined
                    property int _lastFocused: -1

                    width: root.btnSize
                    height: root.btnSize

                    RippleButton {
                        anchors.fill: parent
                        buttonRadius: Appearance.rounding.small
                        hoverEnabled: true

                        onClicked: {
                            if (activeSlot.modelData.toplevels.length === 0)
                                return;
                            const next = (activeSlot._lastFocused + 1) % activeSlot.modelData.toplevels.length;
                            activeSlot._lastFocused = next;
                            activeSlot.modelData.toplevels[next].activate();
                        }
                        middleClickAction: () => DesktopEntries.heuristicLookup(activeSlot.modelData.appId)?.execute()
                        altAction: () => TaskbarApps.togglePin(activeSlot.modelData.appId)

                        contentItem: Item {
                            anchors.centerIn: parent

                            IconImage {
                                id: activeIcon
                                anchors.centerIn: parent
                                source: Quickshell.iconPath(AppSearch.guessIcon(activeSlot.modelData.appId), "image-missing")
                                implicitSize: root.iconSize
                            }

                            Loader {
                                active: Config.options.dock.monochromeIcons
                                anchors.fill: activeIcon
                                sourceComponent: Item {
                                    Desaturate {
                                        id: desat2
                                        visible: false
                                        anchors.fill: parent
                                        source: activeIcon
                                        desaturation: 0.8
                                    }
                                    ColorOverlay {
                                        anchors.fill: desat2
                                        source: desat2
                                        color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.8)
                                    }
                                }
                            }

                            Flow {
                                flow: root.vertical ? Flow.TopToBottom : Flow.LeftToRight
                                spacing: 2
                                anchors {
                                    left: root.vertical ? activeIcon.right : undefined
                                    top: root.vertical ? undefined : activeIcon.bottom
                                    leftMargin: root.vertical ? 1 : 0
                                    topMargin: root.vertical ? 0 : 1
                                    horizontalCenter: root.vertical ? undefined : parent.horizontalCenter
                                    verticalCenter: root.vertical ? parent.verticalCenter : undefined
                                }
                                Repeater {
                                    model: Math.min(activeSlot.modelData.toplevels.length, 3)
                                    delegate: Rectangle {
                                        radius: Appearance.rounding.full
                                        implicitWidth: root.vertical ? 2 : (activeSlot.modelData.toplevels.length <= 3 ? 4 : 2)
                                        implicitHeight: root.vertical ? (activeSlot.modelData.toplevels.length <= 3 ? 4 : 2) : 2
                                        color: activeSlot.appIsActive ? Appearance.colors.colPrimary : ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.4)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
