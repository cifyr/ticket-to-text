import UIKit
import AudioToolbox

// Lightweight juice: haptics + built-in system sounds (no audio assets needed).
enum Feedback {
    static func claim() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        AudioServicesPlaySystemSound(1104) // tock
    }
    static func draw() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        AudioServicesPlaySystemSound(1104)
    }
    static func win() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        AudioServicesPlaySystemSound(1025) // fanfare-ish
    }
}
