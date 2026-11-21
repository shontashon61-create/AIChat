import SwiftUI
import UIKit

struct ChatView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var store: ChatStore
    @State var session: ChatSession
    @State private var input = ""
    @State private var attachments: [Attachment] = []
    @State private var isSending = false
    @State private var errorText: String?
    @State private var showPicker = false
    @State private var showCamera = false
    @State private var showAttachMenu = false
    @State private var showSearch = false
    @State private var searchText = ""
    @State private var previewAttachment: Attachment?
    @State private var showModelSheet = false
    @State private var isGeneratingImage = false
    @State private var pendingPhotoEdit = false
    @FocusState private var inputFocused: Bool
    @StateObject private var speech = SpeechManager()
    @State private var streamTask: Task<Void, Never>?
    var visibleMessages: [ChatMessage] { searchText.isEmpty ? session.messages : session.messages.filter { $0.content.localizedCaseInsensitiveContains(searchText) } }
    var body: some View {
        VStack(spacing: 0) {
            if showSearch { TextField("Поиск в этом чате...", text: $searchText).textFieldStyle(.roundedBorder).padding(.horizontal).padding(.top, 8) }
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 14) {
                        if session.messages.isEmpty { emptyView }
                        ForEach(visibleMessages) { msg in
                            MessageRow(message: msg, onRegenerate: regenerate, onDelete: { deleteMessage(msg) }, onEdit: { editMessage(msg) }, onPreview: { previewAttachment = $0 }, onAnnotate: { annotateAnswers(for: msg) }, onVisualize: { visualizeAnswer(msg) }).messageAppear()
                        }
                        if isSending { HStack { TypingDots(); Text("ИИ печатает...").font(.caption).foregroundStyle(.secondary); Spacer(); Button("Стоп") { stopGeneration() }.font(.caption.bold()).foregroundStyle(.red) }.padding(.leading, 4) }
                    }.padding(.horizontal).padding(.vertical, 12)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: session.messages.count) { _ in scrollToLast(proxy) }
                .onChange(of: session.messages.last?.content ?? "") { _ in scrollToLast(proxy) }
            }
            if session.messages.isEmpty { quickPrompts }
            attachmentPreview
            inputBar
        }
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showSearch.toggle(); if !showSearch { searchText = "" } } label: { Image(systemName: "magnifyingglass") } } }
        .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Готово") { inputFocused = false } } }
        .sheet(isPresented: $showModelSheet) { ModelPickerSheet() }
        .sheet(isPresented: $showPicker) { PhotoVideoPicker(onPick: addAttachment) }
        .sheet(isPresented: $showCamera) { CameraPicker(onPick: addAttachment) }
        .sheet(item: $previewAttachment) { a in AttachmentPreviewView(attachment: a) }
        .confirmationDialog("Добавить", isPresented: $showAttachMenu) { Button("Фото или видео из галереи") { showPicker = true }; Button("Снять фото или видео") { showCamera = true }; Button("Сгенерировать фото") { Task { await generateImage() } }; Button("Отмена", role: .cancel) {} }
        .alert("Ошибка", isPresented: Binding(get: { errorText != nil }, set: { if !$0 { errorText = nil } })) { Button("OK") {} } message: { Text(errorText ?? "") }
        .onChange(of: store.currentId) { _ in if let s = store.sessions.first(where: { $0.id == store.currentId }) { session = s } }
        .onChange(of: speech.transcript) { v in input = v }
        .onChange(of: speech.errorText ?? "") { v in if !v.isEmpty { errorText = v; speech.errorText = nil } }
        .onDisappear { speech.stop(); Speaker.shared.stop() }
    }
    func scrollToLast(_ proxy: ScrollViewProxy) { if let last = visibleMessages.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } } }
    var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles").font(.system(size: 44)).foregroundStyle(DesignTheme.primary).pulseIcon()
            Text("Чем помочь?").font(.title2.bold())
            if settings.selectedModel.isEmpty {
                Button("Выбрать модель") { showModelSheet = true }.buttonStyle(PrimaryButtonStyle())
                Text("Без модели сообщения не отправляются").font(.caption).foregroundStyle(.secondary)
            } else {
                Text(settings.selectedModel).font(.caption).padding(.horizontal, 10).padding(.vertical, 4).background(DesignTheme.chip, in: Capsule()).foregroundStyle(.secondary)
            }
            Text("Спроси, попроси написать текст или код, пришли фото или видео, скажи «сделай дз» или «нарисуй».").multilineTextAlignment(.center).foregroundStyle(.secondary).font(.subheadline)
        }.padding(.vertical, 32).padding(.horizontal)
    }
    var quickPrompts: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150, maximum: 280), spacing: 8)], spacing: 8) {
            ForEach([("Объясни простыми словами", "text.bubble"), ("Напиши код", "chevron.left.forwardslash.chevron.right"), ("Составь план", "list.bullet"), ("Проверь текст", "checkmark.circle"), ("Сделай дз", "pencil.and.outline"), ("Нарисуй картинку", "photo"), ("Визуализируй ответ", "photo.badge.plus"), ("Переведи текст", "globe")], id: \.0) { p in
                Button { Haptic.tap(); if settings.selectedModel.isEmpty { showModelSheet = true } else { input = p.0; send() } } label: { HStack(alignment: .top, spacing: 6) { Image(systemName: p.1).font(.caption); Text(p.0).lineLimit(2).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true).minimumScaleFactor(0.85) }.frame(maxWidth: .infinity, alignment: .leading) }.padding(.horizontal, 10).padding(.vertical, 10).background(DesignTheme.chip, in: RoundedRectangle(cornerRadius: 12)).font(.callout)
            }
        }.padding(.horizontal).padding(.bottom, 8)
    }
    var attachmentPreview: some View {
        Group {
            if !attachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(attachments) { a in
                            ZStack(alignment: .topTrailing) {
                                Button { previewAttachment = a } label: { AttachmentThumbView(attachment: a) }
                                Button { attachments.removeAll { $0.id == a.id } } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.white, .black.opacity(0.6)) }.offset(x: 6, y: -6)
                            }
                        }
                    }.padding(.horizontal)
                }.padding(.vertical, 6)
            }
        }
    }
    var inputBar: some View {
        VStack(spacing: 4) {
            HStack(alignment: .bottom, spacing: 6) {
                Button { showAttachMenu = true } label: { Image(systemName: "plus.circle.fill").font(.title2).foregroundStyle(DesignTheme.primary) }
                TextField("Сообщение...", text: $input, axis: .vertical).focused($inputFocused).lineLimit(1...5).padding(10).background(DesignTheme.chip, in: RoundedRectangle(cornerRadius: 18))
                Button { if speech.isRecording { speech.stop() } else { speech.transcript = ""; speech.start() } } label: { Image(systemName: speech.isRecording ? "mic.fill" : "mic").font(.title3).foregroundStyle(speech.isRecording ? .red : .primary) }
                if isSending { Button { stopGeneration() } label: { Image(systemName: "stop.circle.fill").font(.title2).foregroundStyle(.red) } } else { Button { send() } label: { Image(systemName: "arrow.up.circle.fill").font(.title2).foregroundStyle(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && attachments.isEmpty ? .gray : DesignTheme.primary) }.disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && attachments.isEmpty) }
            }
            if !input.isEmpty { HStack { Spacer(); Text("\(input.count) симв.").font(.caption2).foregroundStyle(.secondary) } }
        }.padding(.horizontal).padding(.vertical, 10).background(DesignTheme.background)
    }
    func addAttachment(_ data: Data, _ kind: String, _ mime: String) {
        if data.count > 15_000_000 { errorText = "Файл слишком большой. Максимум 15 МБ, сейчас \(String(format: "%.1f", Double(data.count)/1024/1024)) МБ."; return }
        if attachments.count >= 5 { errorText = "Максимум 5 вложений за раз."; return }
        let ext = kind == "image" ? "jpg" : "mp4"
        attachments.append(Attachment(kind: kind, fileName: "file-\(attachments.count + 1).\(ext)", mimeType: mime, base64: data.base64EncodedString()))
    }
    func imagePromptsFromReply(_ text: String) -> [String] {
        var out: [String] = []; var rest = text[...]
        while let s = rest.range(of: "[IMAGE:"), let e = rest.range(of: "]", range: s.upperBound..<rest.endIndex) { let p = String(rest[s.upperBound..<e.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines); if !p.isEmpty { out.append(p) }; rest = rest[e.upperBound...] }
        return out
    }
    func imagePromptFromReply(_ text: String) -> String? { imagePromptsFromReply(text).first }
    func generateImage(promptOverride: String? = nil) async {
        let prompt = promptOverride ?? input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { errorText = "Напиши описание картинки в поле ввода."; return }
        isGeneratingImage = true
        session.messages.append(ChatMessage(role: "user", content: prompt))
        session.messages.append(ChatMessage(role: "assistant", content: "Рисую картинку...", model: settings.imageModel))
        store.update(session); input = ""
        do {
            let img = try await APIClient.generateImage(settings: settings, prompt: prompt)
            if let idx = session.messages.indices.last { session.messages[idx].content = "Готово: " + prompt; session.messages[idx].attachments = [img] }
            store.update(session)
        } catch {
            if let idx = session.messages.indices.last { session.messages[idx].content = "Не удалось сгенерировать фото: " + error.localizedDescription; session.messages[idx].isError = true }
            store.update(session)
        }
        isGeneratingImage = false
    }
    func isHomeworkRequest(_ t: String) -> Bool {
        let s = t.lowercased()
        return s.contains("сделай за меня дз") || s.contains("сделай дз") || s.contains("сделай домаш") || s.contains("реши дз") || s.contains("реши домаш") || s.contains("вставь ответы") || s.contains("сделай за меня") || s.contains("выполни дз") || s.contains("сделай домашку")
    }
    func isImageRequest(_ t: String) -> Bool {
        let s = t.lowercased()
        return s.contains("нарисуй") || s.contains("сгенерируй фото") || s.contains("сгенерируй картинку") || s.contains("сгенерируй изображ") || s.contains("создай картинку") || s.contains("создай фото") || s.contains("создай изображ") || s.contains("сделай картинку") || s.contains("сделай фото") || s.contains("покажи картинку") || s.contains("покажи фото") || s.contains("иллюстрац")
    }
    func isVisualizeRequest(_ t: String) -> Bool {
        let s = t.lowercased()
        return s.contains("визуализируй") || s.contains("визуализировать") || s.contains("визуализацию") || s.contains("покажи наглядно") || s.contains("нарисуй свой ответ") || s.contains("нарисуй схему")
    }
    func isVideoRequest(_ t: String) -> Bool {
        let s = t.lowercased()
        return s.contains("видео") && (s.contains("сгенерируй") || s.contains("создай") || s.contains("сделай"))
    }
    func send() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !isSending, (!text.isEmpty || !attachments.isEmpty) else { return }
        if isVideoRequest(text) { errorText = "Видео сгенерировать не могу: у провайдера нет endpoint для видео."; return }
        if isVisualizeRequest(text) && attachments.isEmpty { let source = session.messages.last(where: { $0.role == "assistant" })?.content ?? text; input = ""; Task { await generateImage(promptOverride: "Визуализация: " + String(source.prefix(600))) }; return }
        if isImageRequest(text) && attachments.isEmpty { Task { await generateImage() }; return }
        let hasPhotoNow = attachments.contains(where: { $0.kind == "image" })
        let hasPhotoBefore = session.messages.contains(where: { $0.attachments.contains(where: { $0.kind == "image" }) })
        let editIntent = isHomeworkRequest(text) || text.lowercased().contains("вставь") || text.lowercased().contains("отредактируй") || text.lowercased().contains("напиши на фото") || text.lowercased().contains("подчеркни") || text.lowercased().contains("исправь фото")
        pendingPhotoEdit = editIntent && (hasPhotoNow || hasPhotoBefore)
        guard !settings.selectedModel.isEmpty else { errorText = "Сначала выберите модель в меню сверху или в настройках."; return }
        let userMsg = ChatMessage(role: "user", content: text.isEmpty ? "Опиши вложение" : text, attachments: attachments)
        session.messages.append(userMsg)
        if session.title == "Новый чат" || session.title.isEmpty { session.title = String(text.prefix(36)).isEmpty ? "Фото / видео" : String(text.prefix(36)) }
        store.update(session); input = ""; attachments = []
        startAssistantReply()
    }
    func startAssistantReply() {
        BackgroundSupport.requestNotificationPermission()
        BackgroundSupport.shared.begin()
        isSending = true
        session.messages.append(ChatMessage(role: "assistant", content: "", model: settings.selectedModel))
        let history = Array(session.messages.dropLast())
        streamTask = Task {
            do {
                try await APIClient.streamChat(settings: settings, messages: history, onContent: { chunk in DispatchQueue.main.async { guard let idx = session.messages.indices.last else { return }; session.messages[idx].content += chunk } }, onThinking: { chunk in DispatchQueue.main.async { guard let idx = session.messages.indices.last else { return }; session.messages[idx].thinking = (session.messages[idx].thinking ?? "") + chunk } })
                await MainActor.run { store.update(session); isSending = false; BackgroundSupport.notifyAnswerReady(); BackgroundSupport.shared.end(); if let last = session.messages.last { let prompts = imagePromptsFromReply(last.content); if !prompts.isEmpty { for p in prompts { Task { await generateImage(promptOverride: p) } } } else if pendingPhotoEdit { annotateAnswers(for: last) } }; pendingPhotoEdit = false; if settings.autoSpeak, let last = session.messages.last, last.attachments.isEmpty { Speaker.shared.speak(last.content) } }
            } catch {
                await MainActor.run {
                    if Task.isCancelled { store.update(session); isSending = false; BackgroundSupport.shared.end(); return }
                    if let idx = session.messages.indices.last, session.messages[idx].content.isEmpty { session.messages[idx].content = "Ошибка: " + error.localizedDescription + ". Проверьте Base URL, ключ и модель в настройках."; session.messages[idx].isError = true } else { errorText = error.localizedDescription }
                    store.update(session); isSending = false; BackgroundSupport.shared.end()
                }
            }
        }
    }
    func annotateAnswers(for message: ChatMessage) {
        guard let userMsg = session.messages.reversed().first(where: { $0.attachments.contains(where: { $0.kind == "image" }) }) else { errorText = "Сначала пришли фото."; return }
        guard let imgAtt = userMsg.attachments.first(where: { $0.kind == "image" }), let data = Data(base64Encoded: imgAtt.base64), let ui = UIImage(data: data) else { return }
        let answers = ImageAnnotator.parseAnswers(message.content)
        guard !answers.isEmpty else { return }
        guard let annotated = ImageAnnotator.annotatedAttachment(from: ui, answers: answers) else { return }
        session.messages.append(ChatMessage(role: "assistant", content: "Готово — ответы вставлены в фото синей ручкой.", attachments: [annotated], model: settings.selectedModel))
        store.update(session)
    }
    func visualizeAnswer(_ message: ChatMessage) {
        let source = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty else { return }
        Task { await generateImage(promptOverride: "Визуализация: " + String(source.prefix(600))) }
    }
    func stopGeneration() { streamTask?.cancel(); streamTask = nil; isSending = false; store.update(session); BackgroundSupport.shared.end() }
    func regenerate() {
        guard !isSending else { return }
        while session.messages.last?.role == "assistant" { session.messages.removeLast() }
        guard session.messages.last?.role == "user" else { return }
        store.update(session); startAssistantReply()
    }
    func deleteMessage(_ msg: ChatMessage) { session.messages.removeAll { $0.id == msg.id }; store.update(session) }
    func editMessage(_ msg: ChatMessage) {
        guard let idx = session.messages.firstIndex(where: { $0.id == msg.id }) else { return }
        input = msg.content
        session.messages.removeSubrange(idx...)
        store.update(session)
    }
}

