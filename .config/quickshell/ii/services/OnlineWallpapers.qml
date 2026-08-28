pragma Singleton

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string provider:   "wallhaven"  // "wallhaven" | "unsplash"
    property string resolution: "1080p"      // "1080p" | "2K" | "4K"
    property string query:      ""           // empty keyword = random
    property string category:   "general"    // wallhaven: "general"|"anime"|"people" / unsplash: "nature"|"city"|...
    property string purity:     "sfw"        // wallhaven: "sfw"|"sketchy"|"nsfw"
    property bool   loading:    false
    property bool   appending:  false 
    property int    page:       1
    property string seed:       ""          
    property var    results:    []           // list [ {thumb, full, id, provider} ]
    property int totalPages: 0

    signal fetched()
    signal fetchError(string message)

    // ─── APIs ───
    /**
     * Lee una API key del keyring en el momento de usarla.
     * Con `readonly property string x: KeyringStorage.keyringData?.apiKeys?.unsplash ?? ""`
     * el binding se evalúa una vez, mientras el keyring todavía está vacío, y como nadie
     * lo observa nunca se vuelve a evaluar: la key queda clavada en "" aunque exista.
     * Es exactamente el bug que tuvimos con el refresh token de Spotify.
     */
    function apiKey(name) {
        const keys = KeyringStorage.keyringData?.apiKeys;
        if (!keys) return "";
        const value = keys[name];
        return (value === undefined || value === null) ? "" : value;
    }

    // ─── Resolution ───
    readonly property var resolutionMap: ({
        "wallhaven": {
            "1080p": "1920x1080",
            "2K":    "2560x1440",
            "4K":    "3840x2160",
        },
        "unsplash": {
            "1080p": "&w=1920&h=1080&fit=crop",
            "2K":    "&w=2560&h=1440&fit=crop",
            "4K":    "&w=3840&h=2160&fit=crop",
        },
        "pexels": {
            "1080p": "&w=1920&h=1080&fit=crop",
            "2K":    "&w=2560&h=1440&fit=crop",
            "4K":    "&w=3840&h=2160&fit=crop",
        }
    })

    // ─── Categorías wallhaven ───
    // El fork mandaba `categories=100` fijo e ignoraba `root.category`.
    readonly property var categoryMap: ({
        "general": "100",
        "anime":   "010",
        "people":  "001",
    })

    // ─── Purity wallhaven ───
    readonly property var purityMap: ({
        "sfw":     "100",
        "sketchy": "110",
        "nsfw":    "111",
    })

    function fetch() {
        if (root.loading) return;
        root.page = 1;
        root.seed = "";
        root.appending = false;
        root.results = [];
        _doFetch();
    }

    function nextPage() {
        if (root.loading) return;
        if (root.provider !== "unsplash" && root.totalPages > 0 && root.page >= root.totalPages) return;  // NUEVO: no pedir de más
        root.appending = true;   
        root.page += 1;
        _doFetch();
    }

    function prevPage() {
        if (root.loading || root.page <= 1) return;
        root.page -= 1;
        _doFetch();
    }

    function _doFetch() {
        root.loading = true;
        if (root.provider === "wallhaven") {
            _fetchWallhaven();
        } else if (root.provider === "unsplash") {
            _fetchUnsplash();
        } else if (root.provider === "pexels") {
            _fetchPexels();
        }
    }

    function goToPage(n) {
        root.page = n;
        _doFetch();
    }

    function _fetchWallhaven() {
        const res      = root.resolutionMap["wallhaven"][root.resolution] ?? "1920x1080";
        const purity   = root.purityMap[root.purity] ?? "100";
        const categories = root.categoryMap[root.category] ?? "100";
        const apikey   = root.apiKey("wallhaven").length > 0 ? `&apikey=${root.apiKey("wallhaven")}` : "";
        const q        = root.query.length > 0 ? `&q=${encodeURIComponent(root.query)}` : ""; 
        const seedParam = root.seed.length > 0 ? `&seed=${root.seed}` : "";

        const url = `https://wallhaven.cc/api/v1/search?sorting=random&purity=${purity}&categories=${categories}&ratios=16x9&atleast=${res}&page=${root.page}${seedParam}${q}${apikey}`;

        fetchProc.provider = "wallhaven";
        fetchProc.command = ["curl", "-s", url];
        fetchProc.running = true;
    }

    function _fetchUnsplash() {
        const orientation = "landscape";
        const count       = 24;
        const q           = root.query.length > 0 ? `&query=${encodeURIComponent(root.query)}` : `&query=${encodeURIComponent(root.category)}`;  
        const clientId    = root.apiKey("unsplash");

        const url = `https://api.unsplash.com/photos/random?orientation=${orientation}&count=${count}${q}&client_id=${clientId}`;

        fetchProc.provider = "unsplash";
        fetchProc.command = ["curl", "-s", url];
        fetchProc.running = true;
    }

    function _fetchPexels() {
        const q = root.query.length > 0 ? root.query : "wallpaper landscape";
        const url = `https://api.pexels.com/v1/search?query=${encodeURIComponent(q)}&per_page=24&page=${root.page}`;
        fetchProc.provider = "pexels";
        fetchProc.command  = ["curl", "-s", "-H", `Authorization: ${root.apiKey("pexels")}`, url];
        fetchProc.running  = true;
    }

    function _parseWallhaven(jsonStr) {
        try {
            const data = JSON.parse(jsonStr);
            if (data.meta?.seed && root.seed.length === 0) {
                root.seed = data.meta.seed;
            }
            root.totalPages = data.meta?.last_page ?? 0
            const newItems = data.data.map(item => ({
                id:               item.id,
                thumb:            item.thumbs.large,
                full:             item.path,
                provider:         "wallhaven",
                title:            "",
                author:           "",
                authorUrl:        "",
                likes:            0,
                width:            item.dimension_x ?? 0,
                height:           item.dimension_y ?? 0,
                downloadLocation: "",
            }));
            root.results = root.appending ? root.results.concat(newItems) : newItems;   // CAMBIO
            root.fetched();
        } catch (e) {
            root.fetchError("Wallhaven parse error: " + e);
        }
    }

    function _parseUnsplash(jsonStr) {
        try {
            const data = JSON.parse(jsonStr);
            const newItems = data.map(item => ({
                id:               item.id,
                thumb:            item.urls.small,
                full: item.urls.raw + (root.resolution === "4K" ? "&w=3840&h=2160&fit=crop&fm=jpg&q=85"
                    : root.resolution === "2K" ? "&w=2560&h=1440&fit=crop&fm=jpg&q=85"
                    : "&w=1920&h=1080&fit=crop&fm=jpg&q=85"),
                provider:         "unsplash",
                title:            item.alt_description ?? item.description ?? "",
                author:           item.user?.name ?? "",
                authorUrl:        item.user?.links?.html ?? "",
                likes:            item.likes ?? 0,
                width:            item.width ?? 0,
                height:           item.height ?? 0,
                downloadLocation: item.links?.download_location ?? "",
            }));

            root.results = root.appending ? root.results.concat(newItems) : newItems;
            root.fetched();
        } catch (e) {
            root.fetchError("Unsplash parse error: " + e);
        }
    }

    function _parsePexels(jsonStr) {
        try {
            const data = JSON.parse(jsonStr);
            root.totalPages = Math.ceil((data.total_results ?? 0) / 24);
            const newItems = data.photos.map(item => ({
                id:               String(item.id),
                thumb:            item.src.large,
                full: root.resolution === "4K" ? item.src.original + "?auto=compress&cs=tinysrgb&w=3840&h=2160&fit=crop"
                    : root.resolution === "2K" ? item.src.original + "?auto=compress&cs=tinysrgb&w=2560&h=1440&fit=crop"
                    :                            item.src.original + "?auto=compress&cs=tinysrgb&w=1920&h=1080&fit=crop",
                provider:         "pexels",
                title:            item.alt ?? "",
                author:           item.photographer ?? "",
                authorUrl:        item.photographer_url ?? "",
                likes:            0,
                width:            item.width ?? 0,
                height:           item.height ?? 0,
                avgColor:         item.avg_color ?? "",
                downloadLocation: "",
            }));

            root.results = root.appending ? root.results.concat(newItems) : newItems;
            root.fetched();
        } catch (e) {
            root.fetchError("Pexels parse error: " + e);
        }
    }

    // ─── Process ───
    Process {
        id: fetchProc
        property string provider: ""
        property string buffer:   ""

        onRunningChanged: {
            if (running) buffer = "";
        }

        stdout: SplitParser {
            onRead: data => {
                fetchProc.buffer += data;
            }
        }

        onExited: (exitCode) => {
            root.loading = false;
            if (exitCode !== 0) {
                root.fetchError("curl exited with code " + exitCode);
                return;
            }
            if (fetchProc.provider === "wallhaven") {
                root._parseWallhaven(fetchProc.buffer);
            } else if (fetchProc.provider === "unsplash") {
                root._parseUnsplash(fetchProc.buffer);
            } else if (fetchProc.provider === "pexels") {
                root._parsePexels(fetchProc.buffer);
            }
        }
    }
}
