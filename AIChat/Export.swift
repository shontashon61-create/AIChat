import SwiftUI
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

enum Exporter {
    static func makePDF(title: String, text: String) -> URL? {
        let page = CGRect(x: 0, y: 0, width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: page)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("answer.pdf")
        let body = title + "\n\n" + text
        do {
            try renderer.writePDF(to: url) { ctx in
                ctx.beginPage()
                let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 13)]
                body.draw(with: page.insetBy(dx: 36, dy: 36), options: .usesLineFragmentOrigin, attributes: attrs, context: nil)
            }
            return url
        } catch { return nil }
    }
    static func makeImage(title: String, text: String) -> UIImage? {
        let size = CGSize(width: 900, height: 1200)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            UIColor.systemBackground.setFill(); UIRectFill(CGRect(origin: .zero, size: size))
            let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 30), .foregroundColor: UIColor.label]
            (title + "\n\n" + text).draw(with: CGRect(x: 40, y: 40, width: size.width - 80, height: size.height - 80), options: .usesLineFragmentOrigin, attributes: attrs, context: nil)
        }
    }
    static func makeDocument(title: String, text: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("today.txt")
        do { try (title + "\n\n" + text).write(to: url, atomically: true, encoding: .utf8); return url } catch { return nil }
    }
}
