pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtWebEngine

/**
 * La webapp de una red, embebida en el sidebar.
 *
 * Este archivo se carga a mano con un Loader (nunca con un import) porque
 * instanciar un WebEngineView sin el shim de LD_PRELOAD mata la shell entera:
 * Quickshell arranca con argc = 0 y Chromium aborta con "Argument list is empty".
 * Social.qml solo lo carga si QS_WEBENGINE=1, que es lo que exporta el shim.
 * Ver ~/.local/lib/qs-webengine-shim/.
 *
 * Cada red se lleva su propio perfil persistente, así que la sesión sobrevive a
 * los reinicios (WhatsApp no te hace escanear el QR de nuevo) y las cuentas no
 * se pisan entre sí.
 */
Item {
    id: root
    // required: así el Loader las inyecta ANTES de que se evalúen las bindings,
    // y el perfil nace ya con su storageName en vez de arrancar off-the-record y
    // migrar a disco a mitad de camino.
    required property string startUrl
    required property string storageName

    WebEngineView {
        id: view
        anchors.fill: parent
        url: root.startUrl

        // WebEngineProfilePrototype (la API recomendada desde 6.9) revienta la
        // shell al llamar instance() acá, así que seguimos con el WebEngineProfile
        // clásico. Tira un warning de deprecación y nada más.
        profile: WebEngineProfile {
            storageName: root.storageName
            persistentCookiesPolicy: WebEngineProfile.ForcePersistentCookies
        }

        Component.onCompleted: {
            // QtWebEngine se anuncia con un token propio en la UA y WhatsApp Web
            // lo usa para mandarte a "navegador no soportado". Sacando ese token
            // queda una UA de Chrome común y corriente.
            view.profile.httpUserAgent = view.profile.httpUserAgent.replace(/QtWebEngine\/[^ ]+ /, "");
        }


        settings {
            localStorageEnabled: true
            javascriptCanAccessClipboard: true
            javascriptCanPaste: true
            screenCaptureEnabled: false
            showScrollBars: false
        }

        // Solo dejamos pasar notificaciones. Lo demás (cámara, micrófono,
        // ubicación) queda denegado salvo que lo pidas explícitamente.
        onPermissionRequested: (permission) => {
            if (permission.permissionType === WebEnginePermission.Notifications) permission.grant();
            else permission.deny();
        }

        // Los target=_blank van al navegador de siempre, no abren una ventana
        // huérfana adentro del sidebar.
        onNewWindowRequested: (request) => {
            Qt.openUrlExternally(request.requestedUrl);
            request.action = WebEngineNewWindowRequest.InNewWindow;
        }
    }

    // Barra de progreso finita mientras carga, como cualquier navegador.
    Rectangle {
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 2
        color: "transparent"
        visible: view.loading

        Rectangle {
            height: parent.height
            width: parent.width * (view.loadProgress / 100)
            color: Appearance.colors.colPrimary
            Behavior on width {
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
            }
        }
    }
}
