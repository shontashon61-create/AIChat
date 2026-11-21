import SwiftUI
import PhotosUI
import AVFoundation
import Speech
import UniformTypeIdentifiers

func downscaleImageData(_ data: Data, maxDimension: CGFloat = 1024) -> Data? {
    guard let img = UIImage(data: data) else { return nil }
    let scale = min(1, maxDimension / max(img.size.width, img.size.height))
    if scale >= 1 && data.count < 900_000 { return data }
    let newSize = CGSize(width: img.size.width * scale, height: img.size.height * scale)
    let renderer = UIGraphicsImageRenderer(size: newSize)
    let resized = renderer.image { _ in img.draw(in: CGRect(origin: .zero, size: newSize)) }
    return resized.jpegData(compressionQuality: 0.75)
}

func cleanForSpeech(_ text: String) -> String {
    var t = text
    while let r = t.range(of: "```[\\s\\S]*?```", options: .regularExpression) { t.removeSubrange(r) }
    for c in ["#", "*", "`", "_", ">"] { t = t.replacingOccurrences(of: c, with: "") }
    return t.trimmingCharacters(in: .whitespacesAndNewlines)
}

struct PhotoVideoPicker: UIViewControllerRepresentable {
    var onPick: (Data, String, String) -> Void
    @Environment(\.dismiss) var dismiss
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var cfg = PHPickerConfiguration(); cfg.filter = .any(of: [.images, .videos]); cfg.selectionLimit = 5
        let vc = PHPickerViewController(configuration: cfg); vc.delegate = context.coordinator; return vc
    }
    func updateUIViewController(_ vc: PHPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        var parent: PhotoVideoPicker; init(parent: PhotoVideoPicker) { self.parent = parent }
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()
            for r in results {
                if r.itemProvider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    r.itemProvider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in if let d = data { let out = downscaleImageData(d) ?? d; DispatchQueue.main.async { self.parent.onPick(out, "image", "image/jpeg") } } }
                } else if r.itemProvider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                    r.itemProvider.loadDataRepresentation(forTypeIdentifier: UTType.movie.identifier) { data, _ in if let d = data { DispatchQueue.main.async { self.parent.onPick(d, "video", "video/mp4") } } }
                }
            }
        }
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    var onPick: (Data, String, String) -> Void
    @Environment(\.dismiss) var dismiss
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let vc = UIImagePickerController(); vc.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary; vc.mediaTypes = [UTType.image.identifier, UTType.movie.identifier]; vc.delegate = context.coordinator; return vc
    }
    func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        var parent: CameraPicker; init(parent: CameraPicker) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.dismiss()
            if let img = info[.originalImage] as? UIImage, let d = img.jpegData(compressionQuality: 0.82), let out = downscaleImageData(d) ?? d as Data? { parent.onPick(out, "image", "image/jpeg") }
            if let url = info[.mediaURL] as? URL, let d = try? Data(contentsOf: url) { parent.onPick(d, "video", "video/mp4") }
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}

class SpeechManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var transcript = ""
    @Published var errorText: String?
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ru_RU"))
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    func start() {
        SFSpeechRecognizer.requestAuthorization { _ in }
        AVAudioSession.sharedInstance().requestRecordPermission { granted in if !granted { DispatchQueue.main.async { self.errorText = "Нет доступа к микрофону. Разрешите в Настройках iPhone." } } }
        stop()
        guard let rec = recognizer, rec.isAvailable else { errorText = "Распознавание речи недоступно"; return }
        request = SFSpeechAudioBufferRecognitionRequest(); request?.shouldReportPartialResults = true
        guard let req = request else { return }
        task = rec.recognitionTask(with: req) { [weak self] result, err in
            if let err = err { DispatchQueue.main.async { self?.errorText = err.localizedDescription; self?.isRecording = false }; return }
            if let t = result?.bestTranscription.formattedString { DispatchQueue.main.async { self?.transcript = t } }
        }
        let fmt = engine.inputNode.outputFormat(forBus: 0)
        engine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: fmt) { [weak self] buf, _ in self?.request?.append(buf) }
        do { try AVAudioSession.sharedInstance().setCategory(.record, mode: .measurement, options: .duckOthers); try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation); engine.prepare(); try engine.start(); isRecording = true } catch { errorText = error.localizedDescription; stop() }
    }
    func stop() {
        if engine.isRunning { engine.stop(); engine.inputNode.removeTap(onBus: 0) }
        request?.endAudio(); task?.cancel(); request = nil; task = nil; isRecording = false
    }
}

enum VoiceCatalog {
    static let pleasantNames = ["Milena", "Yuri", "Samantha", "Ava", "Daniel", "Karen", "Moira", "Tessa", "Zira", "Veena", "Fiona", "Alex", "Victoria"]
    static func sortedVoices() -> [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices().sorted { a, b in
            let rank: (String) -> Int = { $0.hasPrefix("ru") ? 0 : $0.hasPrefix("en-US") ? 1 : $0.hasPrefix("en") ? 2 : 3 }
            if rank(a.language) != rank(b.language) { return rank(a.language) < rank(b.language) }
            let ai = pleasantNames.firstIndex(of: a.name) ?? 99
            let bi = pleasantNames.firstIndex(of: b.name) ?? 99
            if ai != bi { return ai < bi }
            return a.name < b.name
        }
    }
    static func voice(for id: String) -> AVSpeechSynthesisVoice? {
        if id.isEmpty { return nil }
        if let v = AVSpeechSynthesisVoice(identifier: id) { return v }
        if id.count == 5 { return AVSpeechSynthesisVoice(language: id) }
        return AVSpeechSynthesisVoice.speechVoices().first { $0.identifier == id }
    }
    static func openVoiceSettings() { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } }
}

class Speaker: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = Speaker(); private let synth = AVSpeechSynthesizer()
    func speak(_ text: String) { stop(); let clean = cleanForSpeech(text); guard !clean.isEmpty else { return }; let u = AVSpeechUtterance(string: String(clean.prefix(1200))); let id = UserDefaults.standard.string(forKey: "voiceID") ?? ""; u.voice = VoiceCatalog.voice(for: id) ?? AVSpeechSynthesisVoice(language: "ru-RU"); let r = UserDefaults.standard.double(forKey: "voiceRate"); u.rate = Float(r == 0 ? 0.48 : r); let p = UserDefaults.standard.double(forKey: "voicePitch"); u.pitchMultiplier = Float(p == 0 ? 1.0 : p); synth.speak(u) }
    var isSpeaking: Bool { synth.isSpeaking }
    func stop() { if synth.isSpeaking { synth.stopSpeaking(at: .immediate) } }
}
