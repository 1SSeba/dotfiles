import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls

/**
 * A ListView with animations.
 */
ListView {
    id: root
    spacing: 5
    property real removeOvershoot: 20 // Account for gaps and bouncy animations
    property int dragIndex: -1
    property real dragDistance: 0
    property bool popin: true
    property bool animateAppearance: true
    property bool animateMovement: false
    // Accumulated scroll destination so wheel deltas stack while animating
    property real scrollTargetY: 0

    property real touchpadScrollFactor: Config?.options.interactions.scrolling.touchpadScrollFactor ?? 100
    property real mouseScrollFactor: Config?.options.interactions.scrolling.mouseScrollFactor ?? 50
    property real mouseScrollDeltaThreshold: Config?.options.interactions.scrolling.mouseScrollDeltaThreshold ?? 120

    /**
     * Se emite cuando el scroll lo movió la persona (rueda, arrastre o flick).
     *
     * Hace falta como señal explícita porque la rueda no pasa por dragging ni
     * flicking: el MouseArea de acá abajo escribe contentY directo. Sin esto,
     * quien quiera "seguir el final hasta que el usuario scrollee" no tiene
     * forma de enterarse de que scrolleaste con la rueda.
     */
    signal userScrolled()

    onDraggingChanged: if (root.dragging) root.userScrolled()
    onFlickingChanged: if (root.flicking) root.userScrolled()

    function resetDrag() {
        root.dragIndex = -1
        root.dragDistance = 0
    }

    maximumFlickVelocity: 3500
    boundsBehavior: Flickable.DragOverBounds
    ScrollBar.vertical: StyledScrollBar {}

    MouseArea {
        visible: Config?.options.interactions.scrolling.fasterTouchpadScroll
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: function(wheelEvent) {
            const delta = wheelEvent.angleDelta.y / root.mouseScrollDeltaThreshold;
            // The angleDelta.y of a touchpad is usually small and continuous,
            // while that of a mouse wheel is typically in multiples of ±120.
            var scrollFactor = Math.abs(wheelEvent.angleDelta.y) >= root.mouseScrollDeltaThreshold ? root.mouseScrollFactor : root.touchpadScrollFactor;

            const maxY = Math.max(0, root.contentHeight - root.height);
            const base = scrollAnim.running ? root.scrollTargetY : root.contentY;
            var targetY = Math.max(0, Math.min(base - delta * scrollFactor, maxY));

            root.scrollTargetY = targetY;
            root.contentY = targetY;
            root.userScrolled();
            wheelEvent.accepted = true;
        }
    }

    // Salta al final sin animación y deja el scrollTargetY sincronizado.
    //
    // Hace falta porque el Behavior de abajo tiene alwaysRunToEnd: cada
    // asignación de contentY arranca una animación que no se puede cortar, así
    // que reposicionar mientras el contenido todavía se está midiendo (markdown,
    // tablas, imágenes) nunca aterriza en el final de verdad.
    function snapToEnd() {
        // Se calcula el contentY a mano en vez de usar positionViewAtEnd().
        //
        // Con delegates de altura variable que se siguen midiendo (markdown,
        // tablas, bloques plegables), positionViewAtEnd() no posiciona en
        // absoluto: cada llamada SUMA. Medido en el chat de IA, con
        // contentHeight 950 y height 839, contentY se iba a 20406 → 25391 →
        // ... → 80226, sumando ~4985 por llamada, y encima atYEnd devolvía
        // true todo el tiempo. contentHeight menos la altura visible es el
        // final de verdad, y clampearlo lo deja imposible de desbordar.
        root.instantScroll = true;
        // positionViewAtIndex(último, End) y no positionViewAtEnd() ni una
        // cuenta con contentHeight.
        //
        // Con delegates de altura muy variable (en el chat de IA se midió uno
        // de 2372 px), positionViewAtEnd() estima con promedios y no posiciona
        // en absoluto: cada llamada sumaba ~4985 px. Y calcularlo a mano con
        // contentHeight tampoco sirve, porque mientras la lista instancia esos
        // delegates el originY se sigue moviendo y el blanco cambia abajo de
        // los pies. Apuntar a un índice concreto obliga a crear y medir ese
        // delegate, que es lo único que da una posición real.
        if (root.count > 0) root.positionViewAtIndex(root.count - 1, ListView.End);
        root.scrollTargetY = root.contentY;
        root.instantScroll = false;
    }

    // Mientras esté en true, los cambios de contentY son instantáneos.
    // Por defecto false: el comportamiento de siempre no cambia.
    property bool instantScroll: false

    Behavior on contentY {
        enabled: !root.instantScroll
        NumberAnimation {
            id: scrollAnim
            alwaysRunToEnd: true
            duration: Appearance.animation.scroll.duration
            easing.type: Appearance.animation.scroll.type
            easing.bezierCurve: Appearance.animation.scroll.bezierCurve
        }
    }

    // Keep target synced when not animating (e.g., drag/flick or programmatic changes)
    onContentYChanged: {
        if (!scrollAnim.running) {
            root.scrollTargetY = root.contentY;
        }
    }

    add: Transition {
        animations: animateAppearance ? [
            Appearance?.animation.elementMove.numberAnimation.createObject(this, {
                properties: popin ? "opacity,scale" : "opacity",
                from: 0,
                to: 1,
            }),
        ] : []
    }

    addDisplaced: Transition {
        animations: animateAppearance ? [
            Appearance?.animation.elementMove.numberAnimation.createObject(this, {
                property: "y",
            }),
            Appearance?.animation.elementMove.numberAnimation.createObject(this, {
                properties: popin ? "opacity,scale" : "opacity",
                to: 1,
            }),
        ] : []
    }
    
    displaced: Transition {
        animations: root.animateMovement ? [
            Appearance?.animation.elementMove.numberAnimation.createObject(this, {
                property: "y",
            }),
            Appearance?.animation.elementMove.numberAnimation.createObject(this, {
                properties: "opacity,scale",
                to: 1,
            }),
        ] : []
    }

    move: Transition {
        animations: root.animateMovement ? [
            Appearance?.animation.elementMove.numberAnimation.createObject(this, {
                property: "y",
            }),
            Appearance?.animation.elementMove.numberAnimation.createObject(this, {
                properties: "opacity,scale",
                to: 1,
            }),
        ] : []
    }
    moveDisplaced: Transition {
        animations: root.animateMovement ? [
            Appearance?.animation.elementMove.numberAnimation.createObject(this, {
                property: "y",
            }),
            Appearance?.animation.elementMove.numberAnimation.createObject(this, {
                properties: "opacity,scale",
                to: 1,
            }),
        ] : []
    }

    remove: Transition {
        animations: animateAppearance ? [
            Appearance?.animation.elementMove.numberAnimation.createObject(this, {
                property: "x",
                to: root.width + root.removeOvershoot,
            }),
            Appearance?.animation.elementMove.numberAnimation.createObject(this, {
                property: "opacity",
                to: 0,
            })
        ] : []
    }

    // This is movement when something is removed, not removing animation!
    removeDisplaced: Transition { 
        animations: animateAppearance ? [
            Appearance?.animation.elementMove.numberAnimation.createObject(this, {
                property: "y",
            }),
            Appearance?.animation.elementMove.numberAnimation.createObject(this, {
                properties: "opacity,scale",
                to: 1,
            }),
        ] : []
    }
}
