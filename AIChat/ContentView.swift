import SwiftUI

struct ContentView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var store: ChatStore
    @State private var showSettings = false
    @State private var showHistory = false
    var body: some View {
        NavigationStack {
            ZStack {
                DesignTheme.background.ignoresSafeArea()
                if let session = store.current ?? store.sessions.first { ChatView(session: session) } else { VStack(spacing: 16) { Image(systemName: "sparkles").font(.system(size: 44)).foregroundStyle(DesignTheme.primary); Text("Чем помочь?").font(.title2.bold()); Text("Настройте API в шестерёнке, выберите модель и начните чат.").multilineTextAlignment(.center).foregroundStyle(.secondary).padding(.horizontal); Button("Новый чат") { _ = store.newChat() }.buttonStyle(.borderedProminent) } }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button { showHistory = true } label: { Image(systemName: "sidebar.left") } }
                ToolbarItem(placement: .principal) { ModelPickerMenu() }
                ToolbarItem(placement: .topBarTrailing) { HStack(spacing: 14) { Button { _ = store.newChat() } label: { Image(systemName: "square.and.pencil") }; Button { showSettings = true } label: { Image(systemName: "gearshape") } } }
            }
        }
        .preferredColorScheme(AppThemes.palette(for: settings.appTheme).isDark ? .dark : .light).tint(DesignTheme.primary).animation(AppAnim.smooth, value: settings.appTheme)
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showHistory) { HistoryView() }
        .task { if store.sessions.isEmpty { _ = store.newChat() }; await APIClient.fetchModels(settings: settings) }
    }
}

struct ModelPickerMenu: View {
    @EnvironmentObject var settings: SettingsStore
    var shortName: String { settings.selectedModel.isEmpty ? "Модель" : (settings.selectedModel.components(separatedBy: "/").last ?? settings.selectedModel) }
    var body: some View {
        Menu {
            if settings.availableModels.isEmpty { Text(settings.isLoadingModels ? "Загрузка моделей..." : "Модели не загружены") }
            ForEach(settings.availableModels) { m in Button { settings.selectedModel = m.id } label: { Label(m.id, systemImage: settings.selectedModel == m.id ? "checkmark" : "cpu") } }
            Divider()
            Button("Обновить модели") { Task { await APIClient.fetchModels(settings: settings) } }
            if let e = settings.modelsError { Text(e) }
        } label: {
            HStack(spacing: 4) { Text(shortName).lineLimit(1).truncationMode(.middle).font(.callout.bold()).frame(minWidth: 0, maxWidth: .infinity); Image(systemName: "chevron.down").font(.caption2) }.padding(.horizontal, 10).padding(.vertical, 7).background(DesignTheme.chip, in: Capsule()).overlay(Capsule().stroke(DesignTheme.border))
        }.layoutPriority(1)
    }
}

struct ModelPickerSheet: View {
    @EnvironmentObject var settings: SettingsStore
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationStack {
            List {
                if settings.availableModels.isEmpty { Text(settings.isLoadingModels ? "Загрузка моделей..." : "Модели не загружены. Проверьте Base URL и ключ в настройках.").font(.subheadline).foregroundStyle(.secondary) }
                ForEach(settings.availableModels) { m in Button { settings.selectedModel = m.id; dismiss() } label: { HStack { Text(m.id).lineLimit(2).font(.subheadline); Spacer(); if settings.selectedModel == m.id { Image(systemName: "checkmark").foregroundStyle(DesignTheme.primary) } } } }
            }
            .navigationTitle("Выбрать модель").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Обновить") { Task { await APIClient.fetchModels(settings: settings) } } }; ToolbarItem(placement: .topBarTrailing) { Button("Готово") { dismiss() } } }
            .task { if settings.availableModels.isEmpty { await APIClient.fetchModels(settings: settings) } }
        }
    }
}

struct HistoryView: View {
    @EnvironmentObject var store: ChatStore
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    @State private var renameSession: ChatSession?
    @State private var renameText = ""
    var filtered: [ChatSession] { let list = store.sessions.sorted { ($0.isPinned ? 0 : 1, $0.createdAt) > ($1.isPinned ? 0 : 1, $1.createdAt) }; if searchText.isEmpty { return list }; return list.filter { $0.title.localizedCaseInsensitiveContains(searchText) || $0.messages.contains { $0.content.localizedCaseInsensitiveContains(searchText) } } }
    var body: some View {
        NavigationStack {
            List {
                ForEach(filtered) { s in
                    Button { store.currentId = s.id; dismiss() } label: { VStack(alignment: .leading, spacing: 4) { HStack { if s.isPinned { Image(systemName: "pin.fill").font(.caption).foregroundStyle(DesignTheme.primary) }; Text(s.title).bold().lineLimit(1); Spacer(); Text("\(s.messages.count)").font(.caption2).foregroundStyle(.secondary) }; if !s.lastPreview.isEmpty { Text(s.lastPreview).font(.caption).foregroundStyle(.secondary).lineLimit(1) }; Text(s.createdAt, style: .date).font(.caption).foregroundStyle(.secondary) } }
                    .swipeActions(edge: .leading) { Button { store.togglePin(s.id) } label: { Label(s.isPinned ? "Открепить" : "Закрепить", systemImage: "pin") }.tint(DesignTheme.primary) }
                    .swipeActions(edge: .trailing) { Button(role: .destructive) { store.delete(s.id) } label: { Label("Удалить", systemImage: "trash") }; Button { renameSession = s; renameText = s.title } label: { Label("Переименовать", systemImage: "pencil") }.tint(.blue) }
                }
            }
            .searchable(text: $searchText, prompt: "Поиск по чатам")
            .navigationTitle("История чатов")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Новый") { _ = store.newChat(); dismiss() } } }
            .alert("Переименовать чат", isPresented: Binding(get: { renameSession != nil }, set: { if !$0 { renameSession = nil } })) { TextField("Название", text: $renameText); Button("Сохранить") { if let s = renameSession { store.rename(s.id, renameText) }; renameSession = nil }; Button("Отмена", role: .cancel) { renameSession = nil } }
        }
    }
}
