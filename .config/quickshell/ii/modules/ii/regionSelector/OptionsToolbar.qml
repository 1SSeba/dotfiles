pragma ComponentBehavior: Bound
import qs
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

// Options toolbar
Toolbar {
    id: root

    // Use a synchronizer on these
    property var action
    property var selectionMode
    // Signals
    signal dismiss()

    readonly property int selectionModeIndex: root.selectionMode === RegionSelection.SelectionMode.RectCorners ? 0 : 1

    ToolbarTabBar {
        id: tabBar
        tabButtonList: [
            {"icon": "activity_zone", "name": Translation.tr("Rect")},
            {"icon": "gesture", "name": Translation.tr("Circle")}
        ]

        // Sincronización explícita en vez de una binding declarativa sobre
        // `currentIndex`: acá se escribe `selectionMode` desde
        // `onCurrentIndexChanged` Y `currentIndex` desde `selectionMode`, así
        // que la binding cerraba el círculo — el log tiraba "Binding loop
        // detected for property currentIndex" cada vez que se usaba el
        // selector de región.
        Component.onCompleted: tabBar.currentIndex = root.selectionModeIndex

        onCurrentIndexChanged: {
            root.selectionMode = tabBar.currentIndex === 0 ? RegionSelection.SelectionMode.RectCorners : RegionSelection.SelectionMode.Circle;
        }

        Connections {
            target: root
            function onSelectionModeIndexChanged() {
                if (tabBar.currentIndex !== root.selectionModeIndex)
                    tabBar.setCurrentIndex(root.selectionModeIndex);
            }
        }
    }
}
