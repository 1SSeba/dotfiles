import qs.modules.common
import qs.services
import QtQuick
import QtQuick.Layouts

MouseArea {
    id: root
    property bool borderless: Config.options.bar.borderless
    property bool alwaysShowAllResources: false
    implicitWidth: rowLayout.implicitWidth + rowLayout.anchors.leftMargin + rowLayout.anchors.rightMargin
    implicitHeight: Appearance.sizes.barHeight
    hoverEnabled: !Config.options.bar.tooltips.clickToShow

    RowLayout {
        id: rowLayout

        spacing: 0
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4

        Resource {
            iconName: "memory"
            percentage: ResourceUsage.memoryUsedPercentage
            shown: Config.options.bar.resources.alwaysShowRam || root.alwaysShowAllResources
            warningThreshold: Config.options.bar.resources.memoryWarningThreshold
        }

        Resource {
            iconName: "swap_horiz"
            percentage: ResourceUsage.swapUsedPercentage
            shown: (Config.options.bar.resources.alwaysShowSwap && percentage > 0) || 
                (MprisController.activePlayer?.trackTitle == null) ||
                root.alwaysShowAllResources
            Layout.leftMargin: shown ? 6 : 0
            warningThreshold: Config.options.bar.resources.swapWarningThreshold
        }

        Resource {
            iconName: "planner_review"
            percentage: ResourceUsage.cpuUsage
            shown: Config.options.bar.resources.alwaysShowCpu || 
                !(MprisController.activePlayer?.trackTitle?.length > 0) ||
                root.alwaysShowAllResources
            Layout.leftMargin: shown ? 6 : 0
            warningThreshold: Config.options.bar.resources.cpuWarningThreshold
        }

        Resource {
            // La temperatura no es un porcentaje: la normalizamos contra 100 °C, que es el
            // punto donde estos procesadores empiezan a hacer throttle.
            iconName: "thermostat"
            percentage: Math.min(1, ResourceUsage.cpuTemp / 100)
            shown: Config.options.bar.resources.alwaysShowCpuTemp || root.alwaysShowAllResources
            Layout.leftMargin: shown ? 6 : 0
            warningThreshold: 85
        }

        Resource {
            iconName: "storage"
            percentage: ResourceUsage.diskUsedPercentage
            shown: Config.options.bar.resources.alwaysShowDisk || root.alwaysShowAllResources
            Layout.leftMargin: shown ? 6 : 0
            warningThreshold: 90
        }

    }

    ResourcesPopup {
        hoverTarget: root
    }
}
