import Foundation

struct ModelsResponse: Decodable {
    let data: [ModelItem]
    enum CodingKeys: String, CodingKey { case data }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let items = try? c.decode([ModelItem].self, forKey: .data) { data = items }
        else if let strs = try? c.decode([String].self, forKey: .data) { data = strs.map { ModelItem(id: $0) } }
        else { data = [] }
    }
}
struct ModelItem: Decodable { let id: String }
struct StreamDelta: Decodable {
    struct Choice: Decodable {
        struct Delta: Decodable { let content: String?; let reasoning_content: String?; let reasoning: String? }
        let delta: Delta?
        let message: Delta?
    }
    let choices: [Choice]?
}

class APIClient {
    static func fetchModels(settings: SettingsStore) async {
        await MainActor.run { settings.isLoadingModels = true; settings.modelsError = nil; settings.connectionOK = nil }
        do {
            guard let url = URL(string: settings.cleanBaseURL + "/models") else { throw URLError(.badURL) }
            var req = URLRequest(url: url, timeoutInterval: 30)
            req.httpMethod = "GET"
            if !settings.apiKey.isEmpty { req.setValue("Bearer \(settings.apiKey)", forHTTPHeaderField: "Authorization") }
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else { throw URLError(.badServerResponse) }
            guard http.statusCode == 200 else {
                let body = String(data: data, encoding: .utf8) ?? ""
                throw NSError(domain: "API", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode): \(String(body.prefix(300)))"])
            }
            let decoded = try JSONDecoder().decode(ModelsResponse.self, from: data)
            let models = decoded.data.map { AIModel(id: $0.id) }.sorted { $0.id < $1.id }
            await MainActor.run {
                settings.availableModels = models
                settings.connectionOK = true
                if models.isEmpty { settings.modelsError = "Сервер вернул пустой список моделей" }
                if settings.selectedModel.isEmpty || !models.contains(where: { $0.id == settings.selectedModel }) { settings.selectedModel = models.first?.id ?? "" }
                settings.isLoadingModels = false
            }
        } catch {
            await MainActor.run { settings.modelsError = error.localizedDescription; settings.connectionOK = false; settings.isLoadingModels = false }
        }
    }
    static func streamChat(settings: SettingsStore, messages: [ChatMessage], onContent: @escaping (String) -> Void, onThinking: @escaping (String) -> Void) async throws {
        guard let url = URL(string: settings.cleanBaseURL + "/chat/completions") else { throw URLError(.badURL) }
        let trimmed = Array(messages.suffix(max(1, settings.contextLimit)))
        var apiMessages: [[String: Any]] = []
        if !settings.systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { apiMessages.append(["role": "system", "content": settings.systemPrompt]) }
        apiMessages.append(["role": "system", "content": "Ты умеешь генерировать фото прямо в этом диалоге, как ассистент с генерацией картинок. Когда пользователь просит нарисовать, сгенерировать, показать картинку, визуализировать твой ответ, сделать схему или иллюстрацию — или когда картинка явно улучшит ответ — добавь в конце ответа отдельную строку [IMAGE: detailed visual prompt in English, style, composition, colors, no text unless requested]. Можно до 3 таких строк для разных картинок. Не объясняй про маркер и не пиши, что не умеешь генерировать фото. Если в чате есть фото и просят вставить ответы, отредактировать или написать на нём — отвечай пронумерованным списком, каждый ответ с новой строки, фразеологизм — объяснение через тире. Если просят написать сочинение, эссе или любой текст на фото или листке — верни только сам текст, абзацами, без заголовков, markdown, нумерации и пояснений, как будто пишешь от руки синей ручкой."])
        for m in trimmed {
            if m.role == "user" && !m.attachments.isEmpty {
                var parts: [[String: Any]] = []
                var text = m.content
                for a in m.attachments where a.kind == "video" { text += "\n[Прикреплено видео: \(a.fileName). Видео как картинка не отправляется, опиши, что на нём, если пользователь спрашивает.]" }
                parts.append(["type": "text", "text": text])
                for a in m.attachments where a.kind == "image" { parts.append(["type": "image_url", "image_url": ["url": "data:\(a.mimeType);base64,\(a.base64)"]]) }
                apiMessages.append(["role": "user", "content": parts])
            } else { apiMessages.append(["role": m.role, "content": m.content]) }
        }
        var body: [String: Any] = ["model": settings.selectedModel.isEmpty ? "gpt-4o-mini" : settings.selectedModel, "messages": apiMessages, "stream": true, "temperature": settings.temperature]
        if settings.maxTokens > 0 { body["max_tokens"] = settings.maxTokens }
        if settings.reasoningEffort != "off" { body["reasoning_effort"] = settings.reasoningEffort }
        var req = URLRequest(url: url, timeoutInterval: 120)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !settings.apiKey.isEmpty { req.setValue("Bearer \(settings.apiKey)", forHTTPHeaderField: "Authorization") }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (bytes, resp) = try await URLSession.shared.bytes(for: req)
        guard let http = resp as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        if http.statusCode != 200 {
            var errText = ""
            for try await line in bytes.lines { errText += line + "\n"; if errText.count > 2000 { break } }
            throw NSError(domain: "API", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode): \(String(errText.prefix(500)))"])
        }
        for try await line in bytes.lines {
            if Task.isCancelled { break }
            var payload = line.trimmingCharacters(in: .whitespaces)
            if payload.hasPrefix("data:") { payload = String(payload.dropFirst(5)).trimmingCharacters(in: .whitespaces) }
            if payload.isEmpty || payload == "[DONE]" { if payload == "[DONE]" { break }; continue }
            guard payload.hasPrefix("{"), let data = payload.data(using: .utf8), let delta = try? JSONDecoder().decode(StreamDelta.self, from: data), let d = delta.choices?.first?.delta ?? delta.choices?.first?.message else { continue }
            if let t = d.reasoning_content ?? d.reasoning, !t.isEmpty { onThinking(t) }
            if let c = d.content, !c.isEmpty { onContent(c) }
        }
    }
    struct ImageResponse: Decodable { struct Item: Decodable { let b64_json: String?; let url: String? }; let data: [Item] }
    static func generateImage(settings: SettingsStore, prompt: String) async throws -> Attachment {
        guard let url = URL(string: settings.cleanBaseURL + "/images/generations") else { throw URLError(.badURL) }
        var req = URLRequest(url: url, timeoutInterval: 120); req.httpMethod = "POST"; req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !settings.apiKey.isEmpty { req.setValue("Bearer \(settings.apiKey)", forHTTPHeaderField: "Authorization") }
        let styledPrompt = settings.imageStyle == "auto" ? prompt : prompt + ", style: " + settings.imageStyle; req.httpBody = try JSONSerialization.data(withJSONObject: ["model": settings.imageModel, "prompt": styledPrompt, "size": settings.imageSize, "n": 1])
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else { let body = String(data: data, encoding: .utf8) ?? ""; throw NSError(domain: "API", code: (resp as? HTTPURLResponse)?.statusCode ?? 0, userInfo: [NSLocalizedDescriptionKey: "Генерация фото: HTTP \((resp as? HTTPURLResponse)?.statusCode ?? 0): \(String(body.prefix(400)))"]) }
        let decoded = try JSONDecoder().decode(ImageResponse.self, from: data)
        guard let item = decoded.data.first else { throw URLError(.badServerResponse) }
        if let b64 = item.b64_json, !b64.isEmpty { return Attachment(kind: "image", fileName: "generated.png", mimeType: "image/png", base64: b64) }
        if let u = item.url, let imgURL = URL(string: u) { let (imgData, _) = try await URLSession.shared.data(from: imgURL); return Attachment(kind: "image", fileName: "generated.png", mimeType: "image/png", base64: imgData.base64EncodedString()) }
        throw URLError(.badServerResponse)
    }
}
