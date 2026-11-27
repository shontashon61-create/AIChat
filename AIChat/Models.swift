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
    var errorCode: Int = 0
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
    @AppStorage("schoolMode") var schoolMode: Bool = true
    @AppStorage("schoolSubject") var schoolSubject: String = "Универсально"
    @AppStorage("schoolFormat") var schoolFormat: String = "Краткие ответы"
    @AppStorage("mellstroyMode") var mellstroyMode: Bool = true
    @AppStorage("mellWallpaper") var mellWallpaper: String = "Градиент"
    @AppStorage("examMode") var examMode: Bool = false
    @AppStorage("verifyAnswers") var verifyAnswers: Bool = false
    @AppStorage("checkerModel") var checkerModel: String = ""
    @AppStorage("textbooks") var textbooks: String = ""
    @AppStorage("meshMinutes") var meshMinutes: Double = 10
    @AppStorage("voiceMode") var voiceMode: Bool = false
    @AppStorage("humanCDZ") var humanCDZ: Bool = true
    @AppStorage("offlineMode") var offlineMode: Bool = true
    @AppStorage("myStyle") var myStyle: String = ""
    @AppStorage("noWaterMode") var noWaterMode: Bool = false
    @AppStorage("notebookLargeFont") var notebookLargeFont: Bool = true
    @AppStorage("onlyUnsolvedCDZ") var onlyUnsolvedCDZ: Bool = true
    init() {
        switch schoolFormat {
        case "Краткие ответы", "Ответы с решением", "Подробные ответы": break
        case "Пошаговое решение", "Как ученик, для тетради": schoolFormat = "Ответы с решением"
        case "Объяснение как учитель", "Вся контрольная": schoolFormat = "Подробные ответы"
        default: schoolFormat = "Краткие ответы"
        }
    }
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
        sessions.sort { if $0.isPinned != $1.isPinned { return $0.isPinned }; return $0.createdAt > $1.createdAt }
        save()
    }
    func rename(_ id: UUID, _ title: String) {
        guard let i = sessions.firstIndex(where: { $0.id == id }) else { return }
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty { sessions[i].title = t }
        save()
    }
    func deleteAll() {
        sessions = []
        currentId = nil
        save()
        _ = newChat()
    }
    private var saveWork: DispatchWorkItem?
    func save() {
        saveWork?.cancel()
        let snapshot = sessions
        let url = fileURL
        let work = DispatchWorkItem { do { try JSONEncoder().encode(snapshot).write(to: url, options: .atomic) } catch { print("save error", error) } }
        saveWork = work
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.4, execute: work)
    }
    func saveNow() {
        saveWork?.cancel()
        do { try JSONEncoder().encode(sessions).write(to: fileURL, options: .atomic) } catch { print("save error", error) }
    }
    func load() {
        guard let d = try? Data(contentsOf: fileURL) else { return }
        if let v = try? JSONDecoder().decode([ChatSession].self, from: d) { sessions = v; currentId = v.first?.id; return }
        try? FileManager.default.moveItem(at: fileURL, to: fileURL.deletingLastPathComponent().appendingPathComponent("chats.corrupted.json"))
    }
}
