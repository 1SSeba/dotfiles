import QtQuick
import qs
import qs.modules.common
import qs.modules.common.widgets

RippleButton {
    id: root
    property bool vertical: Config.options.bar.vertical
    property bool isMaterial: Config.options.bar.cornerStyle === 3

    implicitWidth: 22
    implicitHeight: 22

    buttonRadius: Appearance.rounding.full
    colBackground: root.isMaterial ? Appearance.colors.colPrimaryContainer : "transparent"
    colBackgroundHover: root.isMaterial ? Appearance.colors.colPrimaryContainerHover : Appearance.colors.colLayer1Hover
    colRipple: Appearance.colors.colLayer1Active
    colBackgroundToggled: "transparent"
    colBackgroundToggledHover: Appearance.colors.colSecondaryContainerHover
    colRippleToggled: Appearance.colors.colSecondaryContainerActive
    toggled: GlobalStates.overviewOpen

    onPressed: {
        GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
    }

    MaterialSymbol {
        anchors.centerIn: parent
        iconSize: 18
        text: "search"
        color: Appearance.colors.colPrimary
    }
}
