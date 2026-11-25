import SwiftUI
import UIKit

struct ChatView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var store: ChatStore
    @State var session: ChatSession
    @State private var input = ""
    @State private var attachments: [Attachment] = []
    @State private var isSending = false
    @State private var retryAttempt = 0
    @State private var retryDelay = 0
    @State private var errorText: String?
    @State private var showPicker = false
    @State private var showCamera = false
    @State private var showAttachMenu = false
    @State private var previewAttachment: Attachment?
    @State private var isAtBottom = true
    @FocusState private var inputFocused: Bool
    @State private var streamTask: Task<Void, Never>?
    @State private var emptyMeme = Mellstroy.randomEmpty()
    @State private var emptyJoke = Mellstroy.jokes.randomElement() ?? ""
    @StateObject private var speaker = VoiceSpeaker()
    var body: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 0) {
                    if settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        HStack {
                            Image(systemName: "key.fill")
                            Text("Добавьте API-ключ в настройках, иначе запросы не уйдут.").font(.caption)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color.orange.opacity(0.15))
                    }
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            if session.messages.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: settings.mellstroyMode ? (Mellstroy.icons["crown"] ?? "crown.fill") : "sparkles").font(.system(size: 40)).foregroundStyle(settings.mellstroyMode ? Mellstroy.accent : Color.primary)
                                    Text(settings.mellstroyMode ? emptyMeme.0 : "Чем помочь?").font(.title2.bold())
                                    Text(settings.mellstroyMode ? emptyMeme.1 : (settings.selectedModel.isEmpty ? "Выберите модель в меню сверху" : settings.selectedModel)).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                                    if settings.mellstroyMode { Text(emptyJoke).font(.caption2).foregroundStyle(Mellstroy.accent2) }
                                    Text(settings.selectedModel.isEmpty ? "Выберите модель в меню сверху" : settings.selectedModel).font(.caption2).foregroundStyle(.secondary)
                                    HStack(spacing: 8) {
                                        Button("Тест") { settings.schoolFormat = "Выбор ответа (А/Б/В/Г)"; inputFocused = true }
                                        Button("По шагам") { settings.schoolFormat = "Пошаговое решение"; inputFocused = true }
                                        Button("Объясни") { settings.schoolFormat = "Объяснение как учитель"; inputFocused = true }
                                    }
                                    .font(.caption)
                                    .buttonStyle(.bordered)
                                }
                                .padding(.vertical, 32)
                            }
                            ForEach(session.messages) { msg in MessageRow(message: msg, onRegenerate: regenerate, onDelete: { deleteMessage(msg) }, onEdit: { editMessage(msg) }, onPreview: { previewAttachment = $0 }, onSpeak: { speaker.speak($0) }) }
                            if isSending {
                                HStack {
                                    ProgressView()
                                    Text(statusText).font(.caption).foregroundStyle(.secondary)
                                    Spacer()
                                    Button("Стоп") { stopGeneration() }.font(.caption.bold()).foregroundStyle(.red)
                                }
                                .padding(.leading, 4)
                            }
                            Color.clear.frame(height: 1).id("bottom").onAppear { isAtBottom = true }.onDisappear { isAtBottom = false }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: session.messages.count) { _ in if isAtBottom { scrollToLast(proxy) } }
                    .onChange(of: session.messages.last?.content ?? "") { _ in if isAtBottom { scrollToLast(proxy) } }
                    if settings.schoolMode { schoolBar }
                    attachmentPreview
                    inputBar
                }
                if !isAtBottom && !session.messages.isEmpty {
                    Button { withAnimation { proxy.scrollTo("bottom", anchor: .bottom); isAtBottom = true } } label: { Image(systemName: "arrow.down").font(.callout.bold()).padding(10).background(Color(.secondarySystemBackground)).clipShape(Circle()).shadow(radius: 4) }
                        .padding(.trailing, 16)
                        .padding(.bottom, 76)
                }
            }
        }
        .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Готово") { inputFocused = false } } }
        .confirmationDialog("Вложение", isPresented: $showAttachMenu) { Button("Фото из галереи") { showPicker = true }; Button("Снять фото") { showCamera = true }; Button("Отмена", role: .cancel) {} }
        .sheet(isPresented: $showPicker) { PhotoPicker(onPick: addAttachment) }
        .sheet(isPresented: $showCamera) { CameraPicker(onPick: addAttachment) }
        .sheet(item: $previewAttachment) { a in AttachmentPreviewView(attachment: a) }
        .alert("Ошибка", isPresented: Binding(get: { errorText != nil }, set: { if !$0 { errorText = nil } })) { Button("OK") {} } message: { Text(errorText ?? "") }
        .onChange(of: store.currentId) { _ in if let s = store.sessions.first(where: { $0.id == store.currentId }) { session = s; isAtBottom = true } }
    }
    var statusText: String {
        if retryAttempt > 1 {
            if retryDelay > 0 { return "Повтор " + String(retryAttempt) + "/15, пауза " + String(retryDelay) + " с..." }
            return "Повтор " + String(retryAttempt) + "/15..."
        }
        return "ИИ печатает..."
    }
    func scrollToLast(_ proxy: ScrollViewProxy) { if let last = session.messages.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } } }
    var schoolBar: some View {
        HStack(spacing: 8) {
            Menu { ForEach(SchoolSkills.subjects, id: \.self) { s in Button { settings.schoolSubject = s } label: { Label(s, systemImage: settings.schoolSubject == s ? "checkmark" : "book") } } } label: { Label(settings.schoolSubject, systemImage: "graduationcap").font(.caption.bold()) }
            Menu { ForEach(SchoolSkills.formats, id: \.self) { f in Button { settings.schoolFormat = f } label: { Label(f, systemImage: settings.schoolFormat == f ? "checkmark" : "text.alignleft") } } } label: { Label(settings.schoolFormat, systemImage: "list.bullet").font(.caption).lineLimit(1) }
            Spacer()
        }.padding(.horizontal).padding(.vertical, 6).background(Color(.secondarySystemBackground).opacity(0.6))
    }
    var attachmentPreview: some View {
        Group {
            if !attachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) { HStack { ForEach(attachments) { a in ZStack(alignment: .topTrailing) { Button { previewAttachment = a } label: { AttachmentThumbView(attachment: a) }; Button { attachments.removeAll { $0.id == a.id } } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.white, .black.opacity(0.6)) }.offset(x: 6, y: -6) } } }.padding(.horizontal) }.padding(.vertical, 6)
            }
        }
    }
    var inputBar: some View {
        HStack(alignment: .bottom, spacing: 6) {
            Button { showAttachMenu = true } label: { Image(systemName: "plus.circle.fill").font(.title2) }
            TextField("Сообщение...", text: $input, axis: .vertical).focused($inputFocused).lineLimit(1...5).padding(10).background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
            if isSending { Button { stopGeneration() } label: { Image(systemName: "stop.circle.fill").font(.title2).foregroundStyle(.red) } } else { Button { send() } label: { Image(systemName: "arrow.up.circle.fill").font(.title2) }.disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && attachments.isEmpty) }
        }.padding(.horizontal).padding(.vertical, 10).overlay(alignment: .top) { Divider() }
    }
    func addAttachment(_ data: Data, _ kind: String, _ mime: String) {
        if data.count > 15_000_000 { errorText = "Файл слишком большой. Максимум 15 МБ."; return }
        if attachments.count >= 5 { errorText = "Максимум 5 вложений за раз."; return }
        attachments.append(Attachment(kind: kind, fileName: "file-" + String(attachments.count + 1) + ".jpg", mimeType: mime, base64: data.base64EncodedString()))
    }
    func send() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !isSending, (!text.isEmpty || !attachments.isEmpty) else { return }
        guard !settings.selectedModel.isEmpty else { errorText = "Сначала выберите модель в меню сверху или в настройках."; return }
        let baseText = text.isEmpty ? "Реши задание с фото" : text
        let photoNote = attachments.count > 1 ? "\nФото несколько: решай все как один список по порядку фото, нумеруй сам №1, №2." : ""
        let content = attachments.isEmpty ? baseText : baseText + photoNote + "\nВажно: если ты не уверен на 90%, что на фото именно это задание и ты точно прочитал его номер, условие, числа и все варианты ответа — не решай догадку. Напиши: «Непонятно именно это задание» и укажи, что именно нечитаемо и какой угол или часть переснять крупнее."
        session.messages.append(ChatMessage(role: "user", content: content, attachments: attachments))
        if session.title == "Новый чат" || session.title.isEmpty { let t = text.isEmpty ? "Фото" : text; session.title = t.count > 36 ? String(t.prefix(36)) + "…" : t }
        let hadAttachments = !attachments.isEmpty
        store.update(session); input = ""; attachments = []; isAtBottom = true
        if settings.offlineMode, !hadAttachments, let cached = OfflineCache.loadAnswer(for: content) { session.messages.append(ChatMessage(role: "assistant", content: cached + "\n\n(офлайн: ответ из прошлых решений)", model: settings.selectedModel)); store.update(session); return }
        startAssistantReply()
    }
    func isRetryable(_ error: Error) -> Bool {
        if let api = error as? APIError { return api.retryable }
        if let url = error as? URLError {
            switch url.code {
            case .timedOut, .networkConnectionLost, .notConnectedToInternet, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed, .secureConnectionFailed, .badServerResponse: return true
            default: return false
            }
        }
        return true
    }
    func friendlyError(_ error: Error?) -> String {
        guard let e = error else { return "Неизвестная ошибка. Попробуйте ещё раз." }
        let raw = e.localizedDescription
        if raw.contains("401") { return "Неверный API-ключ (401). Проверьте ключ в Настройках." }
        if raw.contains("404") { return "Модель не найдена (404). Выберите другую модель в меню сверху." }
        if raw.contains("429") { return "Слишком много запросов (429). Сервер перегружен, подождите минуту." }
        if raw.contains("402") { return "Лимит провайдера исчерпан (402). Проверьте баланс PositionAPI." }
        if isRetryable(e) { return "Не удалось после 15 попыток: " + raw }
        return "Ошибка: " + raw + ". Проверьте Base URL, ключ и модель."
    }
    func startAssistantReply() {
        isSending = true
        retryAttempt = 1
        retryDelay = 0
        session.messages.append(ChatMessage(role: "assistant", content: "", model: settings.selectedModel))
        store.update(session)
        let history = Array(session.messages.dropLast())
        streamTask = Task {
            var finalError: Error?
            for attempt in 1...15 {
                await MainActor.run {
                    retryAttempt = attempt
                    if attempt > 1 {
                        retryDelay = min(8, 1 << (attempt - 2))
                        if let idx = session.messages.indices.last, session.messages[idx].content.isEmpty { session.messages[idx].thinking = nil; session.messages[idx].isError = false }
                    }
                }
                do {
                    try await APIClient.streamChat(settings: settings, messages: history, onContent: { chunk in DispatchQueue.main.async { guard let idx = session.messages.indices.last else { return }; session.messages[idx].content += chunk } }, onThinking: { chunk in DispatchQueue.main.async { guard let idx = session.messages.indices.last else { return }; session.messages[idx].thinking = (session.messages[idx].thinking ?? "") + chunk } })
                    let spoken = await MainActor.run { store.update(session); isSending = false; retryAttempt = 0; retryDelay = 0; return session.messages.last?.content ?? "" }
                    if settings.offlineMode, !spoken.isEmpty, let q = history.last(where: { $0.role == "user" })?.content { OfflineCache.saveAnswer(spoken, for: q) }
                    if settings.voiceMode, !spoken.isEmpty { speaker.speak(spoken) }
                    return
                } catch {
                    if Task.isCancelled { await MainActor.run { store.update(session); isSending = false; retryAttempt = 0; retryDelay = 0 }; return }
                    finalError = error
                    let partial = await MainActor.run { session.messages.last?.content.isEmpty == false }
                    if !isRetryable(error) || partial || attempt >= 15 { break }
                    let delay = Double(min(8, 1 << (attempt - 1)))
                    await MainActor.run { retryDelay = Int(delay) }
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
            await MainActor.run {
                if let idx = session.messages.indices.last {
                    if session.messages[idx].content.isEmpty { session.messages[idx].content = friendlyError(finalError) }
                    session.messages[idx].isError = true
                }
                store.update(session); isSending = false; retryAttempt = 0; retryDelay = 0
            }
        }
    }
    func stopGeneration() { streamTask?.cancel(); streamTask = nil; isSending = false; retryAttempt = 0; retryDelay = 0; speaker.stop(); store.update(session) }
    func regenerate() {
        guard !isSending else { return }
        while session.messages.last?.role == "assistant" { session.messages.removeLast() }
        guard session.messages.last?.role == "user" else { return }
        store.update(session); startAssistantReply()
    }
    func deleteMessage(_ msg: ChatMessage) { session.messages.removeAll { $0.id == msg.id }; store.update(session) }
    func editMessage(_ msg: ChatMessage) {
        guard msg.role == "user", let idx = session.messages.firstIndex(where: { $0.id == msg.id }) else { return }
        input = msg.content
        session.messages.removeSubrange(idx...)
        store.update(session)
    }
}

struct AttachmentThumbView: View {
    let attachment: Attachment
    var body: some View {
        Group {
            if attachment.kind == "image", let data = Data(base64Encoded: attachment.base64), let ui = UIImage(data: data) { Image(uiImage: ui).resizable().scaledToFill().frame(width: 72, height: 72).clipped().cornerRadius(12) }
            else { VStack { Image(systemName: "photo"); Text(String(format: "%.1f МБ", attachment.sizeMB)).font(.caption2) }.frame(width: 72, height: 72).background(Color(.secondarySystemBackground)).cornerRadius(12) }
        }
    }
}

struct AttachmentPreviewView: View {
    let attachment: Attachment
    @Environment(\.dismiss) var dismiss
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    var body: some View {
        NavigationStack {
            Group {
                if attachment.kind == "image", let data = Data(base64Encoded: attachment.base64), let ui = UIImage(data: data) { Image(uiImage: ui).resizable().scaledToFit().padding().scaleEffect(scale).gesture(MagnificationGesture().onChanged { v in scale = max(1, min(4, lastScale * v)) }.onEnded { _ in lastScale = scale }).onTapGesture(count: 2) { scale = scale > 1 ? 1 : 2; lastScale = scale } }
                else { VStack(spacing: 12) { Image(systemName: "photo").font(.largeTitle); Text(attachment.fileName) } }
            }.navigationTitle(attachment.fileName).toolbar { ToolbarItem(placement: .topBarLeading) { if attachment.kind == "image", let data = Data(base64Encoded: attachment.base64), let ui = UIImage(data: data) { Button("Сохранить") { UIImageWriteToSavedPhotosAlbum(ui, nil, nil, nil) } } }; ToolbarItem(placement: .topBarTrailing) { Button("Закрыть") { dismiss() } } }
        }
    }
}

struct MessageRow: View {
    @State private var showThinking = false
    @State private var copied = false
    let message: ChatMessage
    let onRegenerate: () -> Void
    let onDelete: () -> Void
    let onEdit: () -> Void
    let onPreview: (Attachment) -> Void
    let onSpeak: (String) -> Void
    var body: some View {
        VStack(alignment: message.role == "user" ? .trailing : .leading, spacing: 6) {
            if let thinking = message.thinking, !thinking.isEmpty, message.role == "assistant" { DisclosureGroup("Ход мыслей ИИ", isExpanded: $showThinking) { Text(thinking).font(.caption).foregroundStyle(.secondary) }.padding(10).background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12)) }
            ForEach(message.attachments) { a in Button { onPreview(a) } label: { AttachmentThumbView(attachment: a) } }
            Group { if message.role == "assistant" { MarkdownView(text: message.content.isEmpty ? "..." : message.content) } else { Text(message.content.isEmpty ? "..." : message.content) } }
            .padding(12).background(message.role == "user" ? Color.accentColor : Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16)).foregroundStyle(message.role == "user" ? .white : .primary).frame(maxWidth: .infinity, alignment: message.role == "user" ? .trailing : .leading).textSelection(.enabled)
            .contextMenu { Button { UIPasteboard.general.string = message.content } label: { Label("Копировать", systemImage: "doc.on.doc") }; if message.role == "user" { Button(action: onEdit) { Label("Изменить", systemImage: "pencil") } }; Button(role: .destructive, action: onDelete) { Label("Удалить", systemImage: "trash") } }
            HStack(spacing: 10) {
                Text(message.createdAt, style: .time).font(.caption2).foregroundStyle(.secondary)
                if message.role == "assistant" && !message.content.isEmpty { Button { UIPasteboard.general.string = message.content; copied = true; DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copied = false } } label: { Image(systemName: copied ? "checkmark" : "doc.on.doc") }; Button { onSpeak(message.content) } label: { Image(systemName: "speaker.wave.2") }; Button(action: onRegenerate) { Image(systemName: "arrow.clockwise") }; if let m = message.model { Text(m).font(.caption2).foregroundStyle(.secondary).lineLimit(1) } }
                if message.role == "user" { Button { UIPasteboard.general.string = message.content } label: { Image(systemName: "doc.on.doc") }; Button(action: onEdit) { Image(systemName: "pencil") }; Button(action: onDelete) { Image(systemName: "trash") } }
                if message.isError { Button("Повторить") { onRegenerate() }.font(.caption.bold()).foregroundStyle(.red) }
            }.font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: message.role == "user" ? .trailing : .leading)
    }
}
