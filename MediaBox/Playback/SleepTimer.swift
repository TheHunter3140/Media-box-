import Foundation

enum SleepMode: Equatable {
    case off
    case duration(TimeInterval)
    case atTime(Date)
    case afterTrack
    case afterQueue
}

@MainActor
final class SleepTimer: ObservableObject {
    @Published private(set) var mode: SleepMode = .off
    @Published private(set) var fireDate: Date?
    @Published var fadeSeconds: Double = 15

    var onFire: (() -> Void)?
    var onVolume: ((Float) -> Void)?
    private var task: Task<Void, Never>?

    nonisolated static func fireDate(for mode: SleepMode, now: Date) -> Date? {
        switch mode {
        case .duration(let s): return now.addingTimeInterval(s)
        case .atTime(let d):
            var t = d
            while t <= now { t = t.addingTimeInterval(86400) }
            return t
        default: return nil
        }
    }

    var isActive: Bool { mode != .off }

    func start(_ newMode: SleepMode) {
        cancel()
        mode = newMode
        guard let fire = SleepTimer.fireDate(for: newMode, now: Date()) else { return }
        fireDate = fire
        task = Task { [weak self] in
            guard let self = self else { return }
            let fade = min(self.fadeSeconds, max(0, fire.timeIntervalSinceNow))
            let wait = fire.timeIntervalSinceNow - fade
            if wait > 0 { try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000)) }
            guard !Task.isCancelled else { return }
            if fade > 0.5 {
                let steps = max(1, Int(fade / 0.5))
                for i in 1...steps {
                    guard !Task.isCancelled else { return }
                    self.onVolume?(1 - Float(i) / Float(steps))
                    try? await Task.sleep(nanoseconds: 500_000_000)
                }
            }
            guard !Task.isCancelled else { return }
            self.finish()
        }
    }

    /// Appelé par le contrôleur à la fin d'un morceau. Retourne vrai si la lecture doit s'arrêter.
    func trackEnded(queueWillEnd: Bool) -> Bool {
        switch mode {
        case .afterTrack: return true
        case .afterQueue: return queueWillEnd
        default: return false
        }
    }

    func finish() {
        task?.cancel(); task = nil
        mode = .off; fireDate = nil
        onFire?()
        onVolume?(1)
    }

    func cancel() {
        task?.cancel(); task = nil
        mode = .off; fireDate = nil
        onVolume?(1)
    }
}
