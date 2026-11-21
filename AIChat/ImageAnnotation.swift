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
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func wrappedLines(_ text: String, font: UIFont, width: CGFloat) -> [String] {
        var result: [String] = []
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        for paragraph in text.components(separatedBy: "\n") {
            if paragraph.isEmpty { result.append(""); continue }
            var current = ""
            for word in paragraph.split(separator: " ") {
                let test = current.isEmpty ? String(word) : current + " " + word
                let w = (test as NSString).size(withAttributes: attrs).width
                if w > width && !current.isEmpty { result.append(current); current = String(word) } else { current = test }
            }
            if !current.isEmpty { result.append(current) }
        }
        return result
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
        let lines = wrappedLines(clean, font: font, width: usableW)
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
                    if line.isEmpty { continue }
                    let y = marginTop + CGFloat(i) * lineHeight
                    let angle = CGFloat((i * 37 % 5) - 2) * 0.004
                    let ctx = UIGraphicsGetCurrentContext()
                    ctx?.saveGState()
                    ctx?.translateBy(x: marginX, y: y)
                    ctx?.rotate(by: angle)
                    (line as NSString).draw(at: .zero, withAttributes: attrs)
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
