import Foundation
import SwiftUI
import Combine

struct Attachment: Identifiable, Codable, Equatable {
    var id = UUID()
    var kind: String
    var fileName: String
    var mimeType: String
    var base64: String
    var sizeMB: Double { Double(base64.count * 3 / 4) / 1024 / 1024 }
}

struct ChatMessage: Identifiable, Codable, Equatable {
    var id = UUID()
    var role: String
    var content: String
    var thinking: String?
    var attachments: [Attachment] = []
    var model: String?
    var createdAt = Date()
    var isError: Bool = false
}

struct ChatSession: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var messages: [ChatMessage] = []
    var createdAt = Date()
    var isPinned: Bool = false
    var lastPreview: String { messages.last?.content.prefix(80).description ?? "" }
}

struct AIModel: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var name: String { id }
}

class SettingsStore: ObservableObject {
    @AppStorage("baseURL") var baseURL: String = "https://positionapi.top/v1"
    @AppStorage("apiKey") var apiKey: String = ""
    @AppStorage("systemPrompt") var systemPrompt: String = "Ты — полезный ИИ-ассистент. Отвечай на русском, кратко и по делу."
    @AppStorage("selectedModel") var selectedModel: String = ""
    @AppStorage("temperature") var temperature: Double = 0.7
    @AppStorage("reasoningEffort") var reasoningEffort: String = "medium"
    @AppStorage("showThinking") var showThinking: Bool = true
    @AppStorage("voiceEnabled") var voiceEnabled: Bool = true
    @AppStorage("autoSpeak") var autoSpeak: Bool = false
    @AppStorage("voiceID") var voiceID: String = ""
    @AppStorage("voiceRate") var voiceRate: Double = 0.48
    @AppStorage("voicePitch") var voicePitch: Double = 1.0
    @AppStorage("imageModel") var imageModel: String = "gpt-image-1"
    @AppStorage("imageSize") var imageSize: String = "1024x1024"
    @AppStorage("imageStyle") var imageStyle: String = "auto"
    @AppStorage("isDark") var isDark: Bool = true
    @AppStorage("appTheme") var appTheme: String = "paper"
    @AppStorage("fontSize") var fontSize: Double = 16
    @AppStorage("hasSeenOnboarding") var hasSeenOnboarding: Bool = false
    @AppStorage("userName") var userName: String = ""
    @AppStorage("maxTokens") var maxTokens: Int = 2048
    @AppStorage("contextLimit") var contextLimit: Int = 20
    @Published var availableModels: [AIModel] = []
    @Published var modelsError: String?
    @Published var isLoadingModels = false
    @Published var connectionOK: Bool?
    var cleanBaseURL: String {
        var u = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        while u.hasSuffix("/") { u.removeLast() }
        if u.hasSuffix("/chat/completions") { u = String(u.dropLast("/chat/completions".count)) }
        if u.hasSuffix("/models") { u = String(u.dropLast("/models".count)) }
        return u.isEmpty ? "https://positionapi.top/v1" : u
    }
}

class ChatStore: ObservableObject {
    @Published var sessions: [ChatSession] = []
    @Published var currentId: UUID?
    private let fileURL: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("chats.json")
    init() { load() }
    var current: ChatSession? { sessions.first { $0.id == currentId } }
    func newChat() -> ChatSession {
        if let first = sessions.first, first.messages.isEmpty { currentId = first.id; return first }
        let s = ChatSession(title: "Новый чат")
        sessions.insert(s, at: 0)
        currentId = s.id
        save()
        return s
    }
    func update(_ session: ChatSession) {
        if let i = sessions.firstIndex(where: { $0.id == session.id }) { sessions[i] = session } else { sessions.insert(session, at: 0) }
        save()
    }
    func delete(_ id: UUID) {
        sessions.removeAll { $0.id == id }
        if currentId == id { currentId = sessions.first?.id }
        save()
    }
    func togglePin(_ id: UUID) {
        guard let i = sessions.firstIndex(where: { $0.id == id }) else { return }
        sessions[i].isPinned.toggle()
        sessions.sort { ($0.isPinned ? 0 : 1, $0.createdAt) > ($1.isPinned ? 0 : 1, $1.createdAt) }
        save()
    }
    func rename(_ id: UUID, _ title: String) {
        guard let i = sessions.firstIndex(where: { $0.id == id }) else { return }
        sessions[i].title = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? sessions[i].title : title
        save()
    }
    func save() {
        do { try JSONEncoder().encode(sessions).write(to: fileURL, options: .atomic) } catch { print("save error", error) }
    }
    func load() {
        guard let d = try? Data(contentsOf: fileURL) else { return }
        if let v = try? JSONDecoder().decode([ChatSession].self, from: d) { sessions = v; currentId = v.first?.id; return }
        try? FileManager.default.moveItem(at: fileURL, to: fileURL.deletingLastPathComponent().appendingPathComponent("chats.corrupted.json"))
    }
    func exportURL() -> URL? {
        guard let data = try? JSONEncoder().encode(sessions) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("aichat-export-\(Int(Date().timeIntervalSince1970)).json")
        try? data.write(to: url)
        return url
    }
}