struct AttachmentThumbView: View {
    let attachment: Attachment
    var body: some View {
        Group {
            if attachment.kind == "image", let data = Data(base64Encoded: attachment.base64), let ui = UIImage(data: data) { Image(uiImage: ui).resizable().scaledToFill().frame(width: attachment.fileName.contains("generated") || attachment.fileName.contains("answered") ? 240 : 72, height: attachment.fileName.contains("generated") || attachment.fileName.contains("answered") ? 240 : 72).clipped().cornerRadius(12) }
            else { VStack { Image(systemName: "video.fill"); Text(String(format: "%.1f МБ", attachment.sizeMB)).font(.caption2) }.frame(width: 72, height: 72).background(DesignTheme.chip).cornerRadius(12) }
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
                if attachment.kind == "image", let data = Data(base64Encoded: attachment.base64), let ui = UIImage(data: data) { Image(uiImage: ui).resizable().scaledToFit().padding().scaleEffect(scale).gesture(MagnificationGesture().onChanged { v in scale = max(1, min(4, lastScale * v)) }.onEnded { _ in lastScale = scale }).onTapGesture(count: 2) { withAnimation(AppAnim.spring) { scale = scale > 1 ? 1 : 2; lastScale = scale } } }
                else { VStack(spacing: 12) { Image(systemName: "video.fill").font(.largeTitle); Text(attachment.fileName); Text(String(format: "%.1f МБ", attachment.sizeMB)).foregroundStyle(.secondary) } }
            }.navigationTitle(attachment.fileName).toolbar { ToolbarItem(placement: .topBarLeading) { if attachment.kind == "image", let data = Data(base64Encoded: attachment.base64), let ui = UIImage(data: data) { Button("Сохранить") { UIImageWriteToSavedPhotosAlbum(ui, nil, nil, nil); UIPasteboard.general.image = ui } } }; ToolbarItem(placement: .topBarTrailing) { Button("Закрыть") { dismiss() } } }
        }
    }
}

