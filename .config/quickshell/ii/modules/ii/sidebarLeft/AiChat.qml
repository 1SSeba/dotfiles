import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.ii.sidebarLeft.aiChat
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io

Item {
    id: root
    property real padding: 4
    /** Está abierta la barra de historial (la dibuja la ventana del sidebar). */
    readonly property bool historyOpen: GlobalStates.aiHistoryOpen
    function toggleHistory() { GlobalStates.aiHistoryOpen = !GlobalStates.aiHistoryOpen; }

    // Los tres niveles de densidad del chat. Los valores de "normal" son los que
    // estaban hardcodeados, así que sin tocar la config se ve exactamente igual.
    readonly property var densityPresets: ({
        "compact":     { "messageSpacing": 4,  "messagePadding": 4,  "contentSpacing": 1 },
        "normal":      { "messageSpacing": 10, "messagePadding": 7,  "contentSpacing": 3 },
        "comfortable": { "messageSpacing": 16, "messagePadding": 11, "contentSpacing": 6 }
    })
    readonly property var density: root.densityPresets[Config.options.sidebar.ai.density] ?? root.densityPresets["normal"]
    property var inputField: messageInputField
    property string commandPrefix: "/"

    property var suggestionQuery: ""
    property var suggestionList: []

    /** Qué panel de opciones está desplegado: "" | "model" | "effort" | "tool". */
    property string openPicker: ""
    readonly property var toolIcons: ({
        "functions": "construction",
        "search": "travel_explore",
        "none": "block"
    })
    readonly property var effortIcons: ({
        "low": "battery_1_bar",
        "medium": "battery_3_bar",
        "high": "battery_5_bar",
        "xhigh": "battery_full",
        "max": "bolt"
    })

    onFocusChanged: focus => {
        if (focus) {
            root.inputField.forceActiveFocus();
        }
    }

    Keys.onPressed: event => {
        messageInputField.forceActiveFocus();
        if (event.modifiers === Qt.NoModifier) {
            if (event.key === Qt.Key_PageUp) {
                messageListView.contentY = Math.max(0, messageListView.contentY - messageListView.height / 2);
                event.accepted = true;
            } else if (event.key === Qt.Key_PageDown) {
                messageListView.contentY = Math.min(messageListView.contentHeight - messageListView.height / 2, messageListView.contentY + messageListView.height / 2);
                event.accepted = true;
            }
        }
        if ((event.modifiers & Qt.ControlModifier) && (event.modifiers & Qt.ShiftModifier) && event.key === Qt.Key_O) {
            Ai.clearMessages();
        }
        // Pestañas: nueva, cerrar, e ir a la N
        if (event.modifiers === Qt.ControlModifier && event.key === Qt.Key_T) {
            Ai.newSession();
            event.accepted = true;
        } else if (event.modifiers === Qt.ControlModifier && event.key === Qt.Key_H) {
            // El historial también por teclado: el botón de la barra tiene un
            // problema de puntero sin resolver, y sin esto la función queda
            // inalcanzable.
            root.toggleHistory();
            event.accepted = true;
        } else if (event.modifiers === Qt.ControlModifier && event.key === Qt.Key_W) {
            Ai.closeSession(Ai.activeIndex);
            event.accepted = true;
        } else if (event.modifiers === Qt.AltModifier && event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
            Ai.setActiveIndex(event.key - Qt.Key_1);
            event.accepted = true;
        }
    }

    /**
     * El texto sin enviar vive en la sesión, así que cambiar de pestaña no lo pierde.
     * `syncingDraft` corta el ida y vuelta entre este binding y el onTextChanged del input.
     */
    property bool syncingDraft: false

    Connections {
        target: Ai
        function onActiveChanged() {
            root.syncingDraft = true;
            messageInputField.text = Ai.active?.draft ?? "";
            root.syncingDraft = false;
            messageInputField.cursorPosition = messageInputField.text.length;
        }
    }

    property var allCommands: [
        {
            name: "attach",
            description: Translation.tr("Attach a file (Gemini, Claude, OpenAI, Mistral)."),
            execute: args => {
                Ai.attachFile(args.join(" ").trim());
            }
        },
        {
            name: "model",
            description: Translation.tr("Choose model"),
            execute: args => {
                Ai.setModel(args[0]);
            }
        },
        {
            name: "effort",
            description: Translation.tr("Cuánto piensa Claude Code: low|medium|high|xhigh|max"),
            execute: args => {
                if (args.length === 0 || args[0] === "get") {
                    Ai.addMessage(Translation.tr("Esfuerzo actual: **%1**\n\nOpciones: %2, o `default`")
                        .arg(Ai.effort.length > 0 ? Ai.effort : "default")
                        .arg(Ai.effortLevels.join(", ")), Ai.interfaceRole);
                    return;
                }
                Ai.setEffort(args[0]);
            }
        },
        {
            name: "tab",
            description: Translation.tr("Pestañas: new [AGENTE] | close | list"),
            execute: args => {
                const sub = (args[0] ?? "").trim().toLowerCase();
                if (sub === "close") {
                    Ai.closeSession(Ai.activeIndex);
                } else if (sub === "list") {
                    const list = Ai.sessions.map((session, i) =>
                        `${i + 1}. ${session.title}${i === Ai.activeIndex ? " ←" : ""}`).join("\n");
                    Ai.addMessage(Translation.tr("Pestañas abiertas:\n\n%1").arg(list), Ai.interfaceRole);
                } else if (sub === "new" || sub.length === 0) {
                    Ai.newSession(args.slice(1).join(" ").trim());
                } else {
                    Ai.addMessage(Translation.tr("Usage: %1tab new [AGENTE] | close | list").arg(root.commandPrefix), Ai.interfaceRole);
                }
            }
        },
        {
            name: "agent",
            description: Translation.tr("Cambiar el agente de esta pestaña"),
            execute: args => {
                const name = args.join(" ").trim();
                const agents = Config.options?.ai?.agents ?? [];
                if (name.length === 0) {
                    const list = agents.map(agent => `- \`${agent.id}\` — ${agent.name ?? agent.id}`).join("\n");
                    Ai.addMessage(Translation.tr("Agente actual: **%1**\n\nDisponibles:\n%2")
                        .arg(Ai.active?.title ?? "?").arg(list), Ai.interfaceRole);
                    return;
                }
                if (!Ai.agentById(name)) {
                    Ai.addMessage(Translation.tr("No existe el agente `%1`. Usá %2agent para ver la lista.")
                        .arg(name).arg(root.commandPrefix), Ai.interfaceRole);
                    return;
                }
                Ai.applyAgent(Ai.active, name);
                Ai.persistSessions();
                Ai.addMessage(Translation.tr("Agente cambiado a **%1**").arg(Ai.active?.title ?? name), Ai.interfaceRole);
            }
        },
        {
            name: "tool",
            description: Translation.tr("Set the tool to use for the model."),
            execute: args => {
                // console.log(args)
                if (args.length == 0 || args[0] == "get") {
                    Ai.addMessage(Translation.tr("Usage: %1tool TOOL_NAME").arg(root.commandPrefix), Ai.interfaceRole);
                } else {
                    const tool = args[0];
                    const switched = Ai.setTool(tool);
                    if (switched) {
                        Ai.addMessage(Translation.tr("Tool set to: %1").arg(tool), Ai.interfaceRole);
                    }
                }
            }
        },
        {
            name: "prompt",
            description: Translation.tr("Set the system prompt for the model."),
            execute: args => {
                if (args.length === 0 || args[0] === "get") {
                    Ai.printPrompt();
                    return;
                }
                Ai.loadPrompt(args.join(" ").trim());
            }
        },
        {
            name: "setup",
            description: Translation.tr("Estado de proveedores y API keys"),
            execute: args => {
                Ai.setupCommand(args);
            }
        },
        {
            name: "key",
            description: Translation.tr("Set API key"),
            execute: args => {
                if (args[0] == "get") {
                    Ai.printApiKey();
                } else {
                    Ai.setApiKey(args[0]);
                }
            }
        },
        {
            name: "save",
            description: Translation.tr("Save chat"),
            execute: args => {
                const joinedArgs = args.join(" ");
                if (joinedArgs.trim().length == 0) {
                    Ai.addMessage(Translation.tr("Usage: %1save CHAT_NAME").arg(root.commandPrefix), Ai.interfaceRole);
                    return;
                }
                Ai.saveChat(joinedArgs);
            }
        },
        {
            name: "load",
            description: Translation.tr("Load chat"),
            execute: args => {
                const joinedArgs = args.join(" ");
                if (joinedArgs.trim().length == 0) {
                    Ai.addMessage(Translation.tr("Usage: %1load CHAT_NAME").arg(root.commandPrefix), Ai.interfaceRole);
                    return;
                }
                Ai.loadChat(joinedArgs);
            }
        },
        {
            name: "clear",
            description: Translation.tr("Clear chat history"),
            execute: () => {
                Ai.clearMessages();
            }
        },
        {
            name: "temp",
            description: Translation.tr("Set temperature (randomness) of the model. Values range between 0 to 2 for Gemini, 0 to 1 for other models. Default is 0.5."),
            execute: args => {
                // console.log(args)
                if (args.length == 0 || args[0] == "get") {
                    Ai.printTemperature();
                } else {
                    const temp = parseFloat(args[0]);
                    Ai.setTemperature(temp);
                }
            }
        },
        {
            name: "test",
            description: Translation.tr("Markdown test"),
            execute: () => {
                Ai.addMessage(`
<think>
A longer think block to test revealing animation
OwO wem ipsum dowo sit amet, consekituwet awipiscing ewit, sed do eiuwsmod tempow inwididunt ut wabowe et dowo mawa. Ut enim ad minim weniam, quis nostwud exeucitation uwuwamcow bowowis nisi ut awiquip ex ea commowo consequat. Duuis aute iwuwe dowo in wepwependewit in wowuptate velit esse ciwwum dowo eu fugiat nuwa pawiatuw. Excepteuw sint occaecat cupidatat non pwowoident, sunt in cuwpa qui officia desewunt mowit anim id est wabowum. Meouw! >w<
Mowe uwu wem ipsum!
</think>
## ✏️ Markdown test
### Formatting

- *Italic*, \`Monospace\`, **Bold**, [Link](https://example.com)
- Arch lincox icon <img src="${Quickshell.shellPath("assets/icons/arch-symbolic.svg")}" height="${Appearance.font.pixelSize.small}"/>

### Table

Quickshell vs AGS/Astal

|                          | Quickshell       | AGS/Astal         |
|--------------------------|------------------|-------------------|
| UI Toolkit               | Qt               | Gtk3/Gtk4         |
| Language                 | QML              | Js/Ts/Lua         |
| Reactivity               | Implied          | Needs declaration |
| Widget placement         | Mildly difficult | More intuitive    |
| Bluetooth & Wifi support | ❌               | ✅                |
| No-delay keybinds        | ✅               | ❌                |
| Development              | New APIs         | New syntax        |

### Code block

Just a hello world...

\`\`\`cpp
#include <bits/stdc++.h>
// This is intentionally very long to test scrolling
const std::string GREETING = \"UwU\";
int main(int argc, char* argv[]) {
    std::cout << GREETING;
}
\`\`\`

### LaTeX


Inline w/ dollar signs: $\\frac{1}{2} = \\frac{2}{4}$

Inline w/ double dollar signs: $$\\int_0^\\infty e^{-x^2} dx = \\frac{\\sqrt{\\pi}}{2}$$

Inline w/ backslash and square brackets \\[\\int_0^\\infty \\frac{1}{x^2} dx = \\infty\\]

Inline w/ backslash and round brackets \\(e^{i\\pi} + 1 = 0\\)
`, Ai.interfaceRole);
            }
        },
    ]

    function handleInput(inputText) {
        if (inputText.startsWith(root.commandPrefix)) {
            // Handle special commands
            const command = inputText.split(" ")[0].substring(1);
            const args = inputText.split(" ").slice(1);
            const commandObj = root.allCommands.find(cmd => cmd.name === `${command}`);
            if (commandObj) {
                commandObj.execute(args);
            } else {
                Ai.addMessage(Translation.tr("Unknown command: ") + command, Ai.interfaceRole);
            }
        } else {
            Ai.sendUserMessage(inputText);
        }

        // Al mandar un mensaje volvemos al final y nos quedamos pegados ahí,
        // así la respuesta que va llegando se sigue sola. Se suelta apenas
        // scrolleás para leer algo de más arriba.
        messageListView.goToEnd();
    }

    Process {
        id: decodeImageAndAttachProc
        property string imageDecodePath: Directories.cliphistDecode
        property string imageDecodeFileName: "image"
        property string imageDecodeFilePath: `${imageDecodePath}/${imageDecodeFileName}`
        function handleEntry(entry: string) {
            imageDecodeFileName = parseInt(entry.match(/^(\d+)\t/)[1]);
            decodeImageAndAttachProc.exec(["bash", "-c", `[ -f ${imageDecodeFilePath} ] || echo '${StringUtils.shellSingleQuoteEscape(entry)}' | ${Cliphist.cliphistBinary} decode > '${imageDecodeFilePath}'`]);
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                Ai.attachFile(imageDecodeFilePath);
            } else {
                console.error("[AiChat] Failed to decode image in clipboard content");
            }
        }
    }

    component StatusItem: MouseArea {
        id: statusItem
        property string icon
        property string statusText
        property string description
        hoverEnabled: true
        implicitHeight: statusItemRowLayout.implicitHeight
        implicitWidth: statusItemRowLayout.implicitWidth

        RowLayout {
            id: statusItemRowLayout
            spacing: 0
            MaterialSymbol {
                text: statusItem.icon
                iconSize: Appearance.font.pixelSize.huge
                color: Appearance.colors.colSubtext
            }
            StyledText {
                font.pixelSize: Appearance.font.pixelSize.small
                text: statusItem.statusText
                color: Appearance.colors.colSubtext
                animateChange: true
            }
        }

        StyledToolTip {
            text: statusItem.description
            extraVisibleCondition: false
            alternativeVisibleCondition: statusItem.containsMouse
        }
    }

    component StatusSeparator: Rectangle {
        implicitWidth: 4
        implicitHeight: 4
        radius: implicitWidth / 2
        color: Appearance.colors.colOutlineVariant
    }

    ColumnLayout {
        id: columnLayout
        anchors {
            fill: parent
            margins: root.padding
        }
        spacing: root.padding

        AiTabBar {
            Layout.fillWidth: true
            visible: Config.options.sidebar.ai.showTabBar
            historyOpen: root.historyOpen
            onHistoryToggled: root.toggleHistory()
        }

        Rectangle {
            // Barra de estado: fila real del layout, no algo flotando encima.
            //
            // Antes se anclaba sobre la lista y se compensaba con un topMargin
            // en la ListView. Eso se rompía de dos formas: el texto de los
            // mensajes pasaba por atrás (se leía partido, mitad arriba y mitad
            // abajo de la barra), y el topMargin le mentía a atYEnd/atYBeginning,
            // que es de donde salía el "no queda centrada". Acá adentro del
            // ColumnLayout ocupa su propio renglón y nada se le mete debajo.
            id: statusBg
            Layout.fillWidth: true
            visible: Config.options.sidebar.ai.showStatusBar
            implicitHeight: Math.max(statusRowLayout.implicitHeight + 10, 34)
            radius: Appearance.rounding.small
            color: Appearance.colors.colLayer2

            RowLayout {
                id: statusRowLayout
                anchors.centerIn: parent
                spacing: 10

                StatusItem {
                    icon: Ai.currentModelHasApiKey ? "key" : "key_off"
                    statusText: ""
                    description: Ai.currentModelHasApiKey ? Translation.tr("API key is set\nChange with /setup PROVIDER KEY") : Translation.tr("No API key\nSet it with /setup PROVIDER KEY")
                }
                StatusSeparator {}
                StatusItem {
                    icon: "device_thermostat"
                    statusText: Ai.temperature.toFixed(1)
                    description: Translation.tr("Temperature\nChange with /temp VALUE")
                }
                StatusSeparator {
                    visible: Ai.tokenCount.total > 0
                }
                StatusItem {
                    visible: Ai.tokenCount.total > 0
                    icon: "token"
                    statusText: Ai.tokenCount.total
                    description: Translation.tr("Total token count\nInput: %1\nOutput: %2").arg(Ai.tokenCount.input).arg(Ai.tokenCount.output)
                }
            }
        }

        Item {
            // Messages
            Layout.fillWidth: true
            Layout.fillHeight: true
            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: swipeView.width
                    height: swipeView.height
                    radius: Appearance.rounding.small
                }
            }

            ScrollEdgeFade {
                z: 1
                target: messageListView
                vertical: true
            }

            StyledListView { // Message list
                id: messageListView
                z: 0
                anchors.fill: parent
                spacing: root.density.messageSpacing
                popin: false

                touchpadScrollFactor: Config.options.interactions.scrolling.touchpadScrollFactor * 1.4
                mouseScrollFactor: Config.options.interactions.scrolling.mouseScrollFactor * 1.4

                property int lastResponseLength: 0

                // Al abrir (o reabrir) el sidebar queremos ver el mensaje más
                // nuevo, no el principio de la conversación.
                //
                // El modelo es "pegado al final hasta que scrolleás vos": nos
                // quedamos siguiendo el fondo mientras el contenido se sigue
                // midiendo (el markdown del último mensaje —tablas, bloques de
                // código, los "Pensamiento" plegables— se arma en varias tandas
                // y estira la altura bastante después), y soltamos apenas movés
                // el scroll.
                //
                // Antes esto era un Timer que reposicionaba cada 16 ms durante
                // unos segundos, y era peor que el problema: la rueda del mouse
                // no dispara dragging ni flicking, así que el timer no se
                // enteraba de que estabas scrolleando y te arrancaba de donde
                // estabas. De ahí la señal userScrolled del StyledListView.
                property bool stickToEnd: false

                onUserScrolled: messageListView.stickToEnd = false


                onContentHeightChanged: if (messageListView.stickToEnd) snapDebounce.restart()
                onHeightChanged: if (messageListView.stickToEnd) snapDebounce.restart()
                onCountChanged: if (messageListView.stickToEnd) snapDebounce.restart()

                Timer {
                    id: snapDebounce
                    interval: 400
                    repeat: false
                    onTriggered: {
                        if (!messageListView.stickToEnd) return;
                        // Con height 0 el "final" no significa nada, y hay que
                        // REINTENTAR en vez de rendirse: al reabrir el sidebar el
                        // contenido ya está medido de antes, así que no viene
                        // ningún cambio de altura atrás que vuelva a disparar esto.
                        if (messageListView.height <= 0 || messageListView.count === 0) {
                            // Sin reintentar acá: cuando el sidebar se abre,
                            // height pasa de 0 al valor real y onHeightChanged
                            // vuelve a disparar este timer. Reintentar a ciegas
                            // dejaba un tick cada 400 ms para siempre con el
                            // sidebar cerrado.
                            return;
                        }

                        // Un solo salto, y recién cuando la lista se quedó quieta.
                        //
                        // Reintentar es lo que rompe esto, no lo que lo arregla.
                        // Cada reposicionamiento tira y rehace delegates, y con
                        // alturas tan dispares (de 10 mensajes viven 2, y uno
                        // solo mide 2372 px) la ListView corre el originY 4985 px
                        // por vuelta. Midiéndolo: con reintentos, después de 20
                        // saltos contentY estaba en 115121 y el delegate del
                        // último mensaje directamente no existía. Llamando una
                        // sola vez con la lista asentada, el viewport termina
                        // exactamente en el fin del último mensaje.
                        //
                        // Por eso el intervalo es largo y el timer se reinicia con
                        // cada cambio de altura: no es un reintento, es esperar a
                        // que el markdown (tablas, bloques de código, los
                        // "Pensamiento" plegables) termine de armarse.
                        messageListView.snapToEnd();
                    }
                }

                function goToEnd() {
                    messageListView.stickToEnd = true;
                    snapDebounce.restart();
                }

                Component.onCompleted: messageListView.goToEnd()
                onVisibleChanged: if (messageListView.visible) messageListView.goToEnd()

                // El sidebar es una capa que se oculta entera, así que al
                // reabrirlo `visible` no siempre cambia. Esta es la señal fiable.
                Connections {
                    target: GlobalStates
                    function onSidebarLeftOpenChanged() {
                        if (GlobalStates.sidebarLeftOpen) messageListView.goToEnd();
                    }
                }

                add: null // Prevent function calls from being janky

                model: ScriptModel {
                    values: Ai.messageIDs.filter(id => {
                        const message = Ai.messageByID[id];
                        return message?.visibleToUser ?? true;
                    })
                }
                delegate: AiMessage {
                    required property var modelData
                    required property int index
                    messagePadding: root.density.messagePadding
                    contentSpacing: root.density.contentSpacing
                    messageIndex: index
                    messageData: {
                        Ai.messageByID[modelData];
                    }
                    messageInputField: root.inputField
                }
            }

            PagePlaceholder {
                z: 2
                shown: Ai.messageIDs.length === 0
                icon: "neurology"
                title: Translation.tr("Large language models")
                description: Translation.tr("Type /setup to see providers and set API keys\nCtrl+O to expand sidebar\nCtrl+P to pin sidebar\nCtrl+D to detach sidebar")
                shape: MaterialShape.Shape.PixelCircle
            }

            ScrollToBottomButton {
                z: 3
                target: messageListView
            }
        }

        DescriptionBox {
            text: root.suggestionList[suggestions.selectedIndex]?.description ?? ""
            showArrows: root.suggestionList.length > 1
        }

        FlowButtonGroup { // Suggestions
            id: suggestions
            visible: root.suggestionList.length > 0 && messageInputField.text.length > 0
            property int selectedIndex: 0
            Layout.fillWidth: true
            spacing: 5

            Repeater {
                id: suggestionRepeater
                model: {
                    suggestions.selectedIndex = 0;
                    return root.suggestionList.slice(0, 10);
                }
                delegate: ApiCommandButton {
                    id: commandButton
                    colBackground: suggestions.selectedIndex === index ? Appearance.colors.colSecondaryContainerHover : Appearance.colors.colSecondaryContainer
                    bounce: false
                    contentItem: StyledText {
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.m3colors.m3onSurface
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData.displayName ?? modelData.name
                    }

                    onHoveredChanged: {
                        if (commandButton.hovered) {
                            suggestions.selectedIndex = index;
                        }
                    }
                    onClicked: {
                        suggestions.acceptSuggestion(modelData.name);
                    }
                }
            }

            function acceptSuggestion(word) {
                const words = messageInputField.text.trim().split(/\s+/);
                if (words.length > 0) {
                    words[words.length - 1] = word;
                } else {
                    words.push(word);
                }
                const updatedText = words.join(" ") + " ";
                messageInputField.text = updatedText;
                messageInputField.cursorPosition = messageInputField.text.length;
                messageInputField.forceActiveFocus();
            }

            function acceptSelectedWord() {
                if (suggestions.selectedIndex >= 0 && suggestions.selectedIndex < suggestionRepeater.count) {
                    const word = root.suggestionList[suggestions.selectedIndex].name;
                    suggestions.acceptSuggestion(word);
                }
            }
        }

        AiOptionPicker { // Modelo
            Layout.fillWidth: true
            open: root.openPicker === "model"
            options: Ai.modelList.map(id => ({
                "key": id,
                "label": Ai.models[id]?.name ?? id,
                "customIcon": Ai.models[id]?.icon ?? "",
                "selected": id === Ai.currentModelId
            }))
            onPicked: key => {
                Ai.setModel(key, false);
                root.openPicker = "";
            }
        }

        AiOptionPicker { // Esfuerzo de Claude Code
            Layout.fillWidth: true
            open: root.openPicker === "effort"
            options: [
                {
                    "key": "",
                    "label": Translation.tr("Default"),
                    "icon": "settings_suggest",
                    "selected": Ai.effort.length === 0
                },
                ...Ai.effortLevels.map(level => ({
                    "key": level,
                    "label": level,
                    "icon": root.effortIcons[level] ?? "bolt",
                    "selected": level === Ai.effort
                }))
            ]
            onPicked: key => {
                Ai.setEffort(key.length === 0 ? "default" : key);
                root.openPicker = "";
            }
        }

        AiOptionPicker { // Herramientas
            Layout.fillWidth: true
            open: root.openPicker === "tool"
            options: Ai.availableTools.map(tool => ({
                "key": tool,
                "label": tool.charAt(0).toUpperCase() + tool.slice(1),
                "icon": root.toolIcons[tool] ?? "service_toolbox",
                "tooltip": Ai.toolDescriptions[tool] ?? "",
                "selected": tool === Ai.currentTool
            }))
            onPicked: key => {
                Ai.setTool(key);
                root.openPicker = "";
            }
        }

        Rectangle { // Input area
            id: inputWrapper
            property real spacing: 5
            Layout.fillWidth: true
            radius: Appearance.rounding.normal - root.padding
            color: Appearance.colors.colLayer2
            implicitHeight: Math.max(inputFieldRowLayout.implicitHeight + inputFieldRowLayout.anchors.topMargin + commandButtonsRow.implicitHeight + commandButtonsRow.anchors.bottomMargin + spacing, 45) + (attachedFileIndicator.implicitHeight + spacing + attachedFileIndicator.anchors.topMargin)
            clip: true

            Behavior on implicitHeight {
                animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
            }

            AttachedFileIndicator {
                id: attachedFileIndicator
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    margins: visible ? 5 : 0
                }
                filePath: Ai.pendingFilePath
                onRemove: Ai.attachFile("")
            }

            RowLayout { // Input field and send button
                id: inputFieldRowLayout
                anchors {
                    bottom: commandButtonsRow.top
                    left: parent.left
                    right: parent.right
                    bottomMargin: 5
                }
                spacing: 0

                ScrollView {
                    id: inputScrollView
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(root.height * 3/5, messageInputField.height)
                    clip: true
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded

                    StyledTextArea { // The actual TextArea (inside ScrollView to enable scrolling)
                        id: messageInputField
                        anchors.fill: parent
                        wrapMode: TextArea.Wrap
                        padding: 10
                        color: activeFocus ? Appearance.m3colors.m3onSurface : Appearance.m3colors.m3onSurfaceVariant
                        placeholderText: Translation.tr('Message the model... "%1" for commands').arg(root.commandPrefix)

                        background: null

                        onTextChanged: {
                            // Guardar el borrador en la pestaña actual
                            if (!root.syncingDraft && Ai.active) Ai.active.draft = messageInputField.text;
                            // Handle suggestions
                            if (messageInputField.text.length === 0) {
                                root.suggestionQuery = "";
                                root.suggestionList = [];
                                return;
                            } else if (messageInputField.text.startsWith(`${root.commandPrefix}model`)) {
                                root.suggestionQuery = messageInputField.text.split(" ")[1] ?? "";
                                const modelResults = Fuzzy.go(root.suggestionQuery, Ai.modelList.map(model => {
                                    return {
                                        name: Fuzzy.prepare(model),
                                        obj: model
                                    };
                                }), {
                                    all: true,
                                    key: "name"
                                });
                                root.suggestionList = modelResults.map(model => {
                                    return {
                                        name: `${messageInputField.text.trim().split(" ").length == 1 ? (root.commandPrefix + "model ") : ""}${model.target}`,
                                        displayName: `${Ai.models[model.target].name}`,
                                        description: `${Ai.models[model.target].description}`
                                    };
                                });
                            } else if (messageInputField.text.startsWith(`${root.commandPrefix}prompt`)) {
                                root.suggestionQuery = messageInputField.text.split(" ")[1] ?? "";
                                const promptFileResults = Fuzzy.go(root.suggestionQuery, Ai.promptFiles.map(file => {
                                    return {
                                        name: Fuzzy.prepare(file),
                                        obj: file
                                    };
                                }), {
                                    all: true,
                                    key: "name"
                                });
                                root.suggestionList = promptFileResults.map(file => {
                                    return {
                                        name: `${messageInputField.text.trim().split(" ").length == 1 ? (root.commandPrefix + "prompt ") : ""}${file.target}`,
                                        displayName: `${FileUtils.trimFileExt(FileUtils.fileNameForPath(file.target))}`,
                                        description: Translation.tr("Load prompt from %1").arg(file.target)
                                    };
                                });
                            } else if (messageInputField.text.startsWith(`${root.commandPrefix}save`)) {
                                root.suggestionQuery = messageInputField.text.split(" ")[1] ?? "";
                                const promptFileResults = Fuzzy.go(root.suggestionQuery, Ai.savedChats.map(file => {
                                    return {
                                        name: Fuzzy.prepare(file),
                                        obj: file
                                    };
                                }), {
                                    all: true,
                                    key: "name"
                                });
                                root.suggestionList = promptFileResults.map(file => {
                                    const chatName = FileUtils.trimFileExt(FileUtils.fileNameForPath(file.target)).trim();
                                    return {
                                        name: `${messageInputField.text.trim().split(" ").length == 1 ? (root.commandPrefix + "save ") : ""}${chatName}`,
                                        displayName: `${chatName}`,
                                        description: Translation.tr("Save chat to %1").arg(chatName)
                                    };
                                });
                            } else if (messageInputField.text.startsWith(`${root.commandPrefix}load`)) {
                                root.suggestionQuery = messageInputField.text.split(" ")[1] ?? "";
                                const promptFileResults = Fuzzy.go(root.suggestionQuery, Ai.savedChats.map(file => {
                                    return {
                                        name: Fuzzy.prepare(file),
                                        obj: file
                                    };
                                }), {
                                    all: true,
                                    key: "name"
                                });
                                root.suggestionList = promptFileResults.map(file => {
                                    const chatName = FileUtils.trimFileExt(FileUtils.fileNameForPath(file.target)).trim();
                                    return {
                                        name: `${messageInputField.text.trim().split(" ").length == 1 ? (root.commandPrefix + "load ") : ""}${chatName}`,
                                        displayName: `${chatName}`,
                                        description: Translation.tr(`Load chat from %1`).arg(file.target)
                                    };
                                });
                            } else if (messageInputField.text.startsWith(`${root.commandPrefix}tool`)) {
                                root.suggestionQuery = messageInputField.text.split(" ")[1] ?? "";
                                const toolResults = Fuzzy.go(root.suggestionQuery, Ai.availableTools.map(tool => {
                                    return {
                                        name: Fuzzy.prepare(tool),
                                        obj: tool
                                    };
                                }), {
                                    all: true,
                                    key: "name"
                                });
                                root.suggestionList = toolResults.map(tool => {
                                    const toolName = tool.target;
                                    return {
                                        name: `${messageInputField.text.trim().split(" ").length == 1 ? (root.commandPrefix + "tool ") : ""}${tool.target}`,
                                        displayName: toolName,
                                        description: Ai.toolDescriptions[toolName]
                                    };
                                });
                            } else if (messageInputField.text.startsWith(`${root.commandPrefix}setup`)) {
                                // /setup [provider|get|login] [provider|login|TU_KEY]
                                const providers = Ai.providerSummary();
                                const providerNames = Object.keys(providers).sort();
                                const trailingSpace = /\s$/.test(messageInputField.text);
                                const trimmedTokens = messageInputField.text.trim().split(/\s+/);
                                const trimmedCount = trimmedTokens.length;
                                const slot = trimmedCount + (trailingSpace ? 1 : 0); // 1: /setup, 2: arg1, 3: arg2

                                let candidates = [];
                                let query = "";
                                let mergePrefix = "";

                                if (slot <= 2) {
                                    query = (trimmedCount >= 2 && !trailingSpace) ? trimmedTokens[1] : "";
                                    candidates = [...providerNames, "get", "login"];
                                    if (trimmedCount === 1) mergePrefix = `${root.commandPrefix}setup `;
                                } else if (slot === 3) {
                                    const arg1 = trimmedTokens[1].toLowerCase();
                                    query = trailingSpace ? "" : (trimmedTokens[2] ?? "");
                                    if (arg1 === "get") {
                                        candidates = providerNames;
                                    } else if (providers[arg1] && query.length === 0) {
                                        // Solo sugerir "login" antes de que empiecen a pegar una key
                                        candidates = ["login"];
                                    }
                                    if (trailingSpace) mergePrefix = `${trimmedTokens[1]} `;
                                }

                                if (candidates.length === 0) {
                                    root.suggestionQuery = "";
                                    root.suggestionList = [];
                                } else {
                                    root.suggestionQuery = query;
                                    const setupResults = Fuzzy.go(query, candidates.map(c => {
                                        return {
                                            name: Fuzzy.prepare(c),
                                            obj: c
                                        };
                                    }), {
                                        all: true,
                                        key: "name"
                                    });
                                    root.suggestionList = setupResults.map(result => {
                                        const word = result.target;
                                        const provider = providers[word];
                                        return {
                                            name: `${mergePrefix}${word}`,
                                            displayName: word,
                                            description: word === "get" ? Translation.tr("Mostrar una key guardada")
                                                : word === "login" ? Translation.tr("Login por navegador / OAuth")
                                                : provider ? (provider.requiresKey
                                                    ? Translation.tr("%1 modelos").arg(provider.models.length)
                                                    : Translation.tr("No necesita API key"))
                                                : ""
                                        };
                                    });
                                }
                            } else if (messageInputField.text.startsWith(root.commandPrefix)) {
                                root.suggestionQuery = messageInputField.text;
                                root.suggestionList = root.allCommands.filter(cmd => cmd.name.startsWith(messageInputField.text.substring(1))).map(cmd => {
                                    return {
                                        name: `${root.commandPrefix}${cmd.name}`,
                                        description: `${cmd.description}`
                                    };
                                });
                            }
                        }

                        function accept() {
                            root.handleInput(text);
                            text = "";
                        }

                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Tab) {
                                suggestions.acceptSelectedWord();
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Up && suggestions.visible) {
                                suggestions.selectedIndex = Math.max(0, suggestions.selectedIndex - 1);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Down && suggestions.visible) {
                                suggestions.selectedIndex = Math.min(root.suggestionList.length - 1, suggestions.selectedIndex + 1);
                                event.accepted = true;
                            } else if ((event.key === Qt.Key_Enter || event.key === Qt.Key_Return)) {
                                if (event.modifiers & Qt.ShiftModifier) {
                                    // Insert newline
                                    messageInputField.insert(messageInputField.cursorPosition, "\n");
                                    event.accepted = true;
                                } else {
                                    // Accept text
                                    const inputText = messageInputField.text;
                                    messageInputField.clear();
                                    root.handleInput(inputText);
                                    event.accepted = true;
                                }
                            } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_V) {
                                // Intercept Ctrl+V to handle image/file pasting
                                if (event.modifiers & Qt.ShiftModifier) {
                                    // Let Shift+Ctrl+V = plain paste
                                    messageInputField.text += Quickshell.clipboardText;
                                    event.accepted = true;
                                    return;
                                }
                                // Try image paste first
                                const currentClipboardEntry = Cliphist.entries[0];
                                const cleanCliphistEntry = StringUtils.cleanCliphistEntry(currentClipboardEntry);
                                if (/^\d+\t\[\[.*binary data.*\d+x\d+.*\]\]$/.test(currentClipboardEntry)) {
                                    // First entry = currently copied entry = image?
                                    decodeImageAndAttachProc.handleEntry(currentClipboardEntry);
                                    event.accepted = true;
                                    return;
                                } else if (cleanCliphistEntry.startsWith("file://")) {
                                    // First entry = currently copied entry = image?
                                    const fileName = decodeURIComponent(cleanCliphistEntry);
                                    Ai.attachFile(fileName);
                                    event.accepted = true;
                                    return;
                                }
                                event.accepted = false; // No image, let text pasting proceed
                            } else if (event.key === Qt.Key_Escape) {
                                // Esc to detach file
                                if (Ai.pendingFilePath.length > 0) {
                                    Ai.attachFile("");
                                    event.accepted = true;
                                } else {
                                    event.accepted = false;
                                }
                            }
                        }
                    }
                }
                RippleButton { // Send button
                    id: sendButton
                    Layout.alignment: Qt.AlignBottom
                    Layout.rightMargin: 5
                    implicitWidth: 40
                    implicitHeight: 40
                    buttonRadius: Appearance.rounding.small
                    enabled: messageInputField.text.length > 0
                    toggled: enabled

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: sendButton.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            const inputText = messageInputField.text;
                            root.handleInput(inputText);
                            messageInputField.clear();
                        }
                    }

                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        iconSize: 22
                        color: sendButton.enabled ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer2Disabled
                        text: "arrow_upward"
                    }
                }
            }

            Flow { // Controls
                // Flow y no RowLayout: en la sidebar angosta los indicadores no
                // entraban en una línea y los botones de comando quedaban afuera.
                // Así baja a una segunda línea y el input crece (su implicitHeight
                // ya cuenta el alto de esta fila).
                id: commandButtonsRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 5
                anchors.leftMargin: 10
                anchors.rightMargin: 5
                spacing: 4

                property var commandsShown: [
                    {
                        name: "",
                        sendDirectly: false,
                        dontAddSpace: true
                    },
                    {
                        name: "clear",
                        sendDirectly: true
                    },
                ]

                // El agente ya se ve resaltado en la barra de pestañas de arriba, así
                // que no se repite acá: es el espacio que hacía falta para que entren
                // el modelo, el esfuerzo y la herramienta.

                ApiInputBoxIndicator {
                    // Model indicator
                    visible: Config.options.sidebar.ai.showInputIndicators
                    icon: "api"
                    text: Ai.getModel()?.name ?? ""
                    active: root.openPicker === "model"
                    clickAction: () => root.openPicker = (root.openPicker === "model" ? "" : "model")
                    tooltipText: Translation.tr("Modelo: %1\nClic para cambiarlo, o %2model MODELO").arg(Ai.getModel()?.name ?? "").arg(root.commandPrefix)
                }

                ApiInputBoxIndicator {
                    // Effort indicator (solo Claude Code entiende --effort)
                    visible: Ai.supportsEffort && Config.options.sidebar.ai.showInputIndicators
                    icon: root.effortIcons[Ai.effort] ?? "settings_suggest"
                    // En Default alcanza con el icono; el nombre sólo cuando lo cambiaste
                    text: Ai.effort
                    active: root.openPicker === "effort"
                    clickAction: () => root.openPicker = (root.openPicker === "effort" ? "" : "effort")
                    tooltipText: Translation.tr("Cuánto piensa antes de responder\nClic para cambiarlo, o %1effort NIVEL").arg(root.commandPrefix)
                }

                ApiInputBoxIndicator {
                    // Tool indicator
                    visible: Config.options.sidebar.ai.showInputIndicators
                    icon: root.toolIcons[Ai.currentTool] ?? "service_toolbox"
                    text: Ai.currentTool.charAt(0).toUpperCase() + Ai.currentTool.slice(1)
                    active: root.openPicker === "tool"
                    clickAction: () => root.openPicker = (root.openPicker === "tool" ? "" : "tool")
                    tooltipText: Translation.tr("Herramienta: %1\nClic para cambiarla, o %2tool TOOL").arg(Ai.currentTool).arg(root.commandPrefix)
                }

                ButtonGroup {
                    // Command buttons
                    visible: Config.options.sidebar.ai.showCommandButtons
                    padding: 0

                    Repeater {
                        // Command buttons
                        model: commandButtonsRow.commandsShown
                        delegate: ApiCommandButton {
                            property string commandRepresentation: `${root.commandPrefix}${modelData.name}`
                            buttonText: commandRepresentation
                            downAction: () => {
                                if (modelData.sendDirectly) {
                                    root.handleInput(commandRepresentation);
                                } else {
                                    messageInputField.text = commandRepresentation + (modelData.dontAddSpace ? "" : " ");
                                    messageInputField.cursorPosition = messageInputField.text.length;
                                    messageInputField.forceActiveFocus();
                                }
                                if (modelData.name === "clear") {
                                    messageInputField.text = "";
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
