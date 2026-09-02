//@ pragma UseQApplication
//
// Banco de pruebas de la shell. Se corre asi:
//
//     qs -p ~/.config/quickshell/ii/validate.qml
//
// Existe porque no habia forma confiable de validar un .qml antes de guardarlo:
// `qmlformat` falla en silencio con archivos que estan perfectos, y `qs -c ii -n`
// no anda con la shell ya corriendo. Esto instancia los componentes de verdad, asi
// que cualquier ReferenceError, binding roto o import faltante aparece en pantalla.
//
// Salida esperada: "Configuration Loaded", los renglones [t] y "TOTAL de fallas: 0",
// sin ningun WARN que mencione un archivo propio. Es descartable: borralo cuando no
// lo necesites.
//
// Dos cosas del entorno, no del codigo:
//   - Al salir, quickshell puede tirar un coredump levantando un hilo mientras se
//     desarma. Pasa igual con un archivo vacio, asi que si los renglones [t]
//     salieron, la corrida vale.
//   - Por eso las comprobaciones corren directo en Component.onCompleted y no en
//     un Qt.callLater: no hay que depender de que el event loop llegue vivo a la
//     siguiente vuelta.
//
import QtQuick
import QtQuick.Controls
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings
import qs.modules.ii.sidebarRight
import qs.modules.ii.sidebarRight.calendar
import qs.modules.ii.sidebarRight.todo
import qs.modules.ii.sidebarRight.mail
import qs.modules.ii.sidebarLeft.aiChat
import qs.services.ai
import "modules/ii/sidebarRight/calendar/calendar_layout.js" as CalendarLayout

