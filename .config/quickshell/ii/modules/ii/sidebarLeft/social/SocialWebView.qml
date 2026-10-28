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
 * Cada red se lleva su propio perfil, nombrado de forma estable y guardado en
 * disco bajo ~/.local/state/quickshell/user/social/<perfil>, para que las cuentas
 * no se pisen entre sí. Si `persistCookies` está prendido la sesión sobrevive a
 * los reinicios (WhatsApp no te hace escanear el QR de nuevo); si no, las cookies
 * quedan en memoria nomás y se pierden al cerrar la shell.
 */
Item {
    id: root
    // required: así el Loader las inyecta ANTES de que se evalúen las bindings,
    // y el perfil nace ya con su storageName/policy en vez de arrancar con uno
    // y migrar a mitad de camino.
    required property string startUrl
    required property string storageName
    required property bool persistCookies

    WebEngineView {
        id: view
        anchors.fill: parent
        url: root.startUrl

        // WebEngineProfilePrototype (la API recomendada desde 6.9) revienta la
        // shell al llamar instance() acá, así que seguimos con el WebEngineProfile
        // clásico. Tira un warning de deprecación y nada más.
        profile: WebEngineProfile {
            storageName: root.storageName
            // Explícito: un perfil off-the-record ignora la política de cookies
            // y el storage path (todo vive en RAM y se va con la shell), así que
            // no lo dejamos librado al default de Qt.
            offTheRecord: false
            // Un path propio por red bajo ~/.local/state/quickshell/user/social.
            // El default (AppDataLocation + storageName) cuelga del nombre de app
            // con el que arrancó Quickshell, así que se movía de lugar solo.
            persistentStoragePath: `${Directories.socialProfiles}/${root.storageName}`
            cachePath: `${Directories.socialProfilesCache}/${root.storageName}`
            httpCacheType: WebEngineProfile.DiskHttpCache
            persistentCookiesPolicy: root.persistCookies
                ? WebEngineProfile.ForcePersistentCookies
                : WebEngineProfile.NoPersistentCookies
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
