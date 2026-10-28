pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/**
 * Mezclador de "qué se graba" de la escena activa: audio del sistema, micrófono
 * y audio por aplicación, cada uno con su volumen y su mute.
 *
 * La selección se persiste en la escena (`Config.options.screenRecord.scenes[].audio`)
 * y se guarda por NOMBRE de nodo, no por id numérico: los ids de PipeWire cambian
 * cada vez que la app se reinicia, el nombre no. El script resuelve nombre → id
 * en el momento de grabar.
 */
ColumnLayout {
    id: root
    spacing: 4

    readonly property var entries: Scenes.activeScene?.audio ?? []
    readonly property list<var> appNodes: Audio.outputAppNodes
    readonly property list<var> micNodes: Audio.inputDevices

    // Sin el tracker, PipeWire no mantiene vivas las propiedades de estos nodos.
    PwObjectTracker {
        objects: root.appNodes
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        MaterialSymbol {
            text: "graphic_eq"
            iconSize: Appearance.font.pixelSize.larger
            color: Appearance.colors.colOnLayer1
        }
        StyledText {
            Layout.fillWidth: true
            text: Translation.tr("Audio de la escena")
            font.pixelSize: Appearance.font.pixelSize.normal
            color: Appearance.colors.colOnLayer1
        }
    }

    StyledText {
        Layout.fillWidth: true
        visible: root.entries.length === 0
        text: Translation.tr("Sin fuentes propias: se graba el audio del sistema. Agregá una para elegir qué entra y con cuánto volumen.")
        font.pixelSize: Appearance.font.pixelSize.smaller
        color: Appearance.colors.colSubtext
        wrapMode: Text.Wrap
    }

    Repeater {
        // Cantidad y no el array: el array se reasigna entero en cada cambio
        // (así se persiste), y con el array como modelo se recrearían los
        // delegates en medio de un arrastre del slider.
        model: root.entries.length

        delegate: RowLayout {
            id: entryRow
            required property int index
            readonly property var entry: root.entries[entryRow.index] ?? ({})

            Layout.fillWidth: true
            spacing: 8

            RippleButton {
                id: muteButton
                implicitWidth: 32
                implicitHeight: 32
                buttonRadius: Appearance.rounding.full
                onClicked: Scenes.updateAudio(entryRow.index, { muted: !(entryRow.entry.muted ?? false) })

                // Para las apps se intenta su ícono real (mismo truco que el
                // mezclador de volumen del sidebar); si no hay, cae al símbolo.
                readonly property string appIcon: entryRow.entry.type === "app"
                    ? AppSearch.guessIcon(entryRow.entry.id ?? "")
                    : ""
                readonly property bool useAppIcon: muteButton.appIcon.length > 0
                    && AppSearch.iconExists(muteButton.appIcon)
                    && !(entryRow.entry.muted ?? false)

                contentItem: Item {
                    anchors.centerIn: parent
                    implicitWidth: 24
                    implicitHeight: 24

                    StyledImage {
                        anchors.fill: parent
                        visible: muteButton.useAppIcon
                        source: muteButton.useAppIcon ? Quickshell.iconPath(muteButton.appIcon, "image-missing") : ""
                    }
                    MaterialSymbol {
                        anchors.centerIn: parent
                        visible: !muteButton.useAppIcon
                        text: (entryRow.entry.muted ?? false) ? "volume_off" : Scenes.audioIcon(entryRow.entry)
                        iconSize: Appearance.font.pixelSize.larger
                        color: (entryRow.entry.muted ?? false) ? Appearance.colors.colSubtext : Appearance.colors.colOnLayer1
                    }
                }

                StyledToolTip {
                    text: (entryRow.entry.muted ?? false) ? Translation.tr("Activar") : Translation.tr("Silenciar")
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: -2

                StyledText {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: (entryRow.entry.muted ?? false) ? Appearance.colors.colSubtext : Appearance.colors.colOnLayer1
                    text: entryRow.entry.name ?? entryRow.entry.id ?? ""
                }

                StyledSlider {
                    Layout.fillWidth: true
                    enabled: !(entryRow.entry.muted ?? false)
                    from: 0
                    to: 1.5
                    value: entryRow.entry.volume ?? 1
                    configuration: StyledSlider.Configuration.S
                    onMoved: Scenes.updateAudio(entryRow.index, { volume: Math.round(value * 100) / 100 })
                }
            }

            RippleButton {
                implicitWidth: 32
                implicitHeight: 32
                buttonRadius: Appearance.rounding.full
                onClicked: Scenes.removeAudio(entryRow.index)
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "close"
                    iconSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colSubtext
                }
                StyledToolTip {
                    text: Translation.tr("Quitar de la mezcla")
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 4
        spacing: 6

        RippleButtonWithIcon {
            materialIcon: "volume_up"
            mainText: Translation.tr("Sistema")
            onClicked: Scenes.addAudio("system", "", Translation.tr("Audio del sistema"))
            StyledToolTip {
                text: Translation.tr("Todo lo que suena por la salida por defecto")
            }
        }

        StyledComboBox {
            Layout.preferredWidth: 190
            textRole: "displayName"
            model: [{ displayName: Translation.tr("Agregar micrófono…"), value: "" },
                    ...root.micNodes.map(node => ({ displayName: Audio.friendlyDeviceName(node), value: node.name }))]
            currentIndex: 0
            onActivated: index => {
                if (index === 0) return;
                const node = root.micNodes[index - 1];
                if (node) Scenes.addAudio("mic", node.name, Audio.friendlyDeviceName(node));
                currentIndex = 0;
            }
        }

        StyledComboBox {
            Layout.preferredWidth: 190
            textRole: "displayName"
            model: [{ displayName: Translation.tr("Agregar aplicación…"), value: "" },
                    ...root.appNodes.map(node => ({ displayName: Audio.appNodeDisplayName(node), value: node.name }))]
            currentIndex: 0
            onActivated: index => {
                if (index === 0) return;
                const node = root.appNodes[index - 1];
                if (node) Scenes.addAudio("app", node.name, Audio.appNodeDisplayName(node));
                currentIndex = 0;
            }
            StyledToolTip {
                text: Translation.tr("Solo aparecen las apps que están sonando ahora")
            }
        }
    }
}
