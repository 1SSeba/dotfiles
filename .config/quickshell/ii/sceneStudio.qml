//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
//@ pragma Env QT_SCALE_FACTOR=1

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.panels.sceneStudio

/**
 * "Scene Studio": ventana propia para armar escenas de grabación mientras
 * grabás, en vez de hacerlo desde el widget chico del overlay de Super+G.
 *
 * Corre en su propio proceso (`qs -p sceneStudio.qml`), así que no comparte
 * singletons en caliente con la shell: la comunicación es por disco
 * (`Config` → config.json, `Persistent` → states.json), igual que la app de
 * Settings.
 */
ApplicationWindow {
    id: root
    property real contentPadding: 12

    visible: true
    onClosing: Qt.quit()
    title: Translation.tr("Scene Studio")

    Component.onCompleted: {
        MaterialThemeLoader.reapplyTheme();
        Scenes.refresh();
    }

    minimumWidth: 700
    minimumHeight: 520
    width: 1200
    height: 780
    color: Appearance.m3colors.m3background

    // La lista de ventanas para las fuentes "ventana" envejece rápido (se abren
    // y cierran todo el tiempo), así que se refresca sola mientras la ventana
    // está visible.
    Timer {
        running: root.visible
        interval: 4000
        repeat: true
        onTriggered: Scenes.refresh()
    }

    ColumnLayout {
        anchors {
            fill: parent
            margins: root.contentPadding
        }
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            MaterialSymbol {
                text: "movie_edit"
                iconSize: Appearance.font.pixelSize.huge
                color: Appearance.colors.colOnLayer0
            }
            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("Scene Studio")
                font.pixelSize: Appearance.font.pixelSize.larger
                font.weight: Font.Medium
                color: Appearance.colors.colOnLayer0
            }
            RippleButtonWithIcon {
                materialIcon: "folder_open"
                mainText: Translation.tr("Grabaciones")
                onClicked: Qt.openUrlExternally(`file://${Config.options.screenRecord.savePath}`)
            }
        }

        StyledFlickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: studioPanel.implicitHeight
            clip: true

            SceneStudioPanel {
                id: studioPanel
                width: parent.width
            }
        }
    }
}
