pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/**
 * Barra compuesta por configuración, portada del fork end4-pC.
 *
 * En vez de tener las tres secciones escritas a mano, cada una se arma leyendo una
 * lista de nombres de `Config.options.bar.layouts`. Cada nombre se resuelve al
 * archivo `./<Nombre>.qml` de este mismo directorio, así agregar un widget a la
 * barra es agregar un string a la config — no tocar QML.
 *
 * Convive con la barra escrita a mano: se usa una o la otra según
 * `bar.layouts.enable`, para no romper la barra que ya funciona.
 */
Item {
    id: root

    readonly property bool isMaterial: Config.options.bar.cornerStyle === 3
    readonly property bool trayHasItems: SystemTray.items.values.length > 0

    /**
     * Algunos widgets no viven planos en este directorio o se llaman distinto en
     * ii que en el fork. Acá se corrige el nombre antes de resolver el archivo.
     */
    readonly property var widgetPathOverrides: ({
        "weatherBar": "./weather/WeatherBar.qml",
        "weather": "./weather/WeatherBar.qml"
    })

    /** La bandeja vacía no debe dejar un hueco en la barra. */
    function filterLayout(layout) {
        if (root.trayHasItems) return layout;
        return layout.filter(name => name !== "sysTray");
    }

    readonly property var effectiveLeftLayout: root.filterLayout(Config.options.bar.layouts.leftLayout)
    readonly property var effectiveMiddleLayout: root.filterLayout(Config.options.bar.layouts.middleLayout)
    readonly property var effectiveRightLayout: root.filterLayout(Config.options.bar.layouts.rightLayout)

    function getWidgetUrl(name) {
        if (!name || name.length === 0) return "";
        if (root.widgetPathOverrides[name]) return Qt.resolvedUrl(root.widgetPathOverrides[name]);
        const fileName = name.charAt(0).toUpperCase() + name.slice(1);
        return Qt.resolvedUrl("./" + fileName + ".qml");
    }

    /**
     * El visualizador se espeja de a pares para que quede simétrico cuando hay más
     * de uno en la misma fila.
     */
    function getMirroredForIndex(layout, idx) {
        const previous = layout.slice(0, idx).filter(w => w === "visualizer").length;
        return previous % 2 === 1;
    }

    /**
     * Espeja sólo el visualizador.
     *
     * Antes esto miraba si `mirrored` estaba definida, y ahí estaba el error: todo
     * widget que herede de Control (o sea, cualquier botón) trae una `mirrored` de
     * QtQuick.Controls que es de SOLO LECTURA. La propiedad existía, la asignación
     * explotaba. Por eso ahora se decide por nombre y no por introspección.
     */
    function applyMirror(item, name, names, index) {
        if (!item || name !== "visualizer") return;
        item.mirrored = root.getMirroredForIndex(names, index);
    }

    /**
     * Agrupado en píldoras.
     *
     * La barra escrita a mano mete los widgets en `BarGroup`, que es lo que
     * dibuja la píldora (`colLayer1` redondeado) y lo que hace que el selector
     * "Group style" (`bar.borderless`) signifique algo. La barra por layouts no
     * usaba `BarGroup` en ningún lado, así que con el layout personalizado
     * activo las píldoras desaparecían y ese ajuste no hacía nada.
     *
     * En modo "auto" cada tramo consecutivo entre dos `divisor` es un grupo,
     * que es exactamente la separación que hacía la barra a mano. El `divisor`
     * queda suelto: es el separador, no un miembro del grupo.
     */
    readonly property bool useGroups: !root.isMaterial && Config.options.bar.layouts.grouping === "auto"

    function buildGroups(names) {
        // El índice plano se conserva porque `applyMirror` lo necesita para
        // espejar los visualizadores de a pares dentro de toda la sección.
        const flat = names.map((name, index) => ({ name, index }));
        if (!root.useGroups)
            return flat.map(entry => ({ grouped: false, items: [entry] }));

        const groups = [];
        let current = null;
        for (const entry of flat) {
            if (entry.name === "divisor") {
                current = null;
                groups.push({ grouped: false, items: [entry] });
            } else {
                if (!current) {
                    current = { grouped: true, items: [] };
                    groups.push(current);
                }
                current.items.push(entry);
            }
        }
        return groups;
    }

    /** Con estilo Material, estos se pintan solos y la píldora los ensuciaría. */
    readonly property var pillBlacklist: ["workspaces", "divisor", "powerButton",
        "docktoPanel", "leftSidebarButton", "activeWindow"]

    function shouldPaintPill(name) {
        return root.isMaterial && !root.pillBlacklist.includes(name);
    }

    function pillColor(name) {
        switch (name) {
        case "media":
        case "sysTray":
            return Appearance.colors.colSecondaryContainer;
        case "resources":
            return Appearance.colors.colTertiaryContainer;
        default:
            return Appearance.colors.colPrimaryContainer;
        }
    }

    /** Un widget del layout, ya resuelto a su archivo. */
    component WidgetSlot: Loader {
        id: widgetSlot
        required property string widgetName
        required property var sectionNames
        required property int flatIndex

        Layout.fillHeight: true
        source: root.getWidgetUrl(widgetSlot.widgetName)

        onLoaded: root.applyMirror(item, widgetSlot.widgetName, widgetSlot.sectionNames, widgetSlot.flatIndex)
    }

    /** Una sección: la lista de nombres convertida en grupos de widgets. */
    component LayoutSection: RowLayout {
        id: section
        required property var names
        readonly property var groups: root.buildGroups(section.names)
        spacing: 4

        Repeater {
            model: section.groups

            delegate: Item {
                id: slot
                required property var modelData

                readonly property var soloEntry: slot.modelData.items[0]
                readonly property bool material: !slot.modelData.grouped && root.shouldPaintPill(slot.soloEntry.name)

                Layout.fillHeight: true
                implicitWidth: contentLoader.item?.implicitWidth ?? 0
                implicitHeight: Appearance.sizes.barHeight

                Loader {
                    id: contentLoader
                    anchors.centerIn: parent
                    sourceComponent: slot.modelData.grouped ? groupedComponent : slot.material ? materialComponent : plainComponent
                }

                Component {
                    id: groupedComponent
                    BarGroup {
                        Repeater {
                            model: slot.modelData.items
                            delegate: WidgetSlot {
                                required property var modelData
                                widgetName: modelData.name
                                sectionNames: section.names
                                flatIndex: modelData.index
                            }
                        }
                    }
                }

                Component {
                    id: plainComponent
                    WidgetSlot {
                        widgetName: slot.soloEntry.name
                        sectionNames: section.names
                        flatIndex: slot.soloEntry.index
                    }
                }

                Component {
                    id: materialComponent
                    MaterialPill {
                        bgColor: root.pillColor(slot.soloEntry.name)

                        WidgetSlot {
                            widgetName: slot.soloEntry.name
                            sectionNames: section.names
                            flatIndex: slot.soloEntry.index
                        }
                    }
                }
            }
        }
    }

    LayoutSection {
        id: leftSection
        names: root.effectiveLeftLayout
        anchors {
            left: parent.left
            verticalCenter: parent.verticalCenter
            leftMargin: 8
        }
    }

    LayoutSection {
        id: centerSection
        names: root.effectiveMiddleLayout
        anchors.centerIn: parent
    }

    LayoutSection {
        id: rightSection
        names: root.effectiveRightLayout
        anchors {
            right: parent.right
            verticalCenter: parent.verticalCenter
            rightMargin: 8
        }
    }
}
