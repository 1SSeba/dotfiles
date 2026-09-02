pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common.functions as CF
import qs.modules.common
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.services.ai

/**
 * Basic service to handle LLM chats. Supports Google's and OpenAI's API formats.
 * Supports Gemini and OpenAI models.
 * Limitations:
 * - For now functions only work with Gemini API format
 */
Singleton {
    id: root

    property Component aiMessageComponent: AiMessageData {}
    property Component aiModelComponent: AiModel {}
    property Component geminiApiStrategy: GeminiApiStrategy {}
    property Component openaiApiStrategy: OpenAiApiStrategy {}
    property Component mistralApiStrategy: MistralApiStrategy {}
    property Component anthropicApiStrategy: AnthropicApiStrategy {}
    property Component claudeCodeStrategy: ClaudeCodeStrategy {}
    property Component openaiNativeStrategy: OpenAiNativeStrategy {}
    readonly property string interfaceRole: "interface"
    readonly property string apiKeyEnvVarName: "API_KEY"

    signal responseFinished()

    readonly property var apiKeys: KeyringStorage.keyringData?.apiKeys ?? {}
    readonly property var apiKeysLoaded: KeyringStorage.loaded

    function idForMessage(message) {
        // Generate a unique ID using timestamp and random value
        return Date.now().toString(36) + Math.random().toString(36).substr(2, 8);
    }

    function safeModelName(modelName) {
        return modelName.replace(/:/g, "_").replace(/ /g, "-").replace(/\//g, "-")
    }

    property list<var> defaultPrompts: []
    property list<var> userPrompts: []
    property list<var> promptFiles: [...defaultPrompts, ...userPrompts]
    property list<var> savedChats: []

    property var promptSubstitutions: {
        "{DISTRO}": SystemInfo.distroName,
        "{DATETIME}": `${DateTime.time}, ${DateTime.collapsedCalendarFormat}`,
        "{WINDOWCLASS}": ToplevelManager.activeToplevel?.appId ?? "Unknown",
        "{DE}": `${SystemInfo.desktopEnvironment} (${SystemInfo.windowingSystem})` 
    }

    // Gemini: https://ai.google.dev/gemini-api/docs/function-calling
    // OpenAI: https://platform.openai.com/docs/guides/function-calling
    property var tools: {
        "gemini": {
            "functions": [{"functionDeclarations": [
                {
                    "name": "switch_to_search_mode",
                    "description": "Search the web",
                },
                {
                    "name": "get_shell_config",
                    "description": "Get the desktop shell config file contents",
                },
                {
                    "name": "set_shell_config",
                    "description": "Set a field in the desktop graphical shell config file. Must only be used after `get_shell_config`.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "key": {
                                "type": "string",
                                "description": "The key to set, e.g. `bar.borderless`. MUST NOT BE GUESSED, use `get_shell_config` to see what keys are available before setting.",
                            },
                            "value": {
                                "type": "string",
                                "description": "The value to set, e.g. `true`"
                            }
                        },
                        "required": ["key", "value"]
                    }
                },
                {
                    "name": "run_shell_command",
                    "description": "Run a shell command in bash and get its output. Use this only for quick commands that don't require user interaction. For commands that require interaction, ask the user to run manually instead.",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "command": {
                                "type": "string",
                                "description": "The bash command to run",
                            },
                        },
                        "required": ["command"]
                    }
                },
            ]}],
            "search": [{
                "google_search": {}
            }],
            "none": []
        },
        "openai": {
            "functions": [
                {
                    "type": "function",
                    "function": {
                        "name": "get_shell_config",
                        "description": "Get the desktop shell config file contents",
                        "parameters": {}
                    },
                },
                {
                    "type": "function",
                    "function": {
                        "name": "set_shell_config",
                        "description": "Set a field in the desktop graphical shell config file. Must only be used after `get_shell_config`.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "key": {
                                    "type": "string",
                                    "description": "The key to set, e.g. `bar.borderless`. MUST NOT BE GUESSED, use `get_shell_config` to see what keys are available before setting.",
                                },
                                "value": {
                                    "type": "string",
                                    "description": "The value to set, e.g. `true`"
                                }
                            },
                            "required": ["key", "value"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "run_shell_command",
                        "description": "Run a shell command in bash and get its output. Use this only for quick commands that don't require user interaction. For commands that require interaction, ask the user to run manually instead.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "command": {
                                    "type": "string",
                                    "description": "The bash command to run",
                                },
                            },
                            "required": ["command"]
                        }
                    },
                },
            ],
            "search": [],
            "none": [],
        },
        "mistral": {
            "functions": [
                {
                    "type": "function",
                    "function": {
                        "name": "get_shell_config",
                        "description": "Get the desktop shell config file contents",
                        "parameters": {}
                    },
                },
                {
                    "type": "function",
                    "function": {
                        "name": "set_shell_config",
                        "description": "Set a field in the desktop graphical shell config file. Must only be used after `get_shell_config`.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "key": {
                                    "type": "string",
                                    "description": "The key to set, e.g. `bar.borderless`. MUST NOT BE GUESSED, use `get_shell_config` to see what keys are available before setting.",
                                },
                                "value": {
                                    "type": "string",
                                    "description": "The value to set, e.g. `true`"
                                }
                            },
                            "required": ["key", "value"]
                        }
                    }
                },
                {
                    "type": "function",
                    "function": {
                        "name": "run_shell_command",
                        "description": "Run a shell command in bash and get its output. Use this only for quick commands that don't require user interaction. For commands that require interaction, ask the user to run manually instead.",
                        "parameters": {
                            "type": "object",
                            "properties": {
                                "command": {
                                    "type": "string",
                                    "description": "The bash command to run",
                                },
                            },
                            "required": ["command"]
                        }
                    },
                },
            ],
            "search": [],
            "none": [],
        }
    }
    function toolsForFormat(format) {
        const webSearchAnthropic = {
            "type": "web_search_20250305",
            "name": "web_search",
            "max_uses": 5,
            "user_location": {
                "type": "approximate",
                "city": "Santiago",
                "country": "CL",
                "timezone": "America/Santiago"
            }
        };
        const webSearchOpenAi = { "type": "web_search" };
        if (format === "anthropic") {
            return {
                // Claude puede combinar tools del servidor con las locales
                "functions": [...root.tools["openai"]["functions"], webSearchAnthropic],
                "search": [webSearchAnthropic],
                "none": []
            };
        }
        if (format === "openai-native") {
            return {
                "functions": [...root.tools["openai"]["functions"], webSearchOpenAi],
                "search": [webSearchOpenAi],
                "none": []
            };
        }
        if (format === "claudecode") {
            // Claude Code trae sus propias tools (Read/Edit/Bash/WebSearch/MCP)
            return { "functions": [], "search": [], "none": [] };
        }
        return root.tools[format] ?? root.tools["openai"];
    }
    property var toolDescriptions: {
        "functions": Translation.tr("Commands, edit configs, search.\nTakes an extra turn to switch to search mode if that's needed"),
        "search": Translation.tr("Gives the model search capabilities (immediately)"),
        "none": Translation.tr("Disable tools")
    }

    // Model properties:
    // - name: Name of the model
    // - icon: Icon name of the model
    // - description: Description of the model
    // - endpoint: Endpoint of the model
    // - model: Model name of the model
    // - requires_key: Whether the model requires an API key
    // - key_id: The identifier of the API key. Use the same identifier for models that can be accessed with the same key.
    // - key_get_link: Link to get an API key
    // - key_get_description: Description of pricing and how to get an API key
    // - api_format: The API format of the model. Can be "openai" or "gemini". Default is "openai".
    // - extraParams: Extra parameters to be passed to the model. This is a JSON object.
    property var models: Config.options.policies.ai === 2 ? {} : {
        "gemini-2.5-flash": aiModelComponent.createObject(this, {
            "name": "Gemini 2.5 Flash",
            "icon": "google-gemini-symbolic",
            "description": Translation.tr("Online | Google's model\nNewer model that's slower than its predecessor but should deliver higher quality answers"),
            "homepage": "https://aistudio.google.com",
            "endpoint": "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:streamGenerateContent",
            "model": "gemini-2.5-flash",
            "requires_key": true,
            "key_id": "gemini",
            "key_get_link": "https://aistudio.google.com/app/apikey",
            "key_get_description": Translation.tr("**Pricing**: free. Data used for training.\n\n**Instructions**: Log into Google account, allow AI Studio to create Google Cloud project or whatever it asks, go back and click Get API key"),
            "api_format": "gemini",
        }),
        "gemini-3-flash": aiModelComponent.createObject(this, {
            "name": "Gemini 3 Flash",
            "icon": "google-gemini-symbolic",
            "description": Translation.tr("Online | Google's model\nPro-level intelligence at the speed and pricing of Flash."),
            "homepage": "https://aistudio.google.com",
            "endpoint": "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:streamGenerateContent",
            "model": "gemini-3-flash-preview",
            "requires_key": true,
            "key_id": "gemini",
            "key_get_link": "https://aistudio.google.com/app/apikey",
            "key_get_description": Translation.tr("**Pricing**: free. Data used for training.\n\n**Instructions**: Log into Google account, allow AI Studio to create Google Cloud project or whatever it asks, go back and click Get API key"),
            "api_format": "gemini",
        }),
        "mistral-medium-3": aiModelComponent.createObject(this, {
            "name": "Mistral Medium 3",
            "icon": "mistral-symbolic",
            "description": Translation.tr("Online | %1's model | Delivers fast, responsive and well-formatted answers. Disadvantages: not very eager to do stuff; might make up unknown function calls").arg("Mistral"),
            "homepage": "https://mistral.ai/news/mistral-medium-3",
            "endpoint": "https://api.mistral.ai/v1/chat/completions",
            "model": "mistral-medium-2505",
            "requires_key": true,
            "key_id": "mistral",
            "key_get_link": "https://console.mistral.ai/api-keys",
            "key_get_description": Translation.tr("**Instructions**: Log into Mistral account, go to Keys on the sidebar, click Create new key"),
            "api_format": "mistral",
        }),
    }
    property var modelList: Object.keys(root.models)

    function addUserModels() {
        (Config?.options.ai?.extraModels ?? []).forEach(model => {
            const safeModelName = root.safeModelName(model["id"] || model["model"]);
            root.addModel(safeModelName, model)
        });
    }

    Connections {
        target: Config
        function onReadyChanged() {
            if (!Config.ready) return;
            root.addUserModels()
        }
    }

    Component.onCompleted: {
        root.addUserModels(); // el onReadyChanged de arriba puede no dispararse si la config cargó antes que este servicio
        root.tryRestoreSessions();
    }

    // Las pestañas guardadas viven en Persistent, que carga su archivo async. Si
    // restauráramos antes de que esté listo veríamos la lista vacía y, peor, la
    // pisaríamos al persistir la pestaña nueva.
    Connections {
        target: Persistent
        function onReadyChanged() {
            root.tryRestoreSessions();
        }
    }

    Timer {
        // Red de seguridad: si Persistent nunca carga, igual hay que tener una pestaña
        id: restoreFallbackTimer
        interval: 2000
        running: true
        onTriggered: root.tryRestoreSessions(true)
    }

    function guessModelLogo(model) {
        if (model.includes("llama")) return "ollama-symbolic";
        if (model.includes("gemma")) return "google-gemini-symbolic";
        if (model.includes("deepseek")) return "deepseek-symbolic";
        if (/^phi\d*:/i.test(model)) return "microsoft-symbolic";
        return "ollama-symbolic";
    }

    function guessModelName(model) {
        const replaced = model.replace(/-/g, ' ').replace(/:/g, ' ');
        let words = replaced.split(' ');
        words[words.length - 1] = words[words.length - 1].replace(/(\d+)b$/, (_, num) => `${num}B`)
        words = words.map((word) => {
            return (word.charAt(0).toUpperCase() + word.slice(1))
        });
        if (words[words.length - 1] === "Latest") words.pop();
        else words[words.length - 1] = `(${words[words.length - 1]})`; // Surround the last word with square brackets
        const result = words.join(' ');
        return result;
    }

    function addModel(modelName, data) {
        root.models = Object.assign({}, root.models, {
            [modelName]: aiModelComponent.createObject(this, data)
        });
    }

    Process {
        id: getOllamaModels
        running: true
        command: ["bash", "-c", `${Directories.scriptPath}/ai/show-installed-ollama-models.sh`.replace(/file:\/\//, "")]
        stdout: SplitParser {
            onRead: data => {
                try {
                    if (data.length === 0) return;
                    const dataJson = JSON.parse(data);
                    root.modelList = [...root.modelList, ...dataJson];
                    dataJson.forEach(model => {
                        const safeModelName = root.safeModelName(model);
                        root.addModel(safeModelName, {
                            "name": guessModelName(model),
                            "icon": guessModelLogo(model),
                            "description": Translation.tr("Local Ollama model | %1").arg(model),
                            "homepage": `https://ollama.com/library/${model}`,
                            "endpoint": "http://localhost:11434/v1/chat/completions",
                            "model": model,
                            "requires_key": false,
                        })
                    });

                    root.modelList = Object.keys(root.models);

                } catch (e) {
                    console.log("Could not fetch Ollama models:", e);
                }
            }
        }
    }

    Process {
        id: getDefaultPrompts
        running: true
        command: ["ls", "-1", Directories.defaultAiPrompts]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length === 0) return;
                root.defaultPrompts = text.split("\n")
                    .filter(fileName => fileName.endsWith(".md") || fileName.endsWith(".txt"))
                    .map(fileName => `${Directories.defaultAiPrompts}/${fileName}`)
            }
        }
    }

    Process {
        id: getUserPrompts
        running: true
        command: ["ls", "-1", Directories.userAiPrompts]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length === 0) return;
                root.userPrompts = text.split("\n")
                    .filter(fileName => fileName.endsWith(".md") || fileName.endsWith(".txt"))
                    .map(fileName => `${Directories.userAiPrompts}/${fileName}`)
            }
        }
    }

    Process {
        id: getSavedChats
        running: true
        command: ["ls", "-1", Directories.aiChats]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length === 0) return;
                root.savedChats = text.split("\n")
                    .filter(fileName => fileName.endsWith(".json"))
                    .map(fileName => `${Directories.aiChats}/${fileName}`)
            }
        }
    }

    FileView {
        id: promptLoader
        watchChanges: false;
        onLoadedChanged: {
            if (!promptLoader.loaded) return;
            Config.options.ai.systemPrompt = promptLoader.text();
            root.addMessage(Translation.tr("Loaded the following system prompt\n\n---\n\n%1").arg(Config.options.ai.systemPrompt), root.interfaceRole);
        }
    }

    function loadPrompt(filePath) {
        promptLoader.path = "" // Unload
        promptLoader.path = filePath; // Load
        promptLoader.reload();
    }

    function addApiKeyAdvice(model, session = null) {
        (session ?? root.active)?.addMessage(
            Translation.tr('To set an API key, pass it with the %4 command\n\nTo view the key, pass "get" with the command<br/>\n\n### For %1:\n\n**Link**: %2\n\n%3')
                .arg(model.name).arg(model.key_get_link).arg(model.key_get_description ?? Translation.tr("<i>No further instruction provided</i>")).arg("/key"), 
            Ai.interfaceRole
        );
    }

    /* ---------------- /setup: panel de proveedores y API keys ---------------- */

    property string claudeCodeVersion: ""

    Process {
        id: claudeCodeProbe
        running: true
        command: ["bash", "-c", "command -v claude >/dev/null 2>&1 && (claude --version 2>/dev/null | head -1) || true"]
        stdout: StdioCollector {
            onStreamFinished: root.claudeCodeVersion = text.trim()
        }
    }

    /** Agrupa los modelos por key_id para saber qué proveedores hay configurados. */
    function providerSummary() {
        let providers = ({});
        root.modelList.forEach(modelId => {
            const model = root.models[modelId];
            if (!model) return;
            const bucket = (model.requires_key && model.key_id && model.key_id.length > 0)
                ? model.key_id : "(local)";
            if (!providers[bucket]) providers[bucket] = ({
                "models": [],
                "link": "",
                "description": "",
                "requiresKey": bucket !== "(local)"
            });
            providers[bucket].models.push(modelId);
            if (!providers[bucket].link && model.key_get_link)
                providers[bucket].link = model.key_get_link;
            if (!providers[bucket].description && model.key_get_description)
                providers[bucket].description = model.key_get_description;
        });
        return providers;
    }

    function maskKey(key) {
        if (!key || key.length === 0) return "";
        if (key.length <= 12) return "•".repeat(key.length);
        return key.slice(0, 6) + "…" + key.slice(-4);
    }

    function printSetup() {
        const providers = root.providerSummary();
        const names = Object.keys(providers).sort();
        let lines = [];

        lines.push("## 🔑 " + Translation.tr("Proveedores"));
        lines.push("");
        lines.push("| " + Translation.tr("Proveedor") + " | " + Translation.tr("API key")
            + " | " + Translation.tr("Modelos") + " |");
        lines.push("|---|---|---|");

        let missing = [];
        names.forEach(name => {
            const provider = providers[name];
            let keyCell;
            if (!provider.requiresKey) {
                keyCell = "—";
            } else if (!root.apiKeysLoaded) {
                keyCell = Translation.tr("cargando…");
            } else {
                const key = root.apiKeys[name];
                if (key && key.length > 0) {
                    keyCell = "✅ `" + root.maskKey(key) + "`";
                } else {
                    keyCell = "❌ " + Translation.tr("falta");
                    missing.push(name);
                }
            }
            lines.push(`| \`${name}\` | ${keyCell} | ${provider.models.length} |`);
        });

        lines.push("");
        lines.push("**Claude Code**: " + (root.claudeCodeVersion.length > 0
            ? "✅ `" + root.claudeCodeVersion + "`"
            : "❌ " + Translation.tr("no está instalado o no está en el PATH")));

        if (missing.length > 0) {
            lines.push("");
            lines.push("### " + Translation.tr("Te faltan estas keys"));
            missing.forEach(name => {
                const link = providers[name].link;
                lines.push("");
                lines.push(`- \`/setup ${name} TU_KEY\`` + (link.length > 0 ? ` — ${link}` : ""));
            });
        }

        lines.push("");
        lines.push("---");
        lines.push("");
        lines.push("`/setup PROVEEDOR TU_KEY` " + Translation.tr("guarda la key"));
        lines.push("");
        lines.push("`/setup PROVEEDOR` " + Translation.tr("muestra el link y las instrucciones"));
        lines.push("");
        lines.push("`/setup get PROVEEDOR` " + Translation.tr("muestra la key guardada"));

        root.addMessage(lines.join("\n"), root.interfaceRole);
    }

    function printProviderHelp(name) {
        const providers = root.providerSummary();
        const provider = providers[name];
        if (!provider) return false;
        const key = root.apiKeys[name];
        let lines = [];
        lines.push("## " + name);
        lines.push("");
        lines.push(Translation.tr("Modelos") + ": " + provider.models.map(m => "`" + m + "`").join(", "));
        lines.push("");
        if (!provider.requiresKey) {
            lines.push(Translation.tr("No necesita API key."));
        } else {
            lines.push(Translation.tr("Key") + ": " + ((key && key.length > 0)
                ? "✅ `" + root.maskKey(key) + "`" : "❌ " + Translation.tr("falta")));
            if (provider.link.length > 0) {
                lines.push("");
                lines.push("**Link**: " + provider.link);
            }
            if (provider.description.length > 0) {
                lines.push("");
                lines.push(provider.description);
            }
            lines.push("");
            lines.push("`/setup " + name + " TU_KEY`");
            if (provider.link.length > 0 || name === "anthropic") {
                lines.push("");
                lines.push("`/setup " + name + " login` " + Translation.tr("— abre el navegador para conseguir la key")
                    + (name === "anthropic" && root.claudeCodeVersion.length > 0
                        ? " " + Translation.tr("(o hace login OAuth con Claude Code)") : ""));
            }
        }
        root.addMessage(lines.join("\n"), root.interfaceRole);
        return true;
    }

    /** Login por navegador: para Claude abre el login del CLI, para el resto el link de la key. */
    function loginProvider(name) {
        const providers = root.providerSummary();

        // Los modelos Claude andan con la suscripción vía el CLI, así que no hay
        // ninguna key que guardar acá: el login vive en `claude` y es por navegador.
        // Va antes del chequeo de proveedor porque "anthropic" ya no es un bucket con key.
        if (name === "claude" || name === "anthropic" || name === "claude-code") {
            if (root.claudeCodeVersion.length === 0) {
                root.addMessage(Translation.tr("No encuentro el CLI `claude` en el PATH. Instalalo con:\n\n```sh\ncurl -fsSL https://claude.ai/install.sh | bash\n```"), root.interfaceRole);
                return;
            }
            const cmd = `claude /login; echo; read -p "Enter para cerrar..." _`;
            Quickshell.execDetached(["bash", "-c",
                `${Config.options.apps.terminal} -e bash -c '${CF.StringUtils.shellSingleQuoteEscape(cmd)}'`]);
            root.addMessage(Translation.tr("🔐 Abrí una terminal con el login de Claude Code. Completá el login en el navegador y listo: los modelos `claude-*` usan tu suscripción, sin API key ni créditos."), root.interfaceRole);
            return;
        }

        if (!name || !providers[name]) {
            root.addMessage(Translation.tr("Usá `/setup PROVEEDOR login`. Proveedores: %1")
                .arg(Object.keys(providers).sort().map(p => "`" + p + "`").join(", ")), root.interfaceRole);
            return;
        }
        const provider = providers[name];
        if (!provider.requiresKey) {
            root.addMessage(Translation.tr("`%1` no usa API key, no hay nada que loguear.").arg(name), root.interfaceRole);
            return;
        }
        if (provider.link && provider.link.length > 0) {
            Qt.openUrlExternally(provider.link);
            root.addMessage(Translation.tr("🌐 Abriendo %1 en el navegador. Copiá tu key y guardala con `/setup %2 TU_KEY`.")
                .arg(provider.link).arg(name), root.interfaceRole);
        } else {
            root.addMessage(Translation.tr("No tengo un link de login para `%1`. Guardá la key directo con `/setup %1 TU_KEY`.").arg(name), root.interfaceRole);
        }
    }

    /**
     * Abre la app de Settings directo en "Servicios" (donde vive Proveedores:
     * login de Claude Code, keys de Gemini/OpenAI). Settings corre en su
     * propio proceso (`qs -p settings.qml`), así que no hay forma de
     * empujarle el estado en caliente: se lo dejamos escrito en un archivo
     * que la propia app lee al arrancar y borra apenas lo consume (ver
     * Directories.settingsTargetPagePath).
     */
    function openAccountsSettings() {
        Quickshell.execDetached(["bash", "-c",
            `mkdir -p "$(dirname '${Directories.settingsTargetPagePath}')" && printf '%s' 'modules/settings/ServicesConfig.qml' > '${Directories.settingsTargetPagePath}' && exec qs -p '${Quickshell.shellPath("settings.qml")}'`]);
    }

    function setupCommand(args) {
        if (!args || args.length === 0 || String(args[0]).trim().length === 0) {
            root.printSetup();
            return;
        }
        const providers = root.providerSummary();
        const first = String(args[0]).trim().toLowerCase();

        if (first === "get") {
            const name = args.length > 1 ? String(args[1]).trim().toLowerCase() : "";
            const key = root.apiKeys[name];
            if (!name || !providers[name]) {
                root.addMessage(Translation.tr("Usá `/setup get PROVEEDOR`. Proveedores: %1")
                    .arg(Object.keys(providers).map(p => "`" + p + "`").join(", ")), root.interfaceRole);
            } else if (key && key.length > 0) {
                root.addMessage("```txt\n" + key + "\n```", root.interfaceRole);
            } else {
                root.addMessage(Translation.tr("No hay key guardada para `%1`").arg(name), root.interfaceRole);
            }
            return;
        }

        if (first === "login") {
            const name = args.length > 1 ? String(args[1]).trim().toLowerCase() : "";
            root.loginProvider(name);
            return;
        }

        if (!providers[first]) {
            root.addMessage(Translation.tr("No conozco el proveedor `%1`. Los que hay: %2")
                .arg(first)
                .arg(Object.keys(providers).sort().map(p => "`" + p + "`").join(", ")), root.interfaceRole);
            return;
        }

        if (args.length < 2) {
            root.printProviderHelp(first);
            return;
        }

        if (String(args[1]).trim().toLowerCase() === "login") {
            root.loginProvider(first);
            return;
        }

        // Al pegar desde una terminal la key suele venir cortada con saltos de línea
        // y espacios. Un header con "\n" adentro hace que curl falle con error 43 y
        // no escupa NADA, así que el chat queda mudo. Limpiamos todo el whitespace.
        const key = args.slice(1).join(" ").replace(/\s+/g, "");
        if (key.length === 0) {
            root.addMessage(Translation.tr("Key vacía, no guardé nada."), root.interfaceRole);
            return;
        }
        KeyringStorage.setNestedField(["apiKeys", first], key);
        root.addMessage(Translation.tr("✅ Key guardada para `%1` (%2)")
            .arg(first).arg(root.maskKey(key)), root.interfaceRole);

        // Los tokens OAuth de `claude setup-token` (sk-ant-oat…) NO sirven para la
        // Messages API, que espera una key de console.anthropic.com (sk-ant-api…).
        if (first === "anthropic" && key.indexOf("sk-ant-oat") === 0) {
            root.addMessage(Translation.tr("⚠️ Eso es un **token OAuth de Claude Code**, no una API key, y acá no hace falta.\n\nLos modelos `claude-*` ya usan tu **suscripción** a través del CLI. Elegí uno con `/model claude-haiku` y listo. Si te pide login, corré `/setup claude login`."), root.interfaceRole);
        }
    }


    function printApiKey() {
        const model = models[currentModelId];
        if (model.requires_key) {
            const key = root.apiKeys[model.key_id];
            if (key) {
                root.addMessage(Translation.tr("API key:\n\n```txt\n%1\n```").arg(key), Ai.interfaceRole);
            } else {
                root.addMessage(Translation.tr("No API key set for %1").arg(model.name), Ai.interfaceRole);
            }
        } else {
            root.addMessage(Translation.tr("%1 does not require an API key").arg(model.name), Ai.interfaceRole);
        }
    }

    function printTemperature() {
        root.addMessage(Translation.tr("Temperature: %1").arg(root.temperature), Ai.interfaceRole);
    }


    /**
     * Mensaje de error cuando un request muere sin devolver nada. Antes esto estaba
     * duplicado entre el onExited del requester y el case cli_error de Claude Code.
     */
    function describeRequestFailure(exitCode, modelId) {
        let hint = "";
        if (exitCode === 43) {
            hint = "\n\n" + Translation.tr("`curl` error 43 casi siempre significa que la API key tiene un salto de línea o un espacio adentro (pasa al copiarla de una terminal). Volvé a guardarla con `/setup %1 TU_KEY`.")
                .arg(root.models[modelId]?.key_id ?? "PROVEEDOR");
        } else if (exitCode === 6 || exitCode === 7) {
            hint = "\n\n" + Translation.tr("No se pudo conectar al endpoint. ¿Estás sin internet?");
        }
        return Translation.tr("**El request terminó sin respuesta** (exit code %1).").arg(exitCode) + hint;
    }

    function refreshSavedChats() {
        getSavedChats.running = true;
    }

    /* ------------------------------------------------------------------ */
    /* Sesiones: una por pestaña                                          */
    /* ------------------------------------------------------------------ */

    property Component aiSessionComponent: AiSession {}

    /** Las conversaciones abiertas, en el orden en que se ven las pestañas. */
    property var sessions: []
    property int activeIndex: 0
    readonly property var active: root.sessions[root.activeIndex] ?? null

    /** Niveles que acepta `claude --effort`. */
    readonly property var effortLevels: ["low", "medium", "high", "xhigh", "max"]

    function newSessionId() {
        return Date.now().toString(36) + Math.random().toString(36).substr(2, 5);
    }

    /** Busca la definición de un agente en Config.options.ai.agents. */
    function agentById(agentId) {
        const agents = Config.options?.ai?.agents ?? [];
        for (let i = 0; i < agents.length; i++) {
            if (agents[i].id === agentId) return agents[i];
        }
        return null;
    }

    /**
     * Vuelca un agente sobre una sesión: identidad, modelo, prompt, tool, temperatura
     * y los extraParams (cwd/permission_mode para Claude Code).
     */
    function applyAgent(session, agentId) {
        if (!session) return;
        const agent = root.agentById(agentId);
        if (!agent) {
            session.agentId = "";
            session.title = Translation.tr("Chat");
            return;
        }
        session.agentId = agent.id;
        session.title = agent.name ?? agent.id;
        session.icon = agent.icon ?? "neurology";
        if (agent.model && root.modelList.indexOf(agent.model) !== -1) {
            session.setModel(agent.model, false, false);
        }
        if (agent.tool) session.currentTool = agent.tool;
        if (typeof agent.temperature === "number") session.temperature = agent.temperature;
        session.systemPromptOverride = agent.systemPrompt ?? "";
        session.extraParamsOverride = agent.extraParams ?? ({});
        if (typeof agent.effort === "string") session.effort = agent.effort;
        // El prompt de archivo pisa al inline y se lee async, así que va último
        if (agent.promptFile && agent.promptFile.length > 0) {
            agentPromptLoader.targetSession = session;
            agentPromptLoader.path = "";
            agentPromptLoader.path = agent.promptFile;
            agentPromptLoader.reload();
        }
    }

    FileView {
        id: agentPromptLoader
        property var targetSession: null
        watchChanges: false
        onLoadedChanged: {
            if (!agentPromptLoader.loaded || !agentPromptLoader.targetSession) return;
            agentPromptLoader.targetSession.systemPromptOverride = agentPromptLoader.text();
        }
    }

    /**
     * Abre una pestaña nueva.
     * @param agentId id del agente; vacío = el default de la config
     * @param activate si pasar el foco a la pestaña nueva
     * @param restoreId id existente a reusar (para restaurar al arrancar)
     */
    function newSession(agentId = "", activate = true, restoreId = "") {
        const id = restoreId.length > 0 ? restoreId : root.newSessionId();
        const session = root.aiSessionComponent.createObject(root, {
            "manager": root,
            "sessionId": id,
        });
        if (!session) {
            console.log("[Ai] No se pudo crear la sesión");
            return null;
        }
        root.applyAgent(session, agentId.length > 0 ? agentId : (Config.options?.ai?.defaultAgent ?? ""));
        root.sessions = [...root.sessions, session];
        if (activate) root.setActiveIndex(root.sessions.length - 1);
        root.persistSessions();
        return session;
    }

    /**
     * Cierra una pestaña: corta el request, la manda al historial y libera el objeto.
     *
     * Antes acá se borraba el autoguardado, y eso hacía imposible tener historial:
     * cerrar una pestaña destruía la conversación para siempre. Ahora el chat con
     * contenido se guarda y queda en el historial; sólo se borran de verdad las
     * pestañas vacías, que si no lo llenarían de conversaciones sin un mensaje.
     *
     * Cerrar tampoco archiva: archivar es algo que decide la persona. Cuando el
     * cierre archivaba solo, todo lo cerrado caía en «Archivados» y la lista
     * normal del historial quedaba siempre vacía, que es justo lo contrario de
     * para lo que existe.
     */
    function closeSession(index) {
        if (index < 0 || index >= root.sessions.length) return;
        const session = root.sessions[index];
        session.abort();
        if (session.messageIDs.length === 0) {
            Quickshell.execDetached(["rm", "-f", `${Directories.aiChats}/${session.autoSaveName}.json`]);
            AiHistory.forget(session.autoSaveName);
        } else {
            session.autoSave();
            // Sella la fecha y, si la pestaña tenía nombre propio, lo conserva
            // para que en el historial no aparezca como «session-xxxx».
            // «Chat» es el título por defecto y no dice nada: en ese caso conviene
            // dejar que el historial use el primer mensaje como título.
            const named = session.title.length > 0 && session.title !== Translation.tr("Chat");
            if (named && AiHistory.entryFor(session.autoSaveName).title.length === 0) {
                AiHistory.setTitle(session.autoSaveName, session.title);
            } else {
                AiHistory.touch(session.autoSaveName);
            }
        }

        const remaining = root.sessions.filter((_, i) => i !== index);
        root.sessions = remaining;
        if (root.activeIndex >= remaining.length) root.activeIndex = Math.max(0, remaining.length - 1);
        session.destroy();

        // Nunca quedarse sin pestañas: el panel necesita una para tener dónde escribir
        if (root.sessions.length === 0) root.newSession();
        else {
            root.setActiveIndex(root.activeIndex);
            root.persistSessions();
        }
        AiHistory.refresh();
    }

    function setActiveIndex(index) {
        if (index < 0 || index >= root.sessions.length) return;
        root.activeIndex = index;
        const session = root.sessions[index];
        if (session) session.unread = false;
        root.persistSessions();
    }

    function sessionIndexById(sessionId) {
        for (let i = 0; i < root.sessions.length; i++) {
            if (root.sessions[i].sessionId === sessionId) return i;
        }
        return -1;
    }

    /** Guarda qué pestañas están abiertas para poder reabrirlas al recargar la shell. */
    function persistSessions() {
        // Antes de restaurar no se escribe nada: si no, la primera pestaña que se cree
        // borraría la lista que todavía no leímos.
        if (!root.sessionsRestored) return;
        if (!Persistent.states?.ai) return;
        Persistent.states.ai.tabs = root.sessions.map(session => ({
            "id": session.sessionId,
            "agentId": session.agentId,
            "modelId": session.modelId,
            "effort": session.effort,
            "tool": session.currentTool,
            // Si la pestaña está continuando un chat del historial, el nombre del
            // archivo tiene que sobrevivir al reload o al volver se duplicaría.
            "chatName": session.adoptedChatName,
        }));
        Persistent.states.ai.activeTab = root.activeIndex;
    }

    /** Ya se restauraron las pestañas de la corrida anterior. */
    property bool sessionsRestored: false

    /**
     * Restaura una sola vez, cuando Persistent terminó de cargar.
     * @param force restaurar igual aunque Persistent no esté listo (timeout)
     */
    function tryRestoreSessions(force = false) {
        if (root.sessionsRestored) return;
        if (!Persistent.ready && !force) return;
        root.sessionsRestored = true;
        restoreFallbackTimer.running = false;
        root.restoreSessions();
    }

    /** Reabre las pestañas de la sesión anterior, o crea una si no había ninguna. */
    function restoreSessions() {
        const tabs = Persistent.states?.ai?.tabs ?? [];
        for (let i = 0; i < tabs.length; i++) {
            const tab = tabs[i];
            if (!tab || !tab.id) continue;
            const session = root.newSession(tab.agentId ?? "", false, tab.id);
            if (!session) continue;
            // Modelo y esfuerzo elegidos a mano ganan sobre lo que trae el agente
            if (tab.modelId && root.modelList.indexOf(tab.modelId) !== -1) session.setModel(tab.modelId, false, false);
            if (typeof tab.effort === "string") session.effort = tab.effort;
            if (tab.tool) session.currentTool = tab.tool;
            if (tab.chatName && tab.chatName.length > 0) session.adoptedChatName = tab.chatName;
            session.loadChat(session.autoSaveName);
        }
        if (root.sessions.length === 0) root.newSession();
        else root.setActiveIndex(Math.min(Persistent.states?.ai?.activeTab ?? 0, root.sessions.length - 1));
    }

    /* ------------------------------------------------------------------ */
    /* Fachada: reenvía a la sesión activa                                */
    /*                                                                     */
    /* Todo el panel del sidebar y los delegates de mensajes siguen        */
    /* hablándole a `Ai` como antes; acá abajo se traduce a la pestaña que */
    /* está en pantalla. Las lecturas son bindings, así que cambiar de     */
    /* pestaña re-evalúa la UI sola.                                       */
    /* ------------------------------------------------------------------ */

    readonly property var messageIDs: root.active?.messageIDs ?? []
    readonly property var messageByID: root.active?.messageByID ?? ({})
    readonly property real temperature: root.active?.temperature ?? 0.5
    readonly property string currentTool: root.active?.currentTool ?? (Config?.options.ai.tool ?? "search")
    readonly property var currentModelId: root.active?.modelId ?? ""
    readonly property bool currentModelHasApiKey: root.active?.currentModelHasApiKey ?? true
    // Se calcula acá y no se reenvía el `list<var>` de la sesión: así lo que ve la UI
    // es siempre un array de JS común, sin depender de cómo QML convierte list<var>.
    readonly property var availableTools: root.active
        ? Object.keys(root.toolsForFormat(root.models[root.currentModelId]?.api_format))
        : []
    readonly property string pendingFilePath: root.active?.pendingFilePath ?? ""
    readonly property string systemPrompt: root.active?.systemPrompt ?? ""
    readonly property string effort: root.active?.effort ?? ""
    readonly property bool supportsEffort: root.active?.supportsEffort ?? false

    property QtObject emptyTokenCount: QtObject {
        readonly property int input: -1
        readonly property int output: -1
        readonly property int total: -1
    }
    readonly property var tokenCount: root.active?.tokenCount ?? root.emptyTokenCount

    function addMessage(message, role) { root.active?.addMessage(message, role); }
    function removeMessage(index) { root.active?.removeMessage(index); }
    function clearMessages() { root.active?.clearMessages(); }
    function sendUserMessage(message) { root.active?.sendUserMessage(message); }
    function regenerate(messageIndex) { root.active?.regenerate(messageIndex); }
    function attachFile(filePath) { root.active?.attachFile(filePath); }
    function approveCommand(message) { root.active?.approveCommand(message); }
    function rejectCommand(message) { root.active?.rejectCommand(message); }
    function getModel() { return root.active?.getModel() ?? root.models[root.modelList[0]]; }
    function setModel(modelId, feedback = true, setPersistentState = true) {
        root.active?.setModel(modelId, feedback, setPersistentState);
    }
    function setTool(tool) { return root.active?.setTool(tool) ?? false; }
    function getTemperature() { return root.active?.getTemperature() ?? 0.5; }
    function setTemperature(value) { root.active?.setTemperature(value); }
    function setApiKey(key) { root.active?.setApiKey(key); }
    function printPrompt() { root.active?.printPrompt(); }
    function setEffort(level) { return root.active?.setEffort(level) ?? false; }
    function saveChat(chatName) { root.active?.saveChat(chatName); }
    function loadChat(chatName) { root.active?.loadChat(chatName); }
    function abort() { root.active?.abort(); }
}
