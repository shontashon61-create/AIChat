import SwiftUI
import PhotosUI
import UIKit
import UniformTypeIdentifiers

func downscaleImageData(_ data: Data, maxDimension: CGFloat = 2048) -> Data? {
    guard let img = UIImage(data: data) else { return nil }
    let scale = min(1, maxDimension / max(img.size.width, img.size.height))
    if scale >= 1 && data.count < 900_000 { return data }
    let newSize = CGSize(width: img.size.width * scale, height: img.size.height * scale)
    let renderer = UIGraphicsImageRenderer(size: newSize)
    let resized = renderer.image { _ in img.draw(in: CGRect(origin: .zero, size: newSize)) }
    return resized.jpegData(compressionQuality: 0.8)
}

struct PhotoPicker: UIViewControllerRepresentable {
    var onPick: (Data, String, String) -> Void
    @Environment(\.dismiss) var dismiss
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var cfg = PHPickerConfiguration(); cfg.filter = .images; cfg.selectionLimit = 5
        let vc = PHPickerViewController(configuration: cfg); vc.delegate = context.coordinator; return vc
    }
    func updateUIViewController(_ vc: PHPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        var parent: PhotoPicker; init(parent: PhotoPicker) { self.parent = parent }
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()
            for r in results where r.itemProvider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                r.itemProvider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in if let d = data { let out = downscaleImageData(d) ?? d; DispatchQueue.main.async { self.parent.onPick(out, "image", "image/jpeg") } } }
            }
        }
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    var onPick: (Data, String, String) -> Void
    @Environment(\.dismiss) var dismiss
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let vc = UIImagePickerController()
        vc.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        vc.delegate = context.coordinator
        return vc
    }
    func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        var parent: CameraPicker; init(parent: CameraPicker) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            parent.dismiss()
            if let img = info[.originalImage] as? UIImage, let data = img.jpegData(compressionQuality: 0.85) {
                let out = downscaleImageData(data) ?? data
                DispatchQueue.main.async { self.parent.onPick(out, "image", "image/jpeg") }
            }
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}
