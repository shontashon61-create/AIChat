import SwiftUI

struct FreeItem: Identifiable {
    let id = UUID()
    var kind = "text"
    var x = 50.0
    var y = 50.0
    var x2 = 0.0
    var y2 = 0.0
    var w = 0.0
    var h = 0.0
    var r = 10.0
    var rot = 0.0
    var size = 16.0
    var color = "primary"
    var style = "solid"
    var text = ""
}

enum FreeColor {
    static func from(_ s: String) -> Color {
        switch s.lowercased() {
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "yellow": return .yellow
        case "purple": return .purple
        case "pink": return .pink
        case "black": return .black
        case "gray", "grey": return .gray
        default: return .primary
        }
    }
}

enum FreeParser {
    static let colors: Set<String> = ["red", "blue", "green", "orange", "yellow", "purple", "pink", "black", "gray", "grey", "primary"]
    static func parse(_ code: String) -> (String, [FreeItem]) {
        var base = ""
        var items: [FreeItem] = []
        for raw in code.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            var toks = line.split(separator: " ").map(String.init)
            guard let cmd = toks.first?.lowercased() else { continue }
            toks.removeFirst()
            let nums = toks.compactMap { Double($0) }
            var words = toks.filter { Double($0) == nil }
            if cmd == "base" {
                base = toks.joined(separator: " ")
                continue
            }
            var color = "primary"
            if let first = words.first, colors.contains(first.lowercased()) {
                color = first
                words.removeFirst()
            }
            var style = "solid"
            if let first = words.first, first == "bold" || first == "italic" {
                style = first
                words.removeFirst()
            }
            if cmd == "text" || cmd == "q" || cmd == "question" {
                var rot = 0.0
                var size = 16.0
                if nums.count == 3 { size = nums[2] }
                if nums.count >= 4 { rot = nums[2]; size = nums[3] }
                items.append(FreeItem(kind: cmd, x: nums.count > 0 ? nums[0] : 50, y: nums.count > 1 ? nums[1] : 50, rot: rot, size: size, color: color, style: style, text: words.joined(separator: " ")))
            } else if cmd == "arrow" || cmd == "line" || cmd == "underline" {
                var st = style
                if let first = words.first, ["dashed", "dash", "dotted", "dot", "wave", "wavy"].contains(first.lowercased()) { st = first; words.removeFirst() }
                if nums.count >= 4 { items.append(FreeItem(kind: cmd, x: nums[0], y: nums[1], x2: nums[2], y2: nums[3], color: color, style: st)) }
            } else if cmd == "circle" {
                if nums.count >= 3 { items.append(FreeItem(kind: cmd, x: nums[0], y: nums[1], r: nums[2], color: color)) }
            } else if cmd == "rect" || cmd == "box" || cmd == "hl" || cmd == "highlight" {
                if nums.count >= 4 { items.append(FreeItem(kind: cmd, x: nums[0], y: nums[1], w: nums[2], h: nums[3], color: color, text: words.joined(separator: " "))) }
            }
        }
        return (base, items)
    }
}

struct FreeCanvasView: View {
    let code: String
    var parsed: (String, [FreeItem]) { FreeParser.parse(code) }
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(.secondarySystemBackground)
                if !parsed.0.isEmpty {
                    Text(parsed.0).font(.system(size: 20, weight: .semibold)).multilineTextAlignment(.center).padding(.horizontal, 8).frame(width: geo.size.width - 16).position(x: geo.size.width * 0.5, y: geo.size.height * 0.5)
                }
                ForEach(parsed.1) { it in
                    Group {
                        if it.kind == "text" || it.kind == "q" || it.kind == "question" {
                            Text(it.text).font(.system(size: CGFloat(it.size), weight: it.style == "bold" ? .bold : .regular)).italic(it.style == "italic").foregroundStyle(FreeColor.from(it.color)).rotationEffect(.degrees(it.rot)).position(x: geo.size.width * CGFloat(it.x / 100), y: geo.size.height * CGFloat(it.y / 100))
                        } else if it.kind == "circle" {
                            Circle().stroke(FreeColor.from(it.color), lineWidth: 2).frame(width: geo.size.width * CGFloat(it.r / 100) * 2, height: geo.size.width * CGFloat(it.r / 100) * 2).position(x: geo.size.width * CGFloat(it.x / 100), y: geo.size.height * CGFloat(it.y / 100))
                        } else if it.kind == "arrow" || it.kind == "line" || it.kind == "underline" {
                            Path { p in p.move(to: CGPoint(x: geo.size.width * CGFloat(it.x / 100), y: geo.size.height * CGFloat(it.y / 100))); p.addLine(to: CGPoint(x: geo.size.width * CGFloat(it.x2 / 100), y: geo.size.height * CGFloat(it.y2 / 100))) }.stroke(FreeColor.from(it.color), style: StrokeStyle(lineWidth: 2, dash: it.style == "dashed" || it.style == "dash" ? [7, 5] : it.style == "dotted" || it.style == "dot" ? [2, 5] : it.style == "wave" || it.style == "wavy" ? [4, 3] : []))
                        } else if it.kind == "rect" || it.kind == "box" {
                            Rectangle().stroke(FreeColor.from(it.color), lineWidth: 2).frame(width: geo.size.width * CGFloat(it.w / 100), height: geo.size.height * CGFloat(it.h / 100)).position(x: geo.size.width * CGFloat((it.x + it.w / 2) / 100), y: geo.size.height * CGFloat((it.y + it.h / 2) / 100))
                        } else if it.kind == "hl" || it.kind == "highlight" {
                            Rectangle().fill(Color.yellow.opacity(0.5)).frame(width: geo.size.width * CGFloat(it.w / 100), height: geo.size.height * CGFloat(it.h / 100)).position(x: geo.size.width * CGFloat((it.x + it.w / 2) / 100), y: geo.size.height * CGFloat((it.y + it.h / 2) / 100))
                        }
                    }
                }
            }
        }
        .frame(height: 260)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.12)))
    }
}