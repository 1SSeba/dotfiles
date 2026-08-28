pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

/**
 * Tu cuenta de Google dentro de la shell.
 *
 * Este singleton es lo único que sabe de OAuth: los servicios de arriba
 * (GoogleCalendar, GoogleTasks) sólo llaman a `request(...)` y se olvidan de
 * tokens. Mismo molde que SpotifyService, con tres diferencias que importan:
 *
 *  1. Google exige `client_secret` incluso en clientes "Desktop app" con PKCE.
 *     No es realmente secreto, pero va al keyring igual que los tokens.
 *
 *  2. El refresh token es para siempre — pero sólo si el proyecto en Google
 *     Cloud Console está publicado "In production". En "Testing" vence a los 7
 *     días y habría que reconectar cada semana. Ver docs/CUENTAS.md.
 *
 *  3. Google puede no devolver refresh token en una renovación. Si lo pisáramos
 *     con vacío, la sesión quedaría muerta sin manera de recuperarse salvo
 *     volver a loguearse. `storeTokens` conserva siempre el viejo.
 *
 * OJO con el keyring: carga asincrónico. Un `readonly property` que lo lea se
 * evalúa antes de que haya datos y queda clavado en "" para siempre — el bug que
 * está documentado en SpotifyService.qml. Por eso los tokens se leen con
 * `tokenField()`, que va al keyring en el momento y sin binding de por medio.
 */
