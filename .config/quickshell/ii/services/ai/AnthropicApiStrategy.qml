import QtQuick
import qs.modules.common.functions as CF

/**
 * Strategy for Anthropic's native Messages API (https://api.anthropic.com/v1/messages).
 *
 * Features:
 * - SSE streaming with typed events
 * - Extended thinking -> rendered inside <think> blocks
 * - Client-side tool calling (the shell's own get_shell_config / run_shell_command / ...)
 * - Server-side web search -> feeds the sidebar's source chips and search-query chips
 * - Prompt caching on the system prompt (cheaper follow-up turns)
 * - Image and PDF attachments
 *
 * Differences vs the OpenAI strategy that made this necessary:
 * - Auth uses the `x-api-key` header + a mandatory `anthropic-version` header
 * - The system prompt is a top-level `system` field, NOT a message with role "system"
 * - `max_tokens` is REQUIRED
 * - Tools use `input_schema` instead of `parameters`, and results come back as
 *   `tool_result` blocks that must reference the original `tool_use` id
 */
RichStreamStrategy {
    id: root

    readonly property string anthropicVersion: "2023-06-01"
    readonly property int defaultMaxTokens: 8192

    // Substitution markers for attached files (replaced by shell vars in finalizeScriptContent)
    readonly property string fileMediaTypeVarName: "MEDIA_TYPE"
    readonly property string fileBase64VarName: "FILE_B64"
    readonly property string fileMediaTypeSubstitutionString: "{{ anthropic_media_type }}"
    readonly property string fileBase64SubstitutionString: "{{ anthropic_file_b64 }}"

    // Streaming state
    property string currentBlockKind: ""   // text | thinking | tool_use | server_tool_use | other
    property string toolUseId: ""
    property string toolUseName: ""
    property string jsonBuffer: ""
    property int inputTokens: -1
    property int outputTokens: -1

    // ------------------------------------------------------------------ //
    // Endpoint & headers
    // ------------------------------------------------------------------ //

    function buildEndpoint(model: AiModel): string {
        return model.endpoint;
    }

    function buildAuthorizationHeader(apiKeyEnvVarName: string): string {
        return `-H "x-api-key: \$\{${apiKeyEnvVarName}\}" -H "anthropic-version: ${root.anthropicVersion}"`;
    }

    // ------------------------------------------------------------------ //
    // Helpers
    // ------------------------------------------------------------------ //


    /** Converts OpenAI-style tool definitions to Anthropic's format. */
    function convertTools(tools) {
        if (!tools || tools.length === 0) return [];
        let result = [];
        tools.forEach(tool => {
            // Server tools (web_search) and already-Anthropic-shaped tools pass through
            if (tool.type && tool.type.indexOf("web_search") === 0) {
                result.push(tool);
                return;
            }
            if (tool.name && tool.input_schema) {
                result.push(tool);
                return;
            }
            const fn = tool.function;
            if (!fn || !fn.name) return;
            let schema = fn.parameters;
            // Anthropic rejects an empty/absent schema: normalize it
            if (!schema || !schema.type) {
                schema = { "type": "object", "properties": {} };
            }
            result.push({
                "name": fn.name,
                "description": fn.description ?? "",
                "input_schema": schema
            });
        });
        return result;
    }





    // ------------------------------------------------------------------ //
    // Request body
    // ------------------------------------------------------------------ //

    function buildRequestData(model: AiModel, messages, systemPrompt: string, temperature: real, tools: list<var>, filePath: string) {
        const anthropicTools = root.convertTools(tools);
        let apiMessages = [];
        let lastToolUse = null;

        for (let i = 0; i < messages.length; i++) {
            const message = messages[i];

            if (message.role === "assistant") {
                let parts = [];
                const text = root.cleanHistoryText(message.rawContent);
                if (text.length > 0) parts.push({ "type": "text", "text": text });

                if (message.functionCall && message.functionCall.name) {
                    const id = message.functionCall.id || `toolu_local_${i}`;
                    lastToolUse = { "id": id, "name": message.functionCall.name };
                    parts.push({
                        "type": "tool_use",
                        "id": id,
                        "name": message.functionCall.name,
                        "input": message.functionCall.args ?? {}
                    });
                }

                if (parts.length === 0) continue;
                apiMessages.push({ "role": "assistant", "content": parts });
                continue;
            }

            // User (or tool result) message
            let parts = [];
            const isToolResult = message.functionName
                && message.functionName.length > 0
                && message.functionResponse !== undefined
                && lastToolUse !== null
                && lastToolUse.name === message.functionName;

            if (isToolResult) {
                parts.push({
                    "type": "tool_result",
                    "tool_use_id": lastToolUse.id,
                    "content": (message.functionResponse && message.functionResponse.length > 0)
                        ? message.functionResponse
                        : "(no output)"
                });
                lastToolUse = null;
            } else {
                const text = message.rawContent ?? "";
                if (text.trim().length > 0) parts.push({ "type": "text", "text": text });
            }

            if (parts.length === 0) continue;
            apiMessages.push({ "role": "user", "content": parts });
        }

        // Attach the pending file to the last user message
        if (filePath && filePath.length > 0 && apiMessages.length > 0) {
            const last = apiMessages[apiMessages.length - 1];
            if (last.role === "user") {
                const isPdf = /\.pdf$/i.test(filePath);
                last.content.unshift({
                    "type": isPdf ? "document" : "image",
                    "source": {
                        "type": "base64",
                        "media_type": root.fileMediaTypeSubstitutionString,
                        "data": root.fileBase64SubstitutionString
                    }
                });
            }
        }

        // Anthropic requires a non-empty messages array starting with a user turn
        if (apiMessages.length === 0) {
            apiMessages.push({ "role": "user", "content": [{ "type": "text", "text": "Hello" }] });
        }

        const wantsThinking = model.extraParams && model.extraParams.thinking;

        let baseData = {
            "model": model.model,
            "max_tokens": root.defaultMaxTokens,
            // Array form + cache_control: the system prompt is identical every turn,
            // so caching it makes follow-up messages noticeably cheaper.
            "system": [{
                "type": "text",
                "text": systemPrompt,
                "cache_control": { "type": "ephemeral" }
            }],
            "messages": apiMessages,
            "stream": true,
            // Extended thinking requires temperature exactly 1
            "temperature": wantsThinking ? 1 : Math.min(temperature, 1)
        };

        if (anthropicTools.length > 0) baseData.tools = anthropicTools;

        return model.extraParams ? Object.assign({}, baseData, model.extraParams) : baseData;
    }

    // ------------------------------------------------------------------ //
    // Streaming response parsing (SSE)
    // ------------------------------------------------------------------ //

    function parseResponseLine(line, message) {
        let cleanData = line.trim();

        if (cleanData.length === 0) return {};
        if (cleanData.startsWith("event:")) return {};   // typed by the data line itself
        if (cleanData.startsWith(":")) return {};        // SSE comment / keepalive
        if (cleanData.startsWith("data:")) cleanData = cleanData.slice(5).trim();
        if (cleanData.length === 0) return {};
        if (!cleanData.startsWith("{")) return {};

        try {
            return root.handleEvent(JSON.parse(cleanData), message);
        } catch (e) {
            console.log("[AI] Anthropic: Could not parse line: ", e);
            message.rawContent += line;
            message.content += line;
        }

        return {};
    }

    /**
     * Handles one already-parsed Anthropic stream event.
     * Kept separate from parseResponseLine so ClaudeCodeStrategy can reuse it
     * for the events it nests inside its own `stream_event` envelopes.
     */
    function handleEvent(dataJson, message) {
        // Errors (both streamed error events and plain non-stream error bodies)
        if (dataJson.type === "error" || dataJson.error) {
            const err = dataJson.error ?? {};
            const errorMsg = `**Error${err.type ? ` (${err.type})` : ""}**: ${err.message ?? JSON.stringify(dataJson)}`;
            message.rawContent += errorMsg;
            message.content += errorMsg;
            return { finished: true };
        }

        switch (dataJson.type) {
        case "message_start":
            root.inputTokens = dataJson.message?.usage?.input_tokens ?? -1;
            return {};

        case "content_block_start": {
            const block = dataJson.content_block;
            const kind = block?.type ?? "other";
            root.currentBlockKind = kind;
            root.jsonBuffer = "";

            if (kind === "thinking" || kind === "redacted_thinking") {
                root.openThinkBlock(message);
            } else if (kind === "tool_use") {
                root.closeThinkBlock(message);
                root.toolUseId = block.id ?? "";
                root.toolUseName = block.name ?? "";
            } else if (kind === "server_tool_use") {
                root.closeThinkBlock(message);
                root.toolUseName = block.name ?? "";
            } else if (kind === "web_search_tool_result") {
                root.closeThinkBlock(message);
                const results = block.content ?? [];
                if (Array.isArray(results)) {
                    results.forEach(r => root.addSource(message, r.title, r.url));
                }
            } else {
                root.closeThinkBlock(message);
            }
            return {};
        }

        case "content_block_delta": {
            const delta = dataJson.delta;
            switch (delta?.type) {
            case "thinking_delta":
                root.openThinkBlock(message);
                message.rawContent += delta.thinking ?? "";
                message.content += delta.thinking ?? "";
                break;
            case "text_delta":
                root.closeThinkBlock(message);
                message.rawContent += delta.text ?? "";
                message.content += delta.text ?? "";
                break;
            case "input_json_delta":
                root.jsonBuffer += delta.partial_json ?? "";
                break;
            case "citations_delta": {
                const citation = delta.citation ?? {};
                root.addSource(message, citation.title, citation.url);
                break;
            }
            default:
                break; // signature_delta and anything new: ignore
            }
            return {};
        }

        case "content_block_stop": {
            const kind = root.currentBlockKind;
            root.currentBlockKind = "";

            let args = {};
            if (root.jsonBuffer.length > 0) {
                try {
                    args = JSON.parse(root.jsonBuffer);
                } catch (e) {
                    console.log("[AI] Anthropic: bad tool args:", root.jsonBuffer);
                }
            }
            root.jsonBuffer = "";

            // Server-side web search: surface the query as a chip, no local handling
            if (kind === "server_tool_use") {
                root.addSearchQuery(message, args.query ?? "");
                root.toolUseName = "";
                return {};
            }

            // Client-side tool: hand it back to Ai.qml to execute
            if (kind === "tool_use" && root.toolUseName.length > 0) {
                const name = root.toolUseName;
                const id = root.toolUseId;
                const newContent = `\n\n[[ Function: ${name}(${JSON.stringify(args, null, 2)}) ]]\n`;
                message.rawContent += newContent;
                message.content += newContent;
                message.functionName = name;
                message.functionCall = name;
                root.toolUseName = "";
                root.toolUseId = "";
                return { functionCall: { name: name, args: args, id: id } };
            }
            return {};
        }

        case "message_delta":
            root.outputTokens = dataJson.usage?.output_tokens ?? root.outputTokens;
            return {
                tokenUsage: {
                    input: root.inputTokens,
                    output: root.outputTokens,
                    total: (root.inputTokens >= 0 && root.outputTokens >= 0)
                        ? (root.inputTokens + root.outputTokens) : -1
                }
            };

        case "message_stop":
            root.closeThinkBlock(message);
            return { finished: true };

        case "ping":
        default:
            return {};
        }
    }

    function onRequestFinished(message) {
        root.closeThinkBlock(message);
        return {};
    }

    function reset() {
        root.currentBlockKind = "";
        root.toolUseId = "";
        root.toolUseName = "";
        root.jsonBuffer = "";
        root.inputTokens = -1;
        root.outputTokens = -1;
        root.resetRichState();
    }

    // ------------------------------------------------------------------ //
    // Attached files: base64 the file into shell vars, then substitute
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
