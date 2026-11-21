import UIKit

/// Рисует ответы ИИ синей ручкой прямо на фото, как в тетради.
/// Фразеологизм (часть до " — ") подчёркивается.
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
}
