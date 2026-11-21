import UIKit

enum ImageAnnotator {
    static let penBlue = UIColor(red: 0, green: 0, blue: 0.78, alpha: 1)
    static func parseAnswers(_ text: String) -> [String] {
        var out: [String] = []
        for raw in text.components(separatedBy: "\n") {
            var line = raw.trimmingCharacters(in: .whitespaces)
            line = line.replacingOccurrences(of: "**", with: "")
            line = line.replacingOccurrences(of: "++", with: "")
            line = line.replacingOccurrences(of: "==", with: "")
            line = line.replacingOccurrences(of: "~~", with: "")
            line = line.replacingOccurrences(of: "^^", with: "")
            if line.isEmpty { continue }
            if line.hasPrefix("-") { line = String(line.dropFirst()).trimmingCharacters(in: .whitespaces) }
            out.append(line)
        }
        return out
    }
    static func head(of line: String) -> String {
        if let r = line.range(of: " — ") { return String(line[..<r.lowerBound]) }
        if let r = line.range(of: " - ") { return String(line[..<r.lowerBound]) }
        return line
    }
    static func annotatedImage(from image: UIImage, answers: [String]) -> UIImage {
        let w = image.size.width
        let scale = max(0.8, w / 1000.0)
        let font = UIFont.systemFont(ofSize: 44 * scale, weight: .medium)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: penBlue]
        let padding: CGFloat = 40 * scale
        let lineGap: CGFloat = 28 * scale
        var heights: [CGFloat] = []
        for line in answers {
            let rect = (line as NSString).boundingRect(with: CGSize(width: w - padding * 2, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attrs, context: nil)
            heights.append(ceil(rect.height) + lineGap)
        }
        let extra = heights.reduce(0, +) + padding * 2
        let size = CGSize(width: w, height: image.size.height + extra)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            image.draw(in: CGRect(origin: .zero, size: image.size))
            var y = image.size.height + padding
            for (i, line) in answers.enumerated() {
                let rect = CGRect(x: padding, y: y, width: w - padding * 2, height: heights[i])
                (line as NSString).draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attrs, context: nil)
                let h = head(of: line)
                let headWidth = (h as NSString).size(withAttributes: attrs).width
                let underlineY = y + font.lineHeight + 6 * scale
                let path = UIBezierPath()
                path.move(to: CGPoint(x: padding, y: underlineY))
                path.addLine(to: CGPoint(x: padding + min(headWidth, rect.width), y: underlineY))
                penBlue.setStroke()
                path.lineWidth = 3 * scale
                path.stroke()
                y += heights[i]
            }
        }
    }
    static func annotatedAttachment(from image: UIImage, answers: [String]) -> Attachment? {
        let out = annotatedImage(from: image, answers: answers)
        guard let data = out.jpegData(compressionQuality: 0.9) else { return nil }
        return Attachment(kind: "image", fileName: "answered.jpg", mimeType: "image/jpeg", base64: data.base64EncodedString())
    }
    static func handwritingFont(ofSize size: CGFloat, text: String = "") -> UIFont {
        if text.contains(where: { $0.unicodeScalars.contains { (0x0400...0x04FF).contains($0.value) } }) { return UIFont.italicSystemFont(ofSize: size) }
        for name in ["Noteworthy-Light", "Noteworthy", "BradleyHandITCTT-Bold", "MarkerFelt-Thin"] {
            if let f = UIFont(name: name, size: size) { return f }
        }
        return UIFont.italicSystemFont(ofSize: size)
    }
    static func sup(_ s: String) -> String { let map: [Character: String] = ["0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴", "5": "⁵", "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹", "-": "⁻", "+": "⁺", "x": "ˣ", "n": "ⁿ"]; return s.map { map[$0] ?? String($0) }.joined() }
    static func sub(_ s: String) -> String { let map: [Character: String] = ["0": "₀", "1": "₁", "2": "₂", "3": "₃", "4": "₄", "5": "₅", "6": "₆", "7": "₇", "8": "₈", "9": "₉", "-": "₋", "+": "₊", "x": "ₓ", "n": "ₙ"]; return s.map { map[$0] ?? String($0) }.joined() }
    static func convertFormulas(_ input: String) -> String {
        var t = input
        while let s = t.range(of: "frac{") { guard let m = t.range(of: "}{", range: s.upperBound..<t.endIndex), let e = t.range(of: "}", range: m.upperBound..<t.endIndex) else { break }; let a = String(t[s.upperBound..<m.lowerBound]); let b = String(t[m.upperBound..<e.lowerBound]); var start = s.lowerBound; if start != t.startIndex { let prev = t.index(before: start); if t[prev].unicodeScalars.first?.value == 92 { start = prev } }; t.replaceSubrange(start..<e.upperBound, with: sup(a) + "⁄" + sub(b)) }
        while let s = t.range(of: "sqrt{") { guard let e = t.range(of: "}", range: s.upperBound..<t.endIndex) else { break }; let a = String(t[s.upperBound..<e.lowerBound]); var start = s.lowerBound; if start != t.startIndex { let prev = t.index(before: start); if t[prev].unicodeScalars.first?.value == 92 { start = prev } }; t.replaceSubrange(start..<e.upperBound, with: "√(" + a + ")") }
        while let r = t.range(of: "^") { let after = t.index(after: r.lowerBound); if after >= t.endIndex { break }; if t[after] == "{" { guard let e = t.range(of: "}", range: after..<t.endIndex) else { break }; let inner = String(t[t.index(after: after)..<e.lowerBound]); t.replaceSubrange(r.lowerBound..<e.upperBound, with: sup(inner)) } else { let ch = String(t[after]); t.replaceSubrange(r.lowerBound...after, with: sup(ch)) } }
        while let r = t.range(of: "_") { let after = t.index(after: r.lowerBound); if after >= t.endIndex { break }; if t[after] == "{" { guard let e = t.range(of: "}", range: after..<t.endIndex) else { break }; let inner = String(t[t.index(after: after)..<e.lowerBound]); t.replaceSubrange(r.lowerBound..<e.upperBound, with: sub(inner)) } else { let ch = String(t[after]); if ch.range(of: "[0-9a-zA-Z]", options: .regularExpression) != nil { t.replaceSubrange(r.lowerBound...after, with: sub(ch)) } else { break } } }
        while let r = t.range(of: "[0-9]+/[0-9]+", options: .regularExpression) { let parts = t[r].split(separator: "/"); if parts.count == 2 { t.replaceSubrange(r, with: sup(String(parts[0])) + "⁄" + sub(String(parts[1]))) } else { break } }
        return t
    }
    static func parsePlainText(_ text: String) -> String {
        var out: [String] = []
        for raw in text.components(separatedBy: "\n") {
            var line = raw.trimmingCharacters(in: .whitespaces)
            line = line.replacingOccurrences(of: "**", with: "")
            line = line.replacingOccurrences(of: "## ", with: "")
            line = line.replacingOccurrences(of: "# ", with: "")
            if line.hasPrefix("- ") { line = String(line.dropFirst(2)) }
            if line.count >= 3 { let first = line[line.startIndex]; let second = line[line.index(after: line.startIndex)]; if first.isNumber && second == "." { line = String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces) } }
            out.append(line)
        }
        var cleaned = out.joined(separator: "\n")
        while cleaned.contains("\n\n\n") { cleaned = cleaned.replacingOccurrences(of: "\n\n\n", with: "\n\n") }
        return convertFormulas(cleaned.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    static func wrappedStyledLines(_ text: String, font: UIFont, width: CGFloat) -> [[(String, Int)]] {
        var result: [[(String, Int)]] = []
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        for paragraph in text.components(separatedBy: "\n") {
            if paragraph.isEmpty { result.append([("", 0)]); continue }
            let low = paragraph.lowercased()
            let force = !paragraph.contains("++") && !paragraph.contains("==") && (low.hasPrefix("ответ") || low.hasPrefix("итог") || low.hasPrefix("решение:"))
            var words: [(String, Int)] = []
            var cur = force ? 1 : 0
            for raw in paragraph.split(separator: " ") {
                var w = String(raw)
                var style = cur
                var ends = false
                if w.hasPrefix("++") { w = String(w.dropFirst(2)); style = 1 } else if w.hasPrefix("==") { w = String(w.dropFirst(2)); style = 2 } else if w.hasPrefix("~~") { w = String(w.dropFirst(2)); style = 3 } else if w.hasPrefix("^^") { w = String(w.dropFirst(2)); style = 4 }
                if w.hasSuffix("++") { w = String(w.dropLast(2)); style = 1; ends = true } else if w.hasSuffix("==") { w = String(w.dropLast(2)); style = 2; ends = true } else if w.hasSuffix("~~") { w = String(w.dropLast(2)); style = 3; ends = true } else if w.hasSuffix("^^") { w = String(w.dropLast(2)); style = 4; ends = true }
                if !w.isEmpty { words.append((w, style)) }
                cur = ends ? 0 : style
            }
            var current: [(String, Int)] = []
            var curText = ""
            for word in words {
                let test = curText.isEmpty ? word.0 : curText + " " + word.0
                let ww = (test as NSString).size(withAttributes: attrs).width
                if ww > width && !current.isEmpty { result.append(current); current = [word]; curText = word.0 } else { current.append(word); curText = test }
            }
            if !current.isEmpty { result.append(current) } else if words.isEmpty { result.append([("", 0)]) }
        }
        return result
    }
    static func drawUnderline(from x: CGFloat, to x2: CGFloat, y: CGFloat, style: Int, scale: CGFloat) {
        penBlue.setStroke()
        if style == 1 { let p = UIBezierPath(); p.move(to: CGPoint(x: x, y: y)); p.addLine(to: CGPoint(x: x2, y: y)); p.lineWidth = 3 * scale; p.stroke() }
        else if style == 2 { for dy in [CGFloat(0), 6 * scale] { let p = UIBezierPath(); p.move(to: CGPoint(x: x, y: y + dy)); p.addLine(to: CGPoint(x: x2, y: y + dy)); p.lineWidth = 2.5 * scale; p.stroke() } }
        else if style == 3 { let p = UIBezierPath(); p.move(to: CGPoint(x: x, y: y)); p.addLine(to: CGPoint(x: x2, y: y)); p.setLineDash([7 * scale, 5 * scale], count: 2, phase: 0); p.lineWidth = 3 * scale; p.stroke() }
        else if style == 4 { let p = UIBezierPath(); p.move(to: CGPoint(x: x, y: y)); var cx = x; var up = true; while cx < x2 { let nx = min(cx + 6 * scale, x2); p.addQuadCurve(to: CGPoint(x: nx, y: y), controlPoint: CGPoint(x: cx + 3 * scale, y: y + (up ? -4 * scale : 4 * scale))); cx = nx; up.toggle() }; p.lineWidth = 2.5 * scale; p.stroke() }
    }
    static func writeTextOntoImage(from image: UIImage, text: String) -> [UIImage] {
        let clean = parsePlainText(text)
        guard !clean.isEmpty else { return [] }
        let w = image.size.width
        let h = image.size.height
        let scale = max(0.8, w / 1000.0)
        let fontSize: CGFloat = 44 * scale
        let font = handwritingFont(ofSize: fontSize, text: clean)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: penBlue]
        let marginX = w * 0.08
        let marginTop = h * 0.06
        let marginBottom = h * 0.05
        let usableW = w - marginX * 2
        let usableH = h - marginTop - marginBottom
        let lines = wrappedStyledLines(clean, font: font, width: usableW)
        let lineHeight = font.lineHeight * 1.6
        let perPage = max(1, Int(usableH / lineHeight))
        var pages: [UIImage] = []
        var start = 0
        while start < lines.count {
            let end = min(lines.count, start + perPage)
            let pageLines = Array(lines[start..<end])
            let isFirst = pages.isEmpty
            let base: UIImage
            if isFirst { base = image } else { let blank = UIGraphicsImageRenderer(size: image.size); base = blank.image { ctx in UIColor.white.setFill(); ctx.fill(CGRect(origin: .zero, size: image.size)) } }
            let renderer = UIGraphicsImageRenderer(size: base.size)
            let page = renderer.image { _ in
                base.draw(in: CGRect(origin: .zero, size: base.size))
                for (i, line) in pageLines.enumerated() {
                    if line.allSatisfy({ $0.0.isEmpty }) { continue }
                    let y = marginTop + CGFloat(i) * lineHeight
                    let angle = CGFloat((i * 37 % 5) - 2) * 0.004
                    let ctx = UIGraphicsGetCurrentContext()
                    ctx?.saveGState()
                    ctx?.translateBy(x: marginX, y: y)
                    ctx?.rotate(by: angle)
                    var xOff: CGFloat = 0
                    let spaceW = (" " as NSString).size(withAttributes: attrs).width
                    for (wi, seg) in line.enumerated() {
                        if seg.0.isEmpty { continue }
                        let wSeg = (seg.0 as NSString).size(withAttributes: attrs).width
                        let jitterY = CGFloat((wi * 13 % 3) - 1) * 1.5 * scale
                        var a2 = attrs
                        a2[.foregroundColor] = penBlue.withAlphaComponent(0.85 + CGFloat((wi * 29) % 15) / 100.0)
                        (seg.0 as NSString).draw(at: CGPoint(x: xOff, y: jitterY), withAttributes: a2)
                        if seg.1 != 0 { drawUnderline(from: xOff, to: xOff + wSeg, y: font.lineHeight + 4 * scale + jitterY, style: seg.1, scale: scale) }
                        xOff += wSeg
                        if wi < line.count - 1 { xOff += spaceW }
                    }
                    ctx?.restoreGState()
                }
            }
            pages.append(page)
            start = end
        }
        return pages
    }
    static func annotatedAttachmentOnto(from image: UIImage, text: String) -> [Attachment] {
        let pages = writeTextOntoImage(from: image, text: text)
        var out: [Attachment] = []
        for (i, page) in pages.enumerated() {
            guard let data = page.jpegData(compressionQuality: 0.9) else { continue }
            let name = pages.count == 1 ? "answered.jpg" : "answered-\(i + 1).jpg"
            out.append(Attachment(kind: "image", fileName: name, mimeType: "image/jpeg", base64: data.base64EncodedString()))
        }
        return out
    }
}
