pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

/**
 * Los mails sin leer, por IMAP, de todas tus cuentas a la vez.
 *
 * IMAP y no OAuth a propósito: una contraseña de aplicación no vence nunca, no
 * depende de que Google apruebe la app, y el mismo cliente sirve para Gmail,
 * iCloud y Proton cambiando el host.
 *
 * Proton es el raro: no expone IMAP a internet, porque tu correo está cifrado y
 * nadie fuera de tu máquina puede leerlo. El puente es Proton Mail Bridge, que
 * corre local, descifra ahí mismo y levanta un IMAP en loopback con STARTTLS.
 * Por eso una cuenta lleva su propio `security` y su propio puerto. Con OAuth, el contador de no leídos necesitaría
 * el scope `gmail.readonly`, que Google clasifica como "restricted", para
 * mostrar un numerito.
 *
 * El trabajo pesado lo hace scripts/mail/imap.py: QML no tiene cliente IMAP y
 * abrir un socket TLS a mano acá no tiene ningún sentido. Se corre una cuenta
 * por vez, no todas en paralelo: son varios segundos de TLS cada una y lanzar
 * cuatro procesos juntos al abrir la barra se nota.
 *
 * La contraseña viaja por variable de entorno, nunca por argumento: lo que va en
 * argv lo ve cualquiera que corra `ps`.
 */
