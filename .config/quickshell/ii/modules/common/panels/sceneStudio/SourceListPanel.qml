pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/**
 * Lista de fuentes de la escena activa, al estilo del panel de "Orígenes" de
 * OBS: ojo de visibilidad, orden de capas (z), y alta/baja de fuentes.
 */
ColumnLayout {
    id: root
    spacing: 4

    readonly property var sources: Scenes.activeScene?.sources ?? []

    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        MaterialSymbol {
            text: "layers"
            iconSize: Appearance.font.pixelSize.larger
            color: Appearance.colors.colOnLayer1
        }
        StyledText {
            Layout.fillWidth: true
            text: Translation.tr("Fuentes")
            font.pixelSize: Appearance.font.pixelSize.normal
            color: Appearance.colors.colOnLayer1
        }
        RippleButton {
            implicitWidth: 30
            implicitHeight: 30
            buttonRadius: Appearance.rounding.full
            onClicked: Scenes.refresh()
            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                text: "refresh"
                iconSize: Appearance.font.pixelSize.large
            }
            StyledToolTip {
                text: Translation.tr("Volver a detectar ventanas, cámaras y monitores")
            }
        }
    }

    StyledText {
        Layout.fillWidth: true
        visible: root.sources.length === 0
        text: Translation.tr("La escena no tiene fuentes todavía.")
        font.pixelSize: Appearance.font.pixelSize.smaller
        color: Appearance.colors.colSubtext
    }

    Repeater {
        model: root.sources.length

        delegate: Rectangle {
            id: sourceRow
            required property int index
            readonly property var source: root.sources[sourceRow.index] ?? ({})
            readonly property bool selected: Scenes.selectedSourceIndex === sourceRow.index

            Layout.fillWidth: true
            implicitHeight: rowLayout.implicitHeight + 8
            radius: Appearance.rounding.unsharpenmore
            color: sourceRow.selected ? Appearance.colors.colSecondaryContainer : "transparent"

            TapHandler {
                onTapped: Scenes.selectedSourceIndex = sourceRow.index
            }

            RowLayout {
                id: rowLayout
                anchors.fill: parent
                anchors.margins: 4
                spacing: 4

                RippleButton {
                    implicitWidth: 30
                    implicitHeight: 30
                    buttonRadius: Appearance.rounding.full
                    onClicked: Scenes.toggleSourceVisible(sourceRow.index)
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: (sourceRow.source.visible ?? true) ? "visibility" : "visibility_off"
                        iconSize: Appearance.font.pixelSize.large
                        color: (sourceRow.source.visible ?? true) ? Appearance.colors.colOnLayer1 : Appearance.colors.colSubtext
                    }
                }

                MaterialSymbol {
                    text: Scenes.sourceIcon(sourceRow.source)
                    iconSize: Appearance.font.pixelSize.larger
                    color: Appearance.colors.colOnLayer1
                }

                StyledText {
                    Layout.fillWidth: true
                    elide: Text.ElideMiddle
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: (sourceRow.source.visible ?? true) ? Appearance.colors.colOnLayer1 : Appearance.colors.colSubtext
                    text: Scenes.sourceLabel(sourceRow.source)
                }

                RippleButton {
                    implicitWidth: 28
                    implicitHeight: 28
                    buttonRadius: Appearance.rounding.full
                    enabled: sourceRow.index > 0
                    onClicked: {
                        Scenes.moveSource(sourceRow.index, -1);
                        Scenes.selectedSourceIndex = sourceRow.index - 1;
                    }
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "keyboard_arrow_up"
                        iconSize: Appearance.font.pixelSize.large
                    }
                    StyledToolTip {
                        text: Translation.tr("Mandar atrás")
                    }
                }

                RippleButton {
                    implicitWidth: 28
                    implicitHeight: 28
                    buttonRadius: Appearance.rounding.full
                    enabled: sourceRow.index < root.sources.length - 1
                    onClicked: {
                        Scenes.moveSource(sourceRow.index, 1);
                        Scenes.selectedSourceIndex = sourceRow.index + 1;
                    }
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "keyboard_arrow_down"
                        iconSize: Appearance.font.pixelSize.large
                    }
                    StyledToolTip {
                        text: Translation.tr("Traer adelante")
                    }
                }

                RippleButton {
                    implicitWidth: 28
                    implicitHeight: 28
                    buttonRadius: Appearance.rounding.full
                    onClicked: {
                        Scenes.removeSource(sourceRow.index);
                        Scenes.selectedSourceIndex = -1;
                    }
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "delete"
                        iconSize: Appearance.font.pixelSize.large
                        color: Appearance.colors.colSubtext
                    }
                }
            }
        }
    }

    // Editor de la fuente seleccionada (lo que cambia según el tipo)
    ColumnLayout {
        id: selectedEditor
        Layout.fillWidth: true
        Layout.topMargin: 4
        spacing: 2
        visible: Scenes.selectedSourceIndex >= 0 && Scenes.selectedSourceIndex < root.sources.length

        readonly property var source: root.sources[Scenes.selectedSourceIndex] ?? ({})

        StyledText {
            text: Translation.tr("Fuente seleccionada")
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
        }

        StyledComboBox {
            Layout.fillWidth: true
            visible: selectedEditor.source.type === "screen"
            textRole: "displayName"
            model: [{ displayName: Translation.tr("Monitor activo al grabar"), value: "" },
                    ...Scenes.monitors.map(m => ({ displayName: `${m.name} (${m.width}×${m.height})`, value: m.name }))]
            currentIndex: Math.max(0, 1 + Scenes.monitors.findIndex(m => m.name === selectedEditor.source.monitor))
            onActivated: index => {
                Scenes.updateSource(Scenes.selectedSourceIndex, { monitor: index === 0 ? "" : Scenes.monitors[index - 1].name });
            }
        }

        StyledComboBox {
            Layout.fillWidth: true
            visible: selectedEditor.source.type === "window"
            textRole: "displayName"
            model: Scenes.windows.map(w => ({ displayName: `${w.appClass} — ${w.appTitle}`, value: w.address }))
            currentIndex: Math.max(0, Scenes.windows.findIndex(w => w.address === selectedEditor.source.address))
            onActivated: index => {
                const w = Scenes.windows[index];
                if (w) Scenes.updateSource(Scenes.selectedSourceIndex, { address: w.address, appClass: w.appClass, appTitle: w.appTitle });
            }
        }

        StyledComboBox {
            Layout.fillWidth: true
            visible: selectedEditor.source.type === "webcam"
            textRole: "displayName"
            model: Scenes.cameras.map(d => ({ displayName: d, value: d }))
            currentIndex: Math.max(0, Scenes.cameras.indexOf(selectedEditor.source.device))
            onActivated: index => {
                Scenes.updateSource(Scenes.selectedSourceIndex, { device: Scenes.cameras[index] });
            }
        }

        MaterialTextField {
            Layout.fillWidth: true
            visible: selectedEditor.source.type === "image"
            placeholderText: Translation.tr("Ruta de la imagen (.png/.jpg)")
            text: selectedEditor.source.path ?? ""
            onEditingFinished: Scenes.updateSource(Scenes.selectedSourceIndex, { path: text })
        }
    }

    // Alta de fuentes
    Flow {
        Layout.fillWidth: true
        Layout.topMargin: 4
        spacing: 4

        RippleButtonWithIcon {
            materialIcon: "monitor"
            mainText: Translation.tr("Pantalla")
            onClicked: Scenes.addSource("screen")
        }
        RippleButtonWithIcon {
            materialIcon: "web_asset"
            mainText: Translation.tr("Ventana")
            enabled: Scenes.windows.length > 0
            onClicked: {
                const w = Scenes.windows[0];
                Scenes.addSource("window", { address: w.address, appClass: w.appClass, appTitle: w.appTitle });
            }
            StyledToolTip {
                text: Translation.tr("Se agrega la primera ventana; elegí cuál en el selector de arriba")
            }
        }
        RippleButtonWithIcon {
            materialIcon: "videocam"
            mainText: Translation.tr("Cámara")
            enabled: Scenes.cameras.length > 0
            onClicked: Scenes.addSource("webcam", { device: Scenes.cameras[0] })
            StyledToolTip {
                extraVisibleCondition: Scenes.cameras.length === 0
                text: Translation.tr("No se detectó ninguna cámara en /dev/video*")
            }
        }
        RippleButtonWithIcon {
            materialIcon: "image"
            mainText: Translation.tr("Imagen")
            onClicked: Scenes.addSource("image")
        }
    }
}