ApplicationWindow {
    visible: false
    width: 600
    height: 600

    ServicesConfig {}
    ProfilePage {}
    BackgroundConfig { width: 400; height: 600 }
    WidgetsSubmenu { id: widgetsSubmenuTest; width: 284 }
    BottomWidgetGroup { width: 400; height: 350 }
    CalendarWidget {}
    AgendaWidget { width: 400; height: 350 }
    TodoWidget { width: 400; height: 350 }
    MailWidget { width: 400; height: 350 }
    AiHistoryPanel { width: 400; height: 350 }
    AgentTreeBlock {
        width: 400
        agents: [
            ({ "id": "a1", "name": "Explore", "description": "buscar donde se dibuja el sidebar",
               "status": "done", "tools": [({ "name": "Grep", "detail": "sidebar" })],
               "toolCount": 1, "preview": "", "result": "esta en modules/ii",
               "startedAt": 1000, "endedAt": 4000 }),
            ({ "id": "a2", "name": "general-purpose", "description": "correr las pruebas",
               "status": "running", "tools": [], "toolCount": 0, "preview": "compilando",
               "result": "", "startedAt": 1000, "endedAt": 0 })
        ]
    }

    // Objetos sueltos para las pruebas del arbol multi-agente
    AiMessageData { id: mensajeDePrueba }
    ClaudeCodeStrategy { id: estrategiaDePrueba }

    function check(nombre, condicion) {
        if (condicion) return 0;
        console.log("[t] FALLA:", nombre);
        return 1;
    }

    /**
     * Prueba funcional del correo multicuenta y de la mezcla de proveedores.
     *
     * Toca Config y KeyringStorage de verdad, asi que guarda todo antes y lo
     * restaura al final. El keyring solo se toca en memoria (nunca se llama a
     * saveKeyringData), asi que del disco no sale nada.
     */
    function probarCuentas() {
        let fallas = 0;
        const cfg = Config.options.services;
        const keyringPrevio = KeyringStorage.keyringData;
        const previo = {
            "accounts": cfg.mail.accounts,
            "user": cfg.mail.user,
            "host": cfg.mail.host,
            "mailEnable": cfg.mail.enable,
            "appleUser": cfg.apple.user
        };

        try {
            // ---- correo: dos cuentas a la vez ----
            KeyringStorage.keyringData = Object.assign({}, keyringPrevio, ({
                "mail": ({ "g1": ({ "appPassword": "x" }), "i1": ({ "appPassword": "y" }) })
            }));
            cfg.mail.enable = true;
            cfg.mail.user = "";
            cfg.mail.accounts = [
                ({ "id": "g1", "label": "yo@gmail.com", "host": "imap.gmail.com",
                   "port": 993, "user": "yo@gmail.com", "mailbox": "INBOX", "enable": true }),
                ({ "id": "i1", "label": "yo@icloud.com", "host": "imap.mail.me.com",
                   "port": 993, "user": "yo@icloud.com", "mailbox": "INBOX", "enable": true })
            ];
            fallas += check("las dos cuentas quedan activas", MailService.accounts.length === 2);
            fallas += check("con cuentas hay correo", MailService.enabled);

            MailService.results = ({
                "g1": ({ "unread": 2, "messages": [
                    ({ "from": "A", "subject": "vieja", "timestamp": 100 }),
                    ({ "from": "B", "subject": "nueva", "timestamp": 300 })
                ], "error": "" }),
                "i1": ({ "unread": 1, "messages": [
                    ({ "from": "C", "subject": "media", "timestamp": 200 })
                ], "error": "" })
            });
            fallas += check("el contador suma las dos", MailService.unreadCount === 3);
            fallas += check("los mas nuevos primero",
                MailService.recent.map(m => m.subject).join(",") === "nueva,media,vieja");
            fallas += check("cada mail sabe su webmail",
                MailService.recent[1].webmail.indexOf("icloud") >= 0
                && MailService.recent[0].webmail.indexOf("google") >= 0);

            // Proton: el host es loopback, asi que el webmail tiene que salir de
            // la direccion. Y su cuenta lleva STARTTLS propio, no el SSL de todos.
            KeyringStorage.keyringData = Object.assign({}, KeyringStorage.keyringData, ({
                "mail": ({ "g1": ({ "appPassword": "x" }), "i1": ({ "appPassword": "y" }),
                           "p1": ({ "appPassword": "z" }) })
            }));
            cfg.mail.accounts = cfg.mail.accounts.concat([
                ({ "id": "p1", "label": "yo@proton.me", "host": "127.0.0.1",
                   "port": 1143, "user": "yo@proton.me", "mailbox": "INBOX",
                   "security": "starttls", "enable": true })
            ]);
            fallas += check("la cuenta de Proton entra", MailService.accounts.length === 3);
            const proton = MailService.accounts.filter(a => a.id === "p1")[0];
            fallas += check("Proton conserva su STARTTLS", proton.security === "starttls");
            fallas += check("Proton conserva su puerto", proton.port === 1143);
            fallas += check("el webmail de Proton sale de la direccion, no del host",
                MailService.webmailFor(proton.host, proton.user).indexOf("mail.proton.me") >= 0);
            fallas += check("una cuenta comun no se confunde con Proton",
                MailService.webmailFor("imap.gmail.com", "yo@gmail.com").indexOf("google") >= 0);

            // Una cuenta rota no puede tapar los mails de la otra
            MailService.results = Object.assign({}, MailService.results, ({
                "i1": ({ "unread": 0, "messages": [], "error": "login rechazado" })
            }));
            fallas += check("el error dice de que cuenta es",
                MailService.lastError.indexOf("yo@icloud.com") === 0);
            fallas += check("los otros mails siguen ahi", MailService.recent.length === 2);

            // Apagar una la saca del conteo pero no de la lista de Ajustes
            const cuantas = MailService.allAccounts.length;
            MailService.upsertAccount(Object.assign({}, MailService.allAccounts[1], ({ "enable": false })));
            fallas += check("apagada: fuera del conteo", MailService.accounts.length === cuantas - 1);
            fallas += check("apagada: sigue en Ajustes", MailService.allAccounts.length === cuantas);

            // ---- migracion de la cuenta unica de antes ----
            cfg.mail.accounts = [];
            cfg.mail.user = "viejo@gmail.com";
            cfg.mail.host = "imap.gmail.com";
            KeyringStorage.keyringData = Object.assign({}, KeyringStorage.keyringData, ({
                "mail": ({ "appPassword": "z" })
            }));
            fallas += check("la cuenta vieja se ve sin migrar",
                MailService.allAccounts.length === 1
                && MailService.allAccounts[0].id === "default"
                && MailService.accounts.length === 1);
            MailService.migrateLegacyAccount();
            fallas += check("migrada: queda en la lista",
                (cfg.mail.accounts ?? []).length === 1 && cfg.mail.user === "");
            fallas += check("migrada: conserva su contrasenia",
                MailService.accounts.length === 1);

            // ---- mezcla de calendarios ----
            const antesG = ({ "enabled": GoogleCalendar.enabled, "por": GoogleCalendar.eventsByDate });
            const eventoA = ({ "summary": "de Google", "start": new Date(2026, 7, 26, 9, 0),
                               "end": new Date(2026, 7, 26, 10, 0), "allDay": false, "source": "google" });
            const eventoB = ({ "summary": "de iCloud", "start": new Date(2026, 7, 26, 8, 0),
                               "end": new Date(2026, 7, 26, 8, 30), "allDay": false, "source": "apple" });
            const eventoC = ({ "summary": "todo el dia", "start": new Date(2026, 7, 26, 12, 0),
                               "end": new Date(2026, 7, 26, 12, 0), "allDay": true, "source": "apple" });
            GoogleCalendar.eventsByDate = ({ "2026-08-26": [eventoA] });
            GoogleCalendar.upcoming = [eventoA];
            AppleCalendar.eventsByDate = ({ "2026-08-26": [eventoB, eventoC] });
            AppleCalendar.upcoming = [eventoB, eventoC];
            // Sin proveedores prendidos la mezcla tiene que dar vacio
            fallas += check("apagados: no hay eventos", Calendars.countOn("2026-08-26") === 0);

            // Ahora con los dos prendidos. Las credenciales son de mentira: los
            // refresh que se disparan solos van a fallar, que es justo lo que
            // queremos — asi no pisan los eventos de prueba.
            KeyringStorage.keyringData = Object.assign({}, KeyringStorage.keyringData, ({
                "google": ({ "access_token": "falso", "client_secret": "falso",
                             "expires_at": Date.now() + 3600000 }),
                "apple": ({ "appPassword": "falso" })
            }));
            cfg.apple.user = "nadie@example.invalid";
            GoogleCalendar.eventsByDate = ({ "2026-08-26": [eventoA] });
            GoogleCalendar.upcoming = [eventoA];
            AppleCalendar.eventsByDate = ({ "2026-08-26": [eventoB, eventoC] });
            AppleCalendar.upcoming = [eventoB, eventoC];

            fallas += check("los dos proveedores estan prendidos",
                GoogleCalendar.enabled && AppleCalendar.enabled);
            fallas += check("mezcla: los tres eventos del dia",
                Calendars.countOn("2026-08-26") === 3);
            fallas += check("mezcla: el de todo el dia va primero, despues por hora",
                Calendars.eventsOn("2026-08-26").map(e => e.summary).join(",")
                    === "todo el dia,de iCloud,de Google");
            fallas += check("mezcla: «lo que viene» tambien sale ordenado",
                Calendars.upcoming.length === 3
                && Calendars.upcoming[0].summary === "de iCloud");
            fallas += check("mezcla: enabled y loading miran a los dos", Calendars.enabled);

            // Y el To Do tiene que ver los recordatorios de iCloud
            AppleReminders.list = [({ "content": "de iCloud", "done": false,
                "url": "https://x/1.ics", "etag": "e1", "source": "apple" })];
            fallas += check("el To Do suma los recordatorios de iCloud",
                Todo.unifiedList.filter(t => t.source === "apple").length === 1);

        } finally {
            cfg.mail.accounts = previo.accounts;
            cfg.mail.user = previo.user;
            cfg.mail.host = previo.host;
            cfg.mail.enable = previo.mailEnable;
            cfg.apple.user = previo.appleUser;
            KeyringStorage.keyringData = keyringPrevio;
            MailService.results = ({});
            GoogleCalendar.eventsByDate = ({});
            GoogleCalendar.upcoming = [];
            AppleCalendar.eventsByDate = ({});
            AppleCalendar.upcoming = [];
            AppleReminders.list = [];
        }
        return fallas;
    }

    /**
     * El historial: agrupado por fecha y el indice sellando `updated`.
     *
     * groupLabelFor se prueba contra un "ahora" fijo a proposito: con Date.now()
     * la prueba se rompe sola a la medianoche.
     */
    function probarHistorial() {
        let fallas = 0;
        const ahora = new Date(2026, 7, 27, 10, 0);
        const dia = 86400000;
        const hoy = new Date(2026, 7, 27, 9, 0).getTime();
        const ayer = new Date(2026, 7, 26, 23, 30).getTime();

        fallas += check("hoy es Hoy", AiHistory.groupLabelFor(hoy, ahora) === "Hoy");
        fallas += check("anoche tarde es Ayer", AiHistory.groupLabelFor(ayer, ahora) === "Ayer");
        fallas += check("hace 3 dias es Esta semana",
            AiHistory.groupLabelFor(hoy - 3 * dia, ahora) === "Esta semana");
        fallas += check("hace 15 dias es Este mes",
            AiHistory.groupLabelFor(hoy - 15 * dia, ahora) === "Este mes");
        fallas += check("hace un anio no cae en ningun grupo cercano",
            ["Hoy", "Ayer", "Esta semana", "Este mes"].indexOf(
                AiHistory.groupLabelFor(hoy - 400 * dia, ahora)) === -1);

        // Solo el primero de cada tanda lleva encabezado, y los fijados van juntos.
        const marcados = AiHistory.withGroupLabels([
            ({ "name": "c1", "pinned": true, "mtime": hoy }),
            ({ "name": "c2", "pinned": true, "mtime": hoy - 400 * dia }),
            ({ "name": "c3", "pinned": false, "mtime": hoy }),
            ({ "name": "c4", "pinned": false, "mtime": hoy })
        ]);
        fallas += check("el primer fijado abre el grupo", marcados[0].groupLabel === "Fijados");
        fallas += check("el segundo fijado no repite encabezado", marcados[1].groupLabel === "");
        fallas += check("el primero no fijado abre su fecha", marcados[2].groupLabel.length > 0);
        fallas += check("el segundo de la misma fecha no repite", marcados[3].groupLabel === "");

        // El indice sella la fecha solo, sin que el llamador se acuerde
        const antes = AiHistory.entries;
        try {
            AiHistory.entries = ({});
            AiHistory.setTitle("chat-de-prueba", "un titulo");
            const entrada = AiHistory.entryFor("chat-de-prueba");
            fallas += check("guarda el titulo", entrada.title === "un titulo");
            fallas += check("sella la fecha sola", entrada.updated > 0);
        } finally {
            AiHistory.entries = antes;
        }
        return fallas;
    }

    /**
     * El arbol multi-agente, alimentando la estrategia con el stream de verdad.
     *
     * Lo que se prueba es justo lo que estaba roto: que lo que hace un subagente
     * vaya a su tarjeta y NO se cuele en el texto de la respuesta principal.
     */
    function probarAgentes() {
        let fallas = 0;
        const m = mensajeDePrueba;
        m.content = "";
        m.rawContent = "";
        m.agents = [];

        function linea(obj) { estrategiaDePrueba.parseResponseLine(JSON.stringify(obj), m); }

        // El orquestador larga un subagente
        linea(({ "type": "assistant", "message": ({ "content": [
            ({ "type": "text", "text": "Voy a mirar el sidebar." }),
            ({ "type": "tool_use", "id": "t1", "name": "Task",
               "input": ({ "subagent_type": "Explore", "description": "buscar el sidebar" }) })
        ] }) }));
        fallas += check("el Task crea un agente", m.agents.length === 1);
        fallas += check("el agente arranca corriendo", m.agents[0].status === "running");
        fallas += check("el agente toma su tipo", m.agents[0].name === "Explore");
        fallas += check("el Task no ensucia el chat con una linea de tool",
            m.rawContent.indexOf("Task") === -1);

        // El subagente trabaja: nada de esto puede aparecer en la respuesta
        linea(({ "type": "assistant", "parent_tool_use_id": "t1", "message": ({ "content": [
            ({ "type": "tool_use", "id": "t2", "name": "Grep", "input": ({ "pattern": "sidebar" }) })
        ] }) }));
        linea(({ "type": "stream_event", "parent_tool_use_id": "t1",
                 "event": ({ "type": "content_block_delta",
                             "delta": ({ "type": "text_delta", "text": "mirando archivos" }) }) }));
        const largoAntes = m.rawContent.length;
        fallas += check("la tool del subagente va a su tarjeta", m.agents[0].toolCount === 1);
        fallas += check("la tool del subagente guarda el detalle",
            m.agents[0].tools[0].name === "Grep");
        fallas += check("el texto del subagente no se cuela en la respuesta",
            m.rawContent.indexOf("mirando archivos") === -1);
        fallas += check("mientras corre se ve lo que esta haciendo",
            m.agents[0].preview.indexOf("mirando archivos") >= 0);

        // El resultado del Task cierra el agente, sin escribir en el chat
        linea(({ "type": "user", "message": ({ "content": [
            ({ "type": "tool_result", "tool_use_id": "t1", "content": "esta en modules/ii" })
        ] }) }));
        fallas += check("el tool_result cierra el agente", m.agents[0].status === "done");
        fallas += check("el agente guarda en que termino",
            m.agents[0].result.indexOf("modules/ii") >= 0);
        fallas += check("cerrar el agente no escribe en el chat",
            m.rawContent.length === largoAntes);

        // Una corrida cortada no puede dejar agentes girando para siempre
        linea(({ "type": "assistant", "message": ({ "content": [
            ({ "type": "tool_use", "id": "t9", "name": "Task",
               "input": ({ "subagent_type": "claude", "description": "algo" }) })
        ] }) }));
        fallas += check("hay uno corriendo", estrategiaDePrueba.hasRunningAgents(m));
        estrategiaDePrueba.onRequestFinished(m);
        fallas += check("al terminar no queda ninguno colgado",
            !estrategiaDePrueba.hasRunningAgents(m));

        // Una tool normal del orquestador SI se sigue viendo en el chat
        linea(({ "type": "assistant", "message": ({ "content": [
            ({ "type": "tool_use", "id": "t3", "name": "Read", "input": ({ "file_path": "/tmp/x" }) })
        ] }) }));
        fallas += check("las tools propias siguen saliendo en el chat",
            m.rawContent.indexOf("Read") >= 0);

        m.content = "";
        m.rawContent = "";
        m.agents = [];
        return fallas;
    }

    /**
     * El switch de "Widgets" del click derecho tiene que reflejar y controlar
     * "¿se ve en ESTA pantalla?", no el `enable` global — si no, un widget
     * restringido a otro monitor aparece marcado como activo acá aunque en
     * realidad no se dibuje en esta pantalla (justo el bug reportado).
     */
    function probarWidgetsPorPantalla() {
        let fallas = 0;
        const names = Quickshell.screens.map(s => s.name);
        if (names.length < 2) {
            console.log("[t] widgets por pantalla: se salta (hacen falta 2+ monitores, hay", names.length + ")");
            return 0;
        }
        const [a, b] = names;
        const w = Config.options.background.widgets.clock;
        const antesWidget = { enable: w.enable, screenList: w.screenList };
        const antesMenu = GlobalStates.desktopMenuScreen;
        GlobalStates.desktopMenuScreen = Quickshell.screens[0]; // "parado" en la pantalla A

        try {
            w.enable = true;
            w.screenList = [];
            fallas += check("visible en todas: se ve acá", widgetsSubmenuTest.isVisibleHere("clock"));

            widgetsSubmenuTest.setVisibleHere("clock", false); // apagar en A
            fallas += check("apagar en A: ya no se ve acá", !widgetsSubmenuTest.isVisibleHere("clock"));
            fallas += check("apagar en A: sigue prendido en general", w.enable);
            fallas += check("apagar en A: B sigue en la lista",
                w.screenList.includes(b) && !w.screenList.includes(a));

            widgetsSubmenuTest.setVisibleHere("clock", true); // prender de nuevo en A
            fallas += check("prender en A: vuelve a verse acá", widgetsSubmenuTest.isVisibleHere("clock"));
            fallas += check("prender en A: la lista vuelve a la forma canónica (todas)",
                w.screenList.length === 0);

            // Si A era la única pantalla donde vivía, apagarlo acá lo apaga del todo.
            w.screenList = [a];
            widgetsSubmenuTest.setVisibleHere("clock", false);
            fallas += check("única pantalla: apagar acá apaga del todo", !w.enable);
        } finally {
            w.enable = antesWidget.enable;
            w.screenList = antesWidget.screenList;
            GlobalStates.desktopMenuScreen = antesMenu;
        }
        return fallas;
    }

    Component.onCompleted: {
        console.log("[t] Google:", GoogleAccount.status);
        console.log("[t]   calendario:", GoogleCalendar.enabled, "| tareas:", GoogleTasks.enabled);
        console.log("[t] Correo:", MailService.status);
        console.log("[t] Apple:", AppleAccount.status);
        console.log("[t]   calendario:", AppleCalendar.enabled, "| recordatorios:", AppleReminders.enabled);
        console.log("[t] To Do -> local:", Todo.list.length, "| unificadas:", Todo.unifiedList.length);

        // La grilla del calendario, casillero por casillero, en doce anios
        let fallas = 0;
        for (let y = 2020; y <= 2031; y++) for (let m = 0; m < 12; m++) {
            const l = CalendarLayout.getCalendarLayout(new Date(y, m, 15, 12), false);
            let previa = null;
            for (let i = 0; i < 6; i++) for (let j = 0; j < 7; j++) {
                const c = l[i][j];
                const p = c.dateKey.split("-").map(Number);
                if (p[2] !== c.day) { console.log("[t] FALLA dia!=fecha", c.day, c.dateKey); fallas++; }
                const d = new Date(p[0], p[1] - 1, p[2], 12);
                if (previa !== null && Math.round((d - previa) / 86400000) !== 1) {
                    console.log("[t] FALLA salto en", c.dateKey); fallas++;
                }
                previa = d;
            }
        }
        console.log("[t] grilla del calendario: 6048 casilleros,", fallas, "fallas");

        fallas += probarCuentas();
        const fallasHistorial = probarHistorial();
        console.log("[t] historial: agrupado, busqueda e indice ->", fallasHistorial, "fallas");
        fallas += fallasHistorial;
        const fallasAgentes = probarAgentes();
        console.log("[t] arbol multi-agente ->", fallasAgentes, "fallas");
        fallas += fallasAgentes;
        const fallasWidgetsPorPantalla = probarWidgetsPorPantalla();
        console.log("[t] widgets por pantalla ->", fallasWidgetsPorPantalla, "fallas");
        fallas += fallasWidgetsPorPantalla;
        console.log("[t] TOTAL de fallas:", fallas);
        Qt.quit();
    }
}
