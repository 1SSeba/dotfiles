pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell

Item {
    id: root
    implicitHeight: col.implicitHeight + 16

    // Este menú se abre parado sobre un monitor puntual (el que se clickeó con
    // el botón derecho); los switches tienen que reflejar y controlar "¿se ve
    // ACÁ?", no el `enable` global — si no, un widget restringido a otra
    // pantalla (Config.options.background.widgets.<x>.screenList) aparece
    // marcado como activo en un monitor donde en realidad no se dibuja.
    readonly property string screenName: GlobalStates.desktopMenuScreen?.name ?? ""

    function isVisibleHere(key) {
        const w = Config.options.background.widgets[key];
        if (!w.enable) return false;
        return w.screenList.length === 0 || w.screenList.includes(root.screenName);
    }

    function setVisibleHere(key, on) {
        const w = Config.options.background.widgets[key];
        const allNames = Quickshell.screens.map(s => s.name);
        if (on) {
            const wasOff = !w.enable;
            w.enable = true;
            // Se estaba prendiendo desde apagado del todo: por defecto queda
            // exclusivo de esta pantalla (screenList vacío significaría
            // "todas"), salvo que Settings pida compartir los widgets nuevos
            // entre monitores.
            if (wasOff && w.screenList.length === 0 && !Config.options.background.shareWidgetsAcrossScreens) {
                w.screenList = [root.screenName];
                return;
            }
            // Lista vacía ya significa "todas": esta pantalla ya está incluida.
            if (w.screenList.length > 0 && !w.screenList.includes(root.screenName)) {
                const list = w.screenList.concat([root.screenName]);
                // Si quedaron todas, se vuelve a la forma canónica: vacía.
                w.screenList = (list.length === allNames.length) ? [] : list;
            }
            return;
        }
        // Apagar "acá": si vivía en todas, pasa a vivir en todas menos esta;
        // si ya era exclusivo de esta pantalla, se apaga del todo.
        const base = w.screenList.length === 0 ? allNames : w.screenList;
        const rest = base.filter(n => n !== root.screenName);
        if (rest.length === 0) {
            w.enable = false;
        } else {
            w.screenList = rest;
        }
    }

    readonly property var widgetList: [
        { key: "visualizer",  icon: "graphic_eq",         name: Translation.tr("Visualizer") },
        { key: "customImage", icon: "image",              name: Translation.tr("Custom Image") },
        { key: "weather",     icon: "partly_cloudy_day",  name: Translation.tr("Weather") },
        { key: "clock",       icon: "schedule",           name: Translation.tr("Clock") },
        { key: "media",       icon: "music_note",         name: Translation.tr("Media") },
        { key: "images",      icon: "photo_library",      name: Translation.tr("Image Converter") },
        { key: "resources",   icon: "monitor_heart",      name: Translation.tr("Resources") },
        { key: "calendar",    icon: "calendar_month",     name: Translation.tr("Calendar") },
        { key: "worldClock",  icon: "public",             name: Translation.tr("World Clock") },
        { key: "userCard",    icon: "person",             name: Translation.tr("User Card") },
        { key: "notes",       icon: "note_stack_add",     name: Translation.tr("Notes") },
    ]

    Rectangle {
        anchors.fill: parent
        radius: Appearance.rounding.verylarge
        color: Appearance.colors.colLayer0
    }

    ColumnLayout {
        id: col
        anchors { fill: parent; margins: 8 }
        spacing: 2

        ConfigSwitch {
            Layout.fillWidth: true
            buttonIcon: "lock"
            text: Translation.tr("Lock widget positions")
            checked: Config.options.background.widgetsLocked
            onCheckedChanged: Config.options.background.widgetsLocked = checked
        }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: 8
            visible: root.screenName.length > 0 && Quickshell.screens.length > 1
            text: Translation.tr("On %1").arg(root.screenName)
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: 4
            Layout.bottomMargin: 4
            implicitHeight: 1
            color: Appearance.colors.colOutlineVariant
            opacity: 0.4
        }

        Repeater {
            model: root.widgetList
            delegate: ConfigSwitch {
                required property var modelData
                Layout.fillWidth: true
                buttonIcon: modelData.icon
                text: modelData.name
                checked: root.isVisibleHere(modelData.key)
                onCheckedChanged: root.setVisibleHere(modelData.key, checked)
            }
        }
    }
}