import Foundation

/// Logique d'ordonnancement pure (testable) : combien de tâches démarrer et lesquelles.
struct DownloadQueue {
    static func effectiveLimit(userMax: Int, ecoMax: Int) -> Int { max(0, min(max(1, userMax), ecoMax)) }

    static func idsToStart(states: [(id: UUID, state: DownloadState)], limit: Int) -> [UUID] {
        let running = states.filter { $0.state == .running }.count
        let free = max(0, limit - running)
        return Array(states.filter { $0.state == .queued }.prefix(free).map { $0.id })
    }

    static func idsToSuspend(states: [(id: UUID, state: DownloadState)], limit: Int) -> [UUID] {
        let running = states.filter { $0.state == .running }
        guard running.count > limit else { return [] }
        return Array(running.suffix(running.count - limit).map { $0.id })
    }
}
