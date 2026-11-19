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
    @StateObject private var speech = SpeechManager()
    @State private var streamTask: Task<Void, Never>?

    var visibleMessages: [ChatMessage] {
        searchText.isEmpty ? session.messages : session.messages.filter { $0.content.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            if showSearch {
                TextField("Поиск в этом чате...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                    .padding(.top, 8)
            }
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 14) {
                        if session.messages.isEmpty { emptyView }
                        ForEach(visibleMessages) { msg in
                            MessageRow(message: msg, onRegenerate: regenerate, onDelete: { deleteMessage(msg) }, onEdit: { editMessage(msg) }, onPreview: { previewAttachment = $0 })
                        }
                        if isSending {
                            HStack {
                                ProgressView()
                                Text("ИИ печатает...").font(.caption).foregroundStyle(.secondary)
                                Spacer()
                            }.padding(.leading, 4)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
                .onChange(of: session.messages.count) { _ in scrollToLast(proxy) }
                .onChange(of: session.messages.last?.content ?? "") { _ in scrollToLast(proxy) }
            }
            if session.messages.isEmpty { quickPrompts }
            attachmentPreview
            inputBar
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showSearch.toggle()
                    if !showSearch { searchText = "" }
                } label: { Image(systemName: "magnifyingglass") }
            }
        }
        .sheet(isPresented: $showPicker) { PhotoVideoPicker(onPick: addAttachment) }
        .sheet(isPresented: $showCamera) { CameraPicker(onPick: addAttachment) }
        .sheet(item: $previewAttachment) { a in AttachmentPreviewView(attachment: a) }
        .confirmationDialog("Добавить", isPresented: $showAttachMenu) {
            Button("Фото или видео из галереи") { showPicker = true }
            Button("Снять фото или видео") { showCamera = true }
            Button("Отмена", role: .cancel) {}
        }
        .alert("Ошибка", isPresented: Binding(get: { errorText != nil }, set: { if !$0 { errorText = nil } })) {
            Button("OK") {}
        } message: { Text(errorText ?? "") }
        .onChange(of: store.currentId) { _ in
            if let s = store.sessions.first(where: { $0.id == store.currentId }) { session = s }
        }
        .onChange(of: speech.transcript) { v in input = v }
        .onChange(of: speech.errorText ?? "") { v in
            if !v.isEmpty { errorText = v; speech.errorText = nil }
        }
        .onDisappear { streamTask?.cancel(); speech.stop(); Speaker.shared.stop() }
    }

    func scrollToLast(_ proxy: ScrollViewProxy) {
        if let last = visibleMessages.last {
            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
        }
    }

    var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles").font(.system(size: 44)).foregroundStyle(.purple)
            Text("Чем помочь?").font(.title2.bold())
            Text("Модель: \(settings.selectedModel.isEmpty ? "не выбрана" : settings.selectedModel)").font(.caption).foregroundStyle(.secondary)
            Text("Можно спросить, попросить написать текст или код, прислать фото или видео.").multilineTextAlignment(.center).foregroundStyle(.secondary).font(.subheadline)
        }.padding(.vertical, 40)
    }

    var quickPrompts: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(["Объясни простыми словами", "Напиши код", "Составь план", "Придумай идею", "Проверь текст"], id: \.self) { p in
                    Button(p) { input = p; send() }
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .font(.subheadline)
                }
            }.padding(.horizontal)
        }.padding(.bottom, 8)
    }

    var attachmentPreview: some View {
        Group {
            if !attachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(attachments) { a in
                            ZStack(alignment: .topTrailing) {
                                Button { previewAttachment = a } label: { AttachmentThumbView(attachment: a) }
                                Button { attachments.removeAll { $0.id == a.id } } label: {
                                    Image(systemName: "xmark.circle.fill").foregroundStyle(.white, .black.opacity(0.6))
                                }.offset(x: 6, y: -6)
                            }
                        }
                    }.padding(.horizontal)
                }.padding(.vertical, 6)
            }
        }
    }

    var inputBar: some View {
        VStack(spacing: 4) {
            HStack(alignment: .bottom, spacing: 8) {
                Button { showAttachMenu = true } label: { Image(systemName: "plus.circle.fill").font(.title2).foregroundStyle(.purple) }
                TextField("Сообщение...", text: $input, axis: .vertical).lineLimit(1...5).padding(10).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
                Button {
                    if speech.isRecording { speech.stop() } else { speech.transcript = ""; speech.start() }
                } label: { Image(systemName: speech.isRecording ? "mic.fill" : "mic").font(.title3).foregroundStyle(speech.isRecording ? .red : .primary) }
                if isSending {
                    Button { stopGeneration() } label: { Image(systemName: "stop.circle.fill").font(.title2).foregroundStyle(.red) }
                } else {
                    Button { send() } label: { Image(systemName: "arrow.up.circle.fill").font(.title2).foregroundStyle(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && attachments.isEmpty ? .gray : .purple) }
                        .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && attachments.isEmpty)
                }
            }
            if !input.isEmpty {
                HStack { Spacer(); Text("\(input.count) симв.").font(.caption2).foregroundStyle(.secondary) }
            }
        }.padding(.horizontal).padding(.vertical, 10).background(.ultraThinMaterial)
    }

    func addAttachment(_ data: Data, _ kind: String, _ mime: String) {
        if data.count > 15_000_000 {
            errorText = "Файл слишком большой. Максимум 15 МБ, сейчас \(String(format: "%.1f", Double(data.count) / 1024 / 1024)) МБ."
            return
        }
        if attachments.count >= 5 { errorText = "Максимум 5 вложений за раз."; return }
        let ext = kind == "image" ? "jpg" : "mp4"
        attachments.append(Attachment(kind: kind, fileName: "file-\(attachments.count + 1).\(ext)", mimeType: mime, base64: data.base64EncodedString()))
    }

    func send() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !isSending, (!text.isEmpty || !attachments.isEmpty) else { return }
        guard !settings.selectedModel.isEmpty else { errorText = "Сначала выберите модель в меню сверху или в настройках."; return }
        let userMsg = ChatMessage(role: "user", content: text.isEmpty ? "Опиши вложение" : text, attachments: attachments)
        session.messages.append(userMsg)
        if session.title == "Новый чат" || session.title.isEmpty {
            session.title = String(text.prefix(36)).isEmpty ? "Фото / видео" : String(text.prefix(36))
        }
        store.update(session)
        input = ""
        attachments = []
        startAssistantReply()
    }

    func startAssistantReply() {
        isSending = true
        session.messages.append(ChatMessage(role: "assistant", content: "", model: settings.selectedModel))
        let history = Array(session.messages.dropLast())
        streamTask = Task {
            do {
                try await APIClient.streamChat(settings: settings, messages: history, onContent: { chunk in
                    DispatchQueue.main.async {
                        guard let idx = session.messages.indices.last else { return }
                        session.messages[idx].content += chunk
                    }
                }, onThinking: { chunk in
                    DispatchQueue.main.async {
                        guard let idx = session.messages.indices.last else { return }
                        session.messages[idx].thinking = (session.messages[idx].thinking ?? "") + chunk
                    }
                })
                await MainActor.run {
                    store.update(session)
                    isSending = false
                    if settings.autoSpeak, let last = session.messages.last { Speaker.shared.speak(last.content) }
                }
            } catch {
                await MainActor.run {
                    if Task.isCancelled { isSending = false; return }
                    if let idx = session.messages.indices.last, session.messages[idx].content.isEmpty {
                        session.messages[idx].content = "Ошибка: " + error.localizedDescription + ". Проверьте Base URL, ключ и модель в настройках."
                        session.messages[idx].isError = true
                    } else { errorText = error.localizedDescription }
                    store.update(session)
                    isSending = false
                }
            }
        }
    }

    func stopGeneration() { streamTask?.cancel(); streamTask = nil; isSending = false; store.update(session) }

    func regenerate() {
        guard !isSending else { return }
        while session.messages.last?.role == "assistant" { session.messages.removeLast() }
        guard session.messages.last?.role == "user" else { return }
        store.update(session)
        startAssistantReply()
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
            if attachment.kind == "image", let data = Data(base64Encoded: attachment.base64), let ui = UIImage(data: data) {
                Image(uiImage: ui).resizable().scaledToFill().frame(width: 72, height: 72).clipped().cornerRadius(12)
            } else {
                VStack {
                    Image(systemName: "video.fill")
                    Text(String(format: "%.1f МБ", attachment.sizeMB)).font(.caption2)
                }.frame(width: 72, height: 72).background(.ultraThinMaterial).cornerRadius(12)
            }
        }
    }
}

