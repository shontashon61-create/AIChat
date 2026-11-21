import SwiftUI
import UIKit
import CoreImage

struct ImageEditorView: View {
    let original: UIImage
    let onSave: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var brightness: Double = 0
    @State private var contrast: Double = 1
    @State private var saturation: Double = 1
    @State private var rotation: Int = 0
    @State private var flipped = false
    @State private var selectedFilter = 0
    @State private var writeText = ""
    @State private var writtenImage: UIImage?
    private let filters = ["Оригинал", "Ч/Б", "Сепия", "Яркий", "Тёплый", "Холодный"]
    private let ciContext = CIContext()

    var editedImage: UIImage {
        var base = rotatedImage(writtenImage ?? original, degrees: rotation, flipped: flipped)
        guard let ci = CIImage(image: base) else { return base }
        var out = ci
        switch selectedFilter {
        case 1:
            if let f = CIFilter(name: "CIPhotoEffectMono") { f.setValue(out, forKey: kCIInputImageKey); if let o = f.outputImage { out = o } }
        case 2:
            if let f = CIFilter(name: "CISepiaTone") { f.setValue(out, forKey: kCIInputImageKey); f.setValue(0.8, forKey: kCIInputIntensityKey); if let o = f.outputImage { out = o } }
        case 3:
            if let f = CIFilter(name: "CIColorControls") { f.setValue(out, forKey: kCIInputImageKey); f.setValue(1.5, forKey: kCIInputSaturationKey); f.setValue(1.15, forKey: kCIInputContrastKey); if let o = f.outputImage { out = o } }
        case 4:
            if let f = CIFilter(name: "CITemperatureAndTint") { f.setValue(out, forKey: kCIInputImageKey); f.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral"); f.setValue(CIVector(x: 4500, y: 0), forKey: "inputTargetNeutral"); if let o = f.outputImage { out = o } }
        case 5:
            if let f = CIFilter(name: "CITemperatureAndTint") { f.setValue(out, forKey: kCIInputImageKey); f.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral"); f.setValue(CIVector(x: 8500, y: 0), forKey: "inputTargetNeutral"); if let o = f.outputImage { out = o } }
        default:
            break
        }
        if let f = CIFilter(name: "CIColorControls") {
            f.setValue(out, forKey: kCIInputImageKey)
            f.setValue(brightness, forKey: kCIInputBrightnessKey)
            f.setValue(contrast, forKey: kCIInputContrastKey)
            f.setValue(saturation, forKey: kCIInputSaturationKey)
            if let o = f.outputImage { out = o }
        }
        guard let cg = ciContext.createCGImage(out, from: out.extent) else { return base }
        return UIImage(cgImage: cg, scale: base.scale, orientation: .up)
    }

    func rotatedImage(_ image: UIImage, degrees: Int, flipped: Bool) -> UIImage {
        let d = ((degrees % 360) + 360) % 360
        if d == 0 && !flipped { return image }
        let radians = CGFloat(d) * .pi / 180
        var size = image.size
        if d == 90 || d == 270 { size = CGSize(width: image.size.height, height: image.size.width) }
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            ctx.cgContext.translateBy(x: size.width / 2, y: size.height / 2)
            ctx.cgContext.rotate(by: radians)
            ctx.cgContext.scaleBy(x: flipped ? -1 : 1, y: 1)
            image.draw(in: CGRect(x: -image.size.width / 2, y: -image.size.height / 2, width: image.size.width, height: image.size.height))
        }
    }

    func reset() { brightness = 0; contrast = 1; saturation = 1; rotation = 0; flipped = false; selectedFilter = 0; writtenImage = nil; writeText = "" }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Image(uiImage: editedImage).resizable().scaledToFit().frame(maxHeight: 360).cornerRadius(16).overlay(RoundedRectangle(cornerRadius: 16).stroke(DesignTheme.border))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack { ForEach(filters.indices, id: \.self) { i in Button(filters[i]) { selectedFilter = i }.padding(.horizontal, 12).padding(.vertical, 8).background(selectedFilter == i ? DesignTheme.primary : DesignTheme.chip, in: Capsule()).foregroundStyle(selectedFilter == i ? DesignTheme.onPrimary : DesignTheme.text).font(.caption) } }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Написать на фото").font(.caption.bold())
                    TextField("Текст синей ручкой...", text: $writeText, axis: .vertical).lineLimit(1...3).padding(8).background(DesignTheme.chip, in: RoundedRectangle(cornerRadius: 10))
                    Button("Вписать текст") { let pages = ImageAnnotator.writeTextOntoImage(from: writtenImage ?? original, text: writeText); if let first = pages.first { writtenImage = first } }.disabled(writeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).font(.caption)
                }.padding(12).background(DesignTheme.chip, in: RoundedRectangle(cornerRadius: 12))
                VStack(spacing: 10) {
                    HStack { Text("Яркость").font(.caption); Slider(value: $brightness, in: -0.5...0.5, step: 0.01); Text(String(format: "%.2f", brightness)).font(.caption2).foregroundStyle(.secondary).frame(width: 36) }
                    HStack { Text("Контраст").font(.caption); Slider(value: $contrast, in: 0.5...1.5, step: 0.01); Text(String(format: "%.2f", contrast)).font(.caption2).foregroundStyle(.secondary).frame(width: 36) }
                    HStack { Text("Насыщенность").font(.caption); Slider(value: $saturation, in: 0...2, step: 0.01); Text(String(format: "%.2f", saturation)).font(.caption2).foregroundStyle(.secondary).frame(width: 36) }
                }.padding(12).background(DesignTheme.chip, in: RoundedRectangle(cornerRadius: 12))
                HStack(spacing: 8) {
                    Button { rotation = (rotation + 90) % 360 } label: { Label("Повернуть", systemImage: "rotate.right") }.padding(.horizontal, 12).padding(.vertical, 8).background(DesignTheme.chip, in: Capsule()).font(.caption)
                    Button { flipped.toggle() } label: { Label("Отразить", systemImage: "arrow.left.and.right") }.padding(.horizontal, 12).padding(.vertical, 8).background(DesignTheme.chip, in: Capsule()).font(.caption)
                    Button("Сбросить") { reset() }.padding(.horizontal, 12).padding(.vertical, 8).background(DesignTheme.chip, in: Capsule()).font(.caption)
                }
                Spacer()
            }.padding().background(DesignTheme.background)
            .navigationTitle("Редактор фото").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Отмена") { dismiss() } }; ToolbarItem(placement: .topBarTrailing) { Button("Сохранить") { onSave(editedImage); dismiss() }.bold() } }
        }
    }
}
