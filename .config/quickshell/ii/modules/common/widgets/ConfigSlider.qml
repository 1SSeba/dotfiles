import qs.modules.common.widgets
import qs.modules.common
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.services

RowLayout {
    id: root
    spacing: 10
    // Sin esto la fila se encoge a su ancho implícito y el slider queda como un
    // muñón al lado de los ConfigSwitch, que sí piden fillWidth.
    Layout.fillWidth: true
    Layout.leftMargin: 8
    Layout.rightMargin: 8

    property string text: ""
    property string buttonIcon: ""
    property string tooltip: ""
    // Alias directos contra el slider. Antes `from`/`to` eran propiedades propias
    // bindeadas a slider.from/slider.to mientras el slider se bindeaba de vuelta:
    // una binding loop que dejaba el rango indefinido si el sitio de uso no lo
    // seteaba a mano.
    property alias value: slider.value
    property alias from: slider.from
    property alias to: slider.to
    property alias stepSize: slider.stepSize
    property alias stopIndicatorValues: slider.stopIndicatorValues
    property alias dividerValues: slider.dividerValues
    property alias tooltipContent: slider.tooltipContent
    property bool usePercentTooltip: true
    // Cuando hay stepSize, hace que el handle salte de barrita en barrita al
    // arrastrar en vez de moverse libre — así se puede "calzar" un valor
    // manualmente sin tener que soltar justo en el pixel exacto.
    property bool snapToStep: false
    property real textWidth: 120
    // Permite un slider sin etiqueta, para cuando el ícono ya dice todo.
    property bool showLabel: true

    // StyledToolTip se muestra mirando `parent.hovered`; en un RowLayout esa
    // propiedad no existe, asi que la condicion daba siempre true y cualquier
    // tooltip metido aca adentro quedaba abierto de forma permanente.
    property alias hovered: hoverHandler.hovered
    HoverHandler { id: hoverHandler }

    RowLayout {
        id: row
        spacing: 10

        OptionalMaterialSymbol {
            id: iconWidget
            icon: root.buttonIcon
            iconSize: Appearance.font.pixelSize.larger
            // Mismo atenuado que ConfigSwitch: sin esto un slider deshabilitado
            // se ve idéntico a uno activo.
            opacity: root.enabled ? 1 : 0.4
        }
        StyledText {
            id: labelWidget
            visible: root.showLabel
            // Antes era un ancho fijo de 120: cualquier etiqueta de más de dos
            // palabras entraba cortada mientras el track se quedaba con 600px.
            // Ahora crece con el texto (120 sigue siendo el piso, para que los
            // sliders cortos queden alineados) y el que cede es el slider.
            Layout.preferredWidth: Math.max(root.textWidth, labelWidget.implicitWidth)
            text: root.text
            color: Appearance.colors.colOnSecondaryContainer
            opacity: root.enabled ? 1 : 0.4
        }
        MaterialSymbol {
            visible: root.tooltip && root.tooltip.length > 0
            text: "info"
            iconSize: Appearance.font.pixelSize.large
            color: Appearance.colors.colSubtext
            MouseArea {
                id: sliderInfoMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.WhatsThisCursor
                StyledToolTip {
                    extraVisibleCondition: false
                    alternativeVisibleCondition: sliderInfoMouseArea.containsMouse
                    text: root.tooltip
                }
            }
        }
    }

    StyledSlider {
        id: slider
        configuration: StyledSlider.Configuration.XS
        usePercentTooltip: root.usePercentTooltip
        snapMode: root.snapToStep ? Slider.SnapAlways : Slider.NoSnap
        opacity: root.enabled ? 1 : 0.4
        // Piso para que una etiqueta larga no se coma el track entero.
        Layout.minimumWidth: 160
    }
}
