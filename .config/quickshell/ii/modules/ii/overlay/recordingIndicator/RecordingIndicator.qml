import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.ii.overlay

StyledOverlayWidget {
    id: root
    title: "Recording"
    minimumWidth: 96
    minimumHeight: 34
    resizable: false
    showCenterButton: true
    contentItem: RecordingIndicatorContent {
        radius: root.contentRadius
    }
}
