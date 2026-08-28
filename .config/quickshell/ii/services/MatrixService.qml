pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.modules.common

/**
 * Cliente Matrix para la pestaña de redes.
 *
 * Matrix es el pegamento: Synapse corre local y los puentes (mautrix-whatsapp y
 * compañía) meten los chats de otras redes como salas comunes. Para esta shell
 * entonces WhatsApp no es un caso especial: es una sala más.
 *
 * El token vive en el keyring, nunca en la config. Como en Spotify, los campos del
 * keyring se leen con una función y no con un binding encadenado: el keyring carga
 * asincrónico y el binding se queda clavado en el valor vacío del arranque.
 */
Singleton {
    id: root

    readonly property string homeserver: Config.options?.sidebar?.social?.matrix?.homeserver ?? "http://localhost:8008"
    readonly property string apiBase: `${root.homeserver}/_matrix/client/v3`

    function tokenField(name) {
        const data = KeyringStorage.keyringData?.matrix;
        if (!data) return "";
        const value = data[name];
        return (value === undefined || value === null) ? "" : value;
    }

    // Sólo para la UI; para pedir se usa tokenField()
    readonly property string accessToken: KeyringStorage.keyringData?.matrix?.access_token ?? ""
    readonly property string userId: KeyringStorage.keyringData?.matrix?.user_id ?? ""
    readonly property bool connected: root.accessToken.length > 0

    /** idle | working | error */
    property string state: "idle"
    property string lastError: ""

    property int pending: 0
    readonly property bool loading: root.pending > 0
    property real lastSync: 0
    /** El /sync largo está en vuelo. */
    property bool syncing: false

    /** Token de continuación del /sync incremental. */
    property string syncToken: ""

    /** roomId -> { id, name, avatar, lastBody, lastTs, unread, messages: [] } */
    property var roomData: ({})
    /** Salas ordenadas por actividad, listo para el modelo de la lista. */
    property var rooms: []

    property string openRoomId: ""
    readonly property var openRoom: root.openRoomId.length > 0 ? (root.roomData[root.openRoomId] ?? null) : null
    readonly property var openMessages: root.openRoom?.messages ?? []

    /** Mientras la pestaña está a la vista se sincroniza; si no, no. */
    property bool watching: false

    readonly property string status: {
        if (!root.connected) return Translation.tr("Sin conectar");
        if (root.state === "error") return root.lastError;
        if (root.loading || root.syncing) return Translation.tr("Sincronizando…");
        if (root.rooms.length === 0) return Translation.tr("Conectado · sin chats todavía");
        return Translation.tr("%1 · %2 chats").arg(root.userId).arg(root.rooms.length);
    }

    readonly property bool healthy: root.connected && root.state !== "error" && root.lastSync > 0

    function fail(message) {
        root.lastError = message;
        root.state = "error";
        console.log("[Matrix]", message);
    }

    // ------------------------------------------------------------------ //
    // Sesión
    // ------------------------------------------------------------------ //

    function login(user, password) {
        if (user.length === 0 || password.length === 0) {
            root.fail(Translation.tr("Faltan usuario o contraseña"));
            return;
        }
        // Acepta "scruzd" o "@scruzd:localhost"
        const localpart = user.startsWith("@") ? user.substring(1).split(":")[0] : user;

        root.state = "working";
        root.lastError = "";
        root.pending++;

        const xhr = new XMLHttpRequest();
        xhr.open("POST", `${root.apiBase}/login`);
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            root.pending = Math.max(0, root.pending - 1);

            if (xhr.status === 0) {
                root.fail(Translation.tr("No responde el homeserver en %1").arg(root.homeserver));
                return;
            }
            if (xhr.status === 403) {
                root.fail(Translation.tr("Usuario o contraseña incorrectos"));
                return;
            }
            if (xhr.status !== 200) {
                root.fail(Translation.tr("El homeserver respondió %1").arg(xhr.status));
                return;
            }
            try {
                const data = JSON.parse(xhr.responseText);
                KeyringStorage.setNestedField(["matrix"], {
                    "access_token": data.access_token,
                    "user_id": data.user_id,
                    "device_id": data.device_id ?? ""
                });
                root.state = "idle";
                root.syncToken = "";
                root.roomData = ({});
                root.rooms = [];
            } catch (e) {
                root.fail(String(e));
            }
        };
        xhr.send(JSON.stringify({
            "type": "m.login.password",
            "identifier": { "type": "m.id.user", "user": localpart },
            "password": password
        }));
    }

    function logout() {
        const token = root.tokenField("access_token");
        if (token.length > 0) {
            const xhr = new XMLHttpRequest();
            xhr.open("POST", `${root.apiBase}/logout`);
            xhr.setRequestHeader("Authorization", `Bearer ${token}`);
            xhr.send("{}");
        }
        KeyringStorage.setNestedField(["matrix"], ({}));
        root.syncToken = "";
        root.roomData = ({});
        root.rooms = [];
        root.openRoomId = "";
        root.lastSync = 0;
        root.lastError = "";
        root.state = "idle";
    }

    // ------------------------------------------------------------------ //
    // Sync
    // ------------------------------------------------------------------ //

    /**
     * Un /sync. El primero trae el estado inicial (rápido, poco historial); los
     * siguientes se quedan colgados hasta 30s esperando novedades, que es como
     * Matrix hace tiempo real sin websockets.
     */
    function sync() {
        const token = root.tokenField("access_token");
        if (token.length === 0 || root.syncing) return;

        const first = root.syncToken.length === 0;
        const filter = encodeURIComponent(JSON.stringify({
            "room": { "timeline": { "limit": first ? 20 : 50 } }
        }));
        let url = `${root.apiBase}/sync?filter=${filter}`;
        if (first) {
            url += "&timeout=0";
        } else {
            url += `&since=${encodeURIComponent(root.syncToken)}&timeout=30000`;
        }

        root.syncing = true;
        const xhr = new XMLHttpRequest();
        xhr.open("GET", url);
        xhr.setRequestHeader("Authorization", `Bearer ${token}`);
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            root.syncing = false;

            if (xhr.status === 0) {
                // Un long-poll cortado es normal (cambiar de pestaña, dormir la
                // máquina). No es un error que valga la pena mostrar.
                return;
            }
            if (xhr.status === 401) {
                root.fail(Translation.tr("La sesión de Matrix venció. Entrá de nuevo."));
                return;
            }
            if (xhr.status !== 200) {
                root.fail(Translation.tr("Matrix respondió %1").arg(xhr.status));
                return;
            }
            try {
                root.applySync(JSON.parse(xhr.responseText));
                root.lastSync = Date.now();
                if (root.state === "error") {
                    root.state = "idle";
                    root.lastError = "";
                }
            } catch (e) {
                root.fail(String(e));
            }
        };
        xhr.send();
    }

    function applySync(data) {
        root.syncToken = data.next_batch ?? root.syncToken;
        const joined = data.rooms?.join ?? ({});
        const next = Object.assign({}, root.roomData);

        Object.keys(joined).forEach(roomId => {
            const room = joined[roomId];
            const existing = next[roomId] ?? {
                "id": roomId, "name": "", "avatar": "",
                "lastBody": "", "lastTs": 0, "unread": 0, "messages": []
            };
            const entry = Object.assign({}, existing);
            entry.messages = existing.messages.slice();

            // Nombre y avatar salen del estado de la sala. Los puentes ponen de
            // nombre el del contacto, así que un chat de WhatsApp se ve con el
            // nombre de la persona sin hacer nada especial.
            const stateEvents = (room.state?.events ?? []).concat(room.timeline?.events ?? []);
            stateEvents.forEach(ev => {
                if (ev.type === "m.room.name" && ev.content?.name)
                    entry.name = ev.content.name;
                else if (ev.type === "m.room.avatar" && ev.content?.url)
                    entry.avatar = root.mediaUrl(ev.content.url);
            });

            (room.timeline?.events ?? []).forEach(ev => {
                if (ev.type !== "m.room.message") return;
                if (entry.messages.some(m => m.id === ev.event_id)) return;

                const message = {
                    "id": ev.event_id,
                    "sender": ev.sender,
                    "mine": ev.sender === root.userId,
                    "body": ev.content?.body ?? "",
                    "msgtype": ev.content?.msgtype ?? "m.text",
                    "ts": ev.origin_server_ts ?? Date.now()
                };
                entry.messages.push(message);
                if (message.ts >= entry.lastTs) {
                    entry.lastTs = message.ts;
                    entry.lastBody = message.body;
                }
            });

            entry.messages.sort((a, b) => a.ts - b.ts);
            // No hace falta guardar el chat entero en memoria para siempre
            if (entry.messages.length > 200)
                entry.messages = entry.messages.slice(entry.messages.length - 200);

            entry.unread = (roomId === root.openRoomId)
                ? 0
                : (room.unread_notifications?.notification_count ?? entry.unread);

            if (entry.name.length === 0) entry.name = root.fallbackName(roomId, entry);
            next[roomId] = entry;
        });

        root.roomData = next;
        root.rebuildRoomList();
    }

    /** Sin m.room.name (chats directos), el nombre sale de quién escribió. */
    function fallbackName(roomId, entry) {
        const other = entry.messages.find(m => !m.mine);
        if (other) return other.sender.replace(/^@/, "").split(":")[0];
        return roomId.split(":")[0].replace(/^!/, "");
    }

    function rebuildRoomList() {
        const list = Object.keys(root.roomData).map(id => root.roomData[id]);
        // Lo último primero: es el orden que espera cualquiera que use un chat
        list.sort((a, b) => b.lastTs - a.lastTs);
        root.rooms = list;
    }

    function mediaUrl(mxc) {
        if (!mxc || !mxc.startsWith("mxc://")) return "";
        const path = mxc.substring("mxc://".length);
        return `${root.homeserver}/_matrix/media/v3/thumbnail/${path}?width=64&height=64&method=crop`;
    }

    // ------------------------------------------------------------------ //
    // Mandar
    // ------------------------------------------------------------------ //

    function openChat(roomId) {
        root.openRoomId = roomId;
        const entry = root.roomData[roomId];
        if (entry && entry.unread > 0) {
            const next = Object.assign({}, root.roomData);
            next[roomId] = Object.assign({}, entry, { "unread": 0 });
            root.roomData = next;
            root.rebuildRoomList();
        }
    }

    function closeChat() {
        root.openRoomId = "";
    }

    function sendMessage(text) {
        const body = text.trim();
        const token = root.tokenField("access_token");
        if (body.length === 0 || root.openRoomId.length === 0 || token.length === 0) return;

        // El txnId hace la petición idempotente: si se reintenta no se manda dos veces
        const txnId = `qs${Date.now()}${Math.floor(Math.random() * 1000)}`;
        const url = `${root.apiBase}/rooms/${encodeURIComponent(root.openRoomId)}`
            + `/send/m.room.message/${txnId}`;

        root.pending++;
        const xhr = new XMLHttpRequest();
        xhr.open("PUT", url);
        xhr.setRequestHeader("Authorization", `Bearer ${token}`);
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            root.pending = Math.max(0, root.pending - 1);
            if (xhr.status !== 200) {
                root.fail(Translation.tr("No se pudo enviar (%1)").arg(xhr.status));
                return;
            }
            // El eco vuelve por /sync, no hace falta agregarlo a mano
            root.sync();
        };
        xhr.send(JSON.stringify({ "msgtype": "m.text", "body": body }));
    }

    // Con la pestaña a la vista se encadenan long-polls; el Timer sólo arranca el
    // siguiente cuando el anterior terminó, así que no se apilan peticiones.
    Timer {
        running: root.connected && root.watching
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!root.syncing) root.sync()
    }

    onConnectedChanged: {
        if (root.connected) {
            root.syncToken = "";
            root.sync();
        }
    }
}
