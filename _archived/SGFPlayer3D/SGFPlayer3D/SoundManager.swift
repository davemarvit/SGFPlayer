import Foundation
import AVFoundation

/// Manages game sound effects
class SoundManager: ObservableObject {
    static let shared = SoundManager()

    private var audioPlayers: [String: AVAudioPlayer] = [:]
    @Published var isSoundEnabled = true
    @Published var volume: Float = UserDefaults.standard.object(forKey: "soundVolume") as? Float ?? 0.7  // 0.0 to 1.0

    private init() {
        setupAudioPlayers()

        // Observe volume changes to persist them
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            if let savedVolume = UserDefaults.standard.object(forKey: "soundVolume") as? Float {
                if savedVolume != self.volume {
                    self.volume = savedVolume
                }
            }
        }
    }

    func setVolume(_ newVolume: Float) {
        volume = newVolume
        UserDefaults.standard.set(newVolume, forKey: "soundVolume")
    }

    private func setupAudioPlayers() {
        // Preload all sound files
        loadSound(named: "Stone_click_1", extension: "mp3")
        loadSound(named: "Capture_single", extension: "mp3")
        loadSound(named: "Capture_multiple", extension: "mp3")
    }

    private func loadSound(named name: String, extension ext: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
            NSLog("SoundManager: ⚠️ Could not find sound file: \(name).\(ext)")
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            audioPlayers[name] = player
            NSLog("SoundManager: ✅ Loaded sound: \(name)")
        } catch {
            NSLog("SoundManager: ❌ Error loading sound \(name): \(error.localizedDescription)")
        }
    }

    func playStoneClick() {
        guard isSoundEnabled else { return }
        if let player = audioPlayers["Stone_click_1"] {
            player.volume = volume
            player.play()
        }
    }

    func playCaptureSound(capturedCount: Int) {
        guard isSoundEnabled else { return }

        if capturedCount == 1 {
            if let player = audioPlayers["Capture_single"] {
                player.volume = volume
                player.play()
            }
        } else if capturedCount > 1 {
            if let player = audioPlayers["Capture_multiple"] {
                player.volume = volume
                player.play()
            }
        }
    }
}
