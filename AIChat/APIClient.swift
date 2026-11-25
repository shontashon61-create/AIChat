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

struct APIError: LocalizedError {
    let message: String
    let retryable: Bool
    var errorDescription: String? { message }
}

class APIClient {
    static func complete(settings: SettingsStore, model: String, system: String, user: String) async -> String? {
        guard let url = URL(string: settings.cleanBaseURL + "/chat/completions") else { return nil }
        let body: [String: Any] = ["model": model, "messages": [["role": "system", "content": system], ["role": "user", "content": user]], "stream": false, "temperature": 0.1]
        var req = URLRequest(url: url, timeoutInterval: 90)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !settings.apiKey.isEmpty { req.setValue("Bearer \(settings.apiKey)", forHTTPHeaderField: "Authorization") }
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        guard let (data, resp) = try? await URLSession.shared.data(for: req), let http = resp as? HTTPURLResponse, http.statusCode == 200, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let choices = json["choices"] as? [[String: Any]], let message = choices.first?["message"] as? [String: Any], let content = message["content"] as? String else { return nil }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    static func verifyAnswer(settings: SettingsStore, question: String, answer: String) async -> String? {
        guard settings.verifyAnswers else { return nil }
        let checker = settings.checkerModel.isEmpty ? settings.availableModels.first(where: { $0.id != settings.selectedModel && !$0.id.lowercased().contains("image") })?.id ?? "" : settings.checkerModel
        guard !checker.isEmpty, checker != settings.selectedModel else { return nil }
        let system = "Ты — строгий проверяющий для 6 класса. Проверь ответ на задание. Если ответ верный — верни только слово ВЕРНО. Если есть ошибка — верни одной строкой: ОШИБКА: что именно неверно и правильный ответ. Ничего больше не пиши."
        let user = "Задание:\n" + question + "\n\nОтвет ученика:\n" + answer
        guard let verdict = await complete(settings: settings, model: checker, system: system, user: user), !verdict.isEmpty else { return nil }
        if verdict.uppercased().hasPrefix("ВЕРНО") { return "✅ Проверено второй моделью (" + checker + "): верно." }
        return "⚠️ Проверка второй моделью (" + checker + "): " + verdict
    }
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
                if settings.selectedModel.isEmpty || !models.contains(where: { $0.id == settings.selectedModel }) { settings.selectedModel = models.first(where: { let id = $0.id.lowercased(); return !id.contains("image") && !id.contains("audio") && !id.contains("tts") })?.id ?? models.first?.id ?? "" }
                settings.isLoadingModels = false
            }
        } catch {
            await MainActor.run { settings.modelsError = error.localizedDescription; settings.connectionOK = false; settings.isLoadingModels = false }
        }
    }
    static func streamChat(settings: SettingsStore, messages: [ChatMessage], onContent: @escaping (String) -> Void, onThinking: @escaping (String) -> Void) async throws {
        guard let url = URL(string: settings.cleanBaseURL + "/chat/completions") else { throw URLError(.badURL) }
        let clean = messages.filter { !$0.isError && !($0.role == "assistant" && $0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
        let trimmed = Array(clean.suffix(30))
        var apiMessages: [[String: Any]] = []
        let prompt = SchoolSkills.systemPrompt(settings: settings, lastUserText: trimmed.last(where: { $0.role == "user" })?.content ?? "")
        if !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { apiMessages.append(["role": "system", "content": prompt]) }
        for m in trimmed {
            if m.role == "user" && !m.attachments.isEmpty {
                var parts: [[String: Any]] = [["type": "text", "text": m.content]]
                for a in m.attachments where a.kind == "image" { parts.append(["type": "image_url", "image_url": ["url": "data:\(a.mimeType);base64,\(a.base64)"]]) }
                apiMessages.append(["role": "user", "content": parts])
            } else { apiMessages.append(["role": m.role, "content": m.content]) }
        }
        let effectiveTemp = settings.schoolMode && settings.schoolFormat == "Выбор ответа (А/Б/В/Г)" ? min(settings.temperature, 0.2) : settings.temperature
        let body: [String: Any] = ["model": settings.selectedModel, "messages": apiMessages, "stream": true, "temperature": effectiveTemp]
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
            let code = http.statusCode
            throw APIError(message: "HTTP \(code): \(String(errText.prefix(500)))", retryable: code == 429 || code >= 500)
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
}
