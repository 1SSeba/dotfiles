pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs.services
import Quickshell
import Quickshell.Io
import QtQuick

/**
 * Fuentes de inspiración para la pestaña Inspo.
 *
 * Dos mundos distintos bajo la misma grilla:
 * - "pinterest": TUS boards y pines guardados, vía la API v5 con OAuth. La API
 *   oficial no expone búsqueda global de Pinterest, así que acá sólo se busca
 *   sobre lo que vos ya guardaste (endpoint search/user/pins).
 * - "wallhaven" / "openverse": descubrimiento real de imágenes nuevas, sin
 *   cuenta ni key.
 *
 * Cada fuente normaliza su respuesta a la misma forma de item para que la
 * grilla no sepa de dónde vino nada.
 */
Singleton {
    id: root

    readonly property string tokenUrl: "https://api.pinterest.com/v5/oauth/token"
    readonly property string apiBase: "https://api.pinterest.com/v5"

    signal resultsChanged()
    signal statusMessage(string message)

    property string currentSource: Persistent.states?.inspo?.source ?? "wallhaven"
    property string currentQuery: ""
    property var items: []
    property bool loading: false
    property string message: ""
    property int runningRequests: 0

    // Paginación: wallhaven/openverse usan número de página, Pinterest un bookmark
    property int currentPage: 1
    property string nextBookmark: ""
    property bool hasMore: false

    // Boards de Pinterest (para el selector de board)
    property var boards: []
    property string currentBoardId: ""

    readonly property var sources: ({
        "wallhaven": {
            "name": "Wallhaven",
            "description": Translation.tr("Fotos y arte en alta resolución. Sin cuenta."),
            "needsAuth": false,
            "icon": "wallpaper"
        },
        "openverse": {
            "name": "Openverse",
            "description": Translation.tr("Índice enorme con licencia abierta (Flickr, museos). Sin cuenta."),
            "needsAuth": false,
            "icon": "photo_library"
        },
        "pinterest": {
            "name": "Pinterest",
            "description": Translation.tr("Tus boards y pines guardados. Necesita login."),
            "needsAuth": true,
            "icon": "push_pin"
        }
    })
    readonly property var sourceList: ["wallhaven", "openverse", "pinterest"]

    // ------------------------------------------------------------------ //
    // Credenciales de Pinterest (viven en el keyring, nunca en config.json)
    // ------------------------------------------------------------------ //

    readonly property var pinterestAuth: KeyringStorage.keyringData?.pinterest ?? ({})
    readonly property bool pinterestLinked: (pinterestAuth.access_token?.length ?? 0) > 0
    readonly property bool pinterestConfigured: (pinterestAuth.client_id?.length ?? 0) > 0
                                             && (pinterestAuth.client_secret?.length ?? 0) > 0

    function setPinterestApp(clientId, clientSecret) {
        // Al pegar desde el navegador suele venir con espacios o saltos de línea
        const id = String(clientId ?? "").replace(/\s+/g, "");
        const secret = String(clientSecret ?? "").replace(/\s+/g, "");
        if (id.length === 0 || secret.length === 0) {
            root.statusMessage(Translation.tr("Necesito el App ID y el App secret."));
            return false;
        }
        KeyringStorage.setNestedField(["pinterest", "client_id"], id);
        KeyringStorage.setNestedField(["pinterest", "client_secret"], secret);
        root.statusMessage(Translation.tr("App de Pinterest guardada. Ahora dale a Conectar."));
        return true;
    }

    function unlinkPinterest() {
        KeyringStorage.setNestedField(["pinterest", "access_token"], "");
        KeyringStorage.setNestedField(["pinterest", "refresh_token"], "");
        root.boards = [];
        root.items = [];
        root.statusMessage(Translation.tr("Sesión de Pinterest cerrada."));
    }

    /** Corre el script de login, que abre el navegador y devuelve el token. */
    function loginPinterest() {
        if (!root.pinterestConfigured) {
            root.statusMessage(Translation.tr("Primero cargá el App ID y el App secret de tu app de Pinterest."));
            return;
        }
        if (loginProc.running) {
            root.statusMessage(Translation.tr("Ya hay un login abierto: mirá el navegador."));
            return;
        }
        root.message = Translation.tr("Esperando el login en el navegador…");
        loginProc.command = ["python3", root.loginScriptPath,
            root.pinterestAuth.client_id, root.pinterestAuth.client_secret, "8085"];
        loginProc.running = true;
    }

    readonly property string loginScriptPath: {
        const p = `${Directories.scriptPath}/inspo/pinterest-login.py`;
        return p.replace(/^file:\/\//, "");
    }

    Process {
        id: loginProc
        stdout: SplitParser {
            onRead: data => {
                if (!data || data.length === 0) return;
                let payload;
                try {
                    payload = JSON.parse(data);
                } catch (e) {
                    return; // línea de ruido, la ignoramos
                }
                if (payload.error) {
                    root.message = Translation.tr("Login fallido: %1").arg(payload.error);
                    root.statusMessage(root.message);
                    return;
                }
                if (payload.status === "waiting") {
                    root.message = Translation.tr("Autorizá la app en el navegador…");
                    return;
                }
                if (payload.status === "ok") {
                    KeyringStorage.setNestedField(["pinterest", "access_token"], payload.access_token);
                    KeyringStorage.setNestedField(["pinterest", "refresh_token"], payload.refresh_token ?? "");
                    root.message = "";
                    root.statusMessage(Translation.tr("✅ Pinterest conectado."));
                    root.fetchBoards();
                }
            }
        }
        onExited: (exitCode) => {
            if (exitCode !== 0 && root.message.indexOf("Login fallido") === -1) {
                root.message = Translation.tr("El login terminó con código %1.").arg(exitCode);
            }
        }
    }

    /** Renueva el access token cuando Pinterest devuelve 401. */
    function refreshPinterestToken(onDone) {
        const refresh = root.pinterestAuth.refresh_token ?? "";
        if (refresh.length === 0 || !root.pinterestConfigured) {
            root.message = Translation.tr("Se venció la sesión de Pinterest. Conectá de nuevo.");
            if (onDone) onDone(false);
            return;
        }
        const basic = Qt.btoa(`${root.pinterestAuth.client_id}:${root.pinterestAuth.client_secret}`);
        const xhr = new XMLHttpRequest();
        xhr.open("POST", root.tokenUrl);
        xhr.setRequestHeader("Authorization", `Basic ${basic}`);
        xhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded");
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (xhr.status === 200) {
                try {
                    const data = JSON.parse(xhr.responseText);
                    KeyringStorage.setNestedField(["pinterest", "access_token"], data.access_token);
                    if (data.refresh_token)
                        KeyringStorage.setNestedField(["pinterest", "refresh_token"], data.refresh_token);
                    if (onDone) onDone(true);
                    return;
                } catch (e) {
                    // cae abajo
                }
            }
            root.message = Translation.tr("No pude renovar la sesión de Pinterest. Conectá de nuevo.");
            if (onDone) onDone(false);
        };
        xhr.send(`grant_type=refresh_token&refresh_token=${encodeURIComponent(refresh)}`);
    }

    // ------------------------------------------------------------------ //
    // Normalización: toda fuente termina en esta forma
    // ------------------------------------------------------------------ //

    function makeItem(o) {
        const w = o.width ?? 0;
        const h = o.height ?? 0;
        return {
            "id": String(o.id ?? ""),
            "thumb_url": o.thumb_url ?? "",
            "full_url": o.full_url ?? o.thumb_url ?? "",
            "width": w,
            "height": h,
            "aspect_ratio": (w > 0 && h > 0) ? (w / h) : 1.0,
            "title": o.title ?? "",
            "author": o.author ?? "",
            "source_url": o.source_url ?? "",
            "license": o.license ?? ""
        };
    }

    function mapWallhaven(data) {
        return (data.data ?? []).map(i => root.makeItem({
            "id": i.id,
            "thumb_url": i.thumbs?.small,
            "full_url": i.path,
            "width": i.dimension_x,
            "height": i.dimension_y,
            "title": i.resolution ?? "",
            "source_url": i.url
        }));
    }

    function mapOpenverse(data) {
        return (data.results ?? []).map(i => root.makeItem({
            "id": i.id,
            // El endpoint /thumb responde 301 hacia /thumb/ y el Image de QML no
            // sigue el redirect: sin la barra final la miniatura queda rota.
            "thumb_url": i.thumbnail
                ? (i.thumbnail.endsWith("/") ? i.thumbnail : i.thumbnail + "/")
                : i.url,
            "full_url": i.url,
            "width": i.width,
            "height": i.height,
            "title": i.title ?? "",
            "author": i.creator ?? "",
            "source_url": i.foreign_landing_url ?? i.url,
            "license": i.license ?? ""
        }));
    }

    function mapPinterestPins(data) {
        return (data.items ?? []).map(pin => {
            // media.images trae varios tamaños con claves tipo "150x150", "600x", "1200x"
            const images = pin.media?.images ?? ({});
            const keys = Object.keys(images);
            // Elegimos el más chico para el thumb y el más grande para abrir
            let smallest = null, largest = null;
            keys.forEach(k => {
                const img = images[k];
                if (!img || !img.url) return;
                const area = (img.width ?? 0) * (img.height ?? 0);
                if (!smallest || area < ((smallest.width ?? 0) * (smallest.height ?? 0))) smallest = img;
                if (!largest || area > ((largest.width ?? 0) * (largest.height ?? 0))) largest = img;
            });
            return root.makeItem({
                "id": pin.id,
                "thumb_url": smallest?.url ?? largest?.url ?? "",
                "full_url": largest?.url ?? smallest?.url ?? "",
                "width": largest?.width,
                "height": largest?.height,
                "title": pin.title ?? pin.alt_text ?? "",
                // El link del pin es a dónde apunta; si no hay, al pin en Pinterest
                "source_url": (pin.link && pin.link.length > 0)
                    ? pin.link : `https://www.pinterest.com/pin/${pin.id}/`
            });
        });
    }

    // ------------------------------------------------------------------ //
    // Requests
    // ------------------------------------------------------------------ //

    function setSource(source) {
        if (root.sourceList.indexOf(source) === -1) return;
        root.currentSource = source;
        if (Persistent.states?.inspo) Persistent.states.inspo.source = source;
        root.items = [];
        root.message = "";
        root.currentBoardId = "";
        if (source === "pinterest" && root.pinterestLinked && root.boards.length === 0)
            root.fetchBoards();
    }

    function search(query) {
        root.currentQuery = String(query ?? "").trim();
        root.currentPage = 1;
        root.nextBookmark = "";
        root.items = [];
        root.message = "";
        root.fetchPage(false);
    }

    function loadMore() {
        if (root.loading || !root.hasMore) return;
        if (root.currentSource === "pinterest") {
            if (root.nextBookmark.length === 0) return;
        } else {
            root.currentPage += 1;
        }
        root.fetchPage(true);
    }

    function buildUrl() {
        const q = encodeURIComponent(root.currentQuery);
        if (root.currentSource === "wallhaven") {
            // categories=111 (general+anime+people), purity=100 (sólo SFW)
            return `https://wallhaven.cc/api/v1/search?q=${q}&categories=111&purity=100`
                 + `&sorting=${root.currentQuery.length > 0 ? "relevance" : "toplist"}&page=${root.currentPage}`;
        }
        if (root.currentSource === "openverse") {
            // Sin API key el máximo es 20 por página; pedir más da 401
            return `https://api.openverse.org/v1/images/?q=${q}&page_size=20&page=${root.currentPage}`;
        }
        if (root.currentSource === "pinterest") {
            const bookmark = root.nextBookmark.length > 0
                ? `&bookmark=${encodeURIComponent(root.nextBookmark)}` : "";
            if (root.currentQuery.length > 0)
                return `${root.apiBase}/search/user/pins?query=${q}&page_size=25${bookmark}`;
            if (root.currentBoardId.length > 0)
                return `${root.apiBase}/boards/${root.currentBoardId}/pins?page_size=25${bookmark}`;
            return `${root.apiBase}/pins?page_size=25${bookmark}`;
        }
        return "";
    }

    function fetchPage(append) {
        if (root.currentSource === "pinterest" && !root.pinterestLinked) {
            root.message = Translation.tr("Conectá tu cuenta de Pinterest para ver tus pines.");
            root.resultsChanged();
            return;
        }
        const url = root.buildUrl();
        if (url.length === 0) return;
        root.loading = true;
        root.runningRequests++;
        root.doFetch(url, append, true);
    }

    /** `allowRetry` evita loopear si el refresh del token tampoco sirve. */
    function doFetch(url, append, allowRetry) {
        const xhr = new XMLHttpRequest();
        xhr.open("GET", url);
        if (root.currentSource === "pinterest")
            xhr.setRequestHeader("Authorization", `Bearer ${root.pinterestAuth.access_token}`);
        if (root.currentSource === "openverse")
            xhr.setRequestHeader("User-Agent", "quickshell-inspo/1.0");

        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;

            if (xhr.status === 401 && root.currentSource === "pinterest" && allowRetry) {
                // Token vencido: lo renovamos y reintentamos una sola vez
                root.refreshPinterestToken(ok => {
                    if (ok) root.doFetch(url, append, false);
                    else { root.loading = false; root.runningRequests--; root.resultsChanged(); }
                });
                return;
            }

            root.loading = false;
            root.runningRequests--;

            if (xhr.status !== 200) {
                root.message = root.errorFor(xhr.status, xhr.responseText);
                root.resultsChanged();
                return;
            }

            try {
                const data = JSON.parse(xhr.responseText);
                let mapped = [];
                if (root.currentSource === "wallhaven") {
                    mapped = root.mapWallhaven(data);
                    const meta = data.meta ?? ({});
                    root.hasMore = (meta.current_page ?? 1) < (meta.last_page ?? 1);
                } else if (root.currentSource === "openverse") {
                    mapped = root.mapOpenverse(data);
                    root.hasMore = (data.page ?? 1) < (data.page_count ?? 1);
                } else if (root.currentSource === "pinterest") {
                    mapped = root.mapPinterestPins(data);
                    root.nextBookmark = data.bookmark ?? "";
                    root.hasMore = root.nextBookmark.length > 0;
                }
                // Sin url de imagen no hay nada que mostrar
                mapped = mapped.filter(i => i.thumb_url.length > 0);
                root.items = append ? [...root.items, ...mapped] : mapped;
                root.message = root.items.length > 0 ? "" : Translation.tr("Nada por acá. Probá con otras palabras.");
            } catch (e) {
                root.message = Translation.tr("No pude leer la respuesta: %1").arg(e);
            }
            root.resultsChanged();
        };
        xhr.send();
    }

    function errorFor(status, body) {
        if (status === 0) return Translation.tr("Sin conexión.");
        if (status === 401) return Translation.tr("Sesión vencida. Conectá Pinterest de nuevo.");
        if (status === 403) return Translation.tr("Pinterest rechazó el permiso. ¿La app tiene los scopes boards:read y pins:read?");
        if (status === 429) return Translation.tr("Demasiados pedidos. Esperá un rato.");
        return Translation.tr("Falló el pedido (HTTP %1).").arg(status);
    }

    function fetchBoards() {
        if (!root.pinterestLinked) return;
        const xhr = new XMLHttpRequest();
        xhr.open("GET", `${root.apiBase}/boards?page_size=50`);
        xhr.setRequestHeader("Authorization", `Bearer ${root.pinterestAuth.access_token}`);
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (xhr.status !== 200) return;
            try {
                const data = JSON.parse(xhr.responseText);
                root.boards = (data.items ?? []).map(b => ({
                    "id": b.id,
                    "name": b.name ?? "",
                    "pin_count": b.pin_count ?? 0,
                    "cover": b.media?.image_cover_url ?? ""
                }));
            } catch (e) {
                // sin boards, se sigue pudiendo buscar
            }
        };
        xhr.send();
    }

    function openBoard(boardId) {
        root.currentBoardId = boardId ?? "";
        root.currentQuery = "";
        root.nextBookmark = "";
        root.items = [];
        root.fetchPage(false);
    }
}
