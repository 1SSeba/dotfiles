import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

ContentPage {
    forceWidth: true

    ContentSection {
        id: aiSection
        icon: "neurology"
        title: Translation.tr("AI")

        /** ¿Ya hay algún modelo con este api_format? (para no duplicar al "agregar modelos"). */
        function hasProviderModel(apiFormat) {
            return Ai.modelList.some(id => Ai.models[id]?.api_format === apiFormat);
        }

        /** Suma entries a extraModels (persistido) + Ai.addModel (en caliente), sin duplicar por id. */
        function seedModels(entries) {
            const existingIds = new Set((Config.options.ai.extraModels ?? []).map(m => m.id ?? m.model));
            const newEntries = entries.filter(e => !existingIds.has(e.id));
            if (newEntries.length === 0) return;
            Config.options.ai.extraModels = [...(Config.options.ai.extraModels ?? []), ...newEntries];
            newEntries.forEach(e => Ai.addModel(Ai.safeModelName(e.id), e));
        }

        ContentSubsection {
            title: Translation.tr("Proveedores")
            tooltip: Translation.tr("Conectá los tres motores más comunes en un toque.\nPara cualquier otro (OpenRouter, Ollama, un endpoint propio...), sumalo desde el chat con el botón \"+\" del selector de modelos.")

            // ---------------------------------------------------------- Claude Code
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    MaterialSymbol {
                        text: "terminal"
                        iconSize: Appearance.font.pixelSize.larger
                        color: Appearance.colors.colOnLayer1
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: "Claude Code"
                        font.pixelSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colOnLayer1
                    }
                    StyledText {
                        text: Ai.claudeCodeVersion.length > 0
                            ? Translation.tr("✅ %1").arg(Ai.claudeCodeVersion)
                            : Translation.tr("❌ no encontrado")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                    }
                }
                StyledText {
                    Layout.fillWidth: true
                    visible: Ai.claudeCodeVersion.length === 0
                    text: Translation.tr("Sin API key: usa tu suscripción vía el CLI `claude`. Instalalo con:\ncurl -fsSL https://claude.ai/install.sh | bash")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                    wrapMode: Text.Wrap
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    RippleButtonWithIcon {
                        materialIcon: "login"
                        mainText: Translation.tr("Iniciar sesión")
                        enabled: Ai.claudeCodeVersion.length > 0
                        onClicked: Ai.loginProvider("claude")
                    }
                    RippleButtonWithIcon {
                        materialIcon: "add_circle"
                        mainText: Translation.tr("Agregar modelos")
                        visible: !aiSection.hasProviderModel("claudecode")
                        onClicked: {
                            // Alias que el CLI ya entiende con --model: no hace falta el
                            // id completo del modelo.
                            // Sin "icon": ese campo en un modelo se usa como nombre de
                            // asset (CustomIcon), no como Material Symbol — a
                            // diferencia de los agentes. No hay ícono de Anthropic
                            // en assets/icons, así que agregarlo tiraría el mismo
                            // warning de "Cannot open: assets/icons/..." que ya se
                            // evita en AiOptionPicker.qml. Sin ícono, el selector
                            // muestra sólo el nombre — no rompe nada.
                            aiSection.seedModels([
                                { "id": "claude-haiku", "name": "Claude Haiku", "model": "haiku", "api_format": "claudecode", "requires_key": false },
                                { "id": "claude-sonnet", "name": "Claude Sonnet", "model": "sonnet", "api_format": "claudecode", "requires_key": false },
                                { "id": "claude-opus", "name": "Claude Opus", "model": "opus", "api_format": "claudecode", "requires_key": false },
                            ]);
                        }
                        StyledToolTip {
                            text: Translation.tr("Suma Haiku, Sonnet y Opus al selector de modelos")
                        }
                    }
                }
            }

            // ---------------------------------------------------------- Gemini
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    CustomIcon {
                        width: Appearance.font.pixelSize.larger
                        height: Appearance.font.pixelSize.larger
                        source: "google-gemini-symbolic"
                        colorize: true
                        color: Appearance.colors.colOnLayer1
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: "Gemini"
                        font.pixelSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colOnLayer1
                    }
                    StyledText {
                        text: (Ai.apiKeys["gemini"] ?? "").length > 0
                            ? Translation.tr("✅ %1").arg(Ai.maskKey(Ai.apiKeys["gemini"]))
                            : Translation.tr("❌ sin key")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    MaterialTextField {
                        id: geminiKeyField
                        Layout.fillWidth: true
                        placeholderText: Translation.tr("Pegá tu API key de Gemini")
                        echoMode: TextInput.Password
                    }
                    RippleButtonWithIcon {
                        materialIcon: "save"
                        mainText: Translation.tr("Guardar")
                        enabled: geminiKeyField.text.trim().length > 0
                        onClicked: {
                            KeyringStorage.setNestedField(["apiKeys", "gemini"], geminiKeyField.text.trim());
                            geminiKeyField.text = "";
                        }
                    }
                    RippleButtonWithIcon {
                        materialIcon: "open_in_new"
                        mainText: Translation.tr("Conseguir key")
                        onClicked: Qt.openUrlExternally("https://aistudio.google.com/app/apikey")
                    }
                }
            }

            // ---------------------------------------------------------- OpenAI
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    CustomIcon {
                        width: Appearance.font.pixelSize.larger
                        height: Appearance.font.pixelSize.larger
                        source: "openai-symbolic"
                        colorize: true
                        color: Appearance.colors.colOnLayer1
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: "OpenAI"
                        font.pixelSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colOnLayer1
                    }
                    StyledText {
                        text: (Ai.apiKeys["openai"] ?? "").length > 0
                            ? Translation.tr("✅ %1").arg(Ai.maskKey(Ai.apiKeys["openai"]))
                            : Translation.tr("❌ sin key")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    MaterialTextField {
                        id: openaiKeyField
                        Layout.fillWidth: true
                        placeholderText: Translation.tr("Pegá tu API key de OpenAI")
                        echoMode: TextInput.Password
                    }
                    RippleButtonWithIcon {
                        materialIcon: "save"
                        mainText: Translation.tr("Guardar")
                        enabled: openaiKeyField.text.trim().length > 0
                        onClicked: {
                            KeyringStorage.setNestedField(["apiKeys", "openai"], openaiKeyField.text.trim());
                            openaiKeyField.text = "";
                        }
                    }
                    RippleButtonWithIcon {
                        materialIcon: "open_in_new"
                        mainText: Translation.tr("Conseguir key")
                        onClicked: Qt.openUrlExternally("https://platform.openai.com/api-keys")
                    }
                }

                RippleButtonWithIcon {
                    materialIcon: "add_circle"
                    mainText: Translation.tr("Agregar modelo (gpt-4o-mini)")
                    // No usamos hasProviderModel("openai") acá: "openai" es también
                    // el api_format por default de CUALQUIER modelo custom (ver el
                    // comentario junto a `models` en Ai.qml), así que un modelo
                    // custom sin relación con OpenAI real ya haría desaparecer este
                    // botón. Nos fijamos por key_id en vez de por api_format.
                    visible: !Ai.modelList.some(id => Ai.models[id]?.key_id === "openai")
                    onClicked: {
                        aiSection.seedModels([
                            { "id": "gpt-4o-mini", "name": "GPT-4o mini", "icon": "openai-symbolic",
                              "model": "gpt-4o-mini", "endpoint": "https://api.openai.com/v1/chat/completions",
                              "api_format": "openai", "requires_key": true, "key_id": "openai" },
                        ]);
                    }
                }
            }
        }

        ContentSubsection {
            title: Translation.tr("System prompt")

            MaterialTextArea {
                Layout.fillWidth: true
                placeholderText: Translation.tr("System prompt")
                text: Config.options.ai.systemPrompt
                wrapMode: TextEdit.Wrap
                onTextChanged: {
                    Qt.callLater(() => {
                        Config.options.ai.systemPrompt = text;
                    });
                }
            }
        }
    }

    ContentSection {
        id: agentsSection
        icon: "smart_toy"
        title: Translation.tr("Agentes")

        // Config.options.ai.agents es un list<var>: mutarlo en el lugar no dispara
        // el cambio ni se guarda al disco, así que siempre reasignamos una copia entera.
        function agentsCopy() {
            return JSON.parse(JSON.stringify(Config.options.ai.agents ?? []));
        }
        function setField(index, key, value) {
            const list = agentsSection.agentsCopy();
            if (index < 0 || index >= list.length) return;
            if (list[index][key] === value) return;
            list[index][key] = value;
            Config.options.ai.agents = list;
        }
        function setExtra(index, key, value) {
            const list = agentsSection.agentsCopy();
            if (index < 0 || index >= list.length) return;
            const extra = list[index].extraParams ?? ({});
            if (extra[key] === value) return;
            extra[key] = value;
            list[index].extraParams = extra;
            Config.options.ai.agents = list;
        }
        function removeAgent(index) {
            const list = agentsSection.agentsCopy();
            if (index < 0 || index >= list.length) return;
            list.splice(index, 1);
            Config.options.ai.agents = list;
        }
        function addAgent() {
            const list = agentsSection.agentsCopy();
            // El id es la clave que guardan las pestañas, así que no puede repetirse
            let n = list.length + 1;
            while (list.some(a => a.id === `agente${n}`)) n++;
            list.push({
                "id": `agente${n}`,
                "name": Translation.tr("Agente %1").arg(n),
                "icon": "neurology",
                "model": "",
                "systemPrompt": ""
            });
            Config.options.ai.agents = list;
        }

        // Opciones del selector de modelo, con una vacía adelante que significa
        // "no forzar nada y respetar el último modelo elegido a mano"
        readonly property var modelOptions: [
            {
                "displayName": Translation.tr("(el último usado)"),
                "value": ""
            },
            ...Ai.modelList.map(modelId => ({
                        "displayName": Ai.models[modelId]?.name ?? modelId,
                        "value": modelId
                    }))
        ]
        // Modos de permisos que acepta `claude --permission-mode`
        readonly property var permissionModes: [
            {
                "displayName": Translation.tr("Preguntar (default)"),
                "value": "default"
            },
            {
                "displayName": Translation.tr("Aceptar ediciones"),
                "value": "acceptEdits"
            },
            {
                "displayName": Translation.tr("Saltear permisos"),
                "value": "bypassPermissions"
            },
            {
                "displayName": Translation.tr("Solo planificar"),
                "value": "plan"
            }
        ]

        ContentSubsection {
            title: Translation.tr("Agente por defecto")
            tooltip: Translation.tr("El que se usa al abrir una pestaña nueva sin especificar agente")

            StyledComboBox {
                id: defaultAgentSelector
                buttonIcon: "star"
                textRole: "displayName"
                model: (Config.options.ai.agents ?? []).map(agent => ({
                            "displayName": agent.name ?? agent.id,
                            "value": agent.id,
                            "icon": agent.icon ?? ""
                        }))
                currentIndex: Math.max(0, defaultAgentSelector.model.findIndex(item => item.value === Config.options.ai.defaultAgent))
                onActivated: index => {
                    Config.options.ai.defaultAgent = defaultAgentSelector.model[index].value;
                }
            }
        }

        Repeater {
            // El modelo es la cantidad y no el array en sí: si fuera el array,
            // cada tecla escrita lo reasignaría, recrearía los delegates y
            // perderíamos el foco del campo a media escritura.
            model: (Config.options.ai.agents ?? []).length

            delegate: ContentSubsection {
                id: agentDelegate
                required property int index
                readonly property var agent: Config.options.ai.agents[agentDelegate.index] ?? ({})
                readonly property var agentModel: Ai.models[agentDelegate.agent.model ?? ""] ?? null
                readonly property bool isClaudeCode: agentDelegate.agentModel?.api_format === "claudecode"

                title: `${agentDelegate.agent.name ?? agentDelegate.agent.id ?? ""}  ·  ${agentDelegate.agent.id ?? ""}`

                ConfigRow {
                    MaterialSymbol {
                        Layout.alignment: Qt.AlignVCenter
                        Layout.leftMargin: 4
                        text: agentDelegate.agent.icon ?? ""
                        iconSize: Appearance.font.pixelSize.huge
                        color: Appearance.colors.colOnLayer1
                    }
                    MaterialTextField {
                        Layout.fillWidth: true
                        placeholderText: Translation.tr("Nombre")
                        text: agentDelegate.agent.name ?? ""
                        onTextChanged: {
                            Qt.callLater(() => agentsSection.setField(agentDelegate.index, "name", text));
                        }
                    }
                    MaterialTextField {
                        Layout.fillWidth: true
                        placeholderText: Translation.tr("Ícono (Material Symbol)")
                        text: agentDelegate.agent.icon ?? ""
                        onTextChanged: {
                            Qt.callLater(() => agentsSection.setField(agentDelegate.index, "icon", text));
                        }
                    }
                    RippleButtonWithIcon {
                        Layout.alignment: Qt.AlignVCenter
                        buttonRadius: Appearance.rounding.full
                        materialIcon: "delete"
                        mainText: Translation.tr("Borrar")
                        onClicked: agentsSection.removeAgent(agentDelegate.index)
                    }
                }

                StyledComboBox {
                    id: agentModelSelector
                    buttonIcon: "neurology"
                    textRole: "displayName"
                    model: agentsSection.modelOptions
                    currentIndex: Math.max(0, agentsSection.modelOptions.findIndex(item => item.value === (agentDelegate.agent.model ?? "")))
                    onActivated: index => {
                        agentsSection.setField(agentDelegate.index, "model", agentsSection.modelOptions[index].value);
                    }
                }

                ConfigSlider {
                    id: temperatureSlider
                    // El valor se setea una sola vez a mano en vez de bindearlo:
                    // si lo bindeamos a lo mismo que el slider escribe, Qt canta
                    // binding loop. `initialized` evita escribir el default solo
                    // por haber abierto la página.
                    property bool initialized: false
                    text: Translation.tr("Temperatura")
                    buttonIcon: "thermometer"
                    usePercentTooltip: false
                    from: 0
                    to: 2
                    Component.onCompleted: {
                        temperatureSlider.value = agentDelegate.agent.temperature ?? 0.5;
                        temperatureSlider.initialized = true;
                    }
                    onValueChanged: {
                        if (!temperatureSlider.initialized) return;
                        // Redondeamos porque el slider es continuo y no queremos
                        // escribir 0.7300000000000001 en el config
                        agentsSection.setField(agentDelegate.index, "temperature", Math.round(temperatureSlider.value * 100) / 100);
                    }
                }

                MaterialTextArea {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Prompt propio (vacío = usa el general de arriba)")
                    wrapMode: TextEdit.Wrap
                    // El archivo pisa al prompt inline, así que si hay archivo esto no sirve
                    enabled: !((agentDelegate.agent.promptFile ?? "").length > 0)
                    text: agentDelegate.agent.systemPrompt ?? ""
                    onTextChanged: {
                        Qt.callLater(() => agentsSection.setField(agentDelegate.index, "systemPrompt", text));
                    }
                }

                MaterialTextField {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Archivo de prompt (.md; pisa al prompt propio)")
                    text: agentDelegate.agent.promptFile ?? ""
                    onTextChanged: {
                        Qt.callLater(() => agentsSection.setField(agentDelegate.index, "promptFile", text));
                    }
                }

                ContentSubsection {
                    visible: agentDelegate.isClaudeCode
                    title: Translation.tr("Claude Code")

                    MaterialTextField {
                        Layout.fillWidth: true
                        placeholderText: Translation.tr("Directorio de trabajo (cwd)")
                        text: agentDelegate.agent.extraParams?.cwd ?? ""
                        onTextChanged: {
                            Qt.callLater(() => agentsSection.setExtra(agentDelegate.index, "cwd", text));
                        }
                    }

                    StyledComboBox {
                        id: permissionModeSelector
                        buttonIcon: "shield_person"
                        textRole: "displayName"
                        model: agentsSection.permissionModes
                        currentIndex: Math.max(0, agentsSection.permissionModes.findIndex(item => item.value === (agentDelegate.agent.extraParams?.permission_mode ?? "default")))
                        onActivated: index => {
                            agentsSection.setExtra(agentDelegate.index, "permission_mode", agentsSection.permissionModes[index].value);
                        }
                    }
                }
            }
        }

        RowLayout {
            Item {
                Layout.fillWidth: true
            }
            RippleButtonWithIcon {
                buttonRadius: Appearance.rounding.full
                materialIcon: "add"
                mainText: Translation.tr("Agregar agente")
                onClicked: agentsSection.addAgent()
            }
        }
    }

    ContentSection {
        icon: "music_cast"
        title: Translation.tr("Music Recognition")

        ConfigSpinBox {
            icon: "timer_off"
            text: Translation.tr("Total duration timeout (s)")
            value: Config.options.musicRecognition.timeout
            from: 10
            to: 100
            stepSize: 2
            onValueChanged: {
                Config.options.musicRecognition.timeout = value;
            }
        }
        ConfigSpinBox {
            icon: "av_timer"
            text: Translation.tr("Polling interval (s)")
            value: Config.options.musicRecognition.interval
            from: 2
            to: 10
            stepSize: 1
            onValueChanged: {
                Config.options.musicRecognition.interval = value;
            }
        }
    }

    ContentSection {
        icon: "cell_tower"
        title: Translation.tr("Networking")

        MaterialTextArea {
            Layout.fillWidth: true
            placeholderText: Translation.tr("User agent (for services that require it)")
            text: Config.options.networking.userAgent
            wrapMode: TextEdit.Wrap
            onTextChanged: {
                Config.options.networking.userAgent = text;
            }
        }
    }

    ContentSection {
        icon: "memory"
        title: Translation.tr("Resources")

        ConfigSpinBox {
            icon: "av_timer"
            text: Translation.tr("Polling interval (ms)")
            value: Config.options.resources.updateInterval
            from: 100
            to: 10000
            stepSize: 100
            onValueChanged: {
                Config.options.resources.updateInterval = value;
            }
        }
        
    }

    ContentSection {
        icon: "file_open"
        title: Translation.tr("Save paths")

        MaterialTextArea {
            Layout.fillWidth: true
            placeholderText: Translation.tr("Video Recording Path")
            text: Config.options.screenRecord.savePath
            wrapMode: TextEdit.Wrap
            onTextChanged: {
                Config.options.screenRecord.savePath = text;
            }
        }
        
        MaterialTextArea {
            Layout.fillWidth: true
            placeholderText: Translation.tr("Screenshot Path (leave empty to just copy)")
            text: Config.options.screenSnip.savePath
            wrapMode: TextEdit.Wrap
            onTextChanged: {
                Config.options.screenSnip.savePath = text;
            }
        }
    }

    ContentSection {
        icon: "search"
        title: Translation.tr("Search")

        ConfigSwitch {
            text: Translation.tr("Use Levenshtein distance-based algorithm instead of fuzzy")
            checked: Config.options.search.sloppy
            onCheckedChanged: {
                Config.options.search.sloppy = checked;
            }
            StyledToolTip {
                text: Translation.tr("Could be better if you make a ton of typos,\nbut results can be weird and might not work with acronyms\n(e.g. \"GIMP\" might not give you the paint program)")
            }
        }

        ContentSubsection {
            title: Translation.tr("Prefixes")
            ConfigRow {
                uniform: true
                MaterialTextArea {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Action")
                    text: Config.options.search.prefix.action
                    wrapMode: TextEdit.Wrap
                    onTextChanged: {
                        Config.options.search.prefix.action = text;
                    }
                }
                MaterialTextArea {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Clipboard")
                    text: Config.options.search.prefix.clipboard
                    wrapMode: TextEdit.Wrap
                    onTextChanged: {
                        Config.options.search.prefix.clipboard = text;
                    }
                }
                MaterialTextArea {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Emojis")
                    text: Config.options.search.prefix.emojis
                    wrapMode: TextEdit.Wrap
                    onTextChanged: {
                        Config.options.search.prefix.emojis = text;
                    }
                }
            }

            ConfigRow {
                uniform: true
                MaterialTextArea {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Math")
                    text: Config.options.search.prefix.math
                    wrapMode: TextEdit.Wrap
                    onTextChanged: {
                        Config.options.search.prefix.math = text;
                    }
                }
                MaterialTextArea {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Shell command")
                    text: Config.options.search.prefix.shellCommand
                    wrapMode: TextEdit.Wrap
                    onTextChanged: {
                        Config.options.search.prefix.shellCommand = text;
                    }
                }
                MaterialTextArea {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Web search")
                    text: Config.options.search.prefix.webSearch
                    wrapMode: TextEdit.Wrap
                    onTextChanged: {
                        Config.options.search.prefix.webSearch = text;
                    }
                }
            }

            ConfigRow {
                uniform: true
                MaterialTextArea {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Apps")
                    text: Config.options.search.prefix.app
                    wrapMode: TextEdit.Wrap
                    onTextChanged: {
                        Config.options.search.prefix.app = text;
                    }
                }
                MaterialTextArea {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Keybinds")
                    text: Config.options.search.prefix.keybinds
                    wrapMode: TextEdit.Wrap
                    onTextChanged: {
                        Config.options.search.prefix.keybinds = text;
                    }
                }
                MaterialTextArea {
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Symbols")
                    text: Config.options.search.prefix.symbols
                    wrapMode: TextEdit.Wrap
                    onTextChanged: {
                        Config.options.search.prefix.symbols = text;
                    }
                }
            }
        }
        ContentSubsection {
            title: Translation.tr("Web search")
            MaterialTextArea {
                Layout.fillWidth: true
                placeholderText: Translation.tr("Base URL")
                text: Config.options.search.engineBaseUrl
                wrapMode: TextEdit.Wrap
                onTextChanged: {
                    Config.options.search.engineBaseUrl = text;
                }
            }
        }
    }

    // There's no update indicator in ii for now so we shouldn't show this yet
    // ContentSection {
    //     icon: "deployed_code_update"
    //     title: Translation.tr("System updates (Arch only)")

    //     ConfigSwitch {
    //         text: Translation.tr("Enable update checks")
    //         checked: Config.options.updates.enableCheck
    //         onCheckedChanged: {
    //             Config.options.updates.enableCheck = checked;
    //         }
    //     }

    //     ConfigSpinBox {
    //         icon: "av_timer"
    //         text: Translation.tr("Check interval (mins)")
    //         value: Config.options.updates.checkInterval
    //         from: 60
    //         to: 1440
    //         stepSize: 60
    //         onValueChanged: {
    //             Config.options.updates.checkInterval = value;
    //         }
    //     }
    // }

    ContentSection {
        icon: "weather_mix"
        title: Translation.tr("Weather")
        ConfigRow {
            ConfigSwitch {
                buttonIcon: "assistant_navigation"
                text: Translation.tr("Enable GPS based location")
                checked: Config.options.bar.weather.enableGPS
                onCheckedChanged: {
                    Config.options.bar.weather.enableGPS = checked;
                }
            }
            ConfigSwitch {
                buttonIcon: "thermometer"
                text: Translation.tr("Fahrenheit unit")
                checked: Config.options.bar.weather.useUSCS
                onCheckedChanged: {
                    Config.options.bar.weather.useUSCS = checked;
                }
                StyledToolTip {
                    text: Translation.tr("It may take a few seconds to update")
                }
            }
        }
        
        MaterialTextArea {
            Layout.fillWidth: true
            placeholderText: Translation.tr("City name")
            text: Config.options.bar.weather.city
            wrapMode: TextEdit.Wrap
            onTextChanged: {
                Config.options.bar.weather.city = text;
            }
        }
        ConfigSpinBox {
            icon: "av_timer"
            text: Translation.tr("Polling interval (m)")
            value: Config.options.bar.weather.fetchInterval
            from: 5
            to: 50
            stepSize: 5
            onValueChanged: {
                Config.options.bar.weather.fetchInterval = value;
            }
        }

        // Marca la ubicación que está usando el clima: el fix del GPS si está activo
        // y es válido, si no la ciudad escrita arriba. Sirve para ver de un vistazo
        // si el nombre de ciudad se resolvió a donde uno espera.
        WorldMap {
            Layout.fillWidth: true
            Layout.preferredHeight: 300
        }
    }
}
