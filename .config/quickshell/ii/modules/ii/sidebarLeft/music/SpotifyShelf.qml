pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

/** Un estante de Inicio: título y una fila de tarjetas que se desliza al costado. */
ColumnLayout {
    id: root

    property string title: ""
    property var entries: []
    property int cardSize: 96

    spacing: 4
    visible: root.entries.length > 0

    StyledText {
        Layout.fillWidth: true
        text: root.title
        font.pixelSize: Appearance.font.pixelSize.small
        font.weight: Font.DemiBold
        color: Appearance.colors.colOnLayer1
    }

    ListView {
        Layout.fillWidth: true
        Layout.preferredHeight: root.cardSize + 36
        orientation: ListView.Horizontal
        spacing: 8
        clip: true
        model: root.entries
        boundsBehavior: Flickable.StopAtBounds

        delegate: SpotifyCard {
            required property var modelData
            entry: modelData
            size: root.cardSize
        }
    }
}
