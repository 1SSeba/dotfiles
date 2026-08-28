import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

RippleButton {
    id: button
    property string day
    property int isToday
    property bool bold
    /**
     * Los eventos de ese día, tal como los normaliza Calendars. Vacío deja
     * el botón exactamente como era antes: los puntitos no ocupan lugar propio,
     * van superpuestos abajo del número.
     */
    property var events: []
    readonly property int eventCount: button.events?.length ?? 0
    /** La clave YYYY-MM-DD de ese día. Vacía = el día no se puede abrir. */
    property string dateKey: ""
    property color eventColor: Appearance.m3colors.m3primary

    /** El primer color de calendario que aparezca ese día manda sobre el punto. */
    readonly property color dotColor: {
        const own = button.events?.[0]?.color ?? "";
        return own.length > 0 ? own : button.eventColor;
    }

    Layout.fillWidth: false
    Layout.fillHeight: false
    implicitWidth: 38; 
    implicitHeight: 38;

    toggled: (isToday == 1)
    buttonRadius: Appearance.rounding.small

    // Un día con eventos se abre en el calendario web de un click. Sin eventos
    // el botón queda inerte, igual que antes: no hay nada que mostrar.
    onClicked: {
        if (button.eventCount > 0 && button.dateKey.length > 0)
            Calendars.openDay(button.dateKey);
    }
    
    contentItem: Item {
        anchors.fill: parent

        StyledText {
            anchors.fill: parent
            text: button.day
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            font.weight: button.bold ? Font.DemiBold : Font.Normal
            color: (button.isToday == 1) ? Appearance.m3colors.m3onPrimary : 
                (button.isToday == 0) ? Appearance.colors.colOnLayer1 : 
                Appearance.colors.colOutlineVariant

            Behavior on color {
                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
            }
        }

        // Un punto por evento, hasta tres. Más que eso no se distingue y ensucia.
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 4
            spacing: 2
            visible: button.eventCount > 0

            Repeater {
                model: Math.min(button.eventCount, 3)
                delegate: Rectangle {
                    width: 3
                    height: 3
                    radius: 1.5
                    // Sobre el día de hoy el fondo es el color primario, así que
                    // el punto tiene que ir en el color de encima o desaparece
                    color: (button.isToday == 1)
                        ? Appearance.m3colors.m3onPrimary
                        : button.dotColor
                    opacity: (button.isToday == -1) ? 0.45 : 1

                    Behavior on color {
                        animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                    }
                }
            }
        }
    }

    // Qué hay ese día, sin gastar un pixel de layout
    StyledToolTip {
        extraVisibleCondition: button.eventCount > 0
        text: (button.events ?? []).map(ev => {
            const hora = ev.allDay
                ? Translation.tr("Todo el día")
                : ev.start.toLocaleTimeString(Qt.locale(), "HH:mm");
            return `${hora}  ${ev.summary}`;
        }).join("\n") + "\n\n" + Translation.tr("Click para abrirlo en el navegador")
    }
}
