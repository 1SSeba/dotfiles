import QtQuick
import qs.modules.common.functions as CF

ApiStrategy {
    property bool isReasoning: false

    // ---- Adjuntos (imágenes) ----
    readonly property string fileMediaTypeVarName: "MEDIA_TYPE"
    readonly property string fileBase64VarName: "FILE_B64"
    readonly property string fileMediaTypeSubstitutionString: "{{ oai_media_type }}"
    readonly property string fileBase64SubstitutionString: "{{ oai_file_b64 }}"

    function buildScriptFileSetup(filePath) {
        const trimmedFilePath = CF.FileUtils.trimFileProtocol(filePath);
        let content = "";
        content += `ATTACHED_PATH='${CF.StringUtils.shellSingleQuoteEscape(trimmedFilePath)}'\n`;
        content += `${fileMediaTypeVarName}=$(file -b --mime-type "$ATTACHED_PATH")\n`;
        content += `${fileBase64VarName}=$(base64 -w 0 "$ATTACHED_PATH")\n`;
        return content;
    }

    function finalizeScriptContent(scriptContent: string): string {
        return scriptContent.replace(fileMediaTypeSubstitutionString, `'"\$${fileMediaTypeVarName}"'`)
                            .replace(fileBase64SubstitutionString, `'"\$${fileBase64VarName}"'`);
    }

    function buildEndpoint(model: AiModel): string {
        // console.log("[AI] Endpoint: " + model.endpoint);
        return model.endpoint;
    }

    function buildRequestData(model: AiModel, messages, systemPrompt: string, temperature: real, tools: list<var>, filePath: string) {
        let baseData = {
            "model": model.model,
            "messages": [
                {role: "system", content: systemPrompt},
                ...messages.map(message => {
                    return {
                        "role": message.role,
                        "content": message.rawContent,
                    }
                }),
            ],
            "stream": true,
            "tools": tools,
            "temperature": temperature,
        };

        // Adjunto: se mete como bloque de imagen en el último mensaje del usuario
        if (filePath && filePath.length > 0) {
            for (let i = baseData.messages.length - 1; i >= 0; i--) {
                if (baseData.messages[i].role !== "user") continue;
                baseData.messages[i].content = [
                    { "type": "image_url", "image_url": {
                        "url": `data:${fileMediaTypeSubstitutionString};base64,${fileBase64SubstitutionString}`
                    }},
                    { "type": "text", "text": baseData.messages[i].content }
                ];
                break;
            }
        }
        return model.extraParams ? Object.assign({}, baseData, model.extraParams) : baseData;
    }

    function buildAuthorizationHeader(apiKeyEnvVarName: string): string {
        return `-H "Authorization: Bearer \$\{${apiKeyEnvVarName}\}"`;
    }

    function parseResponseLine(line, message) {
        // Remove 'data: ' prefix if present and trim whitespace
        let cleanData = line.trim();
        if (cleanData.startsWith("data:")) {
            cleanData = cleanData.slice(5).trim();
        }

        // console.log("[AI] OpenAI: Data:", cleanData);
        
        // Handle special cases
        if (!cleanData || cleanData.startsWith(":")) return {};
        if (cleanData === "[DONE]") {
            return { finished: true };
        }
        
        // Real stuff
        try {
            const dataJson = JSON.parse(cleanData);

            // Error response handling
            if (dataJson.error) {
                const errorMsg = `**Error**: ${dataJson.error.message || JSON.stringify(dataJson.error)}`;
                message.rawContent += errorMsg;
                message.content += errorMsg;
                return { finished: true };
            }

            let newContent = "";

            const responseContent = dataJson.choices[0]?.delta?.content || dataJson.message?.content;
            const responseReasoning = dataJson.choices[0]?.delta?.reasoning || dataJson.choices[0]?.delta?.reasoning_content;

            if (responseContent && responseContent.length > 0) {
                if (isReasoning) {
                    isReasoning = false;
                    const endBlock = "\n\n</think>\n\n";
                    message.content += endBlock;
                    message.rawContent += endBlock;
                }
                newContent = responseContent;
            } else if (responseReasoning && responseReasoning.length > 0) {
                if (!isReasoning) {
                    isReasoning = true;
                    const startBlock = "\n\n<think>\n\n";
                    message.rawContent += startBlock;
                    message.content += startBlock;
                }
                newContent = responseReasoning;
            }

            message.content += newContent;
            message.rawContent += newContent;

            // Usage metadata
            if (dataJson.usage) {
                return {
                    tokenUsage: {
                        input: dataJson.usage.prompt_tokens ?? -1,
                        output: dataJson.usage.completion_tokens ?? -1,
                        total: dataJson.usage.total_tokens ?? -1
                    }
                };
            }

            if (dataJson.done) {
                return { finished: true };
            }
            
        } catch (e) {
            console.log("[AI] OpenAI: Could not parse line: ", e);
            message.rawContent += line;
            message.content += line;
        }
        
        return {};
    }
    
    function onRequestFinished(message) {
        // OpenAI format doesn't need special finish handling
        return {};
    }
    
    function reset() {
        isReasoning = false;
    }

}
