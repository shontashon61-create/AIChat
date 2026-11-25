import SwiftUI
import PencilKit
import UIKit

enum MarkStyle: CaseIterable { case none, underline, circle, highlight, strike
    var next: MarkStyle { switch self { case .none: return .underline; case .underline: return .circle; case .circle: return .highlight; case .highlight: return .strike; case .strike: return .none } }
    var label: String { switch self { case .none: return ""; case .underline: return "подчеркнуть"; case .circle: return "обвести"; case .highlight: return "выделить"; case .strike: return "зачеркнуть" } }
}

struct DrawingCanvas: UIViewRepresentable {
    @Binding var canvas: PKCanvasView
    func makeUIView(context: Context) -> PKCanvasView { canvas.drawingPolicy = .anyInput; canvas.tool = PKInkingTool(.pen, color: .systemRed, width: 3); canvas.backgroundColor = .clear; canvas.isOpaque = false; return canvas }
    func updateUIView(_ v: PKCanvasView, context: Context) {}
}

struct TextAnnotatorView: View {
    @State private var text: String = ""
    @State private var marks: [Int: MarkStyle] = [:]
    @State private var canvas = PKCanvasView()
    @State private var toolColor: UIColor = .systemRed
    @State private var savedNote: String = ""
    var words: [String] { text.split(separator: " ", omittingEmptySubsequences: false).map(String.init) }
    var body: some View {
        List {
            Section("Текст задания") {
                TextEditor(text: $text).frame(minHeight: 90)
                Text("Вставь текст или набери формулу. Нажимай на слова внизу: 1 раз — подчеркнуть, 2 — обвести, 3 — выделить, 4 — зачеркнуть, 5 — убрать. Поверх можно писать ручкой, маркером, стрелками и формулами.").font(.caption).foregroundStyle(.secondary)
                HStack { Button("S = a × b") { text += " S = a × b" }; Button("v = s / t") { text += " v = s / t" }; Button("P = 2 × (a + b)") { text += " P = 2 × (a + b)" } }.font(.caption)
            }
            Section("Отмеченный текст") {
                if words.isEmpty { Text("Пока пусто").foregroundStyle(.secondary) } else {
                    FlowWords(words: words, marks: marks) { i in marks[i] = (marks[i] ?? .none).next }
                }
                ForEach(marks.keys.sorted(), id: \.self) { i in if i < words.count, let m = marks[i], m != .none { Text(words[i] + " — " + m.label).font(.caption) } }
                Button("Сбросить все отметки") { marks = [:] }
            }
            Section("Писать поверх: формула, стрелки, обводка") {
                HStack { Button("Красный") { setTool(.systemRed) }; Button("Синий") { setTool(.systemBlue) }; Button("Зелёный") { setTool(.systemGreen) }; Button("Тонко") { canvas.tool = PKInkingTool(.pen, color: toolColor, width: 2) }; Button("Толсто") { canvas.tool = PKInkingTool(.pen, color: toolColor, width: 6) }; Button("Маркер") { canvas.tool = PKInkingTool(.marker, color: .systemYellow, width: 18) }; Button("Ластик") { canvas.tool = PKEraserTool(.bitmap) }; Button("Отмена") { canvas.undoManager?.undo() }; Button("Очистить") { canvas.drawing = PKDrawing() } }
                .font(.caption)
                ZStack { Text(text.isEmpty ? "Здесь будет твой текст, пиши формулу прямо поверх него" : text).frame(maxWidth: .infinity, alignment: .leading).padding(8); DrawingCanvas(canvas: $canvas) }
                .frame(height: 260).background(Color(.secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 10))
                Button("Сохранить картинку с пометками") { saveImage() }
                if !savedNote.isEmpty { Text(savedNote).font(.caption).foregroundStyle(.secondary) }
            }
            Section("Спросить ИИ про отмеченное") {
                Text(annotatedPrompt()).font(.caption)
                Button("Копировать запрос в чат") { UIPasteboard.general.string = annotatedPrompt() }
            }
        }.navigationTitle("Работа с текстом")
    }
    func setTool(_ color: UIColor) { toolColor = color; canvas.tool = PKInkingTool(.pen, color: color, width: 3) }
    func annotatedPrompt() -> String {
        let marked = marks.keys.sorted().filter { (marks[$0] ?? .none) != .none && $0 < words.count }.map { words[$0] + " (" + (marks[$0]?.label ?? "") + ")" }.joined(separator: ", ")
        return "Текст: " + text + "\nОтмечено: " + (marked.isEmpty ? "ничего" : marked) + "\nОбъясни отмеченные слова и формулы, подчеркни в ответе главное, обведи в рамку итоговую формулу и финальный ответ."
    }
    func saveImage() {
        let image = canvas.drawing.image(from: canvas.bounds, scale: UIScreen.main.scale)
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        savedNote = "Сохранил пометки в Фото"
    }
}

struct FlowWords: View {
    let words: [String]
    let marks: [Int: MarkStyle]
    let onTap: (Int) -> Void
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 62), spacing: 6)], alignment: .leading, spacing: 6) {
            ForEach(Array(words.enumerated()), id: \.offset) { pair in
                let style = marks[pair.offset] ?? .none
                Text(pair.element)
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(style == .highlight ? Color.yellow.opacity(0.55) : Color.clear)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(style == .circle ? Color.red : Color.clear, lineWidth: 1.6))
                    .underline(style == .underline, color: .red)
                    .strikethrough(style == .strike, color: .red)
                    .onTapGesture { onTap(pair.offset) }
            }
        }
    }
}
