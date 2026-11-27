import SwiftUI

struct ContentView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var store: ChatStore
    @State private var showSettings = false
    @State private var showHistory = false
    @State private var showMesh = false
    @State private var showTools = false
    var body: some View {
        NavigationStack {
            Group {
                if let session = store.current ?? store.sessions.first { ChatView(session: session) } else { VStack(spacing: 16) { Text("Чем помочь?").font(.title2.bold()); Button("Новый чат") { _ = store.newChat() }.buttonStyle(.borderedProminent) } }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button { showHistory = true } label: { Image(systemName: settings.mellstroyMode ? (Mellstroy.icons["history"] ?? "clock.arrow.circlepath") : "sidebar.left") } }
                ToolbarItem(placement: .principal) { ModelPickerMenu() }
                ToolbarItem(placement: .topBarTrailing) { HStack(spacing: 14) { Button { showTools = true } label: { Image(systemName: settings.mellstroyMode ? (Mellstroy.icons["tools"] ?? "backpack.fill") : "backpack") }; Button { showMesh = true } label: { Image(systemName: settings.mellstroyMode ? (Mellstroy.icons["mesh"] ?? "book.fill") : "book.fill") }; Button { _ = store.newChat() } label: { Image(systemName: settings.mellstroyMode ? (Mellstroy.icons["newChat"] ?? "bolt.fill") : "square.and.pencil") }; Button { showSettings = true } label: { Image(systemName: settings.mellstroyMode ? (Mellstroy.icons["settings"] ?? "slider.horizontal.3") : "gearshape") } } }
            }
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showHistory) { HistoryView() }
        .sheet(isPresented: $showMesh) { MeshView() }
        .sheet(isPresented: $showTools) { NavigationStack { SchoolToolsView() } }
        .task { if store.sessions.isEmpty { _ = store.newChat() }; await APIClient.fetchModels(settings: settings) }
    }
}

struct ModelPickerMenu: View {
    @EnvironmentObject var settings: SettingsStore
    var shortName: String { settings.selectedModel.isEmpty ? "Модель" : settings.selectedModel }
    var groups: [(String, [AIModel])] {
        let models = settings.availableModels
        let families: [(String, String)] = [("Claude", "claude"), ("GPT", "gpt"), ("Gemini", "gemini"), ("DeepSeek", "deepseek"), ("Qwen", "qwen"), ("Grok", "grok"), ("GLM", "glm")]
        var claimed = Set<String>()
        var out: [(String, [AIModel])] = []
        for (name, p) in families {
            let ms = models.filter { $0.id.lowercased().hasPrefix(p) }
            if !ms.isEmpty { out.append((name, ms)); ms.forEach { claimed.insert($0.id) } }
        }
        let rest = models.filter { !claimed.contains($0.id) }
        if !rest.isEmpty { out.append(("Другие", rest)) }
        return out
    }
    var body: some View {
        Menu {
            if settings.availableModels.isEmpty { Text(settings.isLoadingModels ? "Загрузка моделей..." : "Модели не загружены") }
            ForEach(groups, id: \.0) { g in
                Section(g.0) {
                    ForEach(g.1) { m in Button { settings.selectedModel = m.id } label: { Label(m.id, systemImage: settings.selectedModel == m.id ? "checkmark" : "cpu") } }
                }
            }
            Divider()
            Button("Обновить модели") { Task { await APIClient.fetchModels(settings: settings) } }
            if let e = settings.modelsError { Text(e) }
        } label: {
            HStack(spacing: 4) { Text(shortName).lineLimit(1).truncationMode(.middle).font(.callout.bold()); Image(systemName: "chevron.down").font(.caption2) }
        }
    }
}

struct HistoryView: View {
    @EnvironmentObject var store: ChatStore
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    @State private var renameSession: ChatSession?
    @State private var renameText = ""
    var filtered: [ChatSession] {
        var list = store.sessions.sorted { if $0.isPinned != $1.isPinned { return $0.isPinned }; return $0.createdAt > $1.createdAt }
        if !searchText.isEmpty { list = list.filter { $0.title.localizedCaseInsensitiveContains(searchText) || $0.messages.contains { $0.content.localizedCaseInsensitiveContains(searchText) } } }
        return list
    }
    var body: some View {
        NavigationStack {
            List {
                ForEach(filtered) { s in
                    Button { store.currentId = s.id; dismiss() } label: { VStack(alignment: .leading, spacing: 4) { HStack { if s.isPinned { Image(systemName: "pin.fill").font(.caption) }; Text(s.title).bold().lineLimit(1); Spacer(); Text("\(s.messages.count)").font(.caption2).foregroundStyle(.secondary) }; if !s.lastPreview.isEmpty { Text(s.lastPreview).font(.caption).foregroundStyle(.secondary).lineLimit(1) }; Text(s.createdAt, style: .date).font(.caption).foregroundStyle(.secondary) } }
                    .swipeActions(edge: .leading) { Button { store.togglePin(s.id) } label: { Label(s.isPinned ? "Открепить" : "Закрепить", systemImage: "pin") } }
                    .swipeActions(edge: .trailing) { Button(role: .destructive) { store.delete(s.id) } label: { Label("Удалить", systemImage: "trash") }; Button { renameSession = s; renameText = s.title } label: { Label("Переименовать", systemImage: "pencil") } }
                }
            }
            .searchable(text: $searchText, prompt: "Поиск по чатам")
            .navigationTitle("История чатов")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Новый") { _ = store.newChat(); dismiss() } } }
            .alert("Переименовать чат", isPresented: Binding(get: { renameSession != nil }, set: { if !$0 { renameSession = nil } })) { TextField("Название", text: $renameText); Button("Сохранить") { if let s = renameSession { store.rename(s.id, renameText) }; renameSession = nil }; Button("Отмена", role: .cancel) { renameSession = nil } }
        }
    }
}
