import QtQuick;

/**
 * Represents a message in an AI conversation. (Kind of) follows the OpenAI API message structure.
 */
QtObject {
    property string role
    property string content
    property string rawContent
    property string fileMimeType
    property string fileUri
    property string localFilePath
    property string model
    property bool thinking: true
    property bool done: false
    property var annotations: []
    property var annotationSources: []
    property list<string> searchQueries: []
    property string functionName
    property var functionCall
    property string functionResponse
    property bool functionPending: false
    property bool visibleToUser: true

    /**
     * Subagentes que largó esta respuesta, para dibujar el árbol multi-agente.
     *
     * Cada entrada:
     *   { id, name, description, status: "running"|"done"|"error",
     *     tools: [{ name, detail }], toolCount, preview, result,
     *     startedAt, endedAt }
     *
     * Sólo lo llena la estrategia de Claude Code, que es la única que corre
     * agentes de verdad. En los demás modelos queda vacío y no se dibuja nada.
     */
    property var agents: []
}
