import Foundation
import AVFoundation
import AVKit
import Combine

final class PiPDelegate: NSObject, AVPlayerViewControllerDelegate {
    var onStart: (() -> Void)?
    var onRestore: (() -> Void)?
    func playerViewControllerWillStartPictureInPicture(_ playerViewController: AVPlayerViewController) {
        DispatchQueue.main.async { self.onStart?() }
    }
    func playerViewController(_ playerViewController: AVPlayerViewController,
                              restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        DispatchQueue.main.async {
            self.onRestore?()
            completionHandler(true)
        }
    }
}

/// Lecture vidéo via AVPlayer (décodage système, flux depuis le disque).
@MainActor
final class VideoEngine: ObservableObject {
    @Published private(set) var player: AVPlayer?
    @Published private(set) var currentItem: MediaItem?
    @Published private(set) var isPlaying = false
    @Published private(set) var rate: Float = 1.0

    var onFinished: (() -> Void)?
    var onSavePosition: ((MediaItem, TimeInterval) -> Void)?
    let pipDelegate = PiPDelegate()

    private var endObserver: AnyCancellable?
    private var statusObserver: NSKeyValueObservation?

    /// Contrôleur conservé pour que le PiP survive à la fermeture de l'écran vidéo.
    lazy var controller: AVPlayerViewController = {
        let c = AVPlayerViewController()
        c.allowsPictureInPicturePlayback = true
        c.canStartPictureInPictureAutomaticallyFromInline = true
        c.updatesNowPlayingInfoCenter = false
        c.delegate = pipDelegate
        return c
    }()

    var seconds: TimeInterval {
        let s = player?.currentTime().seconds ?? 0
        return s.isFinite ? s : 0
    }
    var duration: TimeInterval {
        let d = player?.currentItem?.duration.seconds ?? 0
        return d.isFinite ? d : 0
    }

    func open(item: MediaItem, url: URL, startAt: TimeInterval) {
        close()
        let p = AVPlayer(url: url)
        p.defaultRate = rate
        player = p
        currentItem = item
        controller.player = p
        if startAt > 1 { p.seek(to: CMTime(seconds: startAt, preferredTimescale: 600)) }
        endObserver = NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: p.currentItem)
            .sink { [weak self] _ in
                guard let self = self, let it = self.currentItem else { return }
                self.onSavePosition?(it, 0)
                self.onFinished?()
            }
        statusObserver = p.observe(\.timeControlStatus, options: [.new]) { [weak self] pl, _ in
            let playing = pl.timeControlStatus == .playing
            Task { @MainActor in self?.isPlaying = playing }
        }
        p.play()
    }

    func play() { player?.play() }
    func pause() { player?.pause(); savePosition() }
    func seek(to t: TimeInterval) { player?.seek(to: CMTime(seconds: t, preferredTimescale: 600)) }
    func setRate(_ r: Float) {
        rate = r
        player?.defaultRate = r
        if isPlaying { player?.rate = r }
    }

    func savePosition() {
        guard let it = currentItem else { return }
        let d = duration
        if d > 0 && seconds / d > 0.95 { onSavePosition?(it, 0) } else { onSavePosition?(it, seconds) }
    }

    func close() {
        guard player != nil else { return }
        savePosition()
        player?.pause()
        controller.player = nil
        player?.replaceCurrentItem(with: nil)
        player = nil
        currentItem = nil
        endObserver = nil
        statusObserver = nil
        isPlaying = false
    }
}
