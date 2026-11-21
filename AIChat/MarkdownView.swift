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
                if s.isCode { CodeBlockView(language: s.language, code: s.text) } else if let rows = tableRows(s.text) { MarkdownTableView(rows: rows) } else { Text(attributed(s.text)) }
            }
        }
    }
    func tableRows(_ raw: String) -> [[String]]? {
        let lines = raw.components(separatedBy: .newlines).filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("|") }
        guard lines.count >= 2 else { return nil }
        let rows = lines.filter { !$0.contains("---") }.map { line in line.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
        return rows.isEmpty ? nil : rows
    }
    func attributed(_ raw: String) -> AttributedString {
        var t = convertFractions(raw)
        let u1 = extractUnderline(t, open: "++", close: "++"); t = u1.0
        let u2 = extractUnderline(t, open: "<u>", close: "</u>"); t = u2.0
        var attr = (try? AttributedString(markdown: t, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .full))) ?? AttributedString(t)
        for phrase in u1.1 + u2.1 { if let r = attr.range(of: phrase) { attr[r].underlineStyle = .single } }
        return attr
    }
    func extractUnderline(_ input: String, open: String, close: String) -> (String, [String]) {
        var t = input; var ranges: [String] = []
        while let s = t.range(of: open), let e = t.range(of: close, range: s.upperBound..<t.endIndex) { let inner = String(t[s.upperBound..<e.lowerBound]); ranges.append(inner); t.replaceSubrange(s.lowerBound..<e.upperBound, with: inner) }
        return (t, ranges)
    }
    func convertFractions(_ input: String) -> String {
        var t = input
        while let s = t.range(of: "\\frac{") { guard let m = t.range(of: "}{", range: s.upperBound..<t.endIndex), let e = t.range(of: "}", range: m.upperBound..<t.endIndex) else { break }; let a = String(t[s.upperBound..<m.lowerBound]); let b = String(t[m.upperBound..<e.lowerBound]); t.replaceSubrange(s.lowerBound..<e.upperBound, with: sup(a) + "\u{2044}" + sub(b)) }
        while let r = t.range(of: "[0-9]+/[0-9]+", options: .regularExpression) { let parts = t[r].split(separator: "/"); if parts.count == 2 { t.replaceSubrange(r, with: sup(String(parts[0])) + "\u{2044}" + sub(String(parts[1]))) } else { break } }
        return t
    }
    func sup(_ s: String) -> String { let map: [Character: String] = ["0": "\u{2070}", "1": "\u{00B9}", "2": "\u{00B2}", "3": "\u{00B3}", "4": "\u{2074}", "5": "\u{2075}", "6": "\u{2076}", "7": "\u{2077}", "8": "\u{2078}", "9": "\u{2079}", "-": "\u{207B}"]; return s.map { map[$0] ?? String($0) }.joined() }
    func sub(_ s: String) -> String { let map: [Character: String] = ["0": "\u{2080}", "1": "\u{2081}", "2": "\u{2082}", "3": "\u{2083}", "4": "\u{2084}", "5": "\u{2085}", "6": "\u{2086}", "7": "\u{2087}", "8": "\u{2088}", "9": "\u{2089}", "-": "\u{208B}"]; return s.map { map[$0] ?? String($0) }.joined() }
}

struct MarkdownTableView: View {
    let rows: [[String]]
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(rows.indices, id: \.self) { i in
                HStack(spacing: 0) {
                    ForEach(rows[i].indices, id: \.self) { j in
                        Text(rows[i][j]).font(i == 0 ? .caption.bold() : .caption).padding(6).frame(maxWidth: .infinity, alignment: .leading).background(i == 0 ? DesignTheme.chip : Color.clear).border(DesignTheme.border)
                    }
                }
            }
        }.clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct CodeBlockView: View {
    let language: String; let code: String
    @State private var copied = false
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack { Text(language.isEmpty ? "code" : language).font(.caption2.bold()).foregroundStyle(.white.opacity(0.7)); Spacer(); Button(copied ? "Скопировано" : "Копировать") { UIPasteboard.general.string = code; copied = true; DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false } }.font(.caption2).foregroundStyle(.white) }
            .padding(.horizontal, 10).padding(.vertical, 6).background(DesignTheme.codeBackground.opacity(0.85))
            ScrollView(.horizontal, showsIndicators: false) { Text(code).font(.system(.caption, design: .monospaced)).foregroundStyle(.white).padding(10).textSelection(.enabled) }
        }.background(DesignTheme.codeBackground, in: RoundedRectangle(cornerRadius: 10))
    }
}
