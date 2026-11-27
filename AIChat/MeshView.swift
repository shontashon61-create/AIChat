import SwiftUI
import UIKit
import WebKit

struct MeshWebView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView { let w = WKWebView(); w.load(URLRequest(url: URL(string: "https://school.mos.ru")!)); return w }
    func updateUIView(_ v: WKWebView, context: Context) {}
}

struct MeshView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var store: ChatStore
    @Environment(\.dismiss) var dismiss
    @StateObject private var mesh = MeshStore()
    @State private var showLogin = false
    @State private var solving = false
    @State private var manualToken = ""
    @State private var autoHW: MeshHomework?
    var shownHomeworks: [MeshHomework] { let sorted = mesh.homeworks.sorted { a, b in if a.isDigital != b.isDigital { return a.isDigital }; return (a.answer == nil) && (b.answer != nil) }; return settings.onlyUnsolvedCDZ ? sorted.filter { $0.answer == nil } : sorted }
    var body: some View {
        NavigationStack {
            List {
                Section("Вход в МЭШ") {
                    if mesh.isLoggedIn { Text("Шаг 3 из 3 — готово: ты вошёл, токен сам сохранился в Связке ключей. Теперь просто нажми «Загрузить ЦДЗ и домашку» ниже.").font(.caption) }
                    else { Text("Как войти, по шагам:\n1. Нажми кнопку «Войти через school.mos.ru» ниже.\n2. В открывшемся окне войди своим логином и паролем МЭШ — пароль вводишь только на сайте школы, приложение его не видит.\n3. После входа нажми вверху «Я вошёл» — приложение само заберёт токен входа (aupd_token), руками его искать и вставлять не надо. Токен — это просто пропуск, который сайт выдаёт после входа.").font(.caption) }
                    Text("ID ученика нужен, чтобы МЭШ отдал именно твою домашку. Он уже подставляется сам после входа, если поле пустое — оставь как есть и просто загрузи домашку.").font(.caption).foregroundStyle(.secondary)
                    TextField("ID ученика", text: $mesh.studentId).autocorrectionDisabled().textInputAutocapitalization(.never)
                    Button(mesh.isLoggedIn ? "Выйти из МЭШ" : "Войти через school.mos.ru") { if mesh.isLoggedIn { mesh.logout() } else { showLogin = true } }
                    Text("Поле ниже — запасной вариант, только если вход через сайт не сработал. Обычно оно не нужно, пропускай его.").font(.caption).foregroundStyle(.secondary)
                    TextField("Запасной вариант: токен вручную", text: $manualToken).autocorrectionDisabled().textInputAutocapitalization(.never)
                    Button("Сохранить токен") { if !manualToken.isEmpty { mesh.saveToken(manualToken); manualToken = "" } }.disabled(manualToken.isEmpty)
                }
                Section("Мои учебники и тетради") {
                    TextEditor(text: $settings.textbooks).frame(minHeight: 80)
                    Text("Например: Математика Виленкин 6 класс, Русский Ладыженская, тетрадь по биологии. Агент отвечает по этим учебникам.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Домашка на неделю") {
                    Button { Task { await mesh.fetchHomeworks() } } label: { HStack { if mesh.isLoading { ProgressView() }; Text("Загрузить ЦДЗ и домашку") } }
                    if let e = mesh.error { Text(e).foregroundStyle(.red).font(.caption) }
                    Button("Сделать всю домашку") { solving = true; Task { await mesh.fetchAndSolveAll(settings: settings, minutes: settings.meshMinutes); solving = false } }.disabled(solving)
                    Stepper("ЦДЗ: решать за " + String(Int(settings.meshMinutes)) + " мин", value: $settings.meshMinutes, in: 1...60, step: 1)
                    Toggle("13. Только несданные ЦДЗ первыми", isOn: $settings.onlyUnsolvedCDZ)
                    Text(TodayTools.cdzHistoryText(total: mesh.homeworks.filter { $0.isDigital }.count, solved: CDZDatabase.load().count)).font(.caption)
                    if solving { Text(mesh.solvingStatus.isEmpty ? "Решаю по порядку..." : mesh.solvingStatus).font(.caption).foregroundStyle(.secondary) }
                }
                Section("Расписание на неделю") {
                    if mesh.lessons.isEmpty { Text("Нажми «Загрузить ЦДЗ и домашку» — уроки подтянутся из МЭШ вместе с заданиями.").font(.caption).foregroundStyle(.secondary) }
                    ForEach(mesh.lessons) { l in HStack { VStack(alignment: .leading) { Text(l.subject).bold(); if !l.homework.isEmpty { Text(l.homework).font(.caption).foregroundStyle(.secondary).lineLimit(2) } }; Spacer(); VStack(alignment: .trailing) { Text(l.date).font(.caption); Text(l.time).font(.caption).foregroundStyle(.secondary) } } }
                }
                ForEach(shownHomeworks) { hw in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack { Text(hw.subject).bold(); Spacer(); Text(hw.isDigital ? "ЦДЗ" : "ДЗ").font(.caption2).padding(4).background(Color.orange.opacity(0.2)).clipShape(Capsule()) }
                        Text(hw.text).font(.callout)
                        if let a = hw.answer { Text(a).font(.callout).padding(8).background(Color(.secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 8)) }
                        HStack {
                            Button("Решить") { Task { if let a = await mesh.solve(hw, settings: settings), let i = mesh.homeworks.firstIndex(where: { $0.id == hw.id }) { mesh.homeworks[i].answer = a; if !hw.link.isEmpty { CDZDatabase.save(link: hw.link, answer: a) } } } }
                            Button("Копировать ответ") { if let a = hw.answer { UIPasteboard.general.string = a } }.disabled(hw.answer == nil)
                            Button("В чат") { openInChat(hw) }
                            if hw.isDigital && !hw.link.isEmpty { Button("Авто ЦДЗ") { autoHW = hw } }
                        }.font(.caption)
                    }
                }
                Text("ЦДЗ — интерактивные задания на платформе МЭШ. Приложение их читает и решает, но автоматически сдать их в МЭШ нельзя: МЭШ не даёт API для отправки ответов. Готовые ответы копируй и вписывай в МЭШ сам.").font(.caption).foregroundStyle(.secondary)
            }
            .navigationTitle("МЭШ: домашка")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Закрыть") { dismiss() } } }
            .sheet(isPresented: $showLogin) { MeshLoginSheet(onDone: { mesh.isLoggedIn = !(MeshKeychain.load() ?? "").isEmpty; showLogin = false }) }
            .sheet(item: $autoHW) { hw in CDZAutoPlayer(homework: hw, token: mesh.token ?? "", minutes: settings.meshMinutes) }
        }
    }
    func openInChat(_ hw: MeshHomework) {
        var s = store.newChat()
        s.messages.append(ChatMessage(role: "user", content: "Предмет: \(hw.subject)\nЗадание из МЭШ:\n\(hw.text)"))
        store.update(s); dismiss()
    }
}

struct MeshLoginSheet: View {
    var onDone: () -> Void
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationStack {
            MeshWebView()
                .navigationTitle("Вход в МЭШ")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { Button("Отмена") { dismiss() } }
                    ToolbarItem(placement: .topBarTrailing) { Button("Я вошёл") { WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cs in if let t = cs.first(where: { $0.name == "aupd_token" })?.value { MeshKeychain.save(t) }; onDone(); dismiss() } } }
                }
        }
    }
}
