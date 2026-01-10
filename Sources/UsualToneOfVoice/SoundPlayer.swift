import AppKit

enum SoundPlayer {
    static func playStart() {
        play(named: "Ping")
    }

    static func playStop() {
        play(named: "Purr")
    }

    private static func play(named: String) {
        if let sound = NSSound(named: NSSound.Name(named)) {
            sound.play()
        } else {
            NSSound.beep()
        }
    }
}
