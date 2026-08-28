pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

/**
 * Tu cuenta de iCloud dentro de la shell.
 *
 * Es el equivalente de GoogleAccount, pero por debajo no hay OAuth: Apple no lo
 * ofrece para esto. "Iniciar sesión con Apple" te loguea en *otros* sitios, no
 * da acceso a tus datos de iCloud. Lo único que existe para un cliente de
 * terceros es CalDAV/IMAP con una contraseña de aplicación.
 *
 * Aun así la conexión se siente igual que un OAuth: `login()` abre el navegador,
 * la página explica y linkea directo a donde se genera la contraseña, y lo que
 * escribas se verifica de verdad contra iCloud antes de guardarse. En el panel
 * de Ajustes no hay ningún campo de secreto. Todo eso lo hace
 * scripts/accounts/connect.py, que habla el mismo protocolo que google/auth.py.
 *
 * La otra diferencia con Google: acá no hay XMLHttpRequest. CalDAV es PROPFIND y
 * REPORT con cuerpos XML, así que el trabajo lo hace scripts/apple/caldav.py y
 * este singleton es la cola que lo llama. Un solo proceso por vez a propósito:
 * iCloud limita las peticiones simultáneas y una tanda en paralelo se come 503s.
 *
 * La contraseña viaja por variable de entorno, nunca por argumento: lo que va en
 * argv lo ve cualquiera que corra `ps`.
 */
