import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.ii.overlay

StyledOverlayWidget {
    id: root
    title: "Scenes"
    minimumWidth: 460
    minimumHeight: 360
    contentItem: SceneEditorContent {
        radius: root.contentRadius
    }
}
