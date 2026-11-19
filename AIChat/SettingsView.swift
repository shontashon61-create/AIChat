import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var store: ChatStore
    @Environment(\.dismiss) var dismiss
    @State private var showKey = false
    @State private var testResult: String?
    @State private var exportURL: URL?
    @State private var showShare = false
    let presets: [(String, String)] = [("Помощник", "Ты — полезный ИИ-ассистент. Отвечай на русском, кратко и по делу."), ("Программист", "Ты — опытный программист. Пиши чистый код, объясняй коротко, указывай файлы и строки."), ("Переводчик", "Ты — переводчик. Переводи точно, сохраняй стиль и смысл оригинала."), ("Учитель", "Ты — терпеливый учитель. Объясняй простыми словами, шаг за шагом, с примерами.")]
    var body: some View {
        NavigationStack {
            Form {
                Section("Подключение") {
                    TextField("API Base URL", text: $settings.baseURL).autocorrectionDisabled().textInputAutocapitalization(.never).keyboardType(.URL)
                    HStack { if showKey { TextField("API Key", text: $settings.apiKey) } else { SecureField("API Key", text: $settings.apiKey) }; Button { showKey.toggle() } label: { Image(systemName: showKey ? "eye.slash" : "eye") } }
                    Button { Task { await APIClient.fetchModels(settings: settings); testResult = settings.connectionOK == true ? "Подключение OK, моделей: \(settings.availableModels.count)" : (settings.modelsError ?? "Ошибка") } } label: { HStack { if settings.isLoadingModels { ProgressView() }; Text("Проверить подключение и обновить модели") } }
                    if let r = testResult { Text(r).font(.caption).foregroundStyle(settings.connectionOK == true ? .green : .red) }
                    if let e = settings.modelsError { Text(e).foregroundStyle(.red).font(.caption) }
                    Picker("Модель", selection: $settings.selectedModel) { Text("Не выбрана").tag(""); ForEach(settings.availableModels) { Text($0.id).tag($0.id) } }
                }
                Section("Системный промт") {
                    ScrollView(.horizontal, showsIndicators: false) { HStack { ForEach(presets, id: \.0) { p in Button(p.0) { settings.systemPrompt = p.1 }.buttonStyle(.bordered).font(.caption) } } }
                    TextEditor(text: $settings.systemPrompt).frame(minHeight: 120)
                    Button("Сбросить промт") { settings.systemPrompt = presets[0].1 }
                }
                Section("Генерация и размышление") {
                    Picker("Размышление", selection: $settings.reasoningEffort) { Text("Выкл").tag("off"); Text("Низкое").tag("low"); Text("Среднее").tag("medium"); Text("Высокое").tag("high") }
                    Toggle("Показывать ход мыслей ИИ", isOn: $settings.showThinking)
                    Stepper("Макс. токенов: \(settings.maxTokens)", value: $settings.maxTokens, in: 256...8192, step: 256)
                    Stepper("Контекст: последние \(settings.contextLimit) сообщ.", value: $settings.contextLimit, in: 4...50, step: 2)
                    HStack { Text("Температура"); Slider(value: $settings.temperature, in: 0...2, step: 0.1); Text(String(format: "%.1f", settings.temperature)) }
                }
                Section("Внешний вид и голос") {
                    Toggle("Тёмная тема", isOn: $settings.isDark)
                    Toggle("Озвучка ответов", isOn: $settings.voiceEnabled)
                    Toggle("Озвучивать автоматически", isOn: $settings.autoSpeak)
                }
                Section("Данные") {
                    Button("Экспорт всех чатов (файл)") { exportURL = store.exportURL(); showShare = exportURL != nil }
                    Button(role: .destructive) { store.sessions.removeAll(); store.currentId = nil; store.save(); _ = store.newChat() } label: { Text("Удалить все чаты") }
                }
                Section { Text("Поддерживается любой OpenAI-совместимый API: /models и /chat/completions со стримингом, reasoning_content, vision-картинками. Видео отправляется как текстовая пометка — модель его не видит как кадры.").font(.caption).foregroundStyle(.secondary) }
            }
            .navigationTitle("Настройки")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Готово") { dismiss() } } }
            .sheet(isPresented: $showShare) { if let u = exportURL { ShareSheet(url: u) } }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: [url], applicationActivities: nil) }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
