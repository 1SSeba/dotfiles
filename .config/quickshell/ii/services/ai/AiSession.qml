pragma ComponentBehavior: Bound

import qs.services // Translation y KeyringStorage viven en services/
import qs.modules.common
import qs.modules.common.functions as CF
import Quickshell
import Quickshell.Io
import QtQuick

/**
 * Una conversación de AI independiente: su propia lista de mensajes, sus propias
 * instancias de ApiStrategy y su propio proceso de request.
 *
 * Antes todo esto vivía en el singleton `Ai`, lo que significaba una sola charla a
 * la vez: dos pestañas se pisaban el `sessionId` de Claude Code, el buffer de JSON y
 * el script en /tmp. Acá cada sesión es un objeto aparte, así que N pestañas pueden
 * estar respondiendo al mismo tiempo sin mezclarse.
 *
 * `manager` es el singleton `Ai`, que sigue siendo el dueño de lo global: la lista
 * de modelos, las API keys y las definiciones de tools. Se pasa por inyección en vez
 * de importarlo para no crear un import circular entre qs.services y qs.services.ai.
 */
Scope {
    id: session

    /** El singleton `Ai`. Se inyecta al crear la sesión en vez de importarlo,
     *  para no armar un import circular entre qs.services y qs.services.ai. */
    property var manager: null
    property string sessionId: ""

    property string agentId: ""
    property string title: Translation.tr("Chat")
    property string icon: "neurology"
    /** Texto tipeado y sin enviar. Vive acá para que cambiar de pestaña no lo pierda. */
    property string draft: ""
    /** Hay un request en vuelo. */
    property bool busy: false
    /** Terminó de responder mientras el usuario miraba otra pestaña. */
    property bool unread: false

    signal responseFinished()

    // ------------------------------------------------------------------ //
    // Estado de la conversación
    // ------------------------------------------------------------------ //

    property var messageIDs: []
    property var messageByID: ({})
    property var postResponseHook
    property string pendingFilePath: ""

    property string modelId: Persistent.states?.ai?.model || session.manager?.modelList[0] || ""
    property real temperature: Persistent.states?.ai?.temperature ?? 0.5
    property string currentTool: Config?.options.ai.tool ?? "search"

    /** Prompt propio del agente. Vacío = usa el global de la config. */
    property string systemPromptOverride: ""

    property string systemPrompt: {
        let prompt = session.systemPromptOverride.length > 0
            ? session.systemPromptOverride
            : (Config.options?.ai?.systemPrompt ?? "");
        const subs = session.manager?.promptSubstitutions ?? ({});
        for (let key in subs) {
            // QML/JS acá no tiene replaceAll, por eso split/join
            prompt = prompt.split(key).join(subs[key]);
        }
        return prompt;
    }

    /** Extras del agente que se mergean sobre los del modelo (cwd, permission_mode...). */
    property var extraParamsOverride: ({})

    /** Nivel de esfuerzo de Claude Code: low | medium | high | xhigh | max. Vacío = el default del CLI. */
    property string effort: ""

    property QtObject tokenCount: QtObject {
        property int input: -1
        property int output: -1
        property int total: -1
    }

    /** El modelo base tal como está declarado en el manager. */
    readonly property var baseModel: session.manager?.models[session.modelId] ?? null

    /**
     * El modelo que efectivamente se usa para pedir: el base con los extraParams del
     * agente mergeados encima (cwd, permission_mode, allowed_tools para Claude Code).
     * Es un AiModel de verdad y no un objeto plano porque las estrategias declaran
     * `buildRequestData(model: AiModel, ...)` y QML valida el tipo.
     */
    property AiModel effectiveModel: null
    /** El clon, si hubo que crearlo. Se guarda aparte para poder liberarlo. */
    property AiModel ownedModelClone: null

    /**
     * Todo lo que se le suma a los extraParams del modelo: lo del agente y, para
     * Claude Code, el nivel de esfuerzo elegido a mano.
     *
     * El esfuerzo se agrega SOLO en claudecode: la estrategia de Anthropic por HTTP
     * vuelca extraParams tal cual en el body del request, y una clave `effort` ahí
     * la rechaza la API.
     */
    function computedOverrides() {
        const base = session.manager?.models[session.modelId];
        let overrides = Object.assign({}, session.extraParamsOverride ?? ({}));
        if (base?.api_format === "claudecode" && session.effort.length > 0) {
            overrides.effort = session.effort;
        }
        return overrides;
    }

    function rebuildEffectiveModel() {
        if (!session.manager) return;
        const base = session.manager.models[session.modelId];
        const previousClone = session.ownedModelClone;
        session.ownedModelClone = null;
        const overrides = session.computedOverrides();

        if (!base) {
            session.effectiveModel = null;
        } else if (Object.keys(overrides).length === 0) {
            session.effectiveModel = base;
        } else {
            const merged = Object.assign({}, base.extraParams ?? ({}), overrides);
            const clone = session.manager.aiModelComponent.createObject(session, {
                "id": base.id,
                "name": base.name,
                "icon": base.icon,
                "description": base.description,
                "homepage": base.homepage,
                "endpoint": base.endpoint,
                "model": base.model,
                "requires_key": base.requires_key,
                "key_id": base.key_id,
                "key_get_link": base.key_get_link,
                "key_get_description": base.key_get_description,
                "api_format": base.api_format,
                "tools": base.tools,
                "extraParams": merged,
            });
            session.ownedModelClone = clone;
            session.effectiveModel = clone;
        }

        if (previousClone) previousClone.destroy();
    }

    onModelIdChanged: session.rebuildEffectiveModel()
    onExtraParamsOverrideChanged: session.rebuildEffectiveModel()
    onEffortChanged: session.rebuildEffectiveModel()

    /** Solo Claude Code entiende niveles de esfuerzo. */
    readonly property bool supportsEffort: session.baseModel?.api_format === "claudecode"

    function setEffort(level) {
        const wanted = String(level ?? "").trim().toLowerCase();
        if (wanted.length === 0 || wanted === "default" || wanted === "auto") {
            session.effort = "";
            session.manager.persistSessions();
            session.addMessage(Translation.tr("Esfuerzo: el que trae Claude Code por defecto"), session.manager.interfaceRole);
            return true;
        }
        if (session.manager.effortLevels.indexOf(wanted) === -1) {
            session.addMessage(Translation.tr("Nivel inválido. Opciones: %1")
                .arg(session.manager.effortLevels.join(", ")), session.manager.interfaceRole);
            return false;
        }
        if (!session.supportsEffort) {
            session.addMessage(Translation.tr("El esfuerzo solo aplica a los modelos que corren por Claude Code."),
                session.manager.interfaceRole);
            return false;
        }
        session.effort = wanted;
        session.manager.persistSessions();
        session.addMessage(Translation.tr("Esfuerzo: **%1**").arg(wanted), session.manager.interfaceRole);
        return true;
    }

    readonly property bool currentModelHasApiKey: {
        if (!session.manager) return true;
        const m = session.manager.models[session.modelId];
        if (!m || !m.requires_key) return true;
        if (!session.manager.apiKeysLoaded) return false;
        const key = session.manager.apiKeys[m.key_id];
        return (key?.length > 0);
    }

    readonly property list<var> availableTools: session.manager
        ? Object.keys(session.manager.toolsForFormat(session.manager.models[session.modelId]?.api_format))
        : []

    // ------------------------------------------------------------------ //
    // Estrategias — una instancia por sesión, ésta es la clave del paralelismo
    // ------------------------------------------------------------------ //

    property var apiStrategies: ({})

    property string requestScriptFilePath: `/tmp/quickshell/ai/request-${session.sessionId}.sh`

    readonly property ApiStrategy currentApiStrategy: session.apiStrategies[
        session.manager?.models[session.modelId]?.api_format || "openai"] ?? null

    Component.onCompleted: {
        const m = session.manager;
        if (!m) return;
        session.apiStrategies = {
            "openai": m.openaiApiStrategy.createObject(session),
            "gemini": m.geminiApiStrategy.createObject(session),
            "mistral": m.mistralApiStrategy.createObject(session),
            "anthropic": m.anthropicApiStrategy.createObject(session),
            "claudecode": m.claudeCodeStrategy.createObject(session, {
                "errFile": `/tmp/quickshell/ai/claude-code-${session.sessionId}.err`
            }),
            "openai-native": m.openaiNativeStrategy.createObject(session),
        };
        session.rebuildEffectiveModel();
    }

    // ------------------------------------------------------------------ //
    // Mensajes
    // ------------------------------------------------------------------ //

    function addMessage(message, role) {
        if (message.length === 0) return;
        const aiMessage = session.manager.aiMessageComponent.createObject(session, {
            "role": role,
            "content": message,
            "rawContent": message,
            "thinking": false,
            "done": true,
        });
        const id = session.manager.idForMessage(aiMessage);
        session.messageIDs = [...session.messageIDs, id];
        session.messageByID[id] = aiMessage;
    }

    function removeMessage(index) {
        if (index < 0 || index >= session.messageIDs.length) return;
        const id = session.messageIDs[index];
        session.messageIDs.splice(index, 1);
        session.messageIDs = [...session.messageIDs];
        delete session.messageByID[id];
    }

    function clearMessages() {
        session.messageIDs = [];
        session.messageByID = ({});
        session.tokenCount.input = -1;
        session.tokenCount.output = -1;
        session.tokenCount.total = -1;
        // Un /clear arranca una charla nueva, así que la estrategia tira su estado
        // (para Claude Code eso es olvidar el --resume anterior).
        session.currentApiStrategy?.resetConversation();
    }

    // ------------------------------------------------------------------ //
    // Ajustes de la sesión
    // ------------------------------------------------------------------ //

    function getModel() {
        return session.baseModel;
    }

    function setModel(modelId, feedback = true, setPersistentState = true) {
        if (!modelId) modelId = "";
        modelId = modelId.toLowerCase();
        if (session.manager.modelList.indexOf(modelId) !== -1) {
            const m = session.manager.models[modelId];
            // Política del sistema: puede prohibir modelos online
            if (Config.options.policies.ai === 2 && !m.endpoint.includes("localhost")) {
                session.addMessage(
                    Translation.tr("Online models disallowed\n\nControlled by `policies.ai` config option"),
                    session.manager.interfaceRole);
                return;
            }
            session.modelId = modelId;
            if (setPersistentState) Persistent.states.ai.model = modelId;
            session.manager.persistSessions(); // el modelo es parte de la pestaña
            if (feedback) session.addMessage(Translation.tr("Model set to %1").arg(m.name), session.manager.interfaceRole);
            if (m.requires_key) {
                if (session.manager.apiKeysLoaded
                    && (!session.manager.apiKeys[m.key_id] || session.manager.apiKeys[m.key_id].length === 0)) {
                    session.manager.addApiKeyAdvice(m, session);
                }
            }
        } else {
            if (feedback) session.addMessage(
                Translation.tr("Invalid model. Supported: \n```\n") + session.manager.modelList.join("\n```\n```\n") + "\n```",
                session.manager.interfaceRole);
        }
    }

    function setTool(tool) {
        const supported = session.manager.toolsForFormat(session.manager.models[session.modelId]?.api_format);
        if (!supported || !(tool in supported)) {
            session.addMessage(Translation.tr("Invalid tool. Supported tools:\n- %1").arg(session.availableTools.join("\n- ")),
                session.manager.interfaceRole);
            return false;
        }
        session.currentTool = tool;
        Config.options.ai.tool = tool; // último usado = default para pestañas nuevas
        session.manager.persistSessions();
        return true;
    }

    function getTemperature() {
        return session.temperature;
    }

    function setTemperature(value) {
        if (isNaN(value) || value < 0 || value > 2) {
            session.addMessage(Translation.tr("Temperature must be between 0 and 2"), session.manager.interfaceRole);
            return;
        }
        session.temperature = value;
        Persistent.states.ai.temperature = value;
        session.addMessage(Translation.tr("Temperature set to %1").arg(value), session.manager.interfaceRole);
    }

    function setApiKey(key) {
        const m = session.manager.models[session.modelId];
        if (!m.requires_key) {
            session.addMessage(Translation.tr("%1 does not require an API key").arg(m.name), session.manager.interfaceRole);
            return;
        }
        if (!key || key.length === 0) {
            session.manager.addApiKeyAdvice(m, session);
            return;
        }
        KeyringStorage.setNestedField(["apiKeys", m.key_id], key.trim());
        session.addMessage(Translation.tr("API key set for %1").arg(m.name), session.manager.interfaceRole);
    }

    function printPrompt() {
        session.addMessage(Translation.tr("The current system prompt is\n\n---\n\n%1").arg(session.systemPrompt),
            session.manager.interfaceRole);
    }

    // ------------------------------------------------------------------ //
    // Request
    // ------------------------------------------------------------------ //

    FileView {
        id: requesterScriptFile
    }

    Process {
        id: requester
        property list<string> baseCommand: ["bash"]
        property AiMessageData message
        property ApiStrategy currentStrategy

        function markDone() {
            // Puede llegar dos veces (por la línea final del stream y por onExited),
            // y no queremos guardar ni avisar dos veces.
            if (!requester.message || requester.message.done) return;
            requester.message.done = true;
            session.busy = false;
            if (session.manager.active !== session) session.unread = true;
            if (session.postResponseHook) {
                session.postResponseHook();
                session.postResponseHook = null;
            }
            session.autoSave();
            session.responseFinished();
        }

        function makeRequest() {
            const model = session.effectiveModel ?? session.manager.models[session.modelId];
            if (!model) {
                session.addMessage(Translation.tr("No hay un modelo válido seleccionado."), session.manager.interfaceRole);
                return;
            }

            // Traer las API keys si hacen falta
            if (model?.requires_key && !KeyringStorage.loaded) KeyringStorage.fetchKeyringData();

            requester.currentStrategy = session.currentApiStrategy;
            requester.currentStrategy.reset();

            /* API key por variable de entorno */
            if (model.requires_key)
                requester.environment[`${session.manager.apiKeyEnvVarName}`] =
                    session.manager.apiKeys ? (session.manager.apiKeys[model.key_id] ?? "") : "";

            /* Endpoint y cuerpo del request */
            const endpoint = requester.currentStrategy.buildEndpoint(model);
            const messageArray = session.messageIDs.map(id => session.messageByID[id]);
            const filteredMessageArray = messageArray.filter(m => m.role !== session.manager.interfaceRole);
            const data = requester.currentStrategy.buildRequestData(model, filteredMessageArray, session.systemPrompt,
                session.temperature, session.manager.toolsForFormat(model.api_format)[session.currentTool],
                session.pendingFilePath);

            let requestHeaders = {
                "Content-Type": "application/json",
            };

            /* Mensaje local donde se va escribiendo la respuesta */
            requester.message = session.manager.aiMessageComponent.createObject(session, {
                "role": "assistant",
                "model": session.modelId,
                "content": "",
                "rawContent": "",
                "thinking": true,
                "done": false,
            });
            const id = session.manager.idForMessage(requester.message);
            session.messageIDs = [...session.messageIDs, id];
            session.messageByID[id] = requester.message;
            session.busy = true;

            /* Headers para curl */
            let headerString = Object.entries(requestHeaders)
                .filter(([k, v]) => v && v.length > 0)
                .map(([k, v]) => `-H '${k}: ${v}'`)
                .join(' ');

            const authHeader = requester.currentStrategy.buildAuthorizationHeader(session.manager.apiKeyEnvVarName);

            const scriptShebang = "#!/usr/bin/env bash\n";

            /* Setup extra cuando hay un archivo adjunto */
            let scriptFileSetupContent = "";
            if (session.pendingFilePath && session.pendingFilePath.length > 0) {
                requester.message.localFilePath = session.pendingFilePath;
                scriptFileSetupContent = requester.currentStrategy.buildScriptFileSetup(session.pendingFilePath);
                session.pendingFilePath = "";
            }

            let scriptRequestContent = requester.currentStrategy.buildRequestCommand(endpoint, headerString, authHeader, data);

            /* A correr */
            const scriptContent = requester.currentStrategy.finalizeScriptContent(
                scriptShebang + scriptFileSetupContent + scriptRequestContent);
            const shellScriptPath = CF.FileUtils.trimFileProtocol(session.requestScriptFilePath);
            requesterScriptFile.path = Qt.resolvedUrl(shellScriptPath);
            requesterScriptFile.setText(scriptContent);
            requester.command = requester.baseCommand.concat([shellScriptPath]);
            requester.running = true;
        }

        stdout: SplitParser {
            onRead: data => {
                if (data.length === 0) return;
                if (requester.message.thinking) requester.message.thinking = false;

                try {
                    const result = requester.currentStrategy.parseResponseLine(data, requester.message);

                    if (result.functionCall) {
                        requester.message.functionCall = result.functionCall;
                        session.handleFunctionCall(result.functionCall.name, result.functionCall.args, requester.message);
                    }
                    if (result.tokenUsage) {
                        session.tokenCount.input = result.tokenUsage.input;
                        session.tokenCount.output = result.tokenUsage.output;
                        session.tokenCount.total = result.tokenUsage.total;
                    }
                    if (result.finished) {
                        requester.markDone();
                    }
                } catch (e) {
                    console.log("[AI] Could not parse response: ", e);
                    requester.message.rawContent += data;
                    requester.message.content += data;
                }
            }
        }

        onExited: (exitCode, exitStatus) => {
            const result = requester.currentStrategy.onRequestFinished(requester.message);

            if (result.finished || !requester.message.done) {
                requester.markDone();
            }

            // Si el request no devolvió ni una línea el chat quedaba mudo y no había
            // forma de saber por qué. Mostramos el código de salida en vez de nada.
            if (requester.message.content.length === 0 && exitCode !== 0) {
                session.addMessage(session.manager.describeRequestFailure(exitCode, session.modelId),
                    session.manager.interfaceRole);
            }

            if (requester.message.content.includes("API key not valid")) {
                session.manager.addApiKeyAdvice(session.manager.models[requester.message.model], session);
            }
        }
    }

    /** Corta el request en vuelo (al cerrar la pestaña o al pedir stop). */
    function abort() {
        if (!requester.running) return;
        requester.running = false;
        session.busy = false;
        if (requester.message && !requester.message.done) {
            requester.message.done = true;
            requester.message.thinking = false;
        }
    }

    function sendUserMessage(message) {
        if (message.length === 0) return;
        session.addMessage(message, "user");
        requester.makeRequest();
    }

    function attachFile(filePath: string) {
        session.pendingFilePath = CF.FileUtils.trimFileProtocol(filePath);
    }

    function regenerate(messageIndex) {
        if (messageIndex < 0 || messageIndex >= session.messageIDs.length) return;
        const id = session.messageIDs[messageIndex];
        const message = session.messageByID[id];
        if (message.role !== "assistant") return;
        // Borrar todo lo que venga después
        for (let i = session.messageIDs.length - 1; i >= messageIndex; i--) {
            session.removeMessage(i);
        }
        requester.makeRequest();
    }

    // ------------------------------------------------------------------ //
    // Function calling
    // ------------------------------------------------------------------ //

    function createFunctionOutputMessage(name, output, includeOutputInChat = true) {
        const body = `[[ Output of ${name} ]]${includeOutputInChat ? ("\n\n<think>\n" + output + "\n</think>") : ""}`;
        return session.manager.aiMessageComponent.createObject(session, {
            "role": "user",
            "content": body,
            "rawContent": body,
            "functionName": name,
            "functionResponse": output,
            "thinking": false,
            "done": true,
        });
    }

    function addFunctionOutputMessage(name, output) {
        const aiMessage = session.createFunctionOutputMessage(name, output);
        const id = session.manager.idForMessage(aiMessage);
        session.messageIDs = [...session.messageIDs, id];
        session.messageByID[id] = aiMessage;
    }

    function rejectCommand(message: AiMessageData) {
        if (!message.functionPending) return;
        message.functionPending = false;
        session.addFunctionOutputMessage(message.functionName, Translation.tr("Command rejected by user"));
    }

    function approveCommand(message: AiMessageData) {
        if (!message.functionPending) return;
        message.functionPending = false;

        const responseMessage = session.createFunctionOutputMessage(message.functionName, "", false);
        const id = session.manager.idForMessage(responseMessage);
        session.messageIDs = [...session.messageIDs, id];
        session.messageByID[id] = responseMessage;

        commandExecutionProc.message = responseMessage;
        commandExecutionProc.baseMessageContent = responseMessage.content;
        commandExecutionProc.shellCommand = message.functionCall.args.command;
        commandExecutionProc.running = true;
    }

    Process {
        id: commandExecutionProc
        property string shellCommand: ""
        property AiMessageData message
        property string baseMessageContent: ""
        command: ["bash", "-c", commandExecutionProc.shellCommand]
        stdout: SplitParser {
            onRead: output => {
                commandExecutionProc.message.functionResponse += output + "\n\n";
                const updatedContent = commandExecutionProc.baseMessageContent
                    + `\n\n<think>\n<tt>${commandExecutionProc.message.functionResponse}</tt>\n</think>`;
                commandExecutionProc.message.rawContent = updatedContent;
                commandExecutionProc.message.content = updatedContent;
            }
        }
        onExited: (exitCode, exitStatus) => {
            commandExecutionProc.message.functionResponse += `[[ Command exited with code ${exitCode} (${exitStatus}) ]]\n`;
            requester.makeRequest(); // seguir la conversación con el resultado
        }
    }

    function handleFunctionCall(name, args: var, message: AiMessageData) {
        if (name === "switch_to_search_mode") {
            const previousTool = session.currentTool;
            session.currentTool = "search";
            session.postResponseHook = () => { session.currentTool = previousTool; };
            session.addFunctionOutputMessage(name, Translation.tr("Switched to search mode. Continue with the user's request."));
            requester.makeRequest();
        } else if (name === "get_shell_config") {
            const configJson = CF.ObjectUtils.toPlainObject(Config.options);
            session.addFunctionOutputMessage(name, JSON.stringify(configJson));
            requester.makeRequest();
        } else if (name === "set_shell_config") {
            if (!args.key || !args.value) {
                session.addFunctionOutputMessage(name, Translation.tr("Invalid arguments. Must provide `key` and `value`."));
                return;
            }
            Config.setNestedValue(args.key, args.value);
        } else if (name === "run_shell_command") {
            if (!args.command || args.command.length === 0) {
                session.addFunctionOutputMessage(name, Translation.tr("Invalid arguments. Must provide `command`."));
                return;
            }
            const contentToAppend = `\n\n**Command execution request**\n\n\`\`\`command\n${args.command}\n\`\`\``;
            message.rawContent += contentToAppend;
            message.content += contentToAppend;
            message.functionPending = true;
        } else {
            session.addMessage(Translation.tr("Unknown function call: %1").arg(name), "assistant");
        }
    }

    // ------------------------------------------------------------------ //
    // Guardado / carga
    // ------------------------------------------------------------------ //

    function chatToJson() {
        return session.messageIDs.map(id => {
            const message = session.messageByID[id];
            return ({
                "role": message.role,
                "rawContent": message.rawContent,
                "fileMimeType": message.fileMimeType,
                "fileUri": message.fileUri,
                "localFilePath": message.localFilePath,
                "model": message.model,
                "thinking": false,
                "done": true,
                "annotations": message.annotations,
                "annotationSources": message.annotationSources,
                "functionName": message.functionName,
                "functionCall": message.functionCall,
                "functionResponse": message.functionResponse,
                "visibleToUser": message.visibleToUser,
                "agents": message.agents,
            });
        });
    }

    FileView {
        id: chatSaveFile
        property string chatName: ""
        path: chatSaveFile.chatName.length > 0 ? `${Directories.aiChats}/${chatSaveFile.chatName}.json` : ""
        blockLoading: true // evita carreras
        // Una pestaña restaurada que todavía no guardó nada no es un error
        printErrors: false
    }

    /**
     * Chat del historial que esta pestaña adoptó, si abrió uno viejo.
     *
     * Existe para que abrir algo del historial CONTINÚE ese chat en vez de
     * clonarlo. Antes la pestaña siempre autoguardaba con su propio nombre, así
     * que cada vez que abrías una conversación vieja quedaba un archivo nuevo:
     * abrir el mismo chat tres veces dejaba tres copias en el historial, y la
     * original nunca volvía a moverse.
     */
    property string adoptedChatName: ""

    /** Nombre del archivo de autoguardado de esta pestaña. */
    readonly property string autoSaveName: session.adoptedChatName.length > 0
        ? session.adoptedChatName
        : `session-${session.sessionId}`

    function autoSave() {
        session.saveChat(session.autoSaveName, false);
        // Sin esto el historial ordena por el mtime del archivo pero nunca se
        // entera de que hay algo nuevo hasta el próximo escaneo completo.
        AiHistory.touch(session.autoSaveName);
    }

    /**
     * Continúa un chat guardado en esta pestaña.
     *
     * Carga los mensajes y se queda con el nombre del archivo, así lo que sigas
     * escribiendo se guarda encima del mismo chat en vez de crear otro.
     */
    function adoptChat(chatName) {
        const clean = (chatName ?? "").trim();
        if (clean.length === 0) return;
        session.loadChat(clean);
        session.adoptedChatName = clean;
    }

    /**
     * Guarda el chat como una lista JSON de mensajes.
     * @param chatName nombre del chat
     * @param refreshList si actualizar la lista de chats guardados del manager
     */
    function saveChat(chatName, refreshList = true) {
        chatSaveFile.chatName = chatName.trim();
        chatSaveFile.setText(JSON.stringify(session.chatToJson()));
        if (refreshList) session.manager.refreshSavedChats();
    }

    /**
     * Carga un chat desde una lista JSON de mensajes.
     * @param chatName nombre del chat
     */
    function loadChat(chatName) {
        try {
            chatSaveFile.chatName = chatName.trim();
            chatSaveFile.reload();
            const saveContent = chatSaveFile.text();
            if (!saveContent || saveContent.length === 0) return;
            const saveData = JSON.parse(saveContent);
            session.clearMessages();
            // Ojo: antes acá se usaba el índice del array como ID, y los mensajes
            // nuevos se generaban con idForMessage(). Los dos espacios de IDs
            // convivían y regenerate()/removeMessage() pegaban en el mensaje
            // equivocado. Ahora se genera un ID real para cada mensaje cargado.
            const ids = [];
            for (let i = 0; i < saveData.length; i++) {
                const message = saveData[i];
                const obj = session.manager.aiMessageComponent.createObject(session, {
                    "role": message.role,
                    "rawContent": message.rawContent,
                    "content": message.rawContent,
                    "fileMimeType": message.fileMimeType,
                    "fileUri": message.fileUri,
                    "localFilePath": message.localFilePath,
                    "model": message.model,
                    "thinking": message.thinking,
                    "done": message.done,
                    "annotations": message.annotations,
                    "annotationSources": message.annotationSources,
                    "functionName": message.functionName,
                    "functionCall": message.functionCall,
                    "functionResponse": message.functionResponse,
                    "visibleToUser": message.visibleToUser,
                    "agents": message.agents ?? [],
                });
                const id = session.manager.idForMessage(obj);
                ids.push(id);
                session.messageByID[id] = obj;
            }
            session.messageIDs = ids;
        } catch (e) {
            console.log("[AI] Could not load chat: ", e);
        }
    }
}
