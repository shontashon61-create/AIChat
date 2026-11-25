import SwiftUI

struct SchoolToolsView: View {
    @EnvironmentObject var settings: SettingsStore
    @StateObject private var speaker = VoiceSpeaker()
    @State private var formulaQuery = ""
    @State private var gradesText = ""
    @State private var essayTopic = ""
    @State private var englishQuery = ""
    @State private var colA = ""
    @State private var colB = ""
    @State private var streak = UserDefaults.standard.integer(forKey: "streakCount")
    @State private var essayText = ""
    @State private var textbookQuery = ""
    @State private var fracA = ""; @State private var fracB = ""; @State private var fracC = ""; @State private var fracD = ""
    @State private var percentNumber = ""; @State private var percentValue = ""
    @State private var showAnnotator = false
    @State private var rewriteInput = ""
    @State private var rewritten = ""
    @State private var rewriting = false
    @State private var cdzHoursText = ""
    @State private var taskListText = ""
    @State private var checkText = ""
    @State private var expectedText = ""
    @State private var linedSheet = true
    @State private var archive = FinalTools.archiveLoad()
    @State private var archiveQuery = ""
    @State private var redoNumber = ""
    @State private var showShare = false
    @State private var documentURL: URL?
    var grades: [Int] { gradesText.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }.filter { (2...5).contains($0) } }
    var body: some View {
        List {
            Section("Стрик Меллстроя") {
                HStack { Image(systemName: "flame.fill").foregroundStyle(.orange); Text(Streaks.message(streak)); Spacer(); Text("\(streak) дн.").bold() }
                Button("Отметить домашку сделанной") { streak = Streaks.markDone() }
            }
            Section("Умножение в столбик") {
                HStack { TextField("1421", text: $colA).keyboardType(.numberPad); Text("×"); TextField("4414", text: $colB).keyboardType(.numberPad) }
                if let a = Int(colA), let b = Int(colB), a > 0, b > 0 { Text(ColumnMath.multiply(a, b)).font(.system(.caption, design: .monospaced)) }
                Text("Так решают в тетради: частичные произведения по разрядам, потом сложение. Не в уме.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Формулы 6 класса") {
                TextField("Поиск: площадь, скорость, процент", text: $formulaQuery)
                ForEach(Formulas.search(formulaQuery)) { f in VStack(alignment: .leading, spacing: 2) { Text(f.title).bold(); Text(f.formula); Text(f.example).font(.caption).foregroundStyle(.secondary) } }
            }
            Section("Оценки и прогноз четвертной") {
                TextField("Оценки через пробел: 4 5 3 5", text: $gradesText)
                if !grades.isEmpty { Text("Средний балл: " + String(format: "%.2f", Grades.average(grades))); Text(Grades.forecast(grades)); Text("Пятёрок до 4.5 нужно: \(Grades.neededFor(grades, target: 4.5))").font(.caption) }
            }
            Section("Английский: слово и произношение") {
                TextField("homework, school, book, friend", text: $englishQuery)
                if let w = EnglishHelper.lookup(englishQuery) { VStack(alignment: .leading) { Text(w.word).bold(); Text(w.transcription + " — " + w.translation); Text(w.example).font(.caption); Button("Послушать") { speaker.speakEnglish(w.word) }.font(.caption) } }
            }
            Section("Модель рисует сама") {
                Text("Теперь подчёркивает, обводит и строит схемы модель, а не ты. Пример, как это выглядит в чате:").font(.caption).foregroundStyle(.secondary)
                MarkdownView(text: "[[u:Кошка]] [[ud:спит]] [[dash:на окне]].\n\n[[box:Ответ: 6272294]]")
                MarkdownView(text: "```scheme\nДано -> Формула -> Подстановка -> Ответ\n```")
                MarkdownView(text: "```free\nbase Кошка спит на окне\nq 20 12 \"кто?\"\narrow 20 18 20 38\nunderline 8 55 32 55\nq 45 12 red \"что делает?\"\narrow 45 18 45 38\nunderline 36 55 54 55\nunderline 36 58 54 58\nunderline 65 55 90 55 dashed\ntext 78 78 -8 14 orange bold \"обстоятельство\"\n```")
                Text("Сфотографируй задание: модель сама напишет вопрос над словом, проведёт стрелку и подчеркнёт нужной линией. Текст на холсте может быть не по линии и под углом — полная свобода.").font(.caption).foregroundStyle(.secondary)
            }
            Section("7. Перепиши как я") {
                TextEditor(text: $rewriteInput).frame(minHeight: 80)
                Text("Вставь готовый ответ. Перепишу коротко, обычными словами, как в тетради. Числа, формулы и итоговый ответ не изменю, объяснений не добавлю.").font(.caption).foregroundStyle(.secondary)
                TextEditor(text: $settings.myStyle).frame(minHeight: 50)
                Text("Сюда можно вставить 2-3 предложения, как пишешь ты сам, — буду писать похоже по стилю.").font(.caption).foregroundStyle(.secondary)
                Button(rewriting ? "Переписываю..." : "Переписать как я") { rewriting = true; Task { let r = await APIClient.complete(settings: settings, model: settings.selectedModel, system: RewriteAsMe.system(style: settings.myStyle), user: RewriteAsMe.user(answer: rewriteInput)); rewritten = r ?? "Не получилось. Проверь модель и ключ."; rewriting = false } }.disabled(rewriteInput.isEmpty || rewriting || settings.selectedModel.isEmpty)
                if !rewritten.isEmpty { Text(rewritten).font(.callout); Button("Копировать") { UIPasteboard.general.string = rewritten }.font(.caption) }
            }
            Section("Новое: переписывание по строкам") {
                Text("Показывает готовый ответ по одной строке: переписал в тетрадь — нажал дальше. Не теряешь место и не пропускаешь строки.").font(.caption).foregroundStyle(.secondary)
                CopyStepsView(text: rewritten.isEmpty ? rewriteInput : rewritten)
            }
            Section("3, 4, 5, 6, 8, 9. Быстрые инструменты") {
                Text("3. Ответы в фото тетради: отправь фото страницы с пропусками в чат с этим запросом.").font(.caption).foregroundStyle(.secondary)
                Text(QuickTools.photoAnswersPrompt()).font(.caption)
                Button("Копировать запрос для фото") { UIPasteboard.general.string = QuickTools.photoAnswersPrompt() }.font(.caption)
                TextField("4. До сдачи ЦДЗ осталось часов: 5", text: $cdzHoursText).keyboardType(.decimalPad)
                if let h = Double(cdzHoursText) { Text(QuickTools.countdown(hours: h) + " - " + QuickTools.urgency(hours: h)).font(.caption.bold()) }
                Text("5. Фото учебника в PDF: сфотографируй страницы, собери их через экспорт в PDF - один чистый файл для печати.").font(.caption).foregroundStyle(.secondary)
                TextEditor(text: $taskListText).frame(minHeight: 60)
                if !taskListText.isEmpty { Text("6. Время на эту домашку: примерно " + String(QuickTools.minutes(subject: "", text: taskListText)) + " мин").font(.caption) }
                TextEditor(text: $checkText).frame(minHeight: 60)
                HStack { Button("8. Без палева") { UIPasteboard.general.string = QuickTools.noPalevoPrompt(text: checkText) }; Button("9. Условие простыми словами") { UIPasteboard.general.string = QuickTools.simplePrompt(text: checkText) } }.font(.caption)
                Text("8 и 9: вставь текст выше, нажми кнопку - запрос скопируется, вставь его в чат.").font(.caption).foregroundStyle(.secondary)
            }
            Section("1, 2, 3, 4, 5, 6, 7, 8, 10. Финал") {
                TextField("1. Номера с фото: 1 2 3 4 5", text: $expectedText)
                if !expectedText.isEmpty { let miss = FinalTools.missing(expected: expectedText, answer: rewriteInput); Text(miss.isEmpty ? "1. Ничего не пропущено" : "1. Пропущены номера: " + miss.map(String.init).joined(separator: ", ")).font(.caption.bold()).foregroundStyle(miss.isEmpty ? .green : .red) }
                Button("2. Запрос проверки переписанного по фото") { UIPasteboard.general.string = FinalTools.verifyCopyPrompt(original: rewritten.isEmpty ? rewriteInput : rewritten) }.font(.caption)
                if !rewriteInput.isEmpty { Text("3. Поля для ЦДЗ по одному:").font(.caption.bold()); ForEach(Array(FinalTools.splitFields(rewriteInput).enumerated()), id: \.offset) { p in HStack { Text(p.element).font(.caption); Spacer(); Button("Коп.") { UIPasteboard.general.string = p.element }.font(.caption) } } }
                Text("4. Архив домашки: \(archive.count) записей").font(.caption)
                ForEach(archive.suffix(10).reversed()) { a in VStack(alignment: .leading) { Text(a.date + " - " + a.subject).font(.caption.bold()); Text(a.answer).font(.caption).lineLimit(2) } }
                Button("В архив текущее") { FinalTools.archiveSave(subject: settings.schoolSubject, text: rewriteInput, answer: rewritten.isEmpty ? rewriteInput : rewritten); archive = FinalTools.archiveLoad() }.font(.caption)
                Toggle("5. Лист в линейку (выкл - в клетку)", isOn: $linedSheet)
                NotebookSheetView(text: rewritten.isEmpty ? rewriteInput : rewritten, lined: linedSheet)
                if !rewriteInput.isEmpty { Text("6. Только ответы:").font(.caption.bold()); ForEach(FinalTools.onlyAnswers(rewriteInput), id: \.self) { Text($0).font(.caption) } }
                Button("7. Сжать под страницу тетради") { UIPasteboard.general.string = FinalTools.fitPrompt(rewriteInput) }.font(.caption)
                if let dup = FinalTools.duplicateAnswer(for: rewriteInput) { Text("8. Такое задание уже решено, ответ из архива:").font(.caption.bold()); Text(dup).font(.caption) }
                Button("10. Картинка одного задания") { if let img = Exporter.makeImage(title: settings.schoolSubject, text: rewritten.isEmpty ? rewriteInput : rewritten) { UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil) } }.font(.caption)
            }
            Section("Сегодня, поиск, чистовик и черновик") {
                Text("1. Пакет фото: в чате прикрепи до 5 фото, модель решит как один список. 4. Номера ставит сама. 18. Если размыто, скажет, какой угол переснять.").font(.caption).foregroundStyle(.secondary)
                TextField("10. Поиск по своим решениям", text: $archiveQuery)
                ForEach(Array(TodayTools.searchArchive(query: archiveQuery, items: archive).suffix(10).reversed())) { a in VStack(alignment: .leading) { Text(a.date + " - " + a.subject).font(.caption.bold()); Text(a.answer).font(.caption).lineLimit(2) } }
                Text("12. Решения по папкам-предметам:").font(.caption.bold())
                ForEach(Array(TodayTools.grouped(archive).keys.sorted()), id: \.self) { subject in Text(subject + ": " + String(TodayTools.grouped(archive)[subject]?.count ?? 0)).font(.caption) }
                HStack { TextField("2. Переделать №", text: $redoNumber).keyboardType(.numberPad); Button("Копировать запрос") { UIPasteboard.general.string = TodayTools.redoPrompt(number: redoNumber, answer: rewritten.isEmpty ? rewriteInput : rewritten) }.disabled(redoNumber.isEmpty) }
                Button("6. Тетрадь в печатный текст: копировать запрос") { UIPasteboard.general.string = TodayTools.notebookOCRPrompt() }
                if !rewriteInput.isEmpty { Text("5. Ячейки таблицы по одной:").font(.caption.bold()); ForEach(Array(TodayTools.tableCells(rewriteInput).enumerated()), id: \.offset) { p in HStack { Text(p.element).font(.caption); Spacer(); Button("Коп.") { UIPasteboard.general.string = p.element }.font(.caption) } } }
                Toggle("17. Ответ без воды", isOn: $settings.noWaterMode)
                Toggle("15. Тетрадный крупный шрифт", isOn: $settings.notebookLargeFont)
                Text("20. Черновик как есть. 9. Чистовик без схем и лишних слов:").font(.caption.bold())
                Text(TodayTools.clean(rewritten.isEmpty ? rewriteInput : rewritten)).font(settings.notebookLargeFont ? .system(size: 22, design: .rounded) : .callout)
                HStack { Button("Копировать черновик") { UIPasteboard.general.string = rewritten.isEmpty ? rewriteInput : rewritten }; Button("Копировать чистовик") { UIPasteboard.general.string = TodayTools.clean(rewritten.isEmpty ? rewriteInput : rewritten) } }.font(.caption)
                Button("7. Все ответы дня одним текстом") { UIPasteboard.general.string = TodayTools.todayText(items: archive) }
                ShareLink(item: TodayTools.todayText(items: archive)) { Text("11. Отправить другу все ответы дня") }
                Button("16. Документ для печати (.txt)") { documentURL = Exporter.makeDocument(title: "Сегодня", text: TodayTools.todayText(items: archive)); showShare = documentURL != nil }
                Text(TodayTools.cdzHistoryText(total: archive.count, solved: CDZDatabase.load().count)).font(.caption)
            }
            Section("27. Проверка сочинения перед сдачей") {
                TextEditor(text: $essayText).frame(minHeight: 90)
                if !essayText.isEmpty { Text(EssayChecker.prompt(text: essayText)).font(.caption); Button("Копировать запрос проверки") { UIPasteboard.general.string = EssayChecker.prompt(text: essayText) }.font(.caption) }
                Text("Скопируй запрос в чат: получишь ошибки по номерам и полностью исправленный текст для тетради.").font(.caption).foregroundStyle(.secondary)
            }
            Section("45. Поиск по учебнику") {
                TextField("Вопрос или тема: дроби, масштаб, фотосинтез", text: $textbookQuery)
                ForEach(TextbookSearch.search(textbookQuery), id: \.1) { t in VStack(alignment: .leading, spacing: 2) { Text(t.0 + ": " + t.1).bold(); Text(t.2).font(.caption).foregroundStyle(.secondary) } }
                if !textbookQuery.isEmpty { Button("Запрос в чат по моим учебникам") { UIPasteboard.general.string = TextbookSearch.prompt(question: textbookQuery, textbooks: settings.textbooks) }.font(.caption) }
            }
            Section("49. Калькулятор дробей и процентов в столбик") {
                HStack { TextField("1", text: $fracA).keyboardType(.numberPad); Text("/"); TextField("2", text: $fracB).keyboardType(.numberPad); Text("+"); TextField("1", text: $fracC).keyboardType(.numberPad); Text("/"); TextField("3", text: $fracD).keyboardType(.numberPad) }
                if let a = Int(fracA), let b = Int(fracB), let c = Int(fracC), let d = Int(fracD), b != 0, d != 0 { Text(FractionCalc.add(a, b, c, d)).font(.system(.caption, design: .monospaced)); Text(FractionCalc.multiply(a, b, c, d)).font(.system(.caption, design: .monospaced)) }
                HStack { TextField("Число: 250", text: $percentNumber).keyboardType(.decimalPad); TextField("%: 20", text: $percentValue).keyboardType(.decimalPad) }
                if let n = Double(percentNumber), let p = Double(percentValue) { Text(FractionCalc.percent(of: n, p: p)).font(.system(.caption, design: .monospaced)) }
                Text(FractionCalc.percentPrompt()).font(.caption).foregroundStyle(.secondary)
            }
            Section("Сочинение / изложение") {
                TextField("Тема", text: $essayTopic)
                if !essayTopic.isEmpty { Text(EssayHelper.prompt(topic: essayTopic, type: "сочинение")).font(.caption) }
                Text("Скопируй этот запрос в чат — получишь план и текст.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Презентация за минуту") {
                ForEach(PresentationHelper.slides(topic: essayTopic.isEmpty ? "Тема доклада" : essayTopic), id: \.self) { Text($0) }
            }
            Section("Страница учебника и доска") {
                Text(PageHelper.prompt).font(.caption)
                Text(PageHelper.boardPrompt).font(.caption)
                Text("Сфотографируй страницу или доску в чате — правило 90% работает: нечитаемо — скажет «Непонятно именно это задание». ").font(.caption).foregroundStyle(.secondary)
            }
            Section("Расписание из МЭШ") {
                Text("Уроки, домашка и контрольные на неделю — в экране МЭШ (книга в шапке). Там же «Сделать всю домашку». ").font(.caption)
            }
        }.navigationTitle("Школьные инструменты").sheet(isPresented: $showAnnotator) { NavigationStack { TextAnnotatorView() } }.sheet(isPresented: $showShare) { if let url = documentURL { ShareSheet(items: [url]) } else { ShareSheet(items: [TodayTools.todayText(items: archive)]) } }
    }
}
