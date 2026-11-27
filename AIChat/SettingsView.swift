import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var store: ChatStore
    @Environment(\.dismiss) var dismiss
    @State private var showKey = false
    @State private var testResult: String?
    @State private var showDeleteAllConfirm = false
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
                Section("Школьный режим") {
                    Toggle("Включён (6 класс)", isOn: $settings.schoolMode)
                    Toggle("Режим «Вся контрольная»", isOn: $settings.examMode)
                    Toggle("Проверка второй моделью", isOn: $settings.verifyAnswers)
                    if settings.verifyAnswers { Picker("Проверяющая модель", selection: $settings.checkerModel) { Text("Авто (другая модель)").tag(""); ForEach(settings.availableModels.filter { $0.id != settings.selectedModel }) { Text($0.id).tag($0.id) } } }
                    Picker("Предмет", selection: $settings.schoolSubject) { ForEach(SchoolSkills.subjects, id: \.self) { Text($0).tag($0) } }
                    Picker("Формат", selection: $settings.schoolFormat) { ForEach(SchoolSkills.formats, id: \.self) { Text($0).tag($0) } }
                    Text("Режимы ответов — только три: «Краткие ответы» — только ответ, «Ответы с решением» — шаги и ответ, «Подробные ответы» — объяснение, шаги и ответ. Для кратких температура автоматически не выше 0.2.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Голос, офлайн, ЦДЗ как человек") {
                    Toggle("Голосовые ответы", isOn: $settings.voiceMode)
                    Toggle("ЦДЗ как человек (паузы 8-25 сек)", isOn: $settings.humanCDZ)
                    Toggle("Офлайн: формулы, оценки и прошлые ответы без сети", isOn: $settings.offlineMode)
                    Text("База ЦДЗ: решённое задание сохраняется локально и в следующий раз берётся за секунду, без запроса к ИИ.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Меллстрой") {
                    Toggle("Тема Меллстроя", isOn: $settings.mellstroyMode)
                    Picker("Обои чата", selection: $settings.mellWallpaper) { ForEach(Mellstroy.wallpapers, id: \.self) { Text($0).tag($0) } }
                    Text("Аватарка с Меллом, все иконки, мемы на обоях и пустом экране, оранжево-красный акцент. На ответы и правило 90% не влияет.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Системный промт") { TextEditor(text: $settings.systemPrompt).frame(minHeight: 120) }
                Section("Генерация") { HStack { Text("Температура"); Slider(value: $settings.temperature, in: 0...2, step: 0.1); Text(String(format: "%.1f", settings.temperature)) } }
                Section("Данные") { Button(role: .destructive) { showDeleteAllConfirm = true } label: { Text("Удалить все чаты") } }
                Text("Один OpenAI-совместимый API: /models и /chat/completions со стримингом. Модели Claude, GPT, Qwen, Gemini и DeepSeek берутся из списка провайдера. При ошибке отправка повторяется до 15 раз.").font(.caption).foregroundStyle(.secondary)
            }
            .navigationTitle("Настройки")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Готово") { dismiss() } } }
            .alert("Удалить все чаты?", isPresented: $showDeleteAllConfirm) { Button("Удалить всё", role: .destructive) { store.deleteAll() }; Button("Отмена", role: .cancel) {} } message: { Text("Это действие нельзя отменить.") }
        }
    }
}
