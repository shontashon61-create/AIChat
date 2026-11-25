import SwiftUI
import UIKit

struct MarkdownSegment: Identifiable { let id = UUID(); let isCode: Bool; let isTable: Bool; let isDiagram: Bool; let isScheme: Bool; let isDraw: Bool; let isFree: Bool; let language: String; let text: String }

struct AnnotatedRun { var text: String; var bold: Bool = false; var italic: Bool = false; var mark: String = "" }

struct AnnotatedTextView: View {
    let text: String
    func parseRuns(_ s: String) -> [AnnotatedRun] {
        var out: [AnnotatedRun] = []
        var plain = ""
        func flush() { if !plain.isEmpty { out.append(AnnotatedRun(text: plain)); plain = "" } }
        var i = s.startIndex
        while i < s.endIndex {
            let rest = s[i...]
            if rest.hasPrefix("[[") {
                if let end = rest.range(of: "]]") {
                    flush()
                    let inner = String(rest[rest.index(i, offsetBy: 2)..<end.lowerBound])
                    if let colon = inner.firstIndex(of: ":") { out.append(AnnotatedRun(text: String(inner[inner.index(after: colon)...]), mark: String(inner[..<colon]))) } else { out.append(AnnotatedRun(text: inner)) }
                    i = end.upperBound
                    continue
                }
            }
            if rest.hasPrefix("**") {
                if let end = rest.dropFirst(2).range(of: "**") {
                    flush()
                    out.append(AnnotatedRun(text: String(rest[rest.index(i, offsetBy: 2)..<end.lowerBound]), bold: true))
                    i = end.upperBound
                    continue
                }
            }
            plain.append(s[i])
            i = s.index(after: i)
        }
        flush()
        return out
    }
    func styled(_ run: AnnotatedRun) -> Text {
        var attr = AttributedString(run.text)
        var isBold = run.bold
        switch run.mark {
        case "u": attr.underlineStyle = Text.LineStyle(pattern: .solid); attr.underlineColor = UIColor.label
        case "ud": attr.underlineStyle = Text.LineStyle(pattern: .solid); attr.underlineColor = UIColor.label; isBold = true
        case "dot": attr.underlineStyle = Text.LineStyle(pattern: .dot); attr.underlineColor = .red
        case "wave": attr.underlineStyle = Text.LineStyle(pattern: .dashDotDot); attr.underlineColor = .red
        case "dash": attr.underlineStyle = Text.LineStyle(pattern: .dashDot); attr.underlineColor = .blue
        case "hl": attr.backgroundColor = Color.yellow.opacity(0.55)
        case "circ": attr.backgroundColor = Color.red.opacity(0.18); isBold = true
        case "box": attr.backgroundColor = Color.orange.opacity(0.3); isBold = true
        case "strike": attr.strikethroughStyle = Text.LineStyle(pattern: .solid); attr.strikethroughColor = .red
        default: break
        }
        if isBold && run.italic { attr.font = .body.bold().italic() }
        else if isBold { attr.font = .body.bold() }
        else if run.italic { attr.font = .body.italic() }
        return Text(attr)
    }
    var body: some View {
        parseRuns(text).reduce(Text(""), { acc, run in acc + styled(run) })
    }
}