struct AttachmentPreviewView: View {
    let attachment: Attachment
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationStack {
            Group {
                if attachment.kind == "image", let data = Data(base64Encoded: attachment.base64), let ui = UIImage(data: data) {
                    Image(uiImage: ui).resizable().scaledToFit().padding()
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "video.fill").font(.largeTitle)
                        Text(attachment.fileName)
                        Text(String(format: "%.1f МБ", attachment.sizeMB)).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(attachment.fileName)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Закрыть") { dismiss() } } }
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

    var body: some View {
        VStack(alignment: message.role == "user" ? .trailing : .leading, spacing: 6) {
            if let thinking = message.thinking, !thinking.isEmpty, settings.showThinking, message.role == "assistant" {
                DisclosureGroup("Ход мыслей ИИ", isExpanded: $showThinking) {
                    Text(thinking).font(.caption).foregroundStyle(.secondary)
                }.padding(10).background(Color.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            }
            ForEach(message.attachments) { a in
                Button { onPreview(a) } label: { AttachmentThumbView(attachment: a) }
            }
            Group {
                if message.role == "assistant" {
                    MarkdownView(text: message.content.isEmpty ? "..." : message.content)
                } else {
                    Text(message.content.isEmpty ? "..." : message.content)
                }
            }
            .padding(12)
            .background(message.role == "user" ? Color.purple : Color.gray.opacity(0.18), in: RoundedRectangle(cornerRadius: 16))
            .foregroundStyle(message.role == "user" ? .white : .primary)
            .frame(maxWidth: .infinity, alignment: message.role == "user" ? .trailing : .leading)
            .textSelection(.enabled)
            HStack(spacing: 4) {
                Text(message.createdAt, style: .time).font(.caption2).foregroundStyle(.secondary)
                if message.role == "assistant" && !message.content.isEmpty {
                    HStack(spacing: 14) {
                        Button {
                            UIPasteboard.general.string = message.content
                            copied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copied = false }
                        } label: { Image(systemName: copied ? "checkmark" : "doc.on.doc") }
                        Button { Speaker.shared.speak(message.content) } label: { Image(systemName: "speaker.wave.2") }
                        Button(action: onRegenerate) { Image(systemName: "arrow.clockwise") }
                        Button(action: onDelete) { Image(systemName: "trash") }
                        if let m = message.model { Text(m).font(.caption2).foregroundStyle(.secondary).lineLimit(1) }
                    }.font(.caption).foregroundStyle(.secondary)
                }
                if message.role == "user" {
                    HStack(spacing: 14) {
                        Button(action: onEdit) { Image(systemName: "pencil") }
                        Button(action: onDelete) { Image(systemName: "trash") }
                    }.font(.caption).foregroundStyle(.secondary)
                }
                if message.isError {
                    Button("Повторить") { onRegenerate() }.font(.caption.bold()).foregroundStyle(.red)
                }
            }
        }.frame(maxWidth: .infinity, alignment: message.role == "user" ? .trailing : .leading)
    }
}
