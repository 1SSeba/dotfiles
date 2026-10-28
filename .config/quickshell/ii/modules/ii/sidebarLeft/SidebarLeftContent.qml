import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Qt.labs.synchronizer
import qs.modules.ii.dock

Item {
    id: root
    required property var scopeRoot
    property int sidebarPadding: 10
    anchors.fill: parent
    property bool aiChatEnabled: Config.options.policies.ai !== 0
    property bool translatorEnabled: Config.options.sidebar.translator.enable
    property bool animeEnabled: Config.options.policies.weeb !== 0
    property bool animeCloset: Config.options.policies.weeb === 2
    property bool inspoEnabled: Config.options.sidebar.inspo.enable
    property bool musicEnabled: Config.options.sidebar.music.enable
    property bool socialEnabled: Config.options.sidebar.social.enable
    property var tabButtonList: [
        ...(root.aiChatEnabled ? [{"icon": "neurology", "name": Translation.tr("Intelligence")}] : []),
        ...(root.translatorEnabled ? [{"icon": "translate", "name": Translation.tr("Translator")}] : []),
        ...(root.inspoEnabled ? [{"icon": "palette", "name": Translation.tr("Inspo")}] : []),
        ...(root.musicEnabled ? [{"icon": "music_note", "name": Translation.tr("Music")}] : []),
        ...(root.socialEnabled ? [{"icon": "public", "name": Translation.tr("Social")}] : []),
        ...((root.animeEnabled && !root.animeCloset) ? [{"icon": "bookmark_heart", "name": Translation.tr("Anime")}] : [])
    ]
    property int tabCount: swipeView.count

    /**
     * Componentes de cada pestaña, EN EL MISMO ORDEN que `tabButtonList`.
     *
     * Antes esto era `contentChildren: [aiChat.createObject(), ...]`: se
     * instanciaban las seis pestañas juntas al nacer el sidebar (o sea, al
     * arrancar la shell), aunque no abrieras ninguna. Eso significaba tener
     * viva, todo el tiempo, la grilla de Booru, el cliente de Spotify, el de
     * Matrix y — la peor — la webview de Social, que es un Chromium entero.
     * Además, si cambiaba cualquiera de los `*Enabled` la lista se reevaluaba y
     * volvía a llamar `createObject()` para TODAS, dejando huérfanas las de
     * antes.
     *
     * Ahora cada pestaña vive en un Loader que se activa la primera vez que la
     * mirás y queda viva de ahí en más (no se descarga al cambiar de pestaña:
     * perder el chat a medio escribir sería peor que la memoria que ahorra).
     */
    readonly property var tabComponents: {
        const list = [];
        if (root.aiChatEnabled) list.push(aiChat);
        if (root.translatorEnabled) list.push(translator);
        if (root.inspoEnabled) list.push(inspo);
        if (root.musicEnabled) list.push(music);
        if (root.socialEnabled) list.push(social);
        if (root.tabButtonList.length === 0
            || (!root.aiChatEnabled && !root.translatorEnabled && !root.inspoEnabled
                && !root.musicEnabled && !root.socialEnabled && root.animeCloset))
            list.push(placeholder);
        if (root.animeEnabled) list.push(anime);
        return list;
    }

    function focusActiveItem() {
        swipeView.currentItem.forceActiveFocus()
    }

    Keys.onPressed: (event) => {
        if (event.modifiers === Qt.ControlModifier) {
            if (event.key === Qt.Key_PageDown) {
                swipeView.incrementCurrentIndex()
                event.accepted = true;
            }
            else if (event.key === Qt.Key_PageUp) {
                swipeView.decrementCurrentIndex()
                event.accepted = true;
            }
        }
    }

    ColumnLayout {
        anchors {
            fill: parent
            margins: sidebarPadding
        }
        spacing: sidebarPadding

        // `sidebar.media.enable` tenía switch en Settings y ningún lector.
        // Va arriba del tab bar para que el reproductor se vea desde cualquier
        // pestaña, no sólo desde Música. Se reusa `DockMedia`, que se colapsa
        // solo cuando no hay nada sonando.
        Loader {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredHeight: active ? 56 : 0
            visible: active && (item?.visible ?? false)
            active: Config.options.sidebar.media.enable

            sourceComponent: DockMedia {
                cardWidth: root.width - root.sidebarPadding * 2
                implicitHeight: 56
                useArtColors: Config.options.sidebar.media.artColors
            }
        }

        Toolbar {
            visible: tabButtonList.length > 0
            Layout.alignment: Qt.AlignHCenter
            enableShadow: false
            ToolbarTabBar {
                id: tabBar
                Layout.alignment: Qt.AlignHCenter
                tabButtonList: root.tabButtonList
                // Lo que queda del panel descontando su margen y el del Toolbar
                availableWidth: root.width - root.sidebarPadding * 2 - 8 * 2

                // Sincronización explícita con el SwipeView, en los dos sentidos
                // y con guarda de igualdad. Antes eran DOS bindings cruzadas
                // (`tabBar.currentIndex: swipeView.currentIndex` y
                // `swipeView.currentIndex: tabBar.currentIndex`): cualquier
                // asignación imperativa —arrastrar el SwipeView, o el
                // Ctrl+AvPág de más arriba— rompía una de las dos y a partir de
                // ahí la barra y el contenido quedaban desincronizados.
                onCurrentIndexChanged: if (swipeView.currentIndex !== tabBar.currentIndex) swipeView.setCurrentIndex(tabBar.currentIndex)
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            implicitWidth: swipeView.implicitWidth
            implicitHeight: swipeView.implicitHeight
            radius: Appearance.rounding.normal
            color: Appearance.colors.colLayer1

            SwipeView { // Content pages
                id: swipeView
                anchors.fill: parent
                spacing: 10

                onCurrentIndexChanged: if (tabBar.currentIndex !== swipeView.currentIndex) tabBar.setCurrentIndex(swipeView.currentIndex)

                clip: true
                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: swipeView.width
                        height: swipeView.height
                        radius: Appearance.rounding.small
                    }
                }

                Repeater {
                    model: root.tabComponents

                    delegate: Loader {
                        id: pageLoader
                        required property var modelData
                        /** Ya se abrió alguna vez: se instancia y no se vuelve a descargar. */
                        property bool everShown: false
                        readonly property bool isCurrent: SwipeView.isCurrentItem

                        onIsCurrentChanged: if (pageLoader.isCurrent) pageLoader.everShown = true
                        Component.onCompleted: if (pageLoader.isCurrent) pageLoader.everShown = true

                        active: pageLoader.everShown
                        sourceComponent: pageLoader.modelData
                    }
                }
            }
        }

        Component {
            id: aiChat
            AiChat {}
        }
        Component {
            id: translator
            Translator {}
        }
        Component {
            id: inspo
            Inspo {}
        }
        Component {
            id: music
            Music {}
        }
        Component {
            id: social
            Social {}
        }
        Component {
            id: anime
            Anime {}
        }
        Component {
            id: placeholder
            Item {
                StyledText {
                    anchors.centerIn: parent
                    text: root.animeCloset ? Translation.tr("Nothing") : Translation.tr("Enjoy your empty sidebar...")
                    color: Appearance.colors.colSubtext
                }
            }
        }
    }
}