struct MessageRow: View {
    @EnvironmentObject var settings: SettingsStore
    @State private var showThinking = false
    @State private var copied = false
    let message: ChatMessage
    let onRegenerate: () -> Void
    let onDelete: () -> Void
    let onEdit: () -> Void
    let onPreview: (Attachment) -> Void
    let onAnnotate: () -> Void
    let onVisualize: () -> Void
    var body: some View {
        VStack(alignment: message.role == "user" ? .trailing : .leading, spacing: 6) {
            if let thinking = message.thinking, !thinking.isEmpty, settings.showThinking, message.role == "assistant" {
                DisclosureGroup("Ход мыслей ИИ", isExpanded: $showThinking) { Text(thinking).font(.caption).foregroundStyle(.secondary) }.padding(10).background(DesignTheme.chip, in: RoundedRectangle(cornerRadius: 12))
            }
            ForEach(message.attachments) { a in Button { onPreview(a) } label: { AttachmentThumbView(attachment: a) } }
            Group {
                if message.role == "assistant" { MarkdownView(text: message.content.isEmpty ? "..." : message.content) } else { Text(message.content.isEmpty ? "..." : message.content) }
            }.font(.system(size: settings.fontSize)).padding(12).background(message.role == "user" ? DesignTheme.primary : DesignTheme.chip, in: RoundedRectangle(cornerRadius: 16)).foregroundStyle(message.role == "user" ? DesignTheme.onPrimary : DesignTheme.text).frame(maxWidth: .infinity, alignment: message.role == "user" ? .trailing : .leading).textSelection(.enabled)
            .contextMenu { Button { UIPasteboard.general.string = message.content; Haptic.success() } label: { Label("Копировать полностью", systemImage: "doc.on.doc") }; if message.role == "assistant" { Button { Speaker.shared.speak(message.content) } label: { Label("Озвучить", systemImage: "speaker.wave.2") }; Button(action: onVisualize) { Label("Визуализировать", systemImage: "photo.badge.plus") }; Button(action: onAnnotate) { Label("Вставить ответы в фото", systemImage: "pencil.and.outline") }; ShareLink(item: message.content) { Label("Поделиться", systemImage: "square.and.arrow.up") } }; Button(role: .destructive, action: onDelete) { Label("Удалить", systemImage: "trash") } }
            HStack(spacing: 4) {
                Text(message.createdAt, style: .time).font(.caption2).foregroundStyle(.secondary)
                if message.role == "assistant" && !message.content.isEmpty {
                    HStack(spacing: 14) {
                        Button { UIPasteboard.general.string = message.content; Haptic.success(); copied = true; DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copied = false } } label: { HStack(spacing: 4) { Image(systemName: copied ? "checkmark" : "doc.on.doc"); if copied { Text("Скопировано") } } }
                        ShareLink(item: message.content) { Image(systemName: "square.and.arrow.up") }
                        Button { Speaker.shared.speak(message.content) } label: { Image(systemName: "speaker.wave.2") }
                        Button(action: onAnnotate) { Image(systemName: "pencil.and.outline") }
                        Button(action: onVisualize) { Image(systemName: "photo.badge.plus") }
                        Button(action: onRegenerate) { Image(systemName: "arrow.clockwise") }
                        Button(action: onDelete) { Image(systemName: "trash") }
                        if let m = message.model { Text(m).font(.caption2).foregroundStyle(.secondary).lineLimit(1) }
                    }.font(.caption).foregroundStyle(.secondary)
                }
                if message.role == "user" { HStack(spacing: 14) { Button(action: onEdit) { Image(systemName: "pencil") }; Button(action: onDelete) { Image(systemName: "trash") } }.font(.caption).foregroundStyle(.secondary) }
                if message.isError { Button("Повторить") { onRegenerate() }.font(.caption.bold()).foregroundStyle(.red) }
            }
        }.frame(maxWidth: .infinity, alignment: message.role == "user" ? .trailing : .leading)
    }
}
