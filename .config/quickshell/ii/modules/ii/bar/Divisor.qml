import QtQuick
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root
    property bool vertical: Config.options.bar.vertical
    property real btnSize: 40
    property real btnSpacing: 2
    property bool isMaterial: Config.options.bar.cornerStyle === 3
    // Config.options.bar.divider todavía no existe en esta config: se usan defaults
    // seguros para que el widget funcione igual mientras se agrega la opción.
    property string style: Config.options.bar.divider?.style ?? "rect" // "rect" - "dot" - "space"
    property int dividerSpacing: Config.options.bar.divider?.spacing ?? 8

    width:  vertical ? btnSize : (root.style === "space" ? root.dividerSpacing : (1 + btnSpacing * 3))
    height: vertical ? (root.style === "space" ? root.dividerSpacing : (1 + btnSpacing * 3)) : btnSize

    Rectangle {
        visible: root.style === "rect"
        anchors.centerIn: parent
        width:  root.vertical ? Math.round(root.btnSize * 0.6) : 1
        height: root.vertical ? 1 : Math.round(root.btnSize * 0.6)
        color:  root.isMaterial ? Appearance.colors.colPrimary : Appearance.colors.colOutlineVariant
    }

    StyledText {
        visible: root.style === "dot"
        anchors.centerIn: parent
        text: "•"
        color: root.isMaterial ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer0
        font.pixelSize: Appearance.font.pixelSize.normal
    }
}
