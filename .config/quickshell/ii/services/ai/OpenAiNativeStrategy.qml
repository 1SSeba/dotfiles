import QtQuick
import qs.modules.common.functions as CF

/**
 * Estrategia nativa de OpenAI: Responses API (https://api.openai.com/v1/responses).
 *
 * Qué gana sobre el shim de chat/completions que ya trae el repo:
 * - Resúmenes de razonamiento -> bloque <think>
 * - Búsqueda web del lado del servidor -> chips de fuentes y de búsquedas
 * - Function calling de verdad (la estrategia vieja no lo maneja para nada)
 * - Imágenes adjuntas
 *
 * Diferencias con chat/completions:
 * - El system prompt va en `instructions`, no como mensaje con role "system"
 * - Los mensajes van en `input`, no en `messages`
 * - El streaming son eventos tipados `response.*`, no deltas de `choices[0]`
 * - Las tools son planas: {type, name, parameters}, sin el wrapper `function`
 * - Los modelos de razonamiento rechazan `temperature`
 */
RichStreamStrategy {
    id: root

    // Marcadores de sustitución para adjuntos
    readonly property string fileMediaTypeVarName: "MEDIA_TYPE"
    readonly property string fileBase64VarName: "FILE_B64"
    readonly property string fileMediaTypeSubstitutionString: "{{ openai_media_type }}"
    readonly property string fileBase64SubstitutionString: "{{ openai_file_b64 }}"

    // Estado del stream
    property string pendingCallId: ""
    property string pendingCallName: ""
    property int inputTokens: -1
    property int outputTokens: -1

    function buildEndpoint(model: AiModel): string {
        return model.endpoint;
    }

    function buildAuthorizationHeader(apiKeyEnvVarName: string): string {
        return `-H "Authorization: Bearer \$\{${apiKeyEnvVarName}\}"`;
    }

    // ------------------------------------------------------------------ //
    // Tools
    // ------------------------------------------------------------------ //

    /** chat/completions -> Responses: aplana el wrapper `function`. */
    function convertTools(tools) {
        if (!tools || tools.length === 0) return [];
        let result = [];
        tools.forEach(tool => {
            // Tools del servidor (web_search, code_interpreter, ...) pasan derecho
            if (tool.type && tool.type !== "function") {
                result.push(tool);
                return;
            }
            const fn = tool.function ?? tool;
            if (!fn.name) return;
            let schema = fn.parameters;
            if (!schema || !schema.type) {
                schema = { "type": "object", "properties": {} };
            }
            result.push({
                "type": "function",
                "name": fn.name,
                "description": fn.description ?? "",
                "parameters": schema
            });
        });
        return result;
    }

    // ------------------------------------------------------------------ //
    // Request body
    // ------------------------------------------------------------------ //

    function buildRequestData(model: AiModel, messages, systemPrompt: string, temperature: real, tools: list<var>, filePath: string) {
        let input = [];
        let lastCall = null;

        for (let i = 0; i < messages.length; i++) {
            const message = messages[i];

            if (message.role === "assistant") {
                const text = root.cleanHistoryText(message.rawContent);
                if (text.length > 0) {
                    input.push({ "role": "assistant", "content": text });
                }
                if (message.functionCall && message.functionCall.name) {
                    const callId = message.functionCall.id || `call_local_${i}`;
                    lastCall = { "id": callId, "name": message.functionCall.name };
                    input.push({
                        "type": "function_call",
                        "call_id": callId,
                        "name": message.functionCall.name,
                        "arguments": JSON.stringify(message.functionCall.args ?? {})
                    });
                }
                continue;
            }

            // Resultado de una tool
            const isToolResult = message.functionName
                && message.functionName.length > 0
                && message.functionResponse !== undefined
                && lastCall !== null
                && lastCall.name === message.functionName;

            if (isToolResult) {
                input.push({
                    "type": "function_call_output",
                    "call_id": lastCall.id,
                    "output": (message.functionResponse && message.functionResponse.length > 0)
                        ? message.functionResponse : "(sin salida)"
                });
                lastCall = null;
                continue;
            }

            const text = message.rawContent ?? "";
            if (text.trim().length === 0) continue;
            input.push({
                "role": "user",
                "content": [{ "type": "input_text", "text": text }]
            });
        }

        // Adjunto en el último mensaje del usuario
        if (filePath && filePath.length > 0) {
            for (let i = input.length - 1; i >= 0; i--) {
                if (input[i].role !== "user" || !Array.isArray(input[i].content)) continue;
                input[i].content.unshift({
                    "type": "input_image",
                    "image_url": `data:${root.fileMediaTypeSubstitutionString};base64,${root.fileBase64SubstitutionString}`
                });
                break;
            }
        }

        if (input.length === 0) {
            input.push({ "role": "user", "content": [{ "type": "input_text", "text": "Hola" }] });
        }

        let baseData = {
            "model": model.model,
            "instructions": systemPrompt,
            "input": input,
            "stream": true
        };

        const converted = root.convertTools(tools);
        if (converted.length > 0) baseData.tools = converted;

        // Los modelos de razonamiento rechazan temperature; el resto la acepta
        const wantsReasoning = model.extraParams && model.extraParams.reasoning;
        if (!wantsReasoning) baseData.temperature = Math.min(temperature, 2);

        const merged = model.extraParams ? Object.assign({}, baseData, model.extraParams) : baseData;

        // Object.assign pisaría el objeto entero, así que reasoning se mergea aparte:
        // sin summary:"auto" la API no manda los resúmenes de razonamiento.
        if (wantsReasoning) {
            merged.reasoning = Object.assign({ "summary": "auto" }, model.extraParams.reasoning);
            delete merged.temperature;
        }
        return merged;
    }

    // ------------------------------------------------------------------ //
    // Streaming
    // ------------------------------------------------------------------ //

    function parseResponseLine(line, message) {
        let cleanData = line.trim();
        if (cleanData.length === 0) return {};
        if (cleanData.startsWith("event:")) return {};
        if (cleanData.startsWith(":")) return {};
        if (cleanData.startsWith("data:")) cleanData = cleanData.slice(5).trim();
        if (cleanData === "[DONE]") return { finished: true };
        if (!cleanData.startsWith("{")) return {};

        try {
            const dataJson = JSON.parse(cleanData);

            switch (dataJson.type) {

            // -------- texto --------
            case "response.output_text.delta":
                root.closeThinkBlock(message);
                message.rawContent += dataJson.delta ?? "";
                message.content += dataJson.delta ?? "";
                return {};

            // -------- razonamiento --------
            case "response.reasoning_summary_text.delta":
                root.openThinkBlock(message);
                message.rawContent += dataJson.delta ?? "";
                message.content += dataJson.delta ?? "";
                return {};

            case "response.reasoning_summary_part.added":
                if (root.isReasoning) {
                    message.rawContent += "\n\n";
                    message.content += "\n\n";
                }
                return {};

            // -------- items (function_call, web_search_call) --------
            case "response.output_item.added":
            case "response.output_item.done": {
                const item = dataJson.item ?? {};
                if (item.type === "web_search_call") {
                    root.closeThinkBlock(message);
                    root.addSearchQuery(message, item.action?.query ?? item.query ?? "");
                } else if (item.type === "function_call") {
                    root.pendingCallId = item.call_id ?? item.id ?? "";
                    root.pendingCallName = item.name ?? "";
                }
                return {};
            }

            // -------- argumentos de function call --------
            case "response.function_call_arguments.done": {
                if (root.pendingCallName.length === 0) return {};
                let args = {};
                try {
                    args = JSON.parse(dataJson.arguments && dataJson.arguments.length > 0
                        ? dataJson.arguments : "{}");
                } catch (e) {
                    console.log("[AI] OpenAI nativo: argumentos inválidos:", dataJson.arguments);
                }
                root.closeThinkBlock(message);
                const name = root.pendingCallName;
                const callId = root.pendingCallId;
                const newContent = `\n\n[[ Function: ${name}(${JSON.stringify(args, null, 2)}) ]]\n`;
                message.rawContent += newContent;
                message.content += newContent;
                message.functionName = name;
                message.functionCall = name;
                root.pendingCallName = "";
                root.pendingCallId = "";
                return { functionCall: { name: name, args: args, id: callId } };
            }

            // -------- citas de la búsqueda web --------
            case "response.output_text.annotation.added": {
                const annotation = dataJson.annotation ?? {};
                if (annotation.type === "url_citation") {
                    root.addSource(message, annotation.title, annotation.url);
                }
                return {};
            }

            // -------- fin --------
            case "response.completed": {
                root.closeThinkBlock(message);
                const usage = dataJson.response?.usage ?? {};
                root.inputTokens = usage.input_tokens ?? -1;
                root.outputTokens = usage.output_tokens ?? -1;
                return {
                    finished: true,
                    tokenUsage: {
                        input: root.inputTokens,
                        output: root.outputTokens,
                        total: usage.total_tokens
                            ?? ((root.inputTokens >= 0 && root.outputTokens >= 0)
                                ? root.inputTokens + root.outputTokens : -1)
                    }
                };
            }

            case "response.incomplete":
            case "response.failed":
            case "error": {
                const err = dataJson.response?.error ?? dataJson.error ?? dataJson;
                const errorMsg = `**Error${err.code ? ` (${err.code})` : ""}**: ${err.message ?? JSON.stringify(dataJson)}`;
                message.rawContent += errorMsg;
                message.content += errorMsg;
                return { finished: true };
            }

            default:
                return {};
            }

        } catch (e) {
            console.log("[AI] OpenAI nativo: no pude parsear la línea: ", e);
        }
        return {};
    }

    function reset() {
        root.pendingCallId = "";
        root.pendingCallName = "";
        root.inputTokens = -1;
        root.outputTokens = -1;
        root.resetRichState();
    }

    // ------------------------------------------------------------------ //
    // Adjuntos: base64 a variables de shell y sustitución
    // ------------------------------------------------------------------ //

    function buildScriptFileSetup(filePath) {
        const trimmedFilePath = CF.FileUtils.trimFileProtocol(filePath);
        let content = "";
        content += `ATTACHED_PATH='${CF.StringUtils.shellSingleQuoteEscape(trimmedFilePath)}'\n`;
        content += `${root.fileMediaTypeVarName}=$(file -b --mime-type "$ATTACHED_PATH")\n`;
        content += `${root.fileBase64VarName}=$(base64 -w 0 "$ATTACHED_PATH")\n`;
        return content;
    }

    function finalizeScriptContent(scriptContent: string): string {
        return scriptContent.replace(root.fileMediaTypeSubstitutionString, `'"\$${root.fileMediaTypeVarName}"'`)
                            .replace(root.fileBase64SubstitutionString, `'"\$${root.fileBase64VarName}"'`);
    }
}