struct MarkdownView: View {
    let text: String
    var segments: [MarkdownSegment] {
        var out: [MarkdownSegment] = []
        var current = ""; var code = ""; var lang = ""; var table = ""; var inCode = false; var inTable = false
        func flushText() { if !current.isEmpty { out.append(MarkdownSegment(isCode: false, isTable: false, isDiagram: false, isScheme: false, isDraw: false, isFree: false, language: "", text: current)); current = "" } }
        func flushTable() { if !table.isEmpty { out.append(MarkdownSegment(isCode: false, isTable: true, isDiagram: false, isScheme: false, isDraw: false, isFree: false, language: "", text: table)); table = "" }; inTable = false }
        for raw in text.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            let isSep = line.hasPrefix("|") && line.contains("---")
            let isRow = line.hasPrefix("|") && line.hasSuffix("|") && !isSep
            if inCode {
                if line.hasPrefix("```") { let l = lang; if l == "diagram" { out.append(MarkdownSegment(isCode: false, isTable: false, isDiagram: true, isScheme: false, isDraw: false, isFree: false, language: l, text: code)) } else if l == "scheme" { out.append(MarkdownSegment(isCode: false, isTable: false, isDiagram: false, isScheme: true, isDraw: false, isFree: false, language: l, text: code)) } else if l == "draw" { out.append(MarkdownSegment(isCode: false, isTable: false, isDiagram: false, isScheme: false, isDraw: true, isFree: false, language: l, text: code)) } else if l == "free" { out.append(MarkdownSegment(isCode: false, isTable: false, isDiagram: false, isScheme: false, isDraw: false, isFree: true, language: l, text: code)) } else { out.append(MarkdownSegment(isCode: true, isTable: false, isDiagram: false, isScheme: false, isDraw: false, isFree: false, language: l, text: code)) }; code = ""; inCode = false } else { code += raw + "\n" }
            } else if line.hasPrefix("```") { flushText(); flushTable(); lang = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces); inCode = true
            } else if isSep { inTable = true
            } else if isRow { flushText(); inTable = true; table += line + "\n"
            } else { if inTable { flushTable() }; current += raw + "\n" }
        }
        if inCode { out.append(MarkdownSegment(isCode: lang != "free" && lang != "scheme" && lang != "diagram" && lang != "draw", isTable: false, isDiagram: lang == "diagram", isScheme: lang == "scheme", isDraw: lang == "draw", isFree: lang == "free", language: lang, text: code)) }
        flushTable(); flushText()
        return out.isEmpty ? [MarkdownSegment(isCode: false, isTable: false, isDiagram: false, isScheme: false, isDraw: false, isFree: false, language: "", text: text)] : out
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(segments) { s in
                if s.isCode { CodeBlockView(language: s.language, code: s.text) }
                else if s.isTable { TableBlockView(text: s.text) }
                else if s.isDiagram { FlowDiagramView(code: s.text) }
                else if s.isScheme { FlowDiagramView(code: s.text) }
                else if s.isDraw { DrawView(code: s.text) }
                else if s.isFree { FreeCanvasView(code: s.text) }
                else { AnnotatedTextView(text: s.text) }
            }
        }
    }
}

struct TableBlockView: View {
    let text: String
    var rows: [[String]] {
        text.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.map { line in
            var cells = line.split(separator: "|", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
            if cells.first == "" { cells.removeFirst() }
            if cells.last == "" { cells.removeLast() }
            return cells
        }
    }
    var body: some View {
        let cols = rows.map { $0.count }.max() ?? 0
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { ri, row in
                    HStack(spacing: 0) {
                        ForEach(0..<cols, id: \.self) { ci in
                            Text(ci < row.count ? row[ci] : "").font(ri == 0 ? .caption.bold() : .caption).padding(.horizontal, 8).padding(.vertical, 6).frame(width: 110, alignment: .leading)
                        }
                    }
                    .background(ri == 0 ? Color.primary.opacity(0.08) : Color.clear)
                    if ri < rows.count - 1 { Divider() }
                }
            }
        }
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.12)))
    }
}

struct CodeBlockView: View {
    let language: String; let code: String
    @State private var copied = false
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack { Text(language.isEmpty ? "code" : language).font(.caption2.bold()).foregroundStyle(.white.opacity(0.7)); Spacer(); Button(copied ? "Скопировано" : "Копировать") { UIPasteboard.general.string = code; copied = true; DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false } }.font(.caption2).foregroundStyle(.white) }
            .padding(.horizontal, 10).padding(.vertical, 6).background(Color.black.opacity(0.85))
            ScrollView(.horizontal, showsIndicators: false) { Text(code).font(.system(.caption, design: .monospaced)).foregroundStyle(.white).padding(10).textSelection(.enabled) }
        }.background(Color.black, in: RoundedRectangle(cornerRadius: 10))
    }
}
