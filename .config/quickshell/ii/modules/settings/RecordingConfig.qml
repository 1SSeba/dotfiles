import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.panels.sceneStudio

/**
 * Página de grabación: los ajustes del grabador y, abajo, el mismo panel de
 * escenas que usa la ventana Scene Studio (mismo componente, no una copia).
 */
ContentPage {
    forceWidth: true

    ContentSection {
        icon: "screen_record"
        title: Translation.tr("Grabación de pantalla")

        RecordingSettingsPanel {
            Layout.fillWidth: true
        }
    }

    ContentSection {
        icon: "movie_edit"
        title: Translation.tr("Escenas")
        shape: MaterialShape.Shape.Pentagon

        RippleButtonWithIcon {
            materialIcon: "open_in_new"
            mainText: Translation.tr("Abrir Scene Studio en su ventana")
            onClicked: Quickshell.execDetached(["qs", "-p", Quickshell.shellPath("sceneStudio.qml")])
            StyledToolTip {
                text: Translation.tr("Más cómodo para armar escenas mientras grabás")
            }
        }

        SceneStudioPanel {
            Layout.fillWidth: true
            showRecordingSettings: false // ya están en la sección de arriba
        }
    }
}
