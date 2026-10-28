pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.panels.sceneStudio
import qs.modules.ii.overlay

/**
 * Versión compacta del editor de escenas, para ajustar sobre la marcha sin
 * salir del overlay de Super+G.
 *
 * La gestión completa (fuentes, mezclador de audio, duplicar escenas) vive en
 * la ventana Scene Studio; acá va lo que se usa en caliente: cambiar de escena,
 * mover/redimensionar lo que ya está, y grabar. Toda la lógica es la misma:
 * el singleton `Scenes` y el mismo `SceneCanvas` que usa el Studio.
 */
OverlayBackground {
    id: root
    property real padding: 10
    implicitWidth: 460
    implicitHeight: 360

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.padding
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            Flow {
                Layout.fillWidth: true
                spacing: 4

                Repeater {
                    model: Scenes.scenes.length

                    delegate: RippleButton {
                        id: sceneChip
                        required property int index
                        readonly property var scene: Scenes.scenes[sceneChip.index] ?? ({})

                        implicitHeight: 28
                        buttonRadius: Appearance.rounding.full
                        toggled: sceneChip.scene.id === Scenes.activeSceneId
                        colBackgroundToggled: Appearance.colors.colSecondaryContainer
                        onClicked: {
                            Scenes.setActiveScene(sceneChip.scene.id);
                            Scenes.applyActiveScene(); // si está grabando, la cambia en vivo
                        }

                        contentItem: RowLayout {
                            anchors.centerIn: parent
                            spacing: 3

                            MaterialSymbol {
                                text: sceneChip.toggled ? "play_circle" : "movie"
                                iconSize: Appearance.font.pixelSize.normal
                                color: sceneChip.toggled ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer2
                            }
                            StyledText {
                                rightPadding: 4
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                text: sceneChip.scene.name ?? sceneChip.scene.id ?? ""
                                color: sceneChip.toggled ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer2
                            }
                        }
                    }
                }
            }
        }

        SceneCanvas {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            RippleButtonWithIcon {
                materialIcon: Scenes.recording ? "stop_circle" : "fiber_manual_record"
                mainText: Scenes.recording ? Translation.tr("Detener") : Translation.tr("Grabar")
                onClicked: Scenes.toggleRecording()
            }

            Item { Layout.fillWidth: true }

            RippleButtonWithIcon {
                materialIcon: "movie_edit"
                mainText: Translation.tr("Studio")
                onClicked: {
                    GlobalStates.overlayOpen = false;
                    Quickshell.execDetached(["qs", "-p", Quickshell.shellPath("sceneStudio.qml")]);
                }
                StyledToolTip {
                    text: Translation.tr("Abrir la ventana completa: fuentes, mezclador de audio y escenas")
                }
            }
        }
    }
}
