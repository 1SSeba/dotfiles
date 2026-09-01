pragma ComponentBehavior: Bound

import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

/**
 * Modal para cargar un modelo custom sin tocar el config a mano.
 *
 * Arma el mismo objeto que ya acepta `Config.options.ai.extraModels` (ver el
 * comentario en Ai.qml junto a `models`), lo persiste ahí (el JsonAdapter de
 * Config escribe solo en cuanto cambia algo) y lo agrega en caliente con
 * `Ai.addModel` para no tener que reiniciar la shell. Si cargás una key acá
 * mismo, se guarda con el mismo mecanismo que usa `/setup PROVIDER KEY`
 * (KeyringStorage, no el config plano).
 *
 * Scrim + tarjeta centrada: mismo patrón que AiNewChatDialog.qml (y el
 * selector de idioma del traductor, SelectionDialog.qml). Quien lo usa lo
 * hostea con un Loader anchors.fill + z alto.
 */
Item {
    id: root

    signal closed()

    readonly property var apiFormats: ["openai", "gemini", "mistral"]
    property string apiFormat: "openai"
    property bool requiresKey: true

    /** Vacía los campos: se llama al cerrar, para no dejar un borrador a medio llenar. */
    function reset() {
        nameField.text = "";
        modelIdField.text = "";
        endpointField.text = "";
        keyIdField.text = "";
        apiKeyField.text = "";
        root.apiFormat = "openai";
        root.requiresKey = true;
    }

    readonly property bool canSubmit: nameField.text.trim().length > 0
        && modelIdField.text.trim().length > 0
        && endpointField.text.trim().length > 0
        && (!root.requiresKey || keyIdField.text.trim().length > 0)

    function submit() {
        if (!root.canSubmit) return;

        const entry = {
            "id": nameField.text.trim(),
            "name": nameField.text.trim(),
            "model": modelIdField.text.trim(),
            "endpoint": endpointField.text.trim(),
            "api_format": root.apiFormat,
            "requires_key": root.requiresKey,
            "description": Translation.tr("Modelo custom agregado desde el sidebar"),
        };
        if (root.requiresKey) entry["key_id"] = keyIdField.text.trim();

        // Persistido: se guarda en el config (extraModels), así que sobrevive
        // a un reinicio de la shell. En caliente: Ai.addModel lo suma a la
        // lista YA, sin esperar a que se recargue nada.
        Config.options.ai.extraModels = [...(Config.options.ai.extraModels ?? []), entry];
        const safeName = Ai.safeModelName(entry.id);
        Ai.addModel(safeName, entry);

        const keyText = apiKeyField.text.trim();
        if (root.requiresKey && keyText.length > 0) {
            KeyringStorage.setNestedField(["apiKeys", keyIdField.text.trim()], keyText);
        }

        const addedKeyText = root.requiresKey && keyText.length > 0 ? Translation.tr(" con su API key") : "";
        Ai.setModel(safeName, false);
        Ai.addMessage(Translation.tr("✅ Modelo `%1` agregado%2").arg(nameField.text.trim()).arg(addedKeyText), Ai.interfaceRole);

        root.reset();
        root.closed();
    }

    Rectangle { // Scrim
        anchors.fill: parent
        color: Appearance.colors.colScrim

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            preventStealing: true
            onClicked: {
                root.reset();
                root.closed();
            }
        }
    }

    Rectangle { // La tarjeta
        id: card
        anchors.centerIn: parent
        width: Math.min(parent.width - 32, 360)
        // `height`, no `implicitHeight`: este Rectangle es un Item plano, no
        // uno adentro de un Layout ni un Control — nada lo bindea solo a su
        // implicitHeight (ver AiNewChatDialog.qml, mismo bug ya encontrado ahí).
        height: Math.min(parent.height - 32, formColumn.implicitHeight + 32)
        radius: Appearance.rounding.normal
        color: Appearance.m3colors.m3surfaceContainerHigh
        clip: true

        // Que un click adentro de la tarjeta no se propague al scrim y la cierre
        MouseArea {
            anchors.fill: parent
        }

        Flickable {
            anchors.fill: parent
            anchors.margins: 16
            contentWidth: width
            contentHeight: formColumn.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: formColumn
                width: parent.width
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    MaterialSymbol {
                        text: "add_circle"
                        iconSize: Appearance.font.pixelSize.larger
                        color: Appearance.m3colors.m3onSurface
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("Modelo nuevo")
                        font.pixelSize: Appearance.font.pixelSize.larger
                        color: Appearance.m3colors.m3onSurface
                    }
                    RippleButton {
                        implicitWidth: 26
                        implicitHeight: 26
                        buttonRadius: Appearance.rounding.small
                        contentItem: MaterialSymbol {
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            text: "close"
                            iconSize: Appearance.font.pixelSize.normal
                            color: Appearance.m3colors.m3onSurface
                        }
                        onClicked: {
                            root.reset();
                            root.closed();
                        }
                    }
                }

                ToolbarTextField {
                    id: nameField
                    Layout.fillWidth: true
                    Layout.fillHeight: false
                    placeholderText: Translation.tr("Nombre (como aparece en el selector)")
                }

                ToolbarTextField {
                    id: modelIdField
                    Layout.fillWidth: true
                    Layout.fillHeight: false
                    placeholderText: Translation.tr("Modelo (el id que espera la API, ej. gpt-4o-mini)")
                }

                ToolbarTextField {
                    id: endpointField
                    Layout.fillWidth: true
                    Layout.fillHeight: false
                    placeholderText: Translation.tr("Endpoint (URL de la API)")
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    StyledText {
                        text: Translation.tr("Formato:")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colSubtext
                    }

                    Repeater {
                        model: root.apiFormats
                        delegate: RippleButton {
                            id: formatButton
                            required property string modelData
                            implicitHeight: 26
                            implicitWidth: formatLabel.implicitWidth + 16
                            buttonRadius: Appearance.rounding.small
                            toggled: root.apiFormat === formatButton.modelData
                            colBackground: Appearance.colors.colLayer1
                            onClicked: root.apiFormat = formatButton.modelData

                            contentItem: StyledText {
                                id: formatLabel
                                horizontalAlignment: Text.AlignHCenter
                                text: formatButton.modelData
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: formatButton.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer2
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    StyledSwitch {
                        id: requiresKeySwitch
                        checked: root.requiresKey
                        onCheckedChanged: root.requiresKey = checked
                    }
                    StyledText {
                        text: Translation.tr("Necesita API key")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnLayer2
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    visible: root.requiresKey
                    spacing: 6

                    ToolbarTextField {
                        id: keyIdField
                        Layout.fillWidth: true
                        Layout.fillHeight: false
                        placeholderText: Translation.tr("Key ID (para agrupar el proveedor, ej. openrouter)")
                    }

                    ToolbarTextField {
                        id: apiKeyField
                        Layout.fillWidth: true
                        Layout.fillHeight: false
                        placeholderText: Translation.tr("API key (opcional acá, después con /key)")
                        echoMode: TextInput.Password
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Layout.topMargin: 2

                    Item { Layout.fillWidth: true }

                    RippleButton {
                        implicitHeight: 30
                        implicitWidth: cancelLabel.implicitWidth + 20
                        buttonRadius: Appearance.rounding.small
                        colBackground: Appearance.colors.colLayer1
                        onClicked: {
                            root.reset();
                            root.closed();
                        }
                        contentItem: StyledText {
                            id: cancelLabel
                            text: Translation.tr("Cancelar")
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnLayer2
                        }
                    }

                    RippleButton {
                        implicitHeight: 30
                        implicitWidth: addLabel.implicitWidth + 20
                        buttonRadius: Appearance.rounding.small
                        enabled: root.canSubmit
                        toggled: root.canSubmit
                        onClicked: root.submit()
                        contentItem: StyledText {
                            id: addLabel
                            text: Translation.tr("Agregar")
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: root.canSubmit ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer2Disabled
                        }
                    }
                }
            }
        }
    }
}