Singleton {
    id: root

    readonly property string user: Config.options?.services?.apple?.user ?? ""
    readonly property int connectPort: Config.options?.services?.apple?.connectPort ?? 8891

    /** La contraseña de aplicación vive en el keyring, jamás en la config. */
    readonly property string appPassword: KeyringStorage.keyringData?.apple?.appPassword ?? ""

    readonly property bool connected: root.user.length > 0 && root.appPassword.length > 0

    /** idle | waiting | working | error */
    property string state: "idle"
    property string lastError: ""
    /**
     * iCloud rechazó la credencial de raíz (contraseña revocada desde
     * account.apple.com, o cambiada). No hay renovación posible: hay que volver
     * a conectar. Se separa de `state === "error"` porque quedarse sin red no
     * es esto.
     */
    property bool needsReauth: false

    property int pending: 0
    readonly property bool loading: root.pending > 0 || root.state === "working"

    readonly property string status: {
        if (!root.connected) return Translation.tr("Sin conectar");
        if (root.needsReauth) return Translation.tr("La contraseña de aplicación dejó de servir. Volvé a conectar la cuenta.");
        if (root.state === "error") return root.lastError;
        if (root.loading) return Translation.tr("Sincronizando…");
        return root.user;
    }

    readonly property bool healthy: root.connected && !root.needsReauth && root.state !== "error"

    signal authUrlReady(string url)
    /** La emiten los servicios de arriba para saber cuándo pueden pedir datos. */
    signal ready()

    // ------------------------------------------------------------------ //
    // Conexión
    // ------------------------------------------------------------------ //

    Process {
        id: connectProc
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
                } else if (tag === "CREDS") {
                    try {
                        root.storeCredentials(JSON.parse(payload));
                        root.state = "idle";
                        root.lastError = "";
                        root.needsReauth = false;
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
            if (root.state === "waiting" || root.state === "working") root.state = "idle";
        }
    }

    /** Abre el navegador. La credencial ya viene verificada cuando vuelve. */
    function login() {
        root.state = "working";
        root.lastError = "";
        connectProc.running = false;
        connectProc.command = ["python3",
            `${Directories.scriptPath}/accounts/connect.py`.replace(/file:\/\//, ""),
            "icloud", String(root.connectPort)];
        connectProc.running = true;
    }

    /** Cancela una conexión a medias (la página quedó abierta y nunca se mandó). */
    function cancelLogin() {
        connectProc.running = false;
        root.state = "idle";
    }

    function storeCredentials(data) {
        if (!data || !data.user || !data.password) throw new Error("respuesta sin credenciales");
        // El Apple ID no es secreto y hay que poder verlo en Ajustes; la
        // contraseña de aplicación no sale nunca del keyring.
        Config.options.services.apple.user = String(data.user);
        KeyringStorage.setNestedField(["apple", "appPassword"], String(data.password));
    }

    /**
     * Borra la sesión local. No hay nada que revocar del lado de Apple desde
     * acá: la contraseña de aplicación se revoca en account.apple.com, y eso es
     * bueno — que la shell no pueda tocar tu cuenta más allá de olvidarla.
     */
    function logout() {
        KeyringStorage.setNestedField(["apple"], ({}));
        Config.options.services.apple.user = "";
        root.state = "idle";
        root.lastError = "";
        root.needsReauth = false;
        root.queue = [];
        root.current = null;
    }

    // ------------------------------------------------------------------ //
    // Cola de comandos
    // ------------------------------------------------------------------ //

    /** [{args, callback, onFail}] esperando turno */
    property var queue: []
    property var current: null
    /** Si el proceso terminó sin haber impreso nada, murió antes de poder hablar. */
    property bool answered: false

    /**
     * Corre un comando de caldav.py. `callback(data)` recibe el JSON ya parseado
     * (con `ok: true`); `onFail(mensaje)` deja que un servicio falle sin ensuciar
     * el estado global — que los recordatorios no respondan no tiene por qué
     * mostrar el calendario como roto.
     */
    function run(args, callback, onFail) {
        if (!root.connected) {
            if (onFail) onFail(Translation.tr("No hay cuenta de iCloud conectada"));
            return;
        }
        root.queue = root.queue.concat([({ "args": args, "callback": callback, "onFail": onFail })]);
        root.pending = root.queue.length + (root.current ? 1 : 0);
        root.pump();
    }

    function pump() {
        if (root.current !== null || root.queue.length === 0) return;
        root.current = root.queue[0];
        root.queue = root.queue.slice(1);
        root.answered = false;
        davProc.running = false;
        davProc.environment = ({ "APPLE_ID": root.user, "APPLE_PASSWORD": root.appPassword });
        davProc.command = ["python3",
            `${Directories.scriptPath}/apple/caldav.py`.replace(/file:\/\//, "")]
            .concat(root.current.args);
        davProc.running = true;
    }

    /** Cierra el comando en curso y arranca el siguiente. */
    function finish() {
        root.current = null;
        root.pending = root.queue.length;
        root.pump();
    }

    function reportFor(entry, message) {
        // Una credencial que dejó de servir no es un error pasajero: hasta que
        // no reconectes, todo lo demás va a fallar igual. Mejor decirlo una vez.
        if (message.indexOf("contrasenia de aplicacion") >= 0
            || message.indexOf("contraseña de aplicación") >= 0) {
            root.needsReauth = true;
        }
        if (entry && entry.onFail) entry.onFail(message);
        else root.fail(message);
    }

    Process {
        id: davProc
        stdout: SplitParser {
            onRead: line => {
                if (line.trim().length === 0) return;
                const entry = root.current;
                root.answered = true;
                try {
                    const data = JSON.parse(line);
                    if (!data.ok) {
                        root.reportFor(entry, data.error ?? Translation.tr("Error desconocido"));
                        return;
                    }
                    if (entry && entry.callback) entry.callback(data);
                    if (root.state === "error") {
                        // Un comando que sale bien limpia el error viejo
                        root.state = "idle";
                        root.lastError = "";
                    }
                    root.needsReauth = false;
                } catch (e) {
                    console.log("[AppleAccount] respuesta ilegible:", line);
                    root.reportFor(entry, String(e));
                }
            }
        }
        onExited: exitCode => {
            const entry = root.current;
            if (!root.answered)
                root.reportFor(entry, Translation.tr("El cliente de iCloud terminó con código %1").arg(exitCode));
            root.finish();
        }
    }

    // ------------------------------------------------------------------ //

    function fail(message) {
        root.lastError = message;
        root.state = "error";
        console.log("[AppleAccount]", message);
    }

    /**
     * Comprueba que la credencial siga sirviendo. Es el validador: si esto anda,
     * un calendario vacío es un calendario vacío y no una sesión rota.
     */
    function validate() {
        if (!root.connected) return;
        root.run(["verify"], () => {
            root.needsReauth = false;
            root.ready();
        }, message => root.fail(message));
    }

    onConnectedChanged: {
        if (root.connected) {
            root.needsReauth = false;
            root.validate();
        }
    }

    /**
     * El keyring carga después que la shell. Cuando aparecen los datos hay que
     * validar: al arrancar, `connected` todavía era false y nadie miró.
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
