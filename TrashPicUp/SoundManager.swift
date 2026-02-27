import Foundation
import AVFoundation

/// Plays delete (swipe), keep (swipe), and celebration sounds. Uses bundled WAV files.
/// Silences effects when user has other audio (music, video, phone call) playing.
enum SoundManager {
    static func playDelete() { play("ElevenLabs_Whoosh") }
    static func playKeep() { play("ElevenLabs_Whoosh") }
    static func playCelebration() { play("ElevenLabs_Celebration") }

    /// Duration of the celebration sound in seconds. Used to sync confetti.
    static var celebrationDuration: TimeInterval {
        guard let url = Bundle.main.url(forResource: "ElevenLabs_Celebration", withExtension: "wav"),
              let player = try? AVAudioPlayer(contentsOf: url) else { return 2.5 }
        return player.duration
    }

    private static var players: [String: AVAudioPlayer] = [:]

    private static func shouldPlaySounds() -> Bool {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        return !session.secondaryAudioShouldBeSilencedHint
        #else
        return true
        #endif
    }

    private static func play(_ name: String) {
        guard shouldPlaySounds() else { return }
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else { return }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            player.play()
            players[name] = player
            DispatchQueue.main.asyncAfter(deadline: .now() + player.duration + 0.1) {
                players[name] = nil
            }
        } catch {
            // Ignore; sounds are optional
        }
    }
}
