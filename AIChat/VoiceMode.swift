import AVFoundation
import SwiftUI

class VoiceSpeaker: NSObject, ObservableObject {
    private let synth = AVSpeechSynthesizer()
    func speak(_ text: String) {
        let u = AVSpeechUtterance(string: text)
        u.voice = AVSpeechSynthesisVoice(language: "ru-RU")
        u.rate = 0.5
        synth.speak(u)
    }
    func speakEnglish(_ text: String) {
        let u = AVSpeechUtterance(string: text)
        u.voice = AVSpeechSynthesisVoice(language: "en-US")
        u.rate = 0.45
        synth.speak(u)
    }
    func stop() { synth.stopSpeaking(at: .immediate) }
}
