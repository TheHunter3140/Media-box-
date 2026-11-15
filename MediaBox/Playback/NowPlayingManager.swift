import Foundation
import MediaPlayer
import UIKit

struct NowPlayingHandlers {
    var play: () -> Void
    var pause: () -> Void
    var toggle: () -> Void
    var next: () -> Void
    var previous: () -> Void
    var seek: (TimeInterval) -> Void
}

/// Écran verrouillé, Centre de contrôle, AirPods/Bluetooth. Mise à jour sur événements uniquement.
@MainActor
final class NowPlayingManager {
    private var configured = false

    func configure(_ h: NowPlayingHandlers) {
        guard !configured else { return }
        configured = true
        let c = MPRemoteCommandCenter.shared()
        c.playCommand.addTarget { _ in Task { @MainActor in h.play() }; return .success }
        c.pauseCommand.addTarget { _ in Task { @MainActor in h.pause() }; return .success }
        c.togglePlayPauseCommand.addTarget { _ in Task { @MainActor in h.toggle() }; return .success }
        c.nextTrackCommand.addTarget { _ in Task { @MainActor in h.next() }; return .success }
        c.previousTrackCommand.addTarget { _ in Task { @MainActor in h.previous() }; return .success }
        c.changePlaybackPositionCommand.addTarget { event in
            guard let e = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            let t = e.positionTime
            Task { @MainActor in h.seek(t) }
            return .success
        }
        c.skipForwardCommand.preferredIntervals = [15]
        c.skipBackwardCommand.preferredIntervals = [15]
        c.skipForwardCommand.addTarget { _ in Task { @MainActor in h.seek(-1) }; return .success }
        c.skipBackwardCommand.isEnabled = false
    }

    func update(title: String, artist: String, album: String, duration: TimeInterval,
                position: TimeInterval, rate: Float, playing: Bool, artwork: UIImage?) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: artist,
            MPMediaItemPropertyAlbumTitle: album,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: position,
            MPNowPlayingInfoPropertyPlaybackRate: playing ? Double(rate) : 0.0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0
        ]
        if let art = artwork {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: art.size) { _ in art }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    func clear() { MPNowPlayingInfoCenter.default().nowPlayingInfo = nil }
}
