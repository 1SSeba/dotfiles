pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

/**
 * Tu Spotify dentro de la shell: inicio, playlists, biblioteca, búsqueda y
 * control de reproducción.
 *
 * El login es Authorization Code + PKCE, así que no hace falta client secret:
 * alcanza con el Client ID de una app creada en developer.spotify.com. El ida y
 * vuelta con el navegador lo hace `scripts/spotify/auth.py`, porque PKCE necesita
 * SHA-256 y hay que escuchar el redirect en un puerto local — dos cosas fuera del
 * alcance de QML. Los tokens quedan en el keyring, nunca en la config.
 *
 * Reproducir usa la Web API (play/pause/siguiente/anterior/seek/shuffle/repeat),
 * que exige Premium. Sin Premium se cae solo a abrir el URI en el Spotify de
 * escritorio, que anda con cualquier cuenta.
 */
Singleton {
    id: root

    readonly property string apiBase: "https://api.spotify.com/v1"
    readonly property string clientId: Config.options?.sidebar?.music?.spotify?.clientId ?? ""
    readonly property int callbackPort: Config.options?.sidebar?.music?.spotify?.callbackPort ?? 8888

    // ------------------------------------------------------------------ //
    // Tokens
    // ------------------------------------------------------------------ //

    /**
     * Lee un token del keyring en el momento, sin binding de por medio.
     *
     * Con `readonly property string refreshToken: ...keyringData?.spotify?.refresh_token`
     * el valor quedaba clavado en "" — el binding se evaluaba mientras el keyring
     * todavía no había cargado y no se volvía a evaluar salvo que la UI lo leyera.
     * Resultado: un refresh token de 131 caracteres se leía como vacío y el servicio
     * creía que la sesión había vencido, así que nunca traía nada.
     */
    function tokenField(name) {
        const data = KeyringStorage.keyringData?.spotify;
        if (!data) return "";
        const value = data[name];
        return (value === undefined || value === null) ? "" : value;
    }

    // Sólo para la UI (acá el binding sí se re-evalúa porque algo lo observa)
    readonly property string accessToken: KeyringStorage.keyringData?.spotify?.access_token ?? ""
    readonly property bool configured: root.clientId.length > 0
    readonly property bool connected: root.accessToken.length > 0

    /** idle | waiting | working | error */
    property string state: "idle"
    property string lastError: ""

    // ------------------------------------------------------------------ //
    // Contenido
    // ------------------------------------------------------------------ //

    property var playlists: []
    property var recent: []
    property var searchResults: []
    property string searchQuery: ""

    // Inicio
    property var topTracks: []
    property var topArtists: []
    property var newReleases: []
    property var likedTracks: []
    property var savedAlbums: []

    /** Playlist o álbum abierto (null = estás en la lista) */
    property var openedCollection: null
    property var collectionTracks: []

    // ------------------------------------------------------------------ //
    // Reproducción
    // ------------------------------------------------------------------ //

    /** Lo que devuelve /me/player: dispositivo, tema, progreso, shuffle, repeat. */
    property var playback: null
    property var devices: []
    /** Mientras la pestaña está a la vista se sondea el estado; si no, no. */
    property bool watching: false

    readonly property bool premium: root.profilePlan === "premium"
    /** Spotify dijo explícitamente que la cuenta es gratuita. */
    readonly property bool knownFree: root.profilePlan === "free"
    /**
     * Se intenta controlar por la Web API salvo que se sepa que no se puede.
     * Con el plan desconocido (falta el scope user-read-private) hay que intentar:
     * fallar cuesta un 403 y el plan B ya está, pero asumir que no se puede rompe
     * el control aunque tengas Premium.
     */
    readonly property bool canControl: root.connected && !root.knownFree
    readonly property bool isPlaying: root.playback?.is_playing ?? false
    readonly property var currentTrack: root.playback?.item ?? null
    readonly property string currentTrackUri: root.playback?.item?.uri ?? ""
    readonly property bool shuffleOn: root.playback?.shuffle_state ?? false
    /** off | context | track */
    readonly property string repeatMode: root.playback?.repeat_state ?? "off"
    readonly property string activeDeviceName: root.playback?.device?.name ?? ""
    readonly property bool hasDevice: (root.playback?.device?.id ?? "").length > 0

    // ------------------------------------------------------------------ //
    // Diagnóstico
    // ------------------------------------------------------------------ //

    /** Peticiones en vuelo: con esto el botón de sync sabe cuándo girar. */
    property int pending: 0
    readonly property bool loading: root.pending > 0

    /** Cuándo terminó el último sync con éxito (0 = todavía ninguno). */
    property real lastSync: 0
    property string profileName: ""
    property string profilePlan: ""

    /**
     * Qué anda y qué no, en un renglón, para mostrarlo en la UI.
     * Antes un token vencido o un 403 dejaban la lista vacía sin explicación.
     */
    readonly property string status: {
        if (!root.configured) return Translation.tr("Falta el Client ID");
        if (!root.connected) return Translation.tr("Sin conectar");
        if (root.state === "error") return root.lastError;
        if (root.loading) return Translation.tr("Sincronizando…");
        if (root.profileName.length > 0) {
            const plan = root.profilePlan.length > 0 ? ` · ${root.profilePlan}` : "";
            const device = root.activeDeviceName.length > 0 ? ` · ${root.activeDeviceName}` : "";
            return `${root.profileName}${plan}${device}`;
        }
        return Translation.tr("Conectado");
    }

    readonly property bool healthy: root.connected && root.state !== "error" && root.profileName.length > 0

    signal authUrlReady(string url)

    // El keyring carga asincrónico: cuando aparece el token recién ahí se puede pedir.
    onConnectedChanged: {
        if (root.connected) {
            root.validate();
            root.refreshAll();
        } else {
            root.profileName = "";
            root.profilePlan = "";
            root.playback = null;
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
                        root.validate();
                        root.refreshAll();
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

    function login() {
        if (!root.configured) {
            root.fail(Translation.tr("Falta el Client ID de Spotify en la config"));
            return;
        }
        root.state = "working";
        root.lastError = "";
        authProc.running = false;
        authProc.command = ["python3",
            `${Directories.scriptPath}/spotify/auth.py`.replace(/file:\/\//, ""),
            root.clientId, String(root.callbackPort)];
        authProc.running = true;
    }

    function logout() {
        KeyringStorage.setNestedField(["spotify"], ({}));
        root.playlists = [];
        root.recent = [];
        root.searchResults = [];
        root.topTracks = [];
        root.topArtists = [];
        root.newReleases = [];
        root.likedTracks = [];
        root.savedAlbums = [];
        root.followedArtists = [];
        root.openedCollection = null;
        root.collectionTracks = [];
        root.playback = null;
        root.devices = [];
        root.profileName = "";
        root.profilePlan = "";
        root.lastSync = 0;
        root.lastError = "";
        root.state = "idle";
    }

    function fail(message) {
        root.lastError = message;
        root.state = "error";
        console.log("[Spotify]", message);
    }

    function storeTokens(data) {
        if (!data || !data.access_token) throw new Error("respuesta sin access_token");
        KeyringStorage.setNestedField(["spotify"], {
            "access_token": data.access_token,
            // En un refresh Spotify puede no mandar uno nuevo: se conserva el viejo
            "refresh_token": data.refresh_token ?? root.tokenField("refresh_token"),
            "expires_at": Date.now() + (data.expires_in ?? 3600) * 1000
        });
    }

    // ------------------------------------------------------------------ //
    // Llamadas a la API
    // ------------------------------------------------------------------ //

    /** Renueva el access token y llama a `next` cuando ya se puede pedir. */
    function renew(next) {
        const refresh = root.tokenField("refresh_token");
        if (refresh.length === 0) {
            root.fail(Translation.tr("La sesión venció. Volvé a conectar tu cuenta."));
            return;
        }
        const body = `grant_type=refresh_token&refresh_token=${encodeURIComponent(refresh)}`
            + `&client_id=${encodeURIComponent(root.clientId)}`;

        const xhr = new XMLHttpRequest();
        xhr.open("POST", "https://accounts.spotify.com/api/token");
        xhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded");
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (xhr.status !== 200) {
                root.fail(Translation.tr("No se pudo renovar la sesión (%1). Reconectá la cuenta.").arg(xhr.status));
                return;
            }
            try {
                root.storeTokens(JSON.parse(xhr.responseText));
                if (next) next();
            } catch (e) {
                root.fail(String(e));
            }
        };
        xhr.send(body);
    }

    /**
     * Una petición a la Web API. Si el token está por vencer lo renueva primero, y
     * si igual vuelve 401 lo intenta una sola vez más para no entrar en bucle.
     *
     * `onFail` permite que un comando de reproducción falle sin ensuciar el estado
     * global: la lista de playlists no tiene por qué mostrarse rota porque no había
     * un dispositivo activo.
     */
    function request(method, path, body, callback, onFail, isRetry = false) {
        const token = root.tokenField("access_token");
        if (token.length === 0) {
            root.fail(Translation.tr("No hay sesión de Spotify"));
            return;
        }
        const expiresAt = Number(root.tokenField("expires_at") || 0);
        if (Date.now() > expiresAt - 30000 && !isRetry) {
            root.renew(() => root.request(method, path, body, callback, onFail, true));
            return;
        }

        const report = message => {
            if (onFail) onFail(message);
            else root.fail(message);
        };

        root.pending++;
        const xhr = new XMLHttpRequest();
        xhr.open(method, path.startsWith("http") ? path : `${root.apiBase}${path}`);
        xhr.setRequestHeader("Authorization", `Bearer ${token}`);
        if (body !== null && body !== undefined)
            xhr.setRequestHeader("Content-Type", "application/json");

        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            root.pending = Math.max(0, root.pending - 1);

            if (xhr.status === 401 && !isRetry) {
                root.renew(() => root.request(method, path, body, callback, onFail, true));
                return;
            }
            if (xhr.status === 0) {
                report(Translation.tr("Sin conexión con Spotify"));
                return;
            }
            if (xhr.status === 429) {
                report(Translation.tr("Spotify te frenó por demasiadas peticiones. Esperá un momento."));
                return;
            }
            if (xhr.status === 403) {
                report(Translation.tr("Spotify rechazó el permiso (403). Puede que necesites Premium o volver a conectar la cuenta."));
                return;
            }
            if (xhr.status === 404) {
                report(Translation.tr("No hay ningún dispositivo de Spotify activo"));
                return;
            }
            // 204 = comando aceptado y sin cuerpo (play, pause, next…)
            if (xhr.status === 204 || xhr.responseText.length === 0) {
                if (callback) callback(null);
                if (root.state === "error") { root.state = "idle"; root.lastError = ""; }
                return;
            }
            if (xhr.status < 200 || xhr.status >= 300) {
                report(Translation.tr("Spotify respondió %1").arg(xhr.status));
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

    function api(path, callback, onFail) {
        root.request("GET", path, null, callback, onFail);
    }

    /**
     * Comprueba que el token realmente sirva pidiendo el perfil.
     * Es el validador: si esto anda, cualquier lista vacía es una lista vacía de
     * verdad y no una sesión rota.
     */
    function validate() {
        if (!root.configured) {
            root.fail(Translation.tr("Falta el Client ID de Spotify"));
            return;
        }
        root.api("/me", data => {
            if (!data) return;
            root.profileName = data.display_name ?? data.id ?? "";
            root.profilePlan = data.product ?? "";
        });
    }

    function refreshAll() {
        root.fetchPlaylists();
        root.fetchRecent();
        root.fetchHome();
        root.fetchPlayback();
        if (root.searchQuery.trim().length > 0) root.search(root.searchQuery);
    }

    /** Lo que dispara el botón de sync: revalida y vuelve a bajar todo. */
    function sync() {
        root.lastError = "";
        root.state = "idle";
        root.validate();
        root.refreshAll();
    }

    // ------------------------------------------------------------------ //
    // Biblioteca
    // ------------------------------------------------------------------ //

    function fetchPlaylists() {
        root.api("/me/playlists?limit=50", data => {
            root.playlists = (data?.items ?? []).filter(item => item).map(item => ({
                "uri": item.uri,
                "id": item.id,
                "type": "playlist",
                "name": item.name,
                "subtitle": Translation.tr("%1 temas").arg(item.tracks?.total ?? 0),
                "image": item.images?.[0]?.url ?? ""
            }));
            root.lastSync = Date.now();
        });
    }

    function fetchRecent() {
        root.api("/me/player/recently-played?limit=30", data => {
            const seen = ({});
            const out = [];
            (data?.items ?? []).forEach(item => {
                const track = item.track;
                if (!track || seen[track.uri]) return; // el historial repite mucho
                seen[track.uri] = true;
                out.push(root.trackEntry(track));
            });
            root.recent = out;
            root.lastSync = Date.now();
        });
    }

    property var followedArtists: []

    /** Todo lo que llena la pestaña Inicio. */
    function fetchHome() {
        root.api("/me/following?type=artist&limit=20", data => {
            root.followedArtists = (data?.artists?.items ?? []).filter(a => a).map(artist => ({
                "uri": artist.uri,
                "id": artist.id,
                "type": "artist",
                "name": artist.name,
                "subtitle": (artist.genres ?? []).slice(0, 2).join(", "),
                "image": artist.images?.[0]?.url ?? ""
            }));
        }, () => {});

        root.api("/me/top/tracks?limit=20&time_range=short_term", data => {
            root.topTracks = (data?.items ?? []).filter(t => t).map(track => root.trackEntry(track));
        }, () => {}); // si falta el scope no rompe el resto

        root.api("/me/top/artists?limit=20", data => {
            root.topArtists = (data?.items ?? []).filter(a => a).map(artist => ({
                "uri": artist.uri,
                "id": artist.id,
                "type": "artist",
                "name": artist.name,
                "subtitle": (artist.genres ?? []).slice(0, 2).join(", "),
                "image": artist.images?.[0]?.url ?? ""
            }));
        }, () => {});

        root.api("/browse/new-releases?limit=20", data => {
            root.newReleases = (data?.albums?.items ?? []).filter(a => a).map(album => root.albumEntry(album));
        }, () => {});

        root.api("/me/tracks?limit=50", data => {
            root.likedTracks = (data?.items ?? []).filter(i => i?.track).map(item => root.trackEntry(item.track));
        }, () => {});

        root.api("/me/albums?limit=20", data => {
            root.savedAlbums = (data?.items ?? []).filter(i => i?.album).map(item => root.albumEntry(item.album));
        }, () => {});
    }

    function search(query) {
        root.searchQuery = query;
        if (query.trim().length === 0) {
            root.searchResults = [];
            return;
        }
        root.api(`/search?type=track,playlist,album,artist&limit=8&q=${encodeURIComponent(query)}`, data => {
            if (!data) return;
            const tracks = (data.tracks?.items ?? []).filter(t => t).map(track => root.trackEntry(track));
            const albums = (data.albums?.items ?? []).filter(a => a).map(album => root.albumEntry(album));
            const lists = (data.playlists?.items ?? []).filter(p => p).map(playlist => ({
                "uri": playlist.uri,
                "id": playlist.id,
                "type": "playlist",
                "name": playlist.name,
                "subtitle": Translation.tr("Playlist"),
                "image": playlist.images?.[0]?.url ?? ""
            }));
            const artists = (data.artists?.items ?? []).filter(a => a).map(artist => ({
                "uri": artist.uri,
                "id": artist.id,
                "type": "artist",
                "name": artist.name,
                "subtitle": Translation.tr("Artista"),
                "image": artist.images?.[0]?.url ?? ""
            }));
            root.searchResults = [...tracks, ...lists, ...albums, ...artists];
        });
    }

    function trackEntry(track) {
        return ({
            "uri": track.uri,
            "id": track.id,
            "type": "track",
            "name": track.name,
            "subtitle": (track.artists ?? []).map(a => a.name).join(", "),
            "image": track.album?.images?.[0]?.url ?? ""
        });
    }

    function albumEntry(album) {
        return ({
            "uri": album.uri,
            "id": album.id,
            "type": "album",
            "name": album.name,
            "subtitle": (album.artists ?? []).map(a => a.name).join(", "),
            "image": album.images?.[0]?.url ?? ""
        });
    }

    // ------------------------------------------------------------------ //
    // Abrir una playlist / álbum / artista
    // ------------------------------------------------------------------ //

    /** Entra a una colección y trae sus temas, para poder tocar uno suelto. */
    function openCollection(entry) {
        if (!entry) return;
        root.openedCollection = entry;
        root.collectionTracks = [];

        if (entry.type === "playlist") {
            root.api(`/playlists/${entry.id}/tracks?limit=100`, data => {
                root.collectionTracks = (data?.items ?? [])
                    .filter(item => item?.track?.uri)
                    .map(item => root.trackEntry(item.track));
            });
        } else if (entry.type === "album") {
            root.api(`/albums/${entry.id}/tracks?limit=50`, data => {
                // Los temas de un álbum no traen el álbum adentro: le pegamos la tapa
                root.collectionTracks = (data?.items ?? []).filter(t => t).map(track => {
                    const built = root.trackEntry(track);
                    built.image = entry.image;
                    return built;
                });
            });
        } else if (entry.type === "artist") {
            root.api(`/artists/${entry.id}/top-tracks?market=from_token`, data => {
                root.collectionTracks = (data?.tracks ?? []).filter(t => t).map(track => root.trackEntry(track));
            });
        }
    }

    function closeCollection() {
        root.openedCollection = null;
        root.collectionTracks = [];
    }

    // ------------------------------------------------------------------ //
    // Control de reproducción
    // ------------------------------------------------------------------ //

    function fetchPlayback() {
        if (!root.connected) return;
        root.api("/me/player", data => {
            root.playback = data; // null cuando no hay nada sonando en ningún lado
        }, () => {}); // callado: sondea seguido, no vale romper la UI por un hipo
    }

    function fetchDevices() {
        root.api("/me/player/devices", data => {
            root.devices = (data?.devices ?? []).map(device => ({
                "id": device.id,
                "name": device.name,
                "type": device.type,
                "active": device.is_active ?? false,
                "volume": device.volume_percent ?? 0
            }));
        }, () => {});
    }

    function transferTo(deviceId, keepPlaying = true) {
        root.request("PUT", "/me/player", { "device_ids": [deviceId], "play": keepPlaying },
            () => root.pokePlayback(), message => root.fail(message));
    }

    /** Tras un comando el estado tarda un instante en reflejarse del lado de Spotify. */
    function pokePlayback() {
        pokeTimer.restart();
    }

    Timer {
        id: pokeTimer
        interval: 400
        onTriggered: {
            root.fetchPlayback();
            root.fetchDevices();
        }
    }

    /**
     * Manda un comando de reproducción. Si no se puede (sin Premium, sin dispositivo
     * activo) cae en abrir el URI con el Spotify de escritorio, que anda siempre.
     */
    function command(method, path, body, fallbackUri) {
        if (root.knownFree) {
            root.openInApp(fallbackUri);
            return;
        }
        root.request(method, path, body, () => root.pokePlayback(), message => {
            if (fallbackUri) root.openInApp(fallbackUri);
            else root.fail(message);
        });
    }

    /** Toca una playlist, álbum o artista entero. */
    function playContext(uri, offsetUri) {
        if (!uri) return;
        const body = ({ "context_uri": uri });
        if (offsetUri) body.offset = ({ "uri": offsetUri });
        root.command("PUT", "/me/player/play", body, offsetUri ?? uri);
    }

    /** Toca un tema suelto; con `contextUri` sigue la lista después de ese tema. */
    function playTrack(uri, contextUri) {
        if (!uri) return;
        if (contextUri) {
            root.playContext(contextUri, uri);
            return;
        }
        root.command("PUT", "/me/player/play", ({ "uris": [uri] }), uri);
    }

    /** Punto de entrada desde la UI: cada tipo se toca como corresponde. */
    function play(entryOrUri, contextUri) {
        if (!entryOrUri) return;
        if (typeof entryOrUri === "string") {
            root.playTrack(entryOrUri, contextUri);
            return;
        }
        if (entryOrUri.type === "track") root.playTrack(entryOrUri.uri, contextUri);
        else root.playContext(entryOrUri.uri);
    }

    function pause() { root.command("PUT", "/me/player/pause", null, ""); }
    function resume() { root.command("PUT", "/me/player/play", null, ""); }
    function togglePlay() { root.isPlaying ? root.pause() : root.resume(); }
    function nextTrack() { root.command("POST", "/me/player/next", null, ""); }
    function previousTrack() { root.command("POST", "/me/player/previous", null, ""); }

    function seekTo(ms) {
        root.command("PUT", `/me/player/seek?position_ms=${Math.round(ms)}`, null, "");
    }
    function setShuffle(on) {
        root.command("PUT", `/me/player/shuffle?state=${on ? "true" : "false"}`, null, "");
    }
    function toggleShuffle() { root.setShuffle(!root.shuffleOn); }
    function setRepeat(mode) {
        root.command("PUT", `/me/player/repeat?state=${mode}`, null, "");
    }
    /** off → context → track → off */
    function cycleRepeat() {
        const order = ["off", "context", "track"];
        const next = order[(order.indexOf(root.repeatMode) + 1) % order.length];
        root.setRepeat(next);
    }
    function setVolume(percent) {
        root.command("PUT", `/me/player/volume?volume_percent=${Math.round(percent)}`, null, "");
    }

    /**
     * Plan B cuando la Web API no puede controlar (cuenta gratuita).
     *
     * Va por MPRIS y no por xdg-open: `OpenUri` sobre el bus le dice al Spotify que
     * ya tenés abierto qué tocar, sin levantar la ventana ni sacarte de lo que
     * estabas haciendo. xdg-open, en cambio, abre el cliente y te roba el foco.
     * Sólo si no hay Spotify en el bus se cae a xdg-open, que ahí sí hace falta
     * porque no hay nada corriendo que pueda recibir la orden.
     */
    property string pendingUri: ""

    function openInApp(uri) {
        if (!uri || uri.length === 0) return;
        root.pendingUri = uri;
        // Spotify expone las dos: OpenUri toca un tema suelto, LoadContextUri carga
        // una playlist/álbum/artista como contexto (que es lo que hace falta para
        // que después siga sonando la lista y no un tema aislado).
        const isContext = uri.startsWith("spotify:playlist:")
            || uri.startsWith("spotify:album:")
            || uri.startsWith("spotify:artist:");
        const method = isContext
            ? "org.mpris.MediaPlayer2.Player.LoadContextUri"
            : "org.mpris.MediaPlayer2.Player.OpenUri";

        mprisOpen.running = false;
        mprisOpen.command = ["dbus-send", "--session", "--print-reply=literal",
            "--dest=org.mpris.MediaPlayer2.spotify",
            "/org/mpris/MediaPlayer2", method, `string:${uri}`];
        mprisOpen.running = true;
    }

    Process {
        id: mprisOpen
        onExited: exitCode => {
            if (exitCode !== 0 && root.pendingUri.length > 0) {
                // No hay Spotify escuchando en el bus: no queda otra que abrirlo
                Quickshell.execDetached(["xdg-open", root.pendingUri]);
            }
            root.pendingUri = "";
            root.pokePlayback();
        }
    }

    // Sondeo del estado mientras mirás la pestaña. Fuera de la pestaña no pide nada
    // para no gastar cuota al pedo.
    Timer {
        running: root.connected && root.watching
        interval: 3000
        repeat: true
        triggeredOnStart: true
        onTriggered: root.fetchPlayback()
    }

    // Red de seguridad: si el token estaba vencido cuando abriste la pestaña y
    // nadie tocó nada, esto lo renueva solo en vez de dejarte la lista vacía.
    Timer {
        running: root.connected
        interval: 15 * 60 * 1000
        repeat: true
        onTriggered: root.sync()
    }

    // A diferencia de MailService/GoogleAccount/AppleAccount/AiSession, esto no
    // pedía el keyring por su cuenta: dependía de que otro feature (Mail, la
    // cuenta de Google, etc.) lo hubiera disparado antes. Si el usuario sólo usa
    // Spotify, `connected` queda en false para siempre después de reiniciar la
    // shell, aunque el token siga siendo válido en el keyring del sistema — el
    // `onConnectedChanged` de arriba nunca llega a dispararse porque nada le
    // avisa al keyring que lo cargue.
    Component.onCompleted: {
        if (!KeyringStorage.loaded) KeyringStorage.fetchKeyringData();
        if (root.connected) {
            root.validate();
            root.refreshAll();
        }
    }
}
