import SwiftUI

struct MarkdownSegment: Identifiable { let id = UUID(); let isCode: Bool; let language: String; let text: String }

struct MarkdownView: View {
    let text: String
    var segments: [MarkdownSegment] {
        var out: [MarkdownSegment] = []
        var current = ""; var code = ""; var lang = ""; var inCode = false
        for line in text.components(separatedBy: "\n") {
            if line.hasPrefix("```") {
                if inCode { out.append(MarkdownSegment(isCode: true, language: lang, text: code)); code = ""; inCode = false } else { if !current.isEmpty { out.append(MarkdownSegment(isCode: false, language: "", text: current)); current = "" }; lang = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces); inCode = true }
            } else if inCode { code += line + "\n" } else { current += line + "\n" }
        }
        if inCode { out.append(MarkdownSegment(isCode: true, language: lang, text: code)) }
        else if !current.isEmpty { out.append(MarkdownSegment(isCode: false, language: "", text: current)) }
        return out.isEmpty ? [MarkdownSegment(isCode: false, language: "", text: text)] : out
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(segments) { s in
                if s.isCode { CodeBlockView(language: s.language, code: s.text) } else { markdownText(s.text) }
            }
        }
    }
    func markdownText(_ s: String) -> some View {
        Group {
            if let attr = try? AttributedString(markdown: s, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)) { Text(attr) } else { Text(s) }
        }
    }
}

struct CodeBlockView: View {
    let language: String; let code: String
    @State private var copied = false
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack { Text(language.isEmpty ? "code" : language).font(.caption2.bold()).foregroundStyle(.secondary); Spacer(); Button(copied ? "Скопировано" : "Копировать") { UIPasteboard.general.string = code; copied = true; DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false } }.font(.caption2) }
            .padding(.horizontal, 10).padding(.vertical, 6).background(Color.black.opacity(0.25))
            ScrollView(.horizontal, showsIndicators: false) { Text(code).font(.system(.caption, design: .monospaced)).padding(10).textSelection(.enabled) }
        }.background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
    }
}
