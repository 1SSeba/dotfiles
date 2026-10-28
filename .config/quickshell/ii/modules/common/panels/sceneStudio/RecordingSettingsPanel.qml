import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/**
 * Ajustes del grabador (codec, framerate, lienzo, destino).
 *
 * Vive acá y no dentro de la página de Settings porque se muestra en los dos
 * lados: en Settings → Grabación y en la ventana Scene Studio, donde hacen
 * falta a mano mientras armás la escena.
 */
ColumnLayout {
    id: root
    spacing: 4

    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        MaterialSymbol {
            text: "tune"
            iconSize: Appearance.font.pixelSize.larger
            color: Appearance.colors.colOnLayer1
        }
        StyledText {
            Layout.fillWidth: true
            text: Translation.tr("Codificación")
            font.pixelSize: Appearance.font.pixelSize.normal
            color: Appearance.colors.colOnLayer1
        }
    }

    ConfigSelectionArray {
        currentValue: Config.options.screenRecord.encoder
        onSelected: newValue => {
            Config.options.screenRecord.encoder = newValue;
        }
        options: [
            { displayName: Translation.tr("Software (CPU)"), icon: "memory", value: "software" },
            { displayName: Translation.tr("NVENC (GPU)"), icon: "bolt", value: "nvenc" },
        ]
    }

    StyledText {
        Layout.fillWidth: true
        visible: Config.options.screenRecord.encoder === "nvenc"
        text: Translation.tr("NVENC necesita driver NVIDIA 610+. Con uno más viejo la grabación cae sola a software y te avisa.")
        font.pixelSize: Appearance.font.pixelSize.smaller
        color: Appearance.colors.colSubtext
        wrapMode: Text.Wrap
    }

    ConfigComboBox {
        Layout.fillWidth: true
        buttonIcon: "speed"
        text: Translation.tr("Preset x264")
        enabled: Config.options.screenRecord.encoder === "software"
        currentValue: Config.options.screenRecord.x264Preset
        onSelected: newValue => {
            Config.options.screenRecord.x264Preset = newValue;
        }
        model: [
            { displayName: Translation.tr("ultrafast — mínimo CPU"), value: "ultrafast" },
            { displayName: "superfast", value: "superfast" },
            { displayName: Translation.tr("veryfast — recomendado"), value: "veryfast" },
            { displayName: "faster", value: "faster" },
            { displayName: "fast", value: "fast" },
            { displayName: Translation.tr("medium — máxima compresión"), value: "medium" },
        ]
    }

    ConfigSpinBox {
        icon: "60fps"
        text: Translation.tr("Framerate (0 = el del monitor)")
        value: Config.options.screenRecord.frameRate
        from: 0
        to: 240
        stepSize: 10
        onValueChanged: {
            Config.options.screenRecord.frameRate = value;
        }
    }

    ConfigRow {
        uniform: true
        ConfigSpinBox {
            icon: "width"
            text: Translation.tr("Ancho")
            value: Config.options.screenRecord.canvasWidth
            from: 0
            to: 3840
            stepSize: 160
            onValueChanged: {
                Config.options.screenRecord.canvasWidth = value;
            }
        }
        ConfigSpinBox {
            icon: "height"
            text: Translation.tr("Alto")
            value: Config.options.screenRecord.canvasHeight
            from: 0
            to: 2160
            stepSize: 90
            onValueChanged: {
                Config.options.screenRecord.canvasHeight = value;
            }
        }
    }

    StyledText {
        Layout.fillWidth: true
        text: Translation.tr("Lienzo en 0 × 0 = usa la resolución del monitor que grabes.")
        font.pixelSize: Appearance.font.pixelSize.smaller
        color: Appearance.colors.colSubtext
        wrapMode: Text.Wrap
    }

    ConfigSwitch {
        buttonIcon: "fiber_manual_record"
        text: Translation.tr("Indicador de grabación sobre todo")
        checked: Config.options.screenRecord.showIndicator
        onCheckedChanged: {
            Config.options.screenRecord.showIndicator = checked;
        }
    }

    MaterialTextField {
        Layout.fillWidth: true
        Layout.topMargin: 4
        placeholderText: Translation.tr("Carpeta de las grabaciones")
        text: Config.options.screenRecord.savePath
        onEditingFinished: Config.options.screenRecord.savePath = text
    }
}
