pragma Singleton
pragma ComponentBehavior: Bound

import qs
import qs.modules.common
import qs.modules.common.functions
import Quickshell;
import Quickshell.Io;
import QtQuick;

/**
 * For storing sensitive data in the keyring.
 * Use this for small data only, since it stores a JSON of the contents directly and doesn't use a database.
 */
Singleton {
    id: root

    signal dataChanged()

    property bool loaded: false
    property var keyringData: ({})
    
    readonly property string explanationText: "For storing API keys and other sensitive information"
    /** El atributo como quedaba cuando se traducía; se limpia al guardar. */
    readonly property string legacyExplanation: Translation.tr(root.explanationText)

    property var properties: {
        "application": "illogical-impulse",
        // SIN traducir a propósito: secret-tool identifica el ítem por todos
        // sus atributos, y la shell arranca en inglés y cambia de idioma un
        // rato después. Traducido, guardar antes o después del cambio creaba
        // dos ítems distintos y la lectura podía devolver el viejo.
        "explanation": root.explanationText,
    }
    property var propertiesAsArgs: Object.keys(root.properties).reduce(
        function(arr, key) {
            return arr.concat([key, root.properties[key]]);
        }, []
    )
    property string keyringLabel: Translation.tr("%1 Safe Storage").arg("illogical-impulse")

    /**
     * Devuelve una copia de `obj` con `value` puesto en `path`. Copia cada
     * nivel que toca para que los bindings que miran keyringData se enteren.
     */
    function withField(obj, path, value) {
        const top = Object.assign({}, obj ?? {});
        let cursor = top;
        for (let i = 0; i < path.length - 1; ++i) {
            const next = cursor[path[i]];
            cursor[path[i]] = (next && typeof next === "object") ? Object.assign({}, next) : {};
            cursor = cursor[path[i]];
        }
        cursor[path[path.length - 1]] = value;
        return top;
    }

    function withPending(obj) {
        return root.pendingChanges.reduce((acc, change) => root.withField(acc, change.path, change.value), obj);
    }

    /**
     * El keyring es UN solo JSON compartido por todos los procesos de la shell
     * (la shell, Ajustes...). Antes cada uno guardaba su copia en memoria
     * entera, así que el último en escribir pisaba al resto: conectabas Google
     * desde Ajustes y a la hora, cuando la shell renovaba el token de Spotify,
     * reescribía el blob sin Google y la cuenta desaparecía.
     *
     * Ahora un cambio se aplica en memoria al toque (la UI no espera) y queda
     * pendiente; al guardar se relee el keyring, se le aplican los pendientes
     * encima y recién ahí se escribe. Así cada proceso sólo toca sus campos.
     */
    function setNestedField(path, value) {
        root.pendingChanges = root.pendingChanges.concat([{ "path": path, "value": value }]);
        root.keyringData = root.withField(root.keyringData, path, value);
        saveKeyringData();
    }

    function fetchKeyringData() {
        // Un pedido explícito (p. ej. recién desbloqueaste la pantalla) arranca
        // la espera de cero: el keyring probablemente ya está listo.
        root.retries = 0;
        if (getData.running) return;
        retryTimer.stop();
        getData.running = true;
    }

    /** Relee, mezcla los pendientes y escribe (ver setNestedField). */
    function saveKeyringData() {
        if (mergeRead.running || saveData.running) {
            root.saveQueued = true;
            return;
        }
        mergeRetryTimer.stop();
        mergeRead.running = true;
    }

    property var pendingChanges: []
    property bool saveQueued: false
    property string lastOwnStamp: ""
    readonly property string stampPath: FileUtils.trimFileProtocol(`${Directories.state}/user/keyring-changed`)

    Process {
        id: mergeRead
        command: ["bash", "-c", `${Directories.scriptPath}/keyring/try_lookup.sh 2> /dev/null`]
        stdout: StdioCollector { id: mergeReadCollector }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 2) {
                // Bloqueado: los cambios siguen en memoria y pendientes
                mergeRetryTimer.restart();
                return;
            }
            let base = ({});
            if (exitCode === 0) {
                try {
                    base = JSON.parse(mergeReadCollector.text);
                } catch (e) {
                    console.error("[KeyringStorage] Keyring data unreadable while saving, reinitializing.");
                }
            }
            const merged = root.withPending(base);
            root.pendingChanges = [];
            root.keyringData = merged;
            saveData.payload = JSON.stringify(merged);
            saveData.stdinEnabled = true;
            saveData.running = true;
        }
    }

    Timer {
        id: mergeRetryTimer
        interval: 5000
        onTriggered: root.saveKeyringData()
    }

    Process {
        id: saveData
        property string payload: "{}"
        command: [
            "secret-tool", "store", "--label=" + keyringLabel,
            ...propertiesAsArgs,
        ]
        onRunningChanged: {
            if (saveData.running) {
                saveData.write(saveData.payload);
                root.dataChanged()
                stdinEnabled = false // End input stream
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                // El ítem viejo con el atributo traducido ya quedó reemplazado
                if (root.legacyExplanation !== root.explanationText)
                    Quickshell.execDetached(["secret-tool", "clear",
                        "application", root.properties.application,
                        "explanation", root.legacyExplanation]);
                // Avisarle a los otros procesos que relean
                root.lastOwnStamp = `${Date.now()}-${Math.random()}`;
                stampFile.setText(root.lastOwnStamp);
            } else {
                console.error("[KeyringStorage] secret-tool store failed with code", exitCode);
            }
            if (root.saveQueued) {
                root.saveQueued = false;
                root.saveKeyringData();
            }
        }
    }

    /**
     * La marca que dejan los otros procesos al guardar. Si cambió y no fuimos
     * nosotros, releer: así la shell ve al instante la cuenta que conectaste en
     * Ajustes, sin reiniciar.
     */
    FileView {
        id: stampFile
        path: root.stampPath
        watchChanges: true
        onFileChanged: this.reload()
        // Sin el archivo no hay nada que vigilar: crearlo vacío
        onLoadFailed: (error) => {
            if (error == FileViewError.FileNotFound) stampFile.setText("");
        }
        onLoaded: {
            if (!root.loaded) return; // la primera lectura ya está en camino
            if (stampFile.text().trim() === root.lastOwnStamp) return;
            root.fetchKeyringData();
        }
    }

    Process {
        id: getData
        command: [ // We need to use echo for a newline so splitparser does parse
            "bash", "-c", `${Directories.scriptPath}/keyring/try_lookup.sh 2> /dev/null`,
        ]
        stdout: StdioCollector {
            id: keyringDataOutputCollector
            onStreamFinished: {
                const data = keyringDataOutputCollector.text;
                if (data.length === 0 || !data.startsWith("{")) return;
                try {
                    // Lo que todavía no se guardó va encima de lo leído
                    root.keyringData = root.withPending(JSON.parse(data));
                    // console.log("[KeyringStorage] Keyring data fetched:", JSON.stringify(root.keyringData));
                } catch (e) {
                    console.error("[KeyringStorage] Failed to get keyring data, reinitializing.");
                    root.keyringData = root.withPending({});
                    saveKeyringData()
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            // console.log("[KeyringStorage] Keyring data fetch process exited with code:", exitCode);
            if (exitCode === 1) {
                console.error("[KeyringStorage] Entry not found, initializing.");
                root.keyringData = root.withPending({});
                saveKeyringData()
            }
            if (exitCode !== 2) {
                root.retries = 0;
                root.loaded = true;
                return;
            }

            // exitCode 2 = el keyring está bloqueado o el secret service todavía
            // no responde. Es lo normal justo después de loguearte: la shell
            // arranca antes de que gnome-keyring/kwallet estén disponibles.
            //
            // Antes esto se quedaba ahí: `loaded` nunca pasaba a true, keyringData
            // quedaba en {} y todo lo que vive en el keyring (Spotify, Google,
            // Mail, las API keys de IA) aparecía desconectado hasta que otra cosa
            // volviera a pedirlo — así que en cada reinicio había que reconectar
            // las cuentas a mano aunque el token siguiera intacto en el keyring.
            // Ahora se reintenta solo, con una espera que va creciendo.
            //
            // Y no se rinde: al arrancar, el keyring sigue bloqueado hasta que
            // escribís la contraseña en la pantalla de bloqueo, y eso puede
            // tardar lo que quieras. Mirar si está bloqueado es una consulta
            // dbus sin prompt (ver try_lookup.sh), así que esperar es barato.
            root.retries++;
            if (root.retries === root.warnAfterRetries)
                console.warn("[KeyringStorage] Keyring still locked/unavailable, will keep retrying every", root.retryMaxInterval / 1000, "s");
            retryTimer.interval = Math.min(root.retryBaseInterval * Math.pow(2, root.retries - 1), root.retryMaxInterval);
            retryTimer.restart();
        }
    }

    // Reintento del fetch cuando el keyring está bloqueado o todavía no arrancó.
    property int retries: 0
    readonly property int warnAfterRetries: 8
    readonly property int retryBaseInterval: 2000
    readonly property int retryMaxInterval: 30000

    Timer {
        id: retryTimer
        repeat: false
        onTriggered: {
            if (getData.running) return;
            getData.running = true;
        }
    }
    
}
