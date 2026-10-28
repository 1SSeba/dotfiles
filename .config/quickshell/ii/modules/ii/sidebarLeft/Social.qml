pragma ComponentBehavior: Bound

import qs.services // Translation vive en services/
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

/**
 * Redes sociales en el sidebar: una mini pestaña por red, y adentro de cada una
 * la webapp embebida.
 *
 * Las pestañas salen de `Config.options.sidebar.social.links`, así que agregar,
 * sacar o reordenar redes es editar la config (o la página Sidebar de Settings).
 *
 * El WebEngineView vive en social/SocialWebView.qml y se carga **a mano con un
 * Loader**, nunca con un import: sin el shim de LD_PRELOAD, instanciar uno mata
 * la shell entera (Quickshell arranca con argc = 0 y Chromium aborta con
 * "Argument list is empty"). El shim exporta QS_WEBENGINE=1; si no está, cada
 * pestaña cae al modo "botón Abrir" y la red se abre en el navegador.
 * Ver ~/.local/lib/qs-webengine-shim/.
 *
 * Cada pestaña se carga recién la primera vez que la visitás, y de ahí en más
 * queda viva: así el arranque del sidebar no paga tres Chromium de una, pero la
 * sesión de WhatsApp no se cae cada vez que cambiás de pestaña.
 */
