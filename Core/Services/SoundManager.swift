import AVFoundation

final class SoundManager {
    static let shared = SoundManager()

    private var connectionPlayer: AVAudioPlayer?
    private var targetReachedPlayer: AVAudioPlayer?

    private init() {
        connectionPlayer = loadSound(named: "connection_sound", ext: "wav")
        targetReachedPlayer = loadSound(named: "target_reached_sound", ext: "wav")
    }

    private func loadSound(named name: String, ext: String) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
            print("[SoundManager] Sound file not found: \(name).\(ext)")
            return nil
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            return player
        } catch {
            print("[SoundManager] Failed to load \(name).\(ext): \(error)")
            return nil
        }
    }

    func playConnectionSound() {
        connectionPlayer?.currentTime = 0
        connectionPlayer?.play()
    }

    func playTargetReachedSound() {
        if let player = targetReachedPlayer {
            player.currentTime = 0
            player.play()
        } else {
            playConnectionSound()
        }
    }
}
