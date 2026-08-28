import QtQuick
import qs.modules.common.functions as CF

QtObject {
    function buildEndpoint(model: AiModel): string { throw new Error("Not implemented") }
    function buildRequestData(model: AiModel, messages, systemPrompt: string, temperature: real, tools: list<var>, filePath: string) { throw new Error("Not implemented") }
    function buildAuthorizationHeader(apiKeyEnvVarName: string): string { throw new Error("Not implemented") }
    function parseResponseLine(line: string, message: AiMessageData) { throw new Error("Not implemented") }
    function onRequestFinished(message: AiMessageData): var { return {} } // Default: no special handling
    function reset() { } // Reset any internal state if needed
    // Estado que sobrevive entre requests de la misma charla (por ejemplo el
    // session id de Claude Code para --resume). reset() corre en cada request;
    // esto solo cuando la conversación arranca de cero.
    function resetConversation() { }
    // Cómo se ejecuta el request. Por defecto curl; una estrategia puede
    // devolver cualquier comando de shell que escupa la respuesta por stdout.
    function buildRequestCommand(endpoint: string, headerString: string, authHeader: string, data: var): string {
        return `curl --no-buffer "${endpoint}" ${headerString}`
            + ((authHeader && authHeader.length > 0) ? ` ${authHeader}` : "")
            + ` --data '${CF.StringUtils.shellSingleQuoteEscape(JSON.stringify(data))}'`
            + "\n";
    }

    function buildScriptFileSetup(filePath) { return "" } // Default: no setup
    function finalizeScriptContent(scriptContent: string): string { return scriptContent } // Optionally modify/finalize script
}