Item {
    id: root
    property real padding: 8

    readonly property var links: Config.options?.sidebar?.social?.links ?? []

    /**
     * Matrix va como primera pestaña, antes de las webapps. Es la que trae los
     * puentes (mautrix-*), así que WhatsApp y compañía entran por acá sin
     * Chromium de por medio.
     *
     * Al ir primero corre los índices de `links` en uno: de ahí `tabOffset`.
     */
    readonly property bool matrixEnabled: Config.options?.sidebar?.social?.matrix?.enable ?? false
    readonly property int tabOffset: root.matrixEnabled ? 1 : 0

    // El shim exporta esto. Sin shim la variable no existe y no hay que ni tocar
    // un WebEngineView.
    readonly property bool webEngineAvailable: Quickshell.env("QS_WEBENGINE") === "1"

    /**
     * Abre en el navegador con xdg-open, que es lo que ya usa el resto de la shell.
     *
     * Sin el `cursor:no_warps` que hace Inspo: `keyword` no es un dispatcher de
     * Hyprland, así que esa llamada siempre falla ("Invalid dispatcher") y lo único
     * que lograba era ensuciar el log.
     */
    function openLink(url) {
        if (!url || url.length === 0) return;
        Quickshell.execDetached(["xdg-open", url]);
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.padding
        spacing: 0
        visible: root.links.length > 0 || root.matrixEnabled

        SecondaryTabBar {
            id: tabBar
            // Alto por defecto a propósito: el SecondaryTabButton mide 48 px y
            // apretar la barra más que eso recorta los botones.

            // `sidebar.social.defaultView` no tenía ni UI ni lector: ahora elige
            // con qué pestaña abre el panel, "chats" (Matrix) o la primera red.
            Component.onCompleted: {
                const wantsChats = (Config.options?.sidebar?.social?.defaultView ?? "chats") === "chats";
                tabBar.currentIndex = (root.matrixEnabled && wantsChats) ? 0 : root.tabOffset;
            }

            // Repeater con modelo 0/1 y no `visible: false`: un TabButton
            // escondido sigue contando para `currentIndex` y `count`.
            Repeater {
                model: root.matrixEnabled ? 1 : 0
                delegate: SecondaryTabButton {
                    buttonText: Translation.tr("Chats")
                }
            }

            Repeater {
                model: root.links
                delegate: SecondaryTabButton {
                    required property var modelData
                    buttonText: modelData.name ?? ""
                }
            }
        }

        StackLayout {
            id: stack
            Layout.topMargin: 6
            Layout.fillWidth: true
            Layout.fillHeight: true
            // StackLayout y no SwipeView a propósito: el arrastre del SwipeView
            // pelea con el scroll y los gestos de adentro de la webapp.
            currentIndex: tabBar.currentIndex

            Repeater {
                model: root.matrixEnabled ? 1 : 0
                // Por Loader y no por import, igual que la webview: el
                // directorio `social/` tiene el SocialWebView, y este archivo
                // evita importarlo a propósito.
                delegate: Loader {
                    id: matrixLoader
                    source: "social/MatrixChats.qml"

                    // El /sync es un long-poll: sólo sincroniza con la pestaña
                    // a la vista.
                    Binding {
                        target: matrixLoader.item
                        property: "active"
                        value: stack.currentIndex === 0
                    }
                }
            }

            Repeater {
                model: root.links

                delegate: Item {
                    id: page
                    required property var modelData
                    required property int index
                    readonly property string url: page.modelData.url ?? ""
                    readonly property string name: page.modelData.name ?? ""

                    // Un perfil por red, con nombre estable: la sesión sobrevive
                    // a los reinicios y las cuentas no se pisan entre sí. El index
                    // es el desempate para nombres que quedan vacíos al limpiarlos
                    // (por ejemplo uno escrito sólo con emoji).
                    readonly property string storageName: {
                        const slug = page.name.toLowerCase().replace(/[^a-z0-9]/g, "");
                        return "social-" + (slug.length > 0 ? slug : "net" + page.index);
                    }

                    // Sólo la pestaña abierta se carga; una vez cargada se queda.
                    //
                    // El disparador es `currentIndex` y NO `visible`: mientras el
                    // StackLayout se está armando, todas las páginas pasan por
                    // visible = true antes de que les asigne la visibilidad real,
                    // así que atarse a `visible` levanta los tres Chromium juntos
                    // apenas nace el sidebar — justo lo que la carga perezosa
                    // quiere evitar.
                    readonly property bool isCurrent: stack.currentIndex === page.index + root.tabOffset
                    onIsCurrentChanged: if (page.isCurrent) webLoader.load()
                    Component.onCompleted: if (page.isCurrent) webLoader.load()

                    Loader {
                        id: webLoader
                        anchors.fill: parent

                        function load() {
                            if (!root.webEngineAvailable) return;
                            if (webLoader.status !== Loader.Null) return; // ya cargada
                            // setSource y no sourceComponent: el tipo no se puede
                            // importar sin arriesgar la shell (ver el comentario
                            // de arriba), y así las required properties entran
                            // antes de que se evalúen las bindings.
                            webLoader.setSource("social/SocialWebView.qml", {
                                "startUrl": page.url,
                                "storageName": page.storageName,
                                "persistCookies": Config.options?.sidebar?.social?.persistCookies ?? false
                            });
                        }
                    }

                    // ---------------- Sin shim: abrir afuera ---------------- //

                    ColumnLayout {
                        anchors.centerIn: parent
                        width: Math.min(parent.width - root.padding * 2, 280)
                        spacing: 4
                        visible: !root.webEngineAvailable

                        // Si el link trae `icon` (glifo de Nerd Font) lo usamos:
                        // es vectorial y se ve nítido a cualquier tamaño. Si no,
                        // caemos al favicon del sitio, que suele venir en 16-32px.
                        Loader {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.bottomMargin: 8
                            // Loader tiene implicitWidth/Height de solo lectura, así
                            // que el tamaño va por Layout.
                            Layout.preferredWidth: 48
                            Layout.preferredHeight: 48
                            sourceComponent: (page.modelData.icon ?? "").length > 0
                                ? nerdIconComponent : faviconComponent

                            Component {
                                id: nerdIconComponent
                                StyledText {
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    text: page.modelData.icon ?? ""
                                    font.family: Appearance.font.family.iconNerd
                                    font.pixelSize: 42
                                    color: Appearance.colors.colPrimary
                                }
                            }

                            Component {
                                id: faviconComponent
                                Favicon {
                                    url: page.url
                                    displayText: page.name
                                    size: 48
                                    implicitSize: 48
                                }
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: page.name
                            font.pixelSize: Appearance.font.pixelSize.larger
                            color: Appearance.colors.colOnLayer1
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            Layout.bottomMargin: 12
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.Wrap
                            text: Translation.tr("Falta el shim de WebEngine,\nasí que la webapp va afuera")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                        }

                        RippleButtonWithIcon {
                            Layout.alignment: Qt.AlignHCenter
                            materialIcon: "open_in_new"
                            mainText: Translation.tr("Abrir")
                            onClicked: root.openLink(page.url)

                            StyledToolTip {
                                text: page.url
                            }
                        }
                    }
                }
            }
        }
    }

    PagePlaceholder {
        anchors.fill: parent
        shown: root.links.length === 0
        icon: "public"
        title: Translation.tr("Sin enlaces")
        description: Translation.tr("Agregá tus redes en Settings → Sidebar,\no en sidebar.social.links")
    }
}
