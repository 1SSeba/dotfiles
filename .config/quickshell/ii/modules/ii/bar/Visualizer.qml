import QtQuick
import Quickshell.Services.Mpris
import qs
import qs.services
import qs.modules.common

Item {
    id: root
    property bool vertical: Config.options.bar.vertical
    property bool isMaterial: Config.options.bar.cornerStyle === 3
    property bool mirrored: false
    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property bool isPlaying: activePlayer?.isPlaying ?? false
    readonly property list<real> points: GlobalStates.visualizerPoints
    property int barCount: 20
    property real dotSize: 3
    property real dotSpacing: 3
    property real maxBarHeight: (vertical
        ? Appearance.sizes.verticalBarWidth
        : Appearance.sizes.barHeight) * 0.7
    property real maxVisualizerValue: 1000

    implicitWidth: vertical
        ? Appearance.sizes.verticalBarWidth
        : (isMaterial
            ? (rowLoader.item?.implicitWidth ?? 0) + 16
            : barCount * (dotSize + dotSpacing))
    implicitHeight: vertical
        ? (isMaterial
            ? (columnLoader.item?.implicitHeight ?? 0) + 16
            : barCount * (dotSize + dotSpacing))
        : Appearance.sizes.barHeight

    transform: Scale {
        xScale: !root.vertical && root.mirrored ? -1 : 1
        origin.x: root.width / 2
    }

    // Loaders y no `visible: false`: un item invisible sigue evaluando sus
    // bindings y corriendo sus animaciones, así que la orientación que no se ve
    // recalculaba y animaba sus 20 barras con cada cuadro de cava.
    Loader {
        id: rowLoader
        anchors.centerIn: parent
        active: !root.vertical

        sourceComponent: Row {
            spacing: root.dotSpacing

            Repeater {
                model: root.barCount
                Rectangle {
                    required property int index
                    width: root.dotSize
                    property real pointValue: {
                        if (!root.isPlaying || root.points.length === 0)
                            return root.dotSize;
                        const idx = Math.floor(index * root.points.length / root.barCount);
                        const v = root.points[idx] ?? 0;
                        return Math.max(root.dotSize, (v / root.maxVisualizerValue) * root.maxBarHeight);
                    }
                    height: pointValue
                    radius: width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    color: Appearance.colors.colPrimary
                    opacity: root.isPlaying ? 0.85 : 0.3
                    Behavior on opacity { NumberAnimation { duration: 300 } }
                }
            }
        }
    }

    Loader {
        id: columnLoader
        anchors.centerIn: parent
        active: root.vertical

        sourceComponent: Column {
            spacing: root.dotSpacing

            Repeater {
                model: root.barCount
                Rectangle {
                    required property int index
                    height: root.dotSize
                    property real pointValue: {
                        if (!root.isPlaying || root.points.length === 0)
                            return root.dotSize;
                        const rawIndex = root.mirrored ? (root.barCount - 1 - index) : index;
                        const idx = Math.floor(rawIndex * root.points.length / root.barCount);
                        const v = root.points[idx] ?? 0;
                        return Math.max(root.dotSize, (v / root.maxVisualizerValue) * root.maxBarHeight);
                    }
                    width: pointValue
                    radius: height / 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: Appearance.colors.colPrimary
                    opacity: root.isPlaying ? 0.85 : 0.3
                    Behavior on opacity { NumberAnimation { duration: 300 } }
                }
            }
        }
    }
}
