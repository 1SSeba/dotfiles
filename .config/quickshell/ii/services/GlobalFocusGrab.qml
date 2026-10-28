pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland

/**
 * Manages a HyprlandFocusGrab that's to be shared by all windows.
 * "Persistent" is for windows that should always be included but not closed on dismiss, like bar and onscreen keyboard.
 * "Dismissable" is for stuff like sidebars
 */ 
Singleton {
    id: root

    signal dismissed()

    property list<var> persistent: []
    property list<var> dismissable: []

    function dismiss() {
        root.dismissable = [];
        root.dismissed();
    }

    Component.onCompleted: {
        console.log("[GlobalFocusGrab] Initialized");
    }

    function addPersistent(window) {
        if (root.persistent.indexOf(window) === -1) {
            root.persistent.push(window);
        }
    }

    function removePersistent(window) {
        var index = root.persistent.indexOf(window);
        if (index !== -1) {
            root.persistent.splice(index, 1);
        }
    }

    function addDismissable(window) {
        if (root.dismissable.indexOf(window) === -1) {
            root.dismissable.push(window);
        }
    }

    function removeDismissable(window) {
        var index = root.dismissable.indexOf(window);
        if (index !== -1) {
            root.dismissable.splice(index, 1);
        }
    }

    /**
     * ¿Hay algo con foco de teclado dentro de este item?
     *
     * Iterativo y con guarda de nulo a propósito: esto lo llama el binding de
     * `windows`, que se re-evalúa cada vez que cambia la lista de hijos de
     * CUALQUIER item del árbol (una lista que crea delegates al hacer scroll,
     * por ejemplo). Con `Array.from(element?.children)` alcanzaba con que un
     * item se estuviera destruyendo justo en ese momento para tirar un
     * TypeError, dejar el binding sin resultado y soltar el grab de foco.
     */
    function hasActive(element) {
        const pending = [element];
        while (pending.length > 0) {
            const item = pending.pop();
            if (!item) continue;
            if (item.activeFocus) return true;
            const children = item.children;
            if (!children) continue;
            for (let i = 0; i < children.length; i++) pending.push(children[i]);
        }
        return false;
    }

    HyprlandFocusGrab {
        id: grab
        windows: root.dismissable.every(w => !w?.focusable) || root.dismissable.some(w => hasActive(w?.contentItem)) ? [...root.dismissable, ...root.persistent] : [...root.dismissable]
        active: root.dismissable.length > 0
        onCleared: () => {
            root.dismiss();
        }
    }

}