Singleton {
    id: root

    readonly property int refreshMinutes: Config.options?.services?.mail?.refreshMinutes ?? 5
    readonly property int maxMessages: Config.options?.services?.mail?.maxMessages ?? 15

    // ------------------------------------------------------------------ //
    // Cuentas
    // ------------------------------------------------------------------ //

    /**
     * { id: contraseña }, leído del keyring de una sola vez.
     *
     * `mail.appPassword` suelto es la cuenta única de antes de que esto fuera
     * multicuenta: se mapea a la id "default" para que una config existente siga
     * andando sin tocar el keyring.
     */
    readonly property var passwords: {
        const data = KeyringStorage.keyringData?.mail ?? ({});
        const out = ({});
        Object.keys(data).forEach(key => {
            if (key === "appPassword") out["default"] = String(data[key] ?? "");
            else if (data[key] && data[key].appPassword) out[key] = String(data[key].appPassword);
        });
        return out;
    }

    /** Todas las cuentas declaradas, estén completas o no. Ajustes las lista así. */
    readonly property var allAccounts: {
        const raw = Config.options?.services?.mail?.accounts ?? [];
        const list = raw.filter(a => a && a.id).map(a => ({
            "id": String(a.id),
            "label": String(a.label ?? a.user ?? a.id),
            "host": String(a.host ?? "imap.gmail.com"),
            "port": Number(a.port ?? 993),
            "user": String(a.user ?? ""),
            "mailbox": String(a.mailbox ?? "INBOX"),
            // Proton va por STARTTLS contra el Bridge en loopback; el resto, SSL
            "security": String(a.security ?? "ssl"),
            "enable": a.enable !== false
        }));
        if (list.length > 0) return list;

        // Config vieja de una sola cuenta: se muestra como la cuenta "default".
        const legacy = Config.options?.services?.mail;
        const user = String(legacy?.user ?? "");
        if (user.length === 0) return [];
        return [({
            "id": "default",
            "label": user,
            "host": String(legacy?.host ?? "imap.gmail.com"),
            "port": Number(legacy?.port ?? 993),
            "user": user,
            "mailbox": String(legacy?.mailbox ?? "INBOX"),
            "security": "ssl",
            "enable": true
        })];
    }

    /** Las que se pueden consultar de verdad: prendidas y con contraseña. */
    readonly property var accounts: root.allAccounts.filter(a => a.enable
        && a.user.length > 0
        && (root.passwords[a.id] ?? "").length > 0)

    readonly property bool configured: root.accounts.length > 0
    readonly property bool enabled: (Config.options?.services?.mail?.enable ?? false) && root.configured

    function passwordFor(id) {
        return root.passwords[id] ?? "";
    }

    function setAppPassword(id, password) {
        KeyringStorage.setNestedField(["mail", String(id), "appPassword"], String(password).trim());
    }

    /** Saca la cuenta de la config y su contraseña del keyring, en ese orden. */
    function removeAccount(id) {
        const rest = (Config.options?.services?.mail?.accounts ?? [])
            .filter(a => a && String(a.id) !== String(id));
        Config.options.services.mail.accounts = rest;
        KeyringStorage.setNestedField(["mail", String(id)], ({}));
        const copia = Object.assign({}, root.results);
        delete copia[String(id)];
        root.results = copia;
        root.setReauth(String(id), false);
        root.clearRetry(String(id));
    }

    /**
     * Agrega (o pisa) una cuenta. La contraseña va aparte, con setAppPassword:
     * acá entra sólo lo que no es secreto.
     */
    function upsertAccount(account) {
        if (!account || !account.id) return;
        const id = String(account.id);
        const previas = (Config.options?.services?.mail?.accounts ?? [])
            .filter(a => a && String(a.id) !== id);
        Config.options.services.mail.accounts = previas.concat([account]);
    }

    /**
     * Pasa la cuenta única de la config vieja a la lista, sin tocar el keyring:
     * conserva la id "default", que es donde `passwords` ya busca su contraseña.
     */
    function migrateLegacyAccount() {
        const legacy = Config.options?.services?.mail;
        if (!legacy || String(legacy.user ?? "").length === 0) return;
        if ((legacy.accounts ?? []).length > 0) return;
        root.upsertAccount(({
            "id": "default",
            "label": String(legacy.user),
            "host": String(legacy.host ?? "imap.gmail.com"),
            "port": Number(legacy.port ?? 993),
            "user": String(legacy.user),
            "mailbox": String(legacy.mailbox ?? "INBOX"),
            "security": "ssl",
            "enable": true
        }));
        Config.options.services.mail.user = "";
    }

    /** El webmail que le corresponde a una cuenta, para el botón de "abrir". */
    function webmailFor(host, user) {
        const lower = String(host ?? "").toLowerCase();
        // El Bridge de Proton corre en loopback, así que el host no dice de quién
        // es la cuenta: hay que mirar la dirección.
        const address = String(user ?? "").toLowerCase();
        if (address.endsWith("@proton.me") || address.endsWith("@protonmail.com")
            || address.endsWith("@pm.me") || address.endsWith("@protonmail.ch"))
            return "https://mail.proton.me/u/0/almost-all-mail#unread";
        if (lower.indexOf("me.com") >= 0 || lower.indexOf("icloud") >= 0)
            return "https://www.icloud.com/mail";
        if (lower.indexOf("outlook") >= 0 || lower.indexOf("office365") >= 0)
            return "https://outlook.live.com/mail/0/";
        return "https://mail.google.com/mail/u/0/#search/is:unread";
    }

    // ------------------------------------------------------------------ //
    // Conectar una cuenta
    // ------------------------------------------------------------------ //

    /**
     * Conectar se siente como un OAuth aunque por debajo sea IMAP: se abre el
     * navegador, la página linkea directo a donde se genera la contraseña de
     * aplicación, y la credencial se verifica contra el servidor de verdad antes
     * de guardarse. Todo eso lo hace scripts/accounts/connect.py, que sirve igual
     * para Gmail que para iCloud. Acá no hay ningún campo de secreto.
     */
    readonly property int connectPort: Config.options?.services?.mail?.connectPort ?? 8892

    /** idle | waiting | working | error */
    property string connectState: "idle"
    property string connectError: ""
    /** "gmail" | "icloud" — cuál se está conectando ahora */
    property string connecting: ""

    /**
     * Los datos de conexión los manda connect.py junto con la credencial, porque
     * en Proton no son fijos: el Bridge deja mover el puerto. Esto queda como
     * respaldo por si alguna vez faltaran.
     */
    readonly property var endpointsByProvider: ({
        "gmail": ({ "host": "imap.gmail.com", "port": 993, "security": "ssl" }),
        "icloud": ({ "host": "imap.mail.me.com", "port": 993, "security": "ssl" }),
        "proton": ({ "host": "127.0.0.1", "port": 1143, "security": "starttls" })
    })

    function connectAccount(provider) {
        if (root.connectState === "waiting" || root.connectState === "working") return;
        root.connecting = provider;
        root.connectState = "working";
        root.connectError = "";
        connectProc.running = false;
        connectProc.command = ["python3",
            `${Directories.scriptPath}/accounts/connect.py`.replace(/file:\/\//, ""),
            provider, String(root.connectPort)];
        connectProc.running = true;
    }

    function cancelConnect() {
        connectProc.running = false;
        root.connectState = "idle";
        root.connecting = "";
    }

    /**
     * La id ata la cuenta con su contraseña en el keyring, así que tiene que ser
     * estable y servir como nombre de campo: proveedor + dirección, sin nada raro.
     */
    function accountId(provider, user) {
        return `${provider}-${String(user).toLowerCase().replace(/[^a-z0-9]+/g, "-")}`;
    }

    Process {
        id: connectProc
        stdout: SplitParser {
            onRead: line => {
                const space = line.indexOf(" ");
                if (space < 0) return;
                const tag = line.substring(0, space);
                const payload = line.substring(space + 1);

                if (tag === "AUTHURL") {
                    root.connectState = "waiting";
                    Quickshell.execDetached(["xdg-open", payload]);
                } else if (tag === "CREDS") {
                    try {
                        const creds = JSON.parse(payload);
                        const provider = creds.provider ?? root.connecting;
                        const id = root.accountId(provider, creds.user);
                        const fallback = root.endpointsByProvider[provider] ?? ({});
                        // Primero la config y después la contraseña: si el keyring
                        // llegara a fallar, queda una cuenta visible sin clave y se
                        // puede reintentar, en vez de una clave huérfana.
                        root.upsertAccount(({
                            "id": id,
                            "label": String(creds.user),
                            "host": String(creds.host ?? fallback.host ?? "imap.gmail.com"),
                            "port": Number(creds.port ?? fallback.port ?? 993),
                            "security": String(creds.security ?? fallback.security ?? "ssl"),
                            "user": String(creds.user),
                            "mailbox": "INBOX",
                            "enable": true
                        }));
                        root.setAppPassword(id, creds.password);
                        // Cuenta reconectada a mano: lo que sabíamos de fallas viejas
                        // (reauth, backoff) ya no aplica, aunque sea la misma id.
                        root.setReauth(id, false);
                        root.clearRetry(id);
                        root.connectState = "idle";
                        root.connecting = "";
                        Qt.callLater(() => root.refresh());
                    } catch (e) {
                        root.connectState = "error";
                        root.connectError = String(e);
                    }
                } else if (tag === "ERROR") {
                    root.connectState = "error";
                    root.connectError = payload;
                    console.log("[Mail]", payload);
                }
            }
        }
        onExited: exitCode => {
            if (root.connectState === "waiting" || root.connectState === "working")
                root.connectState = "idle";
            root.connecting = "";
        }
    }

    // ------------------------------------------------------------------ //
    // Resultados
    // ------------------------------------------------------------------ //

    /** { id: {unread, messages, error, lastSync} } */
    property var results: ({})

    readonly property int unreadCount: root.accounts.reduce(
        (total, a) => total + Number(root.results[a.id]?.unread ?? 0), 0)

    /**
     * Los no leídos de todas las cuentas, los más nuevos primero. Cada mensaje
     * lleva de qué cuenta salió: sin eso, hacer clic abriría el webmail
     * equivocado cuando tenés Gmail e iCloud juntos.
     */
    readonly property var recent: {
        let todos = [];
        root.accounts.forEach(account => {
            const mensajes = root.results[account.id]?.messages ?? [];
            todos = todos.concat(mensajes.map(m => Object.assign({}, m, {
                "accountId": account.id,
                "accountLabel": account.label,
                "webmail": root.webmailFor(account.host, account.user)
            })));
        });
        return todos.sort((a, b) => b.timestamp - a.timestamp).slice(0, root.maxMessages);
    }

    /**
     * Cuentas cuya contraseña de aplicación dejó de servir: { id: true }. No se
     * arreglan reintentando -- necesitan que el usuario reconecte a mano desde
     * Ajustes → Perfil → Cuentas → Correo. Se limpia sólo con un fetch exitoso o
     * al reconectar.
     */
    property var needsReauth: ({})
    readonly property bool anyNeedsReauth: Object.keys(root.needsReauth).some(id => root.needsReauth[id])

    function setReauth(accountId, value) {
        const already = root.needsReauth[accountId] === true;
        if (already === Boolean(value)) return;
        const copia = Object.assign({}, root.needsReauth);
        if (value) copia[accountId] = true;
        else delete copia[accountId];
        root.needsReauth = copia;
    }

    /** Se muestra un error solo: apilar todos no ayuda a entender nada. */
    readonly property string lastError: {
        // Reconectar es lo único que el usuario puede arreglar de verdad;
        // un corte transitorio se resuelve solo y no vale la pena alarmar por eso.
        for (const account of root.accounts) {
            if (root.needsReauth[account.id])
                return Translation.tr("La contraseña de aplicación de %1 dejó de servir. Reconectala desde Ajustes.").arg(account.label);
        }
        for (const account of root.accounts) {
            const error = root.results[account.id]?.error ?? "";
            if (error.length > 0) {
                return root.accounts.length > 1
                    ? `${account.label}: ${error}`
                    : error;
            }
        }
        return "";
    }

    readonly property real lastSync: root.accounts.reduce(
        (acc, a) => Math.max(acc, Number(root.results[a.id]?.lastSync ?? 0)), 0)

    property bool loading: false

    readonly property string status: {
        if (!(Config.options?.services?.mail?.enable ?? false)) return Translation.tr("Desactivado");
        if (!root.configured) return Translation.tr("No hay ninguna cuenta de correo conectada");
        if (root.lastError.length > 0) return root.lastError;
        if (root.loading) return Translation.tr("Sincronizando…");
        if (root.unreadCount === 0) return Translation.tr("Sin mails nuevos");
        return Translation.tr("%1 sin leer").arg(root.unreadCount);
    }

    /** Pinta lo de la última vez mientras el IMAP contesta. */
    function restoreFromCache() {
        if (!root.enabled || root.lastSync > 0) return;
        const cached = AccountsCache.get("mail", null);
        if (cached && Object.keys(cached).length > 0) root.results = cached;
    }

    Connections {
        target: AccountsCache
        function onLoadedChanged() { root.restoreFromCache(); }
    }

    function patchResult(id, changes) {
        const copia = Object.assign({}, root.results);
        copia[id] = Object.assign({}, copia[id] ?? ({}), changes);
        root.results = copia;
    }

    // ------------------------------------------------------------------ //
    // Lectura
    // ------------------------------------------------------------------ //

    /** Cuentas que faltan consultar en esta pasada */
    property var queue: []
    property var current: null
    /** Si el proceso terminó sin haber impreso nada, murió antes de poder hablar. */
    property bool answered: false

    // ------------------------------------------------------------------ //
    // Reintentos
    // ------------------------------------------------------------------ //
    // Un corte de red no debería obligar a esperar hasta el próximo refresh
    // programado (5 min por defecto): eso es lo que hace que una conexión por
    // polling se sienta "que se corta". Un fallo de red agenda un reintento
    // propio, cada vez más espaciado, y una consulta exitosa lo resetea.

    /** id -> cuántos reintentos van, para calcular el próximo delay. */
    property var retryAttempt: ({})
    /**
     * id -> epoch del próximo reintento agendado. Un timestamp por cuenta y no
     * un Timer por cuenta: con dos cuentas fallando cerca en el tiempo, un solo
     * Timer compartido se pisa (la segunda cancela el reintento de la primera).
     * Esto no tiene ese problema.
     */
    property var retryAt: ({})

    function clearRetry(accountId) {
        if (root.retryAttempt[accountId] === undefined && root.retryAt[accountId] === undefined) return;
        const attempts = Object.assign({}, root.retryAttempt);
        delete attempts[accountId];
        root.retryAttempt = attempts;
        const at = Object.assign({}, root.retryAt);
        delete at[accountId];
        root.retryAt = at;
    }

    function scheduleRetry(accountId) {
        const attempt = (root.retryAttempt[accountId] ?? 0) + 1;
        const attempts = Object.assign({}, root.retryAttempt);
        attempts[accountId] = attempt;
        root.retryAttempt = attempts;
        // 15s, 30s, 60s, 120s, tope ahí: ni tan rápido como para hostigar al
        // servidor, ni tan lento como para hacerte esperar el intervalo entero.
        const delaySeconds = Math.min(120, 15 * Math.pow(2, attempt - 1));
        const at = Object.assign({}, root.retryAt);
        at[accountId] = Date.now() + delaySeconds * 1000;
        root.retryAt = at;
    }

    /** Cada 5s se fija si algún reintento agendado ya venció y lo dispara. */
    Timer {
        interval: 5000
        running: root.enabled
        repeat: true
        onTriggered: {
            if (root.current !== null) return; // ya hay una consulta en curso
            const now = Date.now();
            const dueId = Object.keys(root.retryAt).find(id => root.retryAt[id] <= now);
            if (!dueId) return;
            root.clearRetry(dueId);
            const account = root.accounts.find(a => a.id === dueId);
            if (!account) return; // se borró o se apagó mientras esperaba
            root.queue = root.queue.concat([account]);
            root.loading = true;
            root.pump();
        }
    }

    function refresh() {
        if (!root.enabled || root.loading) return;
        root.queue = root.accounts.slice(0);
        root.loading = true;
        root.pump();
    }

    function pump() {
        if (root.current !== null) return;
        if (root.queue.length === 0) {
            root.loading = false;
            return;
        }
        const account = root.queue[0];
        root.queue = root.queue.slice(1);
        root.current = account;
        root.answered = false;

        fetchProc.running = false;
        fetchProc.environment = ({ "MAIL_PASSWORD": root.passwordFor(account.id) });
        fetchProc.command = ["python3",
            `${Directories.scriptPath}/mail/imap.py`.replace(/file:\/\//, ""),
            account.host, String(account.port), account.user,
            account.mailbox, String(root.maxMessages), account.security ?? "ssl"];
        fetchProc.running = true;
    }

    Process {
        id: fetchProc
        stdout: SplitParser {
            onRead: line => {
                if (line.trim().length === 0) return;
                const account = root.current;
                if (!account) return;
                root.answered = true;
                try {
                    const data = JSON.parse(line);
                    if (!data.ok) {
                        const message = data.error ?? Translation.tr("Error desconocido");
                        const kind = data.kind ?? "unknown";
                        root.patchResult(account.id, ({ "error": message, "errorKind": kind }));
                        console.log("[Mail]", account.label, message);
                        if (kind === "auth") {
                            // La contraseña dejó de servir: reintentar en loop no
                            // arregla nada, sólo golpea al servidor. Que espere a
                            // que reconecten a mano (o al próximo refresh normal,
                            // por si era Google rechazando algo pasajero).
                            root.setReauth(account.id, true);
                            root.clearRetry(account.id);
                        } else {
                            root.scheduleRetry(account.id);
                        }
                        return;
                    }
                    root.patchResult(account.id, ({
                        "unread": data.unread ?? 0,
                        "messages": data.messages ?? [],
                        "error": "",
                        "errorKind": "",
                        "lastSync": Date.now()
                    }));
                    root.setReauth(account.id, false);
                    root.clearRetry(account.id);
                    AccountsCache.set("mail", root.results);
                } catch (e) {
                    root.patchResult(account.id, ({ "error": String(e), "errorKind": "unknown" }));
                    root.scheduleRetry(account.id);
                    console.log("[Mail] respuesta ilegible:", line);
                }
            }
        }
        onExited: exitCode => {
            const account = root.current;
            // El script escribe su propio error en stdout; un exit sin nada
            // impreso es que se murió antes de poder decir nada -- eso es un
            // corte, no una credencial mala, así que vale la pena reintentar.
            if (account && !root.answered) {
                root.patchResult(account.id, ({
                    "error": Translation.tr("El lector de correo terminó con código %1").arg(exitCode),
                    "errorKind": "network"
                }));
                root.scheduleRetry(account.id);
            }
            root.current = null;
            root.pump();
        }
    }

    onEnabledChanged: {
        if (root.enabled) {
            root.restoreFromCache();
            root.refresh();
        } else {
            root.results = ({});
            AccountsCache.clear("mail");
        }
    }

    Timer {
        running: root.enabled
        interval: Math.max(1, root.refreshMinutes) * 60 * 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: {
        if (!KeyringStorage.loaded) KeyringStorage.fetchKeyringData();
    }
}
