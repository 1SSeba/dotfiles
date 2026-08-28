pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

/**
 * Lo último que trajeron las cuentas, guardado en disco.
 *
 * Existe por una sola razón: velocidad percibida. Sin esto, abrir la barra
 * recién arrancada mostraba widgets vacíos por varios segundos — el keyring
 * carga asincrónico, después hay que validar la sesión, y recién después salen
 * las peticiones. Con esto los eventos, las tareas y los mails de la última vez
 * están en pantalla al instante y se reemplazan solos cuando llega lo nuevo.
 *
 * Es un cache, no una fuente de verdad: si el archivo no está o está roto, todo
 * sigue funcionando igual, sólo que con la espera de antes. Nada sensible entra
 * acá — los secretos viven en el keyring, esto es lo mismo que ya se ve en
 * pantalla.
 *
 * Un solo archivo para todas las secciones, y las escrituras van con retardo:
 * cinco servicios refrescando a la vez no tienen por qué ser cinco escrituras.
 */
Singleton {
    id: root

    property var data: ({})
    property bool loaded: false

    /** Lo guardado bajo `key`, o `fallback` si no hay nada. */
    function get(key, fallback) {
        const value = root.data[key];
        return (value === undefined || value === null) ? fallback : value;
    }

    function set(key, value) {
        const copia = Object.assign({}, root.data);
        copia[key] = value;
        root.data = copia;
        saveTimer.restart();
    }

    /** Se usa al desconectar una cuenta: lo viejo no puede quedar en pantalla. */
    function clear(key) {
        if (root.data[key] === undefined) return;
        const copia = Object.assign({}, root.data);
        delete copia[key];
        root.data = copia;
        saveTimer.restart();
    }

    Timer {
        id: saveTimer
        interval: 1500
        repeat: false
        onTriggered: cacheFile.setText(JSON.stringify(root.data))
    }

    /** FileView no lee solo: hay que pedirselo, igual que hace Todo.qml. */
    Component.onCompleted: cacheFile.reload()

    FileView {
        id: cacheFile
        path: Qt.resolvedUrl(Directories.accountsCachePath)
        // Sin esto FileView no lee hasta que alguien le pida el texto, y todo el
        // punto de este cache es que lo de la ultima vez ya este en pantalla.
        preload: true
        // La primera vez no existe, y eso no es un error que valga la pena
        // imprimir: onLoadFailed ya deja el cache vacío, que es lo correcto.
        printErrors: false
        onLoaded: {
            let delDisco = ({});
            try {
                const parsed = JSON.parse(cacheFile.text());
                if (parsed && typeof parsed === "object") delDisco = parsed;
            } catch (e) {
                // Un cache ilegible no es un problema: se pisa en el próximo refresh
                console.log("[AccountsCache] archivo ilegible, se ignora:", e);
            }
            // Lo que ya se guardó en memoria gana sobre lo del disco: el archivo
            // se lee asincrónico y puede llegar despues de que un servicio haya
            // refrescado. Sin esto, el disco pisaba lo recien traido de la red.
            root.data = Object.assign({}, delDisco, root.data);
            root.loaded = true;
        }
        onLoadFailed: error => {
            // Lo normal la primera vez: todavía no existe
            root.data = ({});
            root.loaded = true;
        }
    }
}
