pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.modules.common

Item {
    id: root

    signal clicked(event: var)
    property alias iconText: fabWidget.iconText
    // Lo usa el widget de notas para pedir un FAB más chico (38 en vez de 48).
    property alias baseSize: fabWidget.baseSize
    default property alias fabData: fabWidget.data
    property bool enableShadow: true

    // Antes esto anclaba verticalCenter a mano. Adentro de un layout Qt avisa que
    // es comportamiento indefinido, y en los pocos usos con anchors propios (el FAB
    // de Quick, abajo a la derecha) chocaba con anchors.bottom.
    Layout.alignment: Qt.AlignVCenter
    implicitWidth: fabWidget.implicitWidth
    implicitHeight: fabWidget.implicitHeight
    // Hijo directo, no dentro de un Loader: la sombra se ancla al FAB, y desde
    // adentro del Loader el FAB no era ni padre ni hermano.
    StyledRectangularShadow {
        visible: root.enableShadow
        target: fabWidget
        radius: fabWidget.buttonRadius
    }
    FloatingActionButton {
        id: fabWidget
        onClicked: e => root.clicked(e)
        baseSize: 48
        colBackground: Appearance.colors.colTertiaryContainer
        colBackgroundHover: Appearance.colors.colTertiaryContainerHover
        colRipple: Appearance.colors.colTertiaryContainerActive
        colOnBackground: Appearance.colors.colOnTertiaryContainer
    }
}