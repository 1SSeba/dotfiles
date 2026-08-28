import QtQuick

/**
 * Base compartida para las estrategias "ricas": las que renderizan bloques de
 * pensamiento y alimentan los chips de fuentes / búsquedas de la sidebar.
 *
 * No sabe nada de ninguna API en particular — solo maneja el estado que las
 * tres (Anthropic, Claude Code, OpenAI nativo) necesitan por igual.
 */
ApiStrategy {
    id: richRoot

    property bool isReasoning: false
    property var collectedSources: []
    property var collectedQueries: []

    /** Abre un bloque <think> si no hay uno abierto. */
    function openThinkBlock(message) {
        if (richRoot.isReasoning) return;
        richRoot.isReasoning = true;
        const startBlock = "\n\n<think>\n\n";
        message.rawContent += startBlock;
        message.content += startBlock;
    }

    /** Cierra el bloque <think> si hay uno abierto. */
    function closeThinkBlock(message) {
        if (!richRoot.isReasoning) return;
        richRoot.isReasoning = false;
        const endBlock = "\n\n</think>\n\n";
        message.rawContent += endBlock;
        message.content += endBlock;
    }

    /** Agrega un chip de fuente debajo del mensaje, deduplicado por URL. */
    function addSource(message, title, url) {
        if (!url || url.length === 0) return;
        for (let i = 0; i < richRoot.collectedSources.length; i++) {
            if (richRoot.collectedSources[i].url === url) return;
        }
        richRoot.collectedSources = [...richRoot.collectedSources, {
            "type": "url_citation",
            "text": (title && title.length > 0) ? title : url,
            "url": url
        }];
        message.annotationSources = richRoot.collectedSources;
    }

    /** Agrega un chip de búsqueda, deduplicado. */
    function addSearchQuery(message, query) {
        if (!query || query.length === 0) return;
        if (richRoot.collectedQueries.indexOf(query) !== -1) return;
        richRoot.collectedQueries = [...richRoot.collectedQueries, query];
        message.searchQueries = richRoot.collectedQueries;
    }

    /** Saca los bloques <think> y los marcadores de tool antes de reenviar historial. */
    function cleanHistoryText(text) {
        if (!text) return "";
        return String(text).replace(/<think>[\s\S]*?<\/think>/g, "")
                           .replace(/\[\[ Function:[\s\S]*?\]\]/g, "")
                           .replace(/`⏵ [\s\S]*?`\n/g, "")
                           .trim();
    }

    /** Estado común a limpiar entre requests. */
    function resetRichState() {
        richRoot.isReasoning = false;
        richRoot.collectedSources = [];
        richRoot.collectedQueries = [];
    }

    function onRequestFinished(message) {
        richRoot.closeThinkBlock(message);
        return {};
    }

    function reset() {
        richRoot.resetRichState();
    }
}
