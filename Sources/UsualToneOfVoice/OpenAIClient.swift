import Foundation

enum OpenAIClientError: LocalizedError {
    case invalidResponse
    case requestFailed(statusCode: Int, message: String?)
    case emptyOutput(status: String?, reason: String?, responseSnippet: String?)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from OpenAI"
        case .requestFailed(let statusCode, let message):
            if let message, !message.isEmpty {
                return "OpenAI request failed (\(statusCode)): \(message)"
            }
            return "OpenAI request failed (\(statusCode))"
        case .emptyOutput(let status, let reason, let responseSnippet):
            var details: [String] = []
            if let status, !status.isEmpty {
                details.append("status=\(status)")
            }
            if let reason, !reason.isEmpty {
                details.append("reason=\(reason)")
            }
            if let responseSnippet, !responseSnippet.isEmpty {
                details.append("response=\(responseSnippet)")
            }
            if !details.isEmpty {
                let detailText = details.joined(separator: ", ")
                return "OpenAI returned no text (\(detailText))"
            }
            return "OpenAI returned no text"
        }
    }
}

struct OpenAIClient {
    static let defaultModel = OpenAIModel.gpt5Mini.rawValue
    static let defaultMaxOutputTokens = 420
    static let defaultTemperature = 0.2
    static let defaultSystemPrompt = """
あなたは音声入力の書き起こしを、読みやすい文章に整形する変換器です。
内容の追加や推測はせず、質問に答えたり解説しません。
口調と意味を保ちつつ、句読点や改行を整えて出力は本文のみとします。
"""

    func generateResponse(
        input: String,
        apiKey: String,
        model: String = OpenAIClient.defaultModel,
        systemPrompt: String = OpenAIClient.defaultSystemPrompt,
        maxOutputTokens: Int? = OpenAIClient.defaultMaxOutputTokens,
        temperature: Double? = OpenAIClient.defaultTemperature
    ) async throws -> String {
        guard let url = URL(string: "https://api.openai.com/v1/responses") else {
            throw OpenAIClientError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let trimmedSystemPrompt = systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let reasoning = OpenAIClient.supportsReasoningConfig(model: model)
            ? OpenAIReasoning(effort: OpenAIClient.defaultReasoningEffort)
            : nil
        let textConfig = OpenAIClient.supportsTextConfig(model: model)
            ? OpenAITextConfig(verbosity: "low")
            : nil
        let body = OpenAIRequest(
            model: model,
            input: input,
            instructions: trimmedSystemPrompt.isEmpty ? nil : trimmedSystemPrompt,
            store: false,
            maxOutputTokens: maxOutputTokens,
            temperature: temperature,
            reasoning: reasoning,
            text: textConfig
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let responseString = String(data: data, encoding: .utf8)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIClientError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let apiError = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data)
            throw OpenAIClientError.requestFailed(statusCode: httpResponse.statusCode, message: apiError?.error.message)
        }

        let decoded = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        let text = decoded.outputText
        guard !text.isEmpty else {
            let snippet = responseString.map { String($0.prefix(400)) }
            throw OpenAIClientError.emptyOutput(status: decoded.status, reason: decoded.incompleteDetails?.reason, responseSnippet: snippet)
        }
        return text
    }
}

extension OpenAIClient {
    static func supportsTemperature(model: String) -> Bool {
        let normalized = model.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return !normalized.hasPrefix("gpt-5")
    }

    static func supportsReasoningConfig(model: String) -> Bool {
        let normalized = model.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized.hasPrefix("gpt-5")
    }

    static func supportsTextConfig(model: String) -> Bool {
        let normalized = model.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized.hasPrefix("gpt-5")
    }

    static func prefersUnboundedOutput(model: String) -> Bool {
        let normalized = model.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized.hasPrefix("gpt-5")
    }

    static let defaultReasoningEffort = "minimal"
}

private struct OpenAIRequest: Encodable {
    let model: String
    let input: String
    let instructions: String?
    let store: Bool
    let maxOutputTokens: Int?
    let temperature: Double?
    let reasoning: OpenAIReasoning?
    let text: OpenAITextConfig?

    enum CodingKeys: String, CodingKey {
        case model
        case input
        case instructions
        case store
        case maxOutputTokens = "max_output_tokens"
        case temperature
        case reasoning
        case text
    }
}

private struct OpenAIResponse: Decodable {
    let output: [OpenAIOutputItem]?
    let outputTextValue: String?
    let status: String?
    let incompleteDetails: OpenAIIncompleteDetails?

    enum CodingKeys: String, CodingKey {
        case output
        case outputTextValue = "output_text"
        case status
        case incompleteDetails = "incomplete_details"
    }

    var outputText: String {
        if let outputTextValue, !outputTextValue.isEmpty {
            return outputTextValue
        }

        let parts = output?.flatMap { item -> [String] in
            var collected: [String] = []
            if let itemText = item.text, !itemText.isEmpty {
                collected.append(itemText)
            }
            if let content = item.content {
                for contentItem in content {
                    if let text = contentItem.text, !text.isEmpty {
                        collected.append(text)
                    }
                }
            }
            return collected
        } ?? []

        return parts.joined()
    }
}

private struct OpenAIOutputItem: Decodable {
    let type: String?
    let content: [OpenAIOutputContent]?
    let text: String?
}

private struct OpenAIOutputContent: Decodable {
    let type: String?
    let text: String?
}

private struct OpenAIReasoning: Encodable {
    let effort: String
}

private struct OpenAITextConfig: Encodable {
    let verbosity: String
}

private struct OpenAIIncompleteDetails: Decodable {
    let reason: String?
}

private struct OpenAIErrorResponse: Decodable {
    let error: OpenAIErrorDetail
}

private struct OpenAIErrorDetail: Decodable {
    let message: String
}
