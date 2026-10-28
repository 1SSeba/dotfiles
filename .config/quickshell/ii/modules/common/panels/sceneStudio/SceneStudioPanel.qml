pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/**
 * Panel completo de escenas de grabación. Se monta en dos lados con el mismo
 * código: la ventana "Scene Studio" (`sceneStudio.qml`) y la página de
 * grabación de Settings (`modules/settings/RecordingConfig.qml`).
 *
 * Se acomoda solo: en angosto (Settings, ~600px) apila todo, en ancho (Studio)
 * pone fuentes y mezclador al costado del lienzo.
 */
ColumnLayout {
    id: root
    spacing: 12

    readonly property bool compact: root.width < 900
    /** En Settings los ajustes del codec ya están arriba en su propia sección. */
    property bool showRecordingSettings: true

    readonly property bool hasSelection: Scenes.selectedSourceIndex >= 0

    // Atajos sobre la fuente seleccionada, con los mismos gestos que OBS.
    Shortcut {
        sequence: "Ctrl+F"
        enabled: root.hasSelection
        onActivated: Scenes.fitSource(Scenes.selectedSourceIndex, "fit")
    }
    Shortcut {
        sequence: "Ctrl+E"
        enabled: root.hasSelection
        onActivated: Scenes.fitSource(Scenes.selectedSourceIndex, "stretch")
    }
    Shortcut {
        sequence: "Ctrl+D"
        enabled: root.hasSelection
        onActivated: Scenes.fitSource(Scenes.selectedSourceIndex, "center")
    }
    Shortcut {
        sequence: "Ctrl+R"
        enabled: root.hasSelection
        onActivated: Scenes.fitSource(Scenes.selectedSourceIndex, "reset")
    }
    Shortcut {
        sequence: "Delete"
        enabled: root.hasSelection
        onActivated: {
            Scenes.removeSource(Scenes.selectedSourceIndex);
            Scenes.selectedSourceIndex = -1;
        }
    }
    // Flechas para mover de a un píxel; con Shift, de a diez.
    Repeater {
        model: [
            { seq: "Left",        dx: -1,  dy: 0 },
            { seq: "Right",       dx: 1,   dy: 0 },
            { seq: "Up",          dx: 0,   dy: -1 },
            { seq: "Down",        dx: 0,   dy: 1 },
            { seq: "Shift+Left",  dx: -10, dy: 0 },
            { seq: "Shift+Right", dx: 10,  dy: 0 },
            { seq: "Shift+Up",    dx: 0,   dy: -10 },
            { seq: "Shift+Down",  dx: 0,   dy: 10 },
        ]
        delegate: Shortcut {
            required property var modelData
            sequence: modelData.seq
            enabled: root.hasSelection
            onActivated: Scenes.nudgeSource(Scenes.selectedSourceIndex, modelData.dx, modelData.dy)
        }
    }

    // ─────────────────────────────────────────────── barra de grabación
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: headerRow.implicitHeight + 16
        radius: Appearance.rounding.normal
        color: Scenes.recording ? Appearance.colors.colErrorContainer : Appearance.colors.colLayer1

        RowLayout {
            id: headerRow
            anchors.fill: parent
            anchors.margins: 8
            spacing: 8

            RippleButtonWithIcon {
                materialIcon: Scenes.recording ? "stop_circle" : "fiber_manual_record"
                mainText: Scenes.recording ? Translation.tr("Detener") : Translation.tr("Grabar escena")
                onClicked: Scenes.toggleRecording()
            }

            StyledText {
                visible: Scenes.recording
                text: Translation.tr("Grabando: %1").arg(Scenes.activeScene?.name ?? "")
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnErrorContainer
            }

            Item { Layout.fillWidth: true }

            RippleButtonWithIcon {
                visible: Scenes.recording
                materialIcon: "switch_video"
                mainText: Translation.tr("Aplicar escena")
                onClicked: Scenes.applyActiveScene()
                StyledToolTip {
                    text: Translation.tr("Reinicia la grabación con la escena activa (corta ~1s)")
                }
            }
        }
    }

    // ───────────────────────────────────────────────────────── escenas
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            MaterialSymbol {
                text: "video_library"
                iconSize: Appearance.font.pixelSize.larger
                color: Appearance.colors.colOnLayer1
            }
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Escenas")
                font.pixelSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colOnLayer1
            }
        }

        Flow {
            Layout.fillWidth: true
            spacing: 4

            Repeater {
                model: Scenes.scenes.length

                delegate: RippleButton {
                    id: sceneChip
                    required property int index
                    readonly property var scene: Scenes.scenes[sceneChip.index] ?? ({})

                    implicitHeight: 32
                    buttonRadius: Appearance.rounding.full
                    toggled: sceneChip.scene.id === Scenes.activeSceneId
                    colBackgroundToggled: Appearance.colors.colSecondaryContainer
                    onClicked: Scenes.setActiveScene(sceneChip.scene.id)

                    contentItem: RowLayout {
                        anchors.centerIn: parent
                        spacing: 4

                        MaterialSymbol {
                            text: sceneChip.toggled ? "play_circle" : "movie"
                            iconSize: Appearance.font.pixelSize.large
                            color: sceneChip.toggled ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer2
                        }
                        StyledText {
                            rightPadding: 4
                            text: sceneChip.scene.name ?? sceneChip.scene.id ?? ""
                            color: sceneChip.toggled ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer2
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            MaterialTextField {
                Layout.fillWidth: true
                placeholderText: Translation.tr("Nombre de la escena")
                text: Scenes.activeScene?.name ?? ""
                onEditingFinished: Scenes.renameScene(Scenes.activeSceneId, text)
            }
            RippleButtonWithIcon {
                materialIcon: "add"
                mainText: Translation.tr("Nueva")
                onClicked: Scenes.addScene()
            }
            RippleButtonWithIcon {
                materialIcon: "content_copy"
                mainText: Translation.tr("Duplicar")
                onClicked: Scenes.duplicateScene(Scenes.activeSceneId)
            }
            RippleButtonWithIcon {
                materialIcon: "delete"
                mainText: Translation.tr("Borrar")
                enabled: Scenes.scenes.length > 1
                onClicked: Scenes.removeScene(Scenes.activeSceneId)
            }
        }
    }

    // ──────────────────────────────────── lienzo + fuentes + mezclador
    GridLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        columns: root.compact ? 1 : 2
        columnSpacing: 16
        rowSpacing: 12

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            SceneCanvas {
                id: canvas
                Layout.fillWidth: true
                Layout.minimumHeight: 200
            }

            // Encuadres rápidos de la fuente seleccionada (equivalentes a los
            // de OBS). Los atajos están más abajo, en los Shortcut.
            Flow {
                Layout.fillWidth: true
                spacing: 4
                enabled: Scenes.selectedSourceIndex >= 0

                RippleButtonWithIcon {
                    materialIcon: "fit_screen"
                    mainText: Translation.tr("Ajustar")
                    onClicked: Scenes.fitSource(Scenes.selectedSourceIndex, "fit")
                    StyledToolTip {
                        text: Translation.tr("Ctrl+F — entra entero en el lienzo sin deformarse")
                    }
                }
                RippleButtonWithIcon {
                    materialIcon: "aspect_ratio"
                    mainText: Translation.tr("Estirar")
                    onClicked: Scenes.fitSource(Scenes.selectedSourceIndex, "stretch")
                    StyledToolTip {
                        text: Translation.tr("Ctrl+E — ocupa todo el lienzo (puede deformar)")
                    }
                }
                RippleButtonWithIcon {
                    materialIcon: "filter_center_focus"
                    mainText: Translation.tr("Centrar")
                    onClicked: Scenes.fitSource(Scenes.selectedSourceIndex, "center")
                    StyledToolTip {
                        text: Translation.tr("Ctrl+D")
                    }
                }
                RippleButtonWithIcon {
                    materialIcon: "restart_alt"
                    mainText: Translation.tr("Restablecer")
                    onClicked: Scenes.fitSource(Scenes.selectedSourceIndex, "reset")
                    StyledToolTip {
                        text: Translation.tr("Ctrl+R")
                    }
                }

                // Sin anchors: adentro de un Flow rompen el posicionamiento.
                StyledText {
                    leftPadding: 8
                    topPadding: 8
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    text: Translation.tr("Shift al redimensionar = mantiene la proporción · flechas = mover")
                }
            }
        }

        ColumnLayout {
            // En ancho, la columna de fuentes/mezclador tiene ancho fijo y el
            // lienzo se queda con el resto; en angosto va debajo, a todo lo ancho.
            Layout.fillWidth: root.compact
            Layout.preferredWidth: root.compact ? -1 : 360
            Layout.alignment: Qt.AlignTop
            spacing: 16

            SourceListPanel {
                Layout.fillWidth: true
            }

            AudioMixerPanel {
                Layout.fillWidth: true
            }

            RecordingSettingsPanel {
                Layout.fillWidth: true
                visible: root.showRecordingSettings
            }
        }
    }
}
