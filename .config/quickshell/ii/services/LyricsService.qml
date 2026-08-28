pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.modules.common

/**
 * Letras para lo que esté sonando, desde LRCLIB (API pública, sin cuenta ni key).
 *
 * Pide la letra sincronizada; si el tema no la tiene, se conforma con la plana.
 * Todo lo que la UI necesita está en `lines` y `currentIndex`: `lines` son los
 * versos ya parseados del formato LRC y `currentIndex` es el que corresponde a la
 * posición actual del reproductor.
 */
Singleton {
    id: root

    readonly property string endpoint: "https://lrclib.net/api"

    /** idle | loading | synced | plain | notfound | error */
    property string state: "idle"
    /** [{ time: segundos, text: string }] — vacío si la letra no está sincronizada */
    property var lines: []
    property string plain: ""
    property string lastQuery: ""

    readonly property var player: MprisController.activePlayer
    readonly property bool hasSynced: root.state === "synced" && root.lines.length > 0

    /** Índice del verso que suena ahora, o -1. */
    readonly property int currentIndex: {
        if (!root.hasSynced || !root.player) return -1;
        const pos = root.player.position ?? 0;
        let found = -1;
        for (let i = 0; i < root.lines.length; i++) {
            if (root.lines[i].time <= pos + 0.15) found = i;
            else break;
        }
        return found;
    }

    // ------------------------------------------------------------------ //
    // Vista para el widget `Lyrics`
    //
    // El widget dibuja una ventana fija de 7 versos y resalta el que está en la
    // posición `before`; no sabe nada de tiempos ni de índices absolutos. Esto
    // traduce `lines`/`currentIndex`/`state` a ese vocabulario.
    // ------------------------------------------------------------------ //

    readonly property int slotCount: 7

    /** Índice, dentro de `slots`, del verso que suena ahora. */
    readonly property int before: root.state === "plain" ? 0 : 3

    /** ok | loading | idle | notfound | error */
    readonly property string status: {
        if (root.state === "loading") return "loading";
        if (root.state === "synced" || root.state === "plain") return "ok";
        return root.state;
    }

    /** Ventana de `slotCount` versos; los que caen fuera de la letra van vacíos. */
    readonly property var slots: {
        const out = [];
        // Sin timestamps no hay "verso actual": se muestran los primeros versos
        // y se resalta el de arriba (`before` = 0).
        if (root.state === "plain") {
            const plainLines = root.plain.split("\n").filter(l => l.trim().length > 0);
            for (let i = 0; i < root.slotCount; i++) out.push(plainLines[i] ?? "");
            return out;
        }
        const cur = root.currentIndex;
        for (let i = 0; i < root.slotCount; i++) {
            const idx = cur - root.before + i;
            out.push((idx >= 0 && idx < root.lines.length) ? (root.lines[idx].text ?? "") : "");
        }
        return out;
    }

    /** Vuelve a pedir la letra del tema actual, ignorando la caché de `lastQuery`. */
    function restartLyrics() {
        root.lastQuery = "";
        root.maybeFetch();
    }

    // ------------------------------------------------------------------ //
    // Búsqueda
    // ------------------------------------------------------------------ //

    function trackKey(player) {
        if (!player) return "";
        return `${player.trackArtist ?? ""}|${player.trackTitle ?? ""}|${player.trackAlbum ?? ""}`;
    }

    Connections {
        target: MprisController
        function onActivePlayerChanged() {
            root.maybeFetch();
        }
    }

    Connections {
        target: root.player
        ignoreUnknownSignals: true
        function onTrackTitleChanged() {
            root.maybeFetch();
        }
        function onTrackArtistChanged() {
            root.maybeFetch();
        }
    }

    function maybeFetch() {
        const key = root.trackKey(root.player);
        if (key === root.lastQuery) return;
        root.lastQuery = key;
        root.reset();
        if (!(Config.options?.sidebar?.music?.lyrics ?? true)) return;
        if (!root.player || (root.player.trackTitle ?? "").length === 0) return;
        root.fetch(root.player.trackTitle, root.player.trackArtist ?? "",
            root.player.trackAlbum ?? "", root.player.length ?? 0);
    }

    function reset() {
        root.lines = [];
        root.plain = "";
        root.state = "idle";
    }

    function fetch(title, artist, album, duration) {
        root.state = "loading";
        const params = `track_name=${encodeURIComponent(title)}`
            + `&artist_name=${encodeURIComponent(artist)}`
            + (album.length > 0 ? `&album_name=${encodeURIComponent(album)}` : "")
            + (duration > 0 ? `&duration=${Math.round(duration)}` : "");

        root.request(`${root.endpoint}/get?${params}`, result => {
            if (result) {
                root.apply(result);
                return;
            }
            // El match exacto es estricto con el álbum y la duración; si falla,
            // buscamos por texto y nos quedamos con el primero.
            root.request(`${root.endpoint}/search?q=${encodeURIComponent(artist + " " + title)}`, list => {
                if (Array.isArray(list) && list.length > 0) root.apply(list[0]);
                else root.state = "notfound";
            });
        });
    }

    function request(url, callback) {
        const xhr = new XMLHttpRequest();
        xhr.open("GET", url);
        xhr.setRequestHeader("User-Agent", "quickshell-ii-lyrics");
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (xhr.status !== 200) {
                callback(null);
                return;
            }
            try {
                callback(JSON.parse(xhr.responseText));
            } catch (e) {
                console.log("[Lyrics] respuesta ilegible:", e);
                callback(null);
            }
        };
        xhr.send();
    }

    function apply(data) {
        if (!data) {
            root.state = "notfound";
            return;
        }
        if (data.instrumental === true) {
            root.plain = Translation.tr("🎵 Instrumental");
            root.state = "plain";
            return;
        }
        const synced = root.parseLrc(data.syncedLyrics ?? "");
        if (synced.length > 0) {
            root.lines = synced;
            root.plain = data.plainLyrics ?? "";
            root.state = "synced";
            return;
        }
        if ((data.plainLyrics ?? "").length > 0) {
            root.plain = data.plainLyrics;
            root.state = "plain";
            return;
        }
        root.state = "notfound";
    }

    /**
     * Convierte el LRC a [{time, text}].
     * Un verso puede traer varios timestamps: `[00:12.34][01:05.00] estribillo`.
     */
    function parseLrc(lrc) {
        if (!lrc || lrc.length === 0) return [];
        const out = [];
        const stampRe = /\[(\d+):(\d+(?:[.:]\d+)?)\]/g;
        lrc.split("\n").forEach(rawLine => {
            stampRe.lastIndex = 0;
            const text = rawLine.replace(stampRe, "").trim();
            let match;
            while ((match = stampRe.exec(rawLine)) !== null) {
                const minutes = parseInt(match[1], 10);
                const seconds = parseFloat(String(match[2]).replace(":", "."));
                out.push({
                    "time": minutes * 60 + seconds,
                    "text": text
                });
            }
        });
        out.sort((a, b) => a.time - b.time);
        return out;
    }

    Component.onCompleted: root.maybeFetch()
}
