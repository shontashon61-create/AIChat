import UIKit

/// Рисует ответы ИИ синей ручкой прямо на фото, как в тетради.
/// Фразеологизм (часть до " — ") подчёркивается.
/// writeTextOntoImage пишет текст ПОВЕРХ фото — на листе А4, а не под ним.
enum ImageAnnotator {
    static let penBlue = UIColor(red: 0, green: 0, blue: 0.78, alpha: 1)

    static func parseAnswers(_ text: String) -> [String] {
        var out: [String] = []
        for raw in text.components(separatedBy: "\n") {
            var line = raw.trimmingCharacters(in: .whitespaces)
            line = line.replacingOccurrences(of: "**", with: "")
            line = line.replacingOccurrences(of: "++", with: "")
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

    static func handwritingFont(ofSize size: CGFloat) -> UIFont {
        for name in ["Noteworthy-Light", "Noteworthy", "BradleyHandITCTT-Bold", "MarkerFelt-Thin"] {
            if let f = UIFont(name: name, size: size) { return f }
        }
        return UIFont.italicSystemFont(ofSize: size)
    }

    static func sup(_ s: String) -> String { let map: [Character: String] = ["0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴", "5": "⁵", "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹", "-": "⁻"]; return s.map { map[$0] ?? String($0) }.joined() }
    static func sub(_ s: String) -> String { let map: [Character: String] = ["0": "₀", "1": "₁", "2": "₂", "3": "₃", "4": "₄", "5": "₅", "6": "₆", "7": "₇", "8": "₈", "9": "₉", "-": "₋"]; return s.map { map[$0] ?? String($0) }.joined() }
    static func convertFractions(_ input: String) -> String { var t = input; while let r = t.range(of: "[0-9]+/[0-9]+", options: .regularExpression) { let parts = t[r].split(separator: "/"); if parts.count == 2 { t.replaceSubrange(r, with: sup(String(parts[0])) + "⁄" + sub(String(parts[1]))) } else { break } }; return t }
    static func wrappedUnderlineLines(_ text: String, font: UIFont, width: CGFloat) -> [[(String, Bool)]] {
        var result: [[(String, Bool)]] = []
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        for paragraph in text.components(separatedBy: "\n") {
            if paragraph.isEmpty { result.append([("", false)]); continue }
            let low = paragraph.lowercased()
            let forceUnderline = !paragraph.contains("++") && (low.hasPrefix("ответ") || low.hasPrefix("итог") || low.hasPrefix("решение:"))
            var words: [(String, Bool)] = []
            var inUnderline = forceUnderline
            for raw in paragraph.split(separator: " ") {
                var w = String(raw)
                if w.hasPrefix("++") { w = String(w.dropFirst(2)); inUnderline = true }
                var ends = false
                if w.hasSuffix("++") { w = String(w.dropLast(2)); ends = true }
                if !w.isEmpty { words.append((w, inUnderline)) }
                if ends { inUnderline = false }
            }
            var current: [(String, Bool)] = []
            var currentText = ""
            for word in words {
                let test = currentText.isEmpty ? word.0 : currentText + " " + word.0
                let w = (test as NSString).size(withAttributes: attrs).width
                if w > width && !current.isEmpty { result.append(current); current = [word]; currentText = word.0 } else { current.append(word); currentText = test }
            }
            if !current.isEmpty { result.append(current) } else if words.isEmpty { result.append([("", false)]) }
        }
        return result
    }
    static func parsePlainText(_ text: String) -> String {
        var out: [String] = []
        for raw in text.components(separatedBy: "\n") {
            var line = raw.trimmingCharacters(in: .whitespaces)
            line = line.replacingOccurrences(of: "**", with: "")
            line = line.replacingOccurrences(of: "## ", with: "")
            line = line.replacingOccurrences(of: "# ", with: "")
            if line.hasPrefix("- ") { line = String(line.dropFirst(2)) }
            if line.count >= 3 {
                let first = line[line.startIndex]
                let second = line[line.index(after: line.startIndex)]
                if first.isNumber && second == "." { line = String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces) }
            }
            out.append(line)
        }
        var cleaned = out.joined(separator: "\n")
        while cleaned.contains("\n\n\n") { cleaned = cleaned.replacingOccurrences(of: "\n\n\n", with: "\n\n") }
        return convertFractions(cleaned.trimmingCharacters(in: .whitespacesAndNewlines))
    }


    static func writeTextOntoImage(from image: UIImage, text: String) -> [UIImage] {
        let clean = parsePlainText(text)
        guard !clean.isEmpty else { return [] }
        let w = image.size.width
        let h = image.size.height
        let scale = max(0.8, w / 1000.0)
        let fontSize: CGFloat = 44 * scale
        let font = handwritingFont(ofSize: fontSize)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: penBlue]
        let marginX = w * 0.08
        let marginTop = h * 0.06
        let marginBottom = h * 0.05
        let usableW = w - marginX * 2
        let usableH = h - marginTop - marginBottom
        let lines = wrappedUnderlineLines(clean, font: font, width: usableW)
        let lineHeight = font.lineHeight * 1.6
        let perPage = max(1, Int(usableH / lineHeight))
        var pages: [UIImage] = []
        var start = 0
        while start < lines.count {
            let end = min(lines.count, start + perPage)
            let pageLines = Array(lines[start..<end])
            let isFirst = pages.isEmpty
            let base: UIImage
            if isFirst {
                base = image
            } else {
                let blank = UIGraphicsImageRenderer(size: image.size)
                base = blank.image { ctx in UIColor.white.setFill(); ctx.fill(CGRect(origin: .zero, size: image.size)) }
            }
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
                        (seg.0 as NSString).draw(at: CGPoint(x: xOff, y: 0), withAttributes: attrs)
                        if seg.1 { let uy = font.lineHeight + 4 * scale; let p = UIBezierPath(); p.move(to: CGPoint(x: xOff, y: uy)); p.addLine(to: CGPoint(x: xOff + wSeg, y: uy)); penBlue.setStroke(); p.lineWidth = 3 * scale; p.stroke() }
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
