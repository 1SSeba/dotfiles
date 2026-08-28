import QtQuick
import qs.modules.common.functions as CF

/**
 * Talks to the locally installed Claude Code CLI instead of the HTTP API.
 *
 * Why this exists:
 * - Uses your existing `claude` login (subscription), not API credits
 * - Claude can actually DO things: read/edit files, run commands, use your MCP
 *   servers, skills and CLAUDE.md — the whole agent loop, from the sidebar
 *
 * How it works:
 *   claude -p "<prompt>" --output-format stream-json --verbose --include-partial-messages
 * emits newline-delimited JSON. Text arrives inside `stream_event` envelopes that
 * wrap ordinary Anthropic SSE events, which is why this extends AnthropicApiStrategy
 * and reuses its think-block and citation handling.
 *
 * Conversation state lives in Claude Code's own session (via --resume), not in the
 * request body. A new chat in the sidebar starts a new session automatically.
 */
AnthropicApiStrategy {
    id: ccRoot

    property string sessionId: ""
    property bool sawStreamText: false
    property bool showCost: false

    // Lo setea la AiSession que la crea, para que dos pestañas no compartan archivo.
    property string errFile: "/tmp/quickshell/ai/claude-code.err"

    // No HTTP endpoint or auth: this runs a local binary
    function buildEndpoint(model: AiModel): string { return ""; }
    function buildAuthorizationHeader(apiKeyEnvVarName: string): string { return ""; }
    function buildScriptFileSetup(filePath) { return ""; }
    function finalizeScriptContent(scriptContent: string): string { return scriptContent; }

    // ------------------------------------------------------------------ //
    // Request
    // ------------------------------------------------------------------ //

    function buildRequestData(model: AiModel, messages, systemPrompt: string, temperature: real, tools: list<var>, filePath: string) {
        let userCount = 0;
        let lastUser = "";
        for (let i = 0; i < messages.length; i++) {
            if (messages[i].role === "user") {
                userCount++;
                lastUser = messages[i].rawContent ?? "";
            }
        }

        // First user turn of a chat -> drop any previous session so /clear works
        if (userCount <= 1) ccRoot.sessionId = "";

        let prompt = lastUser;
        if (filePath && filePath.length > 0) {
            const p = CF.FileUtils.trimFileProtocol(filePath);
            prompt += `\n\n(Adjunto en disco — leelo con la tool Read: ${p})`;
        }

        ccRoot.showCost = (model.extraParams && model.extraParams.show_cost === true);

        return {
            "prompt": prompt,
            "systemPrompt": systemPrompt,
            "model": model.model,
            "resume": ccRoot.sessionId,
            "options": model.extraParams ?? ({})
        };
    }

    function shellQuote(text) {
        return `'${CF.StringUtils.shellSingleQuoteEscape(String(text ?? ""))}'`;
    }

    function expandHome(path) {
        const p = String(path ?? "");
        if (p.charAt(0) === "~") return "$HOME" + p.slice(1);
        return p;
    }

    /** Replaces the default curl invocation with a `claude -p` invocation. */
    function buildRequestCommand(endpoint: string, headerString: string, authHeader: string, data: var): string {
        const o = data.options ?? ({});
        const bin = o.binary ?? "claude";
        const workdir = ccRoot.expandHome(o.cwd ?? "$HOME");

        let cmd = "";
        cmd += `mkdir -p /tmp/quickshell/ai\n`;
        cmd += `cd "${workdir}" 2>/dev/null || cd "$HOME"\n`;
        cmd += `${bin} -p ${ccRoot.shellQuote(data.prompt)}`
             + ` --output-format stream-json --verbose --include-partial-messages`;

        if (data.model && data.model.length > 0)
            cmd += ` --model ${ccRoot.shellQuote(data.model)}`;
        if (data.resume && data.resume.length > 0)
            cmd += ` --resume ${ccRoot.shellQuote(data.resume)}`;
        // Cuánto piensa antes de responder: low | medium | high | xhigh | max
        if (o.effort)
            cmd += ` --effort ${ccRoot.shellQuote(o.effort)}`;
        if (o.permission_mode)
            cmd += ` --permission-mode ${ccRoot.shellQuote(o.permission_mode)}`;
        if (o.allowed_tools)
            cmd += ` --allowedTools ${ccRoot.shellQuote(o.allowed_tools)}`;
        if (o.add_dir)
            cmd += ` --add-dir ${ccRoot.shellQuote(o.add_dir)}`;
        if (o.extra_args)
            cmd += ` ${o.extra_args}`;
        if (data.systemPrompt && data.systemPrompt.length > 0 && o.append_system_prompt !== false)
            cmd += ` --append-system-prompt ${ccRoot.shellQuote(data.systemPrompt)}`;

        // Keep stderr out of the JSON stream, but report it if the run fails.
        // `< /dev/null` es importante: sin eso el CLI espera 3s por stdin en cada
        // request ("no stdin data received in 3s") y el chat se siente lento.
        cmd += ` < /dev/null 2>${ccRoot.errFile}\n`;
        cmd += `__rc=$?\n`;
        cmd += `if [ $__rc -ne 0 ]; then\n`;
        cmd += `  printf '{"type":"cli_error","code":%s,"text":%s}\\n' "$__rc" "$(jq -Rs . < ${ccRoot.errFile} 2>/dev/null || echo '""')"\n`;
        cmd += `fi\n`;
        return cmd;
    }

    // ------------------------------------------------------------------ //
    // Response
    // ------------------------------------------------------------------ //

    /** Short, readable label for a tool call, e.g.  ⏵ Read  src/main.py */
    function summarizeToolInput(name, input) {
        if (!input) return "";
        const pick = input.file_path ?? input.path ?? input.command
                  ?? input.pattern ?? input.query ?? input.url ?? input.description;
        if (!pick) return "";
        const text = String(pick).replace(/\n+/g, " ");
        return "`" + (text.length > 110 ? text.slice(0, 110) + "…" : text) + "`";
    }

    // ------------------------------------------------------------------ //
    // Subagentes (tool Task)
    //
    // El CLI no manda un evento "arrancó un subagente": manda un tool_use de la
    // tool Task, y despues todo lo que hace ese subagente vuelve con
    // `parent_tool_use_id` apuntando al id de ese tool_use. Con eso alcanza para
    // armar el arbol: el tool_use crea el nodo y el parent_tool_use_id le cuelga
    // la actividad.
    //
    // Esto ademas arregla una contaminacion real: sin mirar parent_tool_use_id,
    // el texto y las tool calls de CADA subagente se iban al mensaje principal
    // mezclados con la respuesta, y no habia forma de saber quien dijo que.
    // ------------------------------------------------------------------ //

    /** Cuántas tool calls se guardan por agente (el resto sólo se cuenta). */
    readonly property int maxToolsPerAgent: 40

    function agentIndexOf(message, agentId) {
        const list = message.agents ?? [];
        for (let i = 0; i < list.length; i++) {
            if (list[i].id === agentId) return i;
        }
        return -1;
    }

    /**
     * Escribe sobre un agente. Reasigna `agents` entero a propósito: mutar el
     * array in-place no notifica a los bindings y el árbol no se redibuja.
     */
    function patchAgent(message, agentId, patch) {
        const index = ccRoot.agentIndexOf(message, agentId);
        if (index < 0) return false;
        const list = (message.agents ?? []).slice();
        list[index] = Object.assign({}, list[index], patch);
        message.agents = list;
        return true;
    }

    /** Nace un subagente: llegó el tool_use de Task. */
    function startAgent(message, block) {
        const input = block.input ?? ({});
        const list = (message.agents ?? []).slice();
        list.push({
            "id": block.id ?? `agent-${list.length}`,
            "name": input.subagent_type ?? "general-purpose",
            "description": String(input.description ?? "").replace(/\n+/g, " ").slice(0, 120),
            "status": "running",
            "tools": [],
            "toolCount": 0,
            "preview": "",
            "result": "",
            "startedAt": Date.now(),
            "endedAt": 0
        });
        message.agents = list;
    }

    /** Una tool call hecha DENTRO de un subagente. */
    function addAgentTool(message, agentId, block) {
        const index = ccRoot.agentIndexOf(message, agentId);
        if (index < 0) return;
        const agent = message.agents[index];
        const tools = agent.tools.slice();
        if (tools.length < ccRoot.maxToolsPerAgent) {
            tools.push({
                "name": block.name ?? "tool",
                "detail": String(ccRoot.summarizeToolInput(block.name, block.input)).replace(/`/g, "")
            });
        }
        ccRoot.patchAgent(message, agentId, {
            "tools": tools,
            "toolCount": agent.toolCount + 1
        });
    }

    /** Lo último que viene diciendo el subagente, para mostrarlo mientras corre. */
    function setAgentPreview(message, agentId, text) {
        const clean = String(text ?? "").replace(/\s+/g, " ").trim();
        if (clean.length === 0) return;
        ccRoot.patchAgent(message, agentId, { "preview": clean.slice(-160) });
    }

    function finishAgent(message, agentId, isError, text) {
        ccRoot.patchAgent(message, agentId, {
            "status": isError ? "error" : "done",
            "result": String(text ?? "").replace(/\s+/g, " ").trim().slice(0, 400),
            "preview": "",
            "endedAt": Date.now()
        });
    }

    /**
     * Cierra lo que haya quedado colgado.
     *
     * Si abortás la corrida o el CLI se corta, el tool_result del Task nunca
     * llega y el agente se quedaría girando para siempre en la UI.
     */
    function closeDanglingAgents(message) {
        const list = message.agents ?? [];
        if (list.length === 0) return;
        let touched = false;
        const next = list.map(agent => {
            if (agent.status !== "running") return agent;
            touched = true;
            return Object.assign({}, agent, { "status": "done", "preview": "", "endedAt": Date.now() });
        });
        if (touched) message.agents = next;
    }

    /** Está corriendo al menos un subagente. */
    function hasRunningAgents(message) {
        return (message.agents ?? []).some(agent => agent.status === "running");
    }

    function parseResponseLine(line, message) {
        const clean = line.trim();
        if (clean.length === 0 || !clean.startsWith("{")) return {};

        let dataJson;
        try {
            dataJson = JSON.parse(clean);
        } catch (e) {
            return {}; // partial line or noise; the CLI re-emits complete objects
        }

        switch (dataJson.type) {

        case "system": {
            if (dataJson.subtype === "init") {
                ccRoot.sessionId = dataJson.session_id ?? "";
                return {};
            }
            if (dataJson.subtype === "api_retry") {
                const note = `\n\n*reintentando (${dataJson.error ?? "error"}) — intento ${dataJson.attempt}/${dataJson.max_retries}*\n`;
                message.content += note;
                message.rawContent += note;
                return {};
            }
            return {};
        }

        // Token-by-token output, wrapping ordinary Anthropic SSE events
        case "stream_event": {
            const ev = dataJson.event;
            if (!ev || ev.type !== "content_block_delta") return {};
            const delta = ev.delta ?? {};

            // Token de un subagente: va a su tarjeta, no a la respuesta.
            //
            // Antes esto caía derecho en message.content y la respuesta salía con
            // el monólogo de cada subagente intercalado, sin decir de quién era.
            const parentId = dataJson.parent_tool_use_id;
            if (parentId) {
                if (delta.type === "text_delta") ccRoot.setAgentPreview(message, parentId, delta.text);
                return {};
            }

            if (delta.type === "text_delta") {
                ccRoot.closeThinkBlock(message);
                message.content += delta.text ?? "";
                message.rawContent += delta.text ?? "";
                ccRoot.sawStreamText = true;
            } else if (delta.type === "thinking_delta") {
                ccRoot.openThinkBlock(message);
                message.content += delta.thinking ?? "";
                message.rawContent += delta.thinking ?? "";
            } else if (delta.type === "citations_delta") {
                const citation = delta.citation ?? {};
                ccRoot.addSource(message, citation.title, citation.url);
            }
            return {};
        }

        // Complete assistant turn: this is where tool calls become visible
        case "assistant": {
            const blocks = dataJson.message?.content ?? [];
            if (!Array.isArray(blocks)) return {};

            // Turno de un subagente: sus tools y su texto van a su tarjeta.
            const parentId = dataJson.parent_tool_use_id;
            if (parentId) {
                blocks.forEach(block => {
                    if (block.type === "tool_use") ccRoot.addAgentTool(message, parentId, block);
                    else if (block.type === "text") ccRoot.setAgentPreview(message, parentId, block.text);
                });
                return {};
            }

            let toolLines = "";
            let plainText = "";
            blocks.forEach(block => {
                if (block.type === "tool_use") {
                    // Task no se dibuja como una línea más de tool: es un agente
                    // entero y se muestra en el árbol, con lo que va haciendo.
                    if (block.name === "Task") {
                        ccRoot.startAgent(message, block);
                        return;
                    }
                    toolLines += `\n\n\`⏵ ${block.name}\` ${ccRoot.summarizeToolInput(block.name, block.input)}\n`;
                } else if (block.type === "text") {
                    plainText += block.text ?? "";
                }
            });

            if (toolLines.length > 0) {
                ccRoot.closeThinkBlock(message);
                message.content += toolLines;
                message.rawContent += toolLines;
            }
            // Fallback for CLI versions without --include-partial-messages
            if (!ccRoot.sawStreamText && plainText.length > 0) {
                message.content += plainText;
                message.rawContent += plainText;
            }
            return {};
        }

        // Tool results: only errors are surfaced, successes would flood the sidebar
        case "user": {
            const blocks = dataJson.message?.content ?? [];
            if (!Array.isArray(blocks)) return {};

            // Un resultado de adentro de un subagente es ruido del subagente, no
            // un error de la respuesta principal: se lo come su tarjeta.
            if (dataJson.parent_tool_use_id) return {};

            let out = "";
            blocks.forEach(block => {
                if (block.type !== "tool_result") return;
                let text = "";
                if (typeof block.content === "string") text = block.content;
                else if (Array.isArray(block.content)) text = block.content.map(c => c.text ?? "").join("");

                // ¿Es el cierre de un Task? Entonces termina un agente y no se
                // escribe nada en el chat: el árbol ya lo muestra.
                if (ccRoot.agentIndexOf(message, block.tool_use_id) >= 0) {
                    ccRoot.finishAgent(message, block.tool_use_id, block.is_error === true, text);
                    return;
                }
                if (!block.is_error) return;
                out += `\n\n\`⚠ ${String(text).replace(/\n+/g, " ").slice(0, 240)}\`\n`;
            });
            if (out.length > 0) {
                message.content += out;
                message.rawContent += out;
            }
            return {};
        }

        case "result": {
            ccRoot.closeThinkBlock(message);
            ccRoot.closeDanglingAgents(message);
            if (dataJson.session_id) ccRoot.sessionId = dataJson.session_id;

            // Safety net: if nothing rendered, fall back to the final text
            if (message.content.trim().length === 0 && dataJson.result) {
                message.content += dataJson.result;
                message.rawContent += dataJson.result;
            }
            if (dataJson.is_error) {
                const errorMsg = `\n\n**Error**: ${dataJson.result ?? "la corrida falló"}`;
                message.content += errorMsg;
                message.rawContent += errorMsg;
            }
            if (dataJson.total_cost_usd !== undefined && ccRoot.showCost) {
                const costMsg = `\n\n<sub>~US$${Number(dataJson.total_cost_usd).toFixed(4)} · ${dataJson.num_turns ?? "?"} turnos</sub>`;
                message.content += costMsg;
                message.rawContent += costMsg;
            }

            const usage = dataJson.usage ?? {};
            const inputTokens = usage.input_tokens ?? -1;
            const outputTokens = usage.output_tokens ?? -1;
            return {
                finished: true,
                tokenUsage: {
                    input: inputTokens,
                    output: outputTokens,
                    total: (inputTokens >= 0 && outputTokens >= 0) ? (inputTokens + outputTokens) : -1
                }
            };
        }

        case "cli_error": {
            const detail = String(dataJson.text ?? "").slice(0, 600);
            const errorMsg = `\n\n**No se pudo ejecutar \`claude\`** (código ${dataJson.code}).\n\n`
                + "```\n" + detail + "\n```\n\n"
                + "Revisá que Claude Code esté instalado y logueado:\n\n"
                + "```bash\nclaude --version\nclaude -p \"hola\"\n```\n";
            message.content += errorMsg;
            message.rawContent += errorMsg;
            return { finished: true };
        }

        default:
            return {};
        }
    }

    function onRequestFinished(message) {
        ccRoot.closeThinkBlock(message);
        ccRoot.closeDanglingAgents(message);
        return {};
    }

    /** Charla nueva: se olvida la sesión del CLI, así --resume no arrastra la anterior. */
    function resetConversation() {
        ccRoot.sessionId = "";
    }

    /** Note: sessionId deliberately survives reset() so --resume keeps working. */
    function reset() {
        ccRoot.isReasoning = false;
        ccRoot.currentBlockKind = "";
        ccRoot.jsonBuffer = "";
        ccRoot.collectedSources = [];
        ccRoot.collectedQueries = [];
        ccRoot.sawStreamText = false;
    }
}
