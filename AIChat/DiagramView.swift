import SwiftUI

struct FlowDiagramView: View {
    let code: String
    var chains: [[String]] {
        code.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.map { $0.components(separatedBy: "->").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }.filter { !$0.isEmpty }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(chains.enumerated()), id: \.offset) { pair in
                HStack(spacing: 6) {
                    ForEach(Array(pair.element.enumerated()), id: \.offset) { item in
                        if item.offset > 0 { Image(systemName: "arrow.right").font(.caption).foregroundStyle(.secondary) }
                        Text(item.element).font(.caption.bold()).padding(.horizontal, 8).padding(.vertical, 6).background(Color.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 8)).overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.orange.opacity(0.4)))
                    }
                }
            }
        }.padding(10).background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
    }
}

enum DrawCommand {
    case circle(cx: Double, cy: Double, r: Double, label: String)
    case rect(x: Double, y: Double, w: Double, h: Double, label: String)
    case line(x1: Double, y1: Double, x2: Double, y2: Double)
    case arrow(x1: Double, y1: Double, x2: Double, y2: Double)
    case triangle(x1: Double, y1: Double, x2: Double, y2: Double, x3: Double, y3: Double)
    case text(x: Double, y: Double, label: String)
    static func parse(_ code: String) -> [DrawCommand] {
        var out: [DrawCommand] = []
        for raw in code.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            let parts = line.split(separator: " ").map(String.init)
            guard let cmd = parts.first else { continue }
            func num(_ i: Int) -> Double { i < parts.count ? Double(parts[i]) ?? 0 : 0 }
            func rest(_ from: Int) -> String { parts.count > from ? parts[from...].joined(separator: " ").replacingOccurrences(of: "\"", with: "") : "" }
            switch cmd {
            case "circle": out.append(.circle(cx: num(1), cy: num(2), r: num(3), label: rest(4)))
            case "rect": out.append(.rect(x: num(1), y: num(2), w: num(3), h: num(4), label: rest(5)))
            case "line": out.append(.line(x1: num(1), y1: num(2), x2: num(3), y2: num(4)))
            case "arrow": out.append(.arrow(x1: num(1), y1: num(2), x2: num(3), y2: num(4)))
            case "triangle": out.append(.triangle(x1: num(1), y1: num(2), x2: num(3), y2: num(4), x3: num(5), y3: num(6)))
            case "text": out.append(.text(x: num(1), y: num(2), label: rest(3)))
            default: break
            }
        }
        return out
    }
}

struct DrawView: View {
    let code: String
    var commands: [DrawCommand] { DrawCommand.parse(code) }
    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(Array(commands.enumerated()), id: \.offset) { pair in DrawShapeView(cmd: pair.element, size: geo.size) }
            }
        }.frame(height: 220).background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.12)))
    }
}

struct DrawShapeView: View {
    let cmd: DrawCommand
    let size: CGSize
    func px(_ v: Double) -> CGFloat { CGFloat(v) / 100 * size.width }
    func py(_ v: Double) -> CGFloat { CGFloat(v) / 100 * size.height }
    @ViewBuilder var body: some View {
        switch cmd {
        case .circle(let cx, let cy, let r, let label):
            ZStack { Circle().stroke(Color.red, lineWidth: 2).frame(width: px(r * 2), height: px(r * 2)); if !label.isEmpty { Text(label).font(.caption2) } }.position(x: px(cx), y: py(cy))
        case .rect(let x, let y, let w, let h, let label):
            ZStack { Rectangle().stroke(Color.blue, lineWidth: 2).frame(width: px(w), height: py(h)); if !label.isEmpty { Text(label).font(.caption2) } }.position(x: px(x + w / 2), y: py(y + h / 2))
        case .line(let x1, let y1, let x2, let y2):
            Path { p in p.move(to: CGPoint(x: px(x1), y: py(y1))); p.addLine(to: CGPoint(x: px(x2), y: py(y2))) }.stroke(Color.primary, lineWidth: 2)
        case .arrow(let x1, let y1, let x2, let y2):
            Path { p in p.move(to: CGPoint(x: px(x1), y: py(y1))); p.addLine(to: CGPoint(x: px(x2), y: py(y2))) }.stroke(Color.orange, lineWidth: 2)
        case .triangle(let x1, let y1, let x2, let y2, let x3, let y3):
            Path { p in p.move(to: CGPoint(x: px(x1), y: py(y1))); p.addLine(to: CGPoint(x: px(x2), y: py(y2))); p.addLine(to: CGPoint(x: px(x3), y: py(y3))); p.closeSubpath() }.stroke(Color.blue, lineWidth: 2)
        case .text(let x, let y, let label):
            Text(label).font(.caption.bold()).position(x: px(x), y: py(y))
        }
    }
}
