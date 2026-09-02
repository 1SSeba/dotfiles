import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import Quickshell

Revealer { // Scroll hint
    id: root
    property string icon
    property string side: "left"
    property string tooltipText: ""
    
    MouseArea {
        id: mouseArea
        anchors.right: root.side === "left" ? parent.right : undefined
        anchors.left: root.side === "right" ? parent.left : undefined
        implicitWidth: contentColumn.implicitWidth
        implicitHeight: contentColumn.implicitHeight
        property bool hovered: false

        hoverEnabled: true
        onEntered: hovered = true
        onExited: hovered = false
        acceptedButtons: Qt.NoButton

        property bool showHintTimedOut: false
        onHoveredChanged: showHintTimedOut = false
        Timer {
            running: mouseArea.hovered
            interval: 500
            onTriggered: mouseArea.showHintTimedOut = true
        }

        PopupToolTip {
            extraVisibleCondition: (tooltipText.length > 0 && mouseArea.showHintTimedOut)
            text: tooltipText
            // Mismo fix que SysTrayItem.qml/ScrollControl.qml: con la barra
            // arriba el default (Edges.Top) hace que el popup se reposicione
            // encima del cursor y parpadee (tapa el hover, se cierra, se
            // vuelve a mostrar...).
            anchorEdges: (!Config.options.bar.bottom && !Config.options.bar.vertical) ? Edges.Bottom : Edges.Top
        }

        Column {
            id: contentColumn
            anchors {
                fill: parent
            }
            spacing: -5
            MaterialSymbol {
                text: "keyboard_arrow_up"
                iconSize: 14
                color: Appearance.colors.colSubtext
            }
            MaterialSymbol {
                text: root.icon
                iconSize: 14
                color: Appearance.colors.colSubtext
            }
            MaterialSymbol {
                text: "keyboard_arrow_down"
                iconSize: 14
                color: Appearance.colors.colSubtext
            }
        }
    }
}