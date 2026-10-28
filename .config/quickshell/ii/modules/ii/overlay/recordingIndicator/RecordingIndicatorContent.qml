import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.overlay

/**
 * Indicador de grabación: una píldora chica que se queda por encima de todo
 * mientras grabás. A propósito es mínima — punto rojo latiendo y el tiempo —
 * para no tapar nada del juego.
 */
OverlayBackground {
    id: root
    property real padding: 7
    implicitWidth: content.implicitWidth + padding * 2
    implicitHeight: content.implicitHeight + padding * 2

    readonly property bool isRecording: Persistent.states.record.enable
    property int nowEpoch: Math.floor(Date.now() / 1000)
    readonly property int elapsedSeconds: isRecording ? Math.max(0, nowEpoch - Persistent.states.record.startEpoch) : 0

    function formatTime(s) {
        const h = Math.floor(s / 3600);
        const m = Math.floor((s % 3600) / 60).toString().padStart(2, '0');
        const sec = (s % 60).toString().padStart(2, '0');
        return h > 0 ? `${h}:${m}:${sec}` : `${m}:${sec}`;
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.isRecording
        onTriggered: root.nowEpoch = Math.floor(Date.now() / 1000)
    }

    RowLayout {
        id: content
        anchors.centerIn: parent
        spacing: 6

        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: 9
            implicitHeight: 9
            radius: implicitWidth / 2
            color: Appearance.colors.colError

            SequentialAnimation on opacity {
                running: root.isRecording
                loops: Animation.Infinite
                NumberAnimation { from: 1; to: 0.25; duration: 700; easing.type: Easing.InOutQuad }
                NumberAnimation { from: 0.25; to: 1; duration: 700; easing.type: Easing.InOutQuad }
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter
            text: root.formatTime(root.elapsedSeconds)
            font.pixelSize: Appearance.font.pixelSize.small
            font.features: { "tnum": 1 }
            color: Appearance.colors.colOnLayer1
        }
    }
}
