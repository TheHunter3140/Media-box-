import Foundation
import AVFoundation
import Combine

@MainActor
final class PlaybackSession {
    static let shared = PlaybackSession()
    enum Mode { case audio, video }

    var onInterruptionBegan: (() -> Void)?
    var onInterruptionEnded: ((Bool) -> Void)?
    var onRouteLost: (() -> Void)?
    private var bag = Set<AnyCancellable>()
    private var observing = false

    func activate(_ mode: Mode) {
        let s = AVAudioSession.sharedInstance()
        do {
            try s.setCategory(.playback, mode: mode == .video ? .moviePlayback : .default, options: [])
            try s.setActive(true)
        } catch {
            PerformanceLogger.shared.warn("AVAudioSession: \(error.localizedDescription)")
        }
        observeIfNeeded()
    }

    func deactivate() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func observeIfNeeded() {
        guard !observing else { return }
        observing = true
        NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)
            .sink { [weak self] n in
                guard let raw = n.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                      let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
                if type == .began { self?.onInterruptionBegan?() }
                else {
                    let optRaw = n.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
                    self?.onInterruptionEnded?(AVAudioSession.InterruptionOptions(rawValue: optRaw).contains(.shouldResume))
                }
            }.store(in: &bag)
        NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)
            .sink { [weak self] n in
                guard let raw = n.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                      let reason = AVAudioSession.RouteChangeReason(rawValue: raw) else { return }
                if reason == .oldDeviceUnavailable { self?.onRouteLost?() }
            }.store(in: &bag)
    }
}