Singleton {
    id: root

    readonly property string tokenEndpoint: "https://oauth2.googleapis.com/token"
    readonly property string revokeEndpoint: "https://oauth2.googleapis.com/revoke"

    readonly property string clientId: Config.options?.services?.google?.clientId ?? ""
    readonly property int callbackPort: Config.options?.services?.google?.callbackPort ?? 8890

    // ------------------------------------------------------------------ //
    // Tokens
    // ------------------------------------------------------------------ //

    /** Lee un campo del keyring en el momento, sin binding (ver comentario de arriba). */
    function field(name) {
        const data = KeyringStorage.keyringData?.google;
        if (!data) return "";
        const value = data[name];
        return (value === undefined || value === null) ? "" : String(value);
    }

    /**
     * El secret no está en Config.qml a propósito: aunque en apps de escritorio
     * no sea un secreto de verdad, no tiene por qué quedar en un JSON de config
     * que se copia y se versiona.
     */
    readonly property string clientSecret: KeyringStorage.keyringData?.google?.client_secret ?? ""

    // Sólo para la UI (acá el binding sí se re-evalúa porque algo lo observa)
    readonly property string accessToken: KeyringStorage.keyringData?.google?.access_token ?? ""
    readonly property bool configured: root.clientId.length > 0 && root.clientSecret.length > 0
    readonly property bool connected: root.accessToken.length > 0

    /** idle | waiting | working | error */
    property string state: "idle"
    property string lastError: ""
    /**
     * Google rechazó el refresh token de raíz (revocado, expirado, proyecto en
     * Testing). No hay renovación posible: hace falta volver a conectar a mano.
     * Se separa de `state === "error"` porque un 500 pasajero no es esto.
     */
    property bool needsReauth: false

    property int pending: 0
    readonly property bool loading: root.pending > 0
    property string profileEmail: ""

    readonly property string status: {
        if (!root.connected) return Translation.tr("Sin conectar");
        if (root.needsReauth) return Translation.tr("La sesión se cortó. Volvé a conectar la cuenta.");
        if (root.state === "error") return root.lastError;
        if (root.loading) return Translation.tr("Sincronizando…");
        if (root.profileEmail.length > 0) return root.profileEmail;
        return Translation.tr("Conectado");
    }

    readonly property bool healthy: root.connected && !root.needsReauth && root.state !== "error"

    signal authUrlReady(string url)
    /** La emiten los servicios de arriba para saber cuándo pueden pedir datos. */
    signal ready()

    onConnectedChanged: {
        if (root.connected) {
            root.needsReauth = false;
            root.validate();
        } else {
            root.profileEmail = "";
        }
    }

    // ------------------------------------------------------------------ //
    // Login
    // ------------------------------------------------------------------ //

    Process {
        id: authProc
        stdout: SplitParser {
            onRead: line => {
                const space = line.indexOf(" ");
                if (space < 0) return;
                const tag = line.substring(0, space);
                const payload = line.substring(space + 1);

                if (tag === "AUTHURL") {
                    root.state = "waiting";
                    root.authUrlReady(payload);
                    Quickshell.execDetached(["xdg-open", payload]);
                } else if (tag === "TOKENS") {
                    try {
                        root.storeTokens(JSON.parse(payload));
                        root.state = "idle";
                        root.lastError = "";
                        root.needsReauth = false;
                        root.validate();
                        root.ready();
                    } catch (e) {
                        root.fail(String(e));
                    }
                } else if (tag === "ERROR") {
                    root.fail(payload);
                }
            }
        }
        onExited: exitCode => {
            if (root.state === "waiting") root.state = "idle";
        }
    }

    /**
     * Abre el navegador y no pide nada más. La página guía la creación del
     * cliente en Google Cloud Console con un link por paso, toma el Client ID y
     * el Secret ahí mismo, sigue sola a la pantalla de permisos y vuelve con los
     * tokens. Antes esto eran seis pasos a mano y dos credenciales tipeadas en
     * este panel; ahora es un click.
     *
     * Si ya hay un cliente cargado se lo pasa para no tener que retipearlo, y si
     * no hace falta la pantalla guiada (por ejemplo para reconectar rápido) el
     * atajo es `relogin()`, que salta directo al permiso.
     */
    function login() {
        root.state = "working";
        root.lastError = "";
        authProc.running = false;
        authProc.command = ["python3",
            `${Directories.scriptPath}/google/connect.py`.replace(/file:\/\//, ""),
            String(root.callbackPort), root.clientId];
        authProc.running = true;
    }

    /** Reconectar con el cliente que ya está guardado: sin pasos, directo al permiso. */
    function relogin() {
        if (!root.configured) {
            root.login();
            return;
        }
        root.state = "working";
        root.lastError = "";
        authProc.running = false;
        authProc.command = ["python3",
            `${Directories.scriptPath}/google/auth.py`.replace(/file:\/\//, ""),
            root.clientId, root.clientSecret, String(root.callbackPort)];
        authProc.running = true;
    }

    /** Cancela una conexión a medias (la página quedó abierta y nunca se completó). */
    function cancelLogin() {
        authProc.running = false;
        root.state = "idle";
    }

    /**
     * Borra la sesión local y le avisa a Google que olvide el grant. Sin el
     * revoke, un login posterior puede reusar el grant viejo y no devolver
     * refresh token — el caso que auth.py detecta y reporta.
     */
    function logout() {
        const refresh = root.field("refresh_token");
        if (refresh.length > 0) {
            const xhr = new XMLHttpRequest();
            xhr.open("POST", root.revokeEndpoint);
            xhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded");
            xhr.send(`token=${encodeURIComponent(refresh)}`);
        }
        // El client_secret sobrevive al logout: es config de la app, no de la sesión
        const secret = root.clientSecret;
        KeyringStorage.setNestedField(["google"], secret.length > 0 ? ({ "client_secret": secret }) : ({}));
        root.profileEmail = "";
        root.state = "idle";
        root.lastError = "";
        root.needsReauth = false;
    }

    function setClientSecret(secret) {
        KeyringStorage.setNestedField(["google", "client_secret"], String(secret).trim());
    }

    function fail(message) {
        root.lastError = message;
        root.state = "error";
        console.log("[GoogleAccount]", message);
    }

    function storeTokens(data) {
        if (!data || !data.access_token) throw new Error("respuesta sin access_token");
        const previous = KeyringStorage.keyringData?.google ?? {};
        // El flujo guiado devuelve el cliente junto con los tokens (lo tipeaste en
        // el navegador, no acá). El Client ID además va a la config, que es donde
        // lo buscan las peticiones; el secret se queda en el keyring.
        if (data.client_id) Config.options.services.google.clientId = String(data.client_id);
        if (data.client_secret) previous.client_secret = String(data.client_secret);
        KeyringStorage.setNestedField(["google"], Object.assign({}, previous, {
            "access_token": data.access_token,
            // En una renovación Google no manda uno nuevo: se conserva el viejo.
            // Pisarlo con vacío dejaría la sesión sin forma de renovarse.
            "refresh_token": (data.refresh_token && String(data.refresh_token).length > 0)
                ? data.refresh_token
                : root.field("refresh_token"),
            "expires_at": Date.now() + (data.expires_in ?? 3600) * 1000
        }));
    }

    // ------------------------------------------------------------------ //
    // Renovación
    // ------------------------------------------------------------------ //

    function renew(next) {
        const refresh = root.field("refresh_token");
        if (refresh.length === 0) {
            root.needsReauth = true;
            root.fail(Translation.tr("No hay refresh token. Volvé a conectar la cuenta."));
            return;
        }
        const body = `grant_type=refresh_token`
            + `&refresh_token=${encodeURIComponent(refresh)}`
            + `&client_id=${encodeURIComponent(root.clientId)}`
            + `&client_secret=${encodeURIComponent(root.clientSecret)}`;

        const xhr = new XMLHttpRequest();
        xhr.open("POST", root.tokenEndpoint);
        xhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded");
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (xhr.status === 0) {
                // Sin red: no es una sesión rota, no marcamos needsReauth
                root.fail(Translation.tr("Sin conexión con Google"));
                return;
            }
            if (xhr.status !== 200) {
                let reason = "";
                try { reason = JSON.parse(xhr.responseText)?.error ?? ""; } catch (e) {}
                if (reason === "invalid_grant") {
                    // El único caso en que reconectar a mano es inevitable
                    root.needsReauth = true;
                    root.fail(Translation.tr("Google invalidó la sesión (invalid_grant). "
                        + "Suele pasar si el proyecto quedó en «Testing» o si le sacaste el acceso a la app. "
                        + "Volvé a conectar la cuenta."));
                } else {
                    root.fail(Translation.tr("No se pudo renovar la sesión (%1 %2)").arg(xhr.status).arg(reason));
                }
                return;
            }
            try {
                root.storeTokens(JSON.parse(xhr.responseText));
                root.needsReauth = false;
                if (next) next();
            } catch (e) {
                root.fail(String(e));
            }
        };
        xhr.send(body);
    }

    // ------------------------------------------------------------------ //
    // Peticiones
    // ------------------------------------------------------------------ //

    /**
     * Una petición a cualquier API de Google. Renueva el token si está por
     * vencer, y si igual vuelve 401 reintenta una sola vez para no entrar en bucle.
     *
     * `onFail` deja que un servicio falle sin ensuciar el estado global: que
     * Tasks no responda no tiene por qué mostrar el calendario como roto.
     */
    function request(method, url, body, callback, onFail, isRetry = false) {
        const token = root.field("access_token");
        if (token.length === 0) {
            if (onFail) onFail(Translation.tr("No hay sesión de Google"));
            return;
        }
        const expiresAt = Number(root.field("expires_at") || 0);
        // 60s de colchón: una petición que sale justo antes del vencimiento
        // llegaría al server ya vencida
        if (Date.now() > expiresAt - 60000 && !isRetry) {
            root.renew(() => root.request(method, url, body, callback, onFail, true));
            return;
        }

        const report = message => {
            if (onFail) onFail(message);
            else root.fail(message);
        };

        root.pending++;
        const xhr = new XMLHttpRequest();
        xhr.open(method, url);
        xhr.setRequestHeader("Authorization", `Bearer ${token}`);
        if (body !== null && body !== undefined)
            xhr.setRequestHeader("Content-Type", "application/json");

        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            root.pending = Math.max(0, root.pending - 1);

            if (xhr.status === 401 && !isRetry) {
                root.renew(() => root.request(method, url, body, callback, onFail, true));
                return;
            }
            if (xhr.status === 0) {
                report(Translation.tr("Sin conexión con Google"));
                return;
            }
            if (xhr.status === 403) {
                let reason = "";
                try { reason = JSON.parse(xhr.responseText)?.error?.message ?? ""; } catch (e) {}
                report(Translation.tr("Google rechazó el permiso (403). %1").arg(reason));
                return;
            }
            if (xhr.status === 429) {
                report(Translation.tr("Demasiadas peticiones a Google. Esperá un momento."));
                return;
            }
            if (xhr.status === 204 || xhr.responseText.length === 0) {
                if (callback) callback(null);
                if (root.state === "error") { root.state = "idle"; root.lastError = ""; }
                return;
            }
            if (xhr.status < 200 || xhr.status >= 300) {
                let reason = "";
                try { reason = JSON.parse(xhr.responseText)?.error?.message ?? ""; } catch (e) {}
                report(Translation.tr("Google respondió %1. %2").arg(xhr.status).arg(reason));
                return;
            }
            try {
                if (callback) callback(JSON.parse(xhr.responseText));
                if (root.state === "error") {
                    // Una petición que sale bien limpia el error viejo
                    root.state = "idle";
                    root.lastError = "";
                }
            } catch (e) {
                report(String(e));
            }
        };
        xhr.send((body !== null && body !== undefined) ? JSON.stringify(body) : undefined);
    }

    function api(url, callback, onFail) {
        root.request("GET", url, null, callback, onFail);
    }

    /**
     * Comprueba que el token sirva de verdad pidiendo el mail de la cuenta.
     * Es el validador: si esto anda, un calendario vacío es un calendario vacío
     * y no una sesión rota.
     */
    function validate() {
        root.api("https://www.googleapis.com/oauth2/v2/userinfo", data => {
            if (!data) return;
            root.profileEmail = data.email ?? "";
            root.ready();
        });
    }

    /**
     * El keyring carga después que la shell. Cuando aparecen los datos hay que
     * revalidar: al arrancar, `connected` ya era true antes de que nadie mirara.
     */
    Connections {
        target: KeyringStorage
        function onLoadedChanged() {
            if (root.connected) root.validate();
        }
    }

    Component.onCompleted: {
        if (!KeyringStorage.loaded) KeyringStorage.fetchKeyringData();
    }
}
