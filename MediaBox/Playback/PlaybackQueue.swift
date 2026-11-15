import Foundation

enum RepeatMode: String, CaseIterable, Codable {
    case off, all, one
    var icon: String {
        switch self { case .off, .all: return "repeat"; case .one: return "repeat.1" }
    }
    var next: RepeatMode {
        switch self { case .off: return .all; case .all: return .one; case .one: return .off }
    }
}

/// File de lecture pure (sans dépendance UI) : testable.
struct PlaybackQueue {
    private(set) var items: [MediaItem] = []
    private(set) var order: [Int] = []
    private(set) var cursor = 0
    private(set) var shuffled = false
    var repeatMode: RepeatMode = .off

    var count: Int { items.count }
    var current: MediaItem? { order.indices.contains(cursor) ? items[order[cursor]] : nil }
    var upcoming: [MediaItem] { cursor + 1 < order.count ? order[(cursor + 1)...].map { items[$0] } : [] }
    var isAtLast: Bool { cursor >= order.count - 1 }
    /// Vrai si, après le morceau courant, la lecture s'arrêterait.
    var wouldEndAfterCurrent: Bool { isAtLast && repeatMode == .off }

    mutating func set(items new: [MediaItem], startIndex: Int, shuffle: Bool) {
        items = new
        shuffled = shuffle
        let start = min(max(0, startIndex), max(0, new.count - 1))
        rebuildOrder(keepingFirst: start)
    }

    mutating func setShuffle(_ on: Bool) {
        guard on != shuffled else { return }
        let currentIndex = order.indices.contains(cursor) ? order[cursor] : 0
        shuffled = on
        rebuildOrder(keepingFirst: currentIndex)
    }

    private mutating func rebuildOrder(keepingFirst first: Int) {
        guard !items.isEmpty else { order = []; cursor = 0; return }
        if shuffled {
            var rest = Array(items.indices).filter { $0 != first }
            rest.shuffle()
            order = [first] + rest
            cursor = 0
        } else {
            order = Array(items.indices)
            cursor = first
        }
    }

    /// Passe au suivant. `auto` = fin naturelle du morceau (la répétition d'un morceau s'applique).
    mutating func advance(auto: Bool) -> MediaItem? {
        guard !order.isEmpty else { return nil }
        if auto && repeatMode == .one { return current }
        if cursor + 1 < order.count { cursor += 1; return current }
        if repeatMode == .all {
            if shuffled { rebuildOrder(keepingFirst: order[cursor]); order.shuffle() }
            cursor = 0
            return current
        }
        return nil
    }

    mutating func back() -> MediaItem? {
        guard !order.isEmpty else { return nil }
        if cursor > 0 { cursor -= 1; return current }
        if repeatMode == .all { cursor = order.count - 1; return current }
        return nil
    }

    mutating func jump(toID id: String) -> MediaItem? {
        guard let pos = order.firstIndex(where: { items[$0].id == id }) else { return nil }
        cursor = pos
        return current
    }

    mutating func playNext(_ item: MediaItem) {
        items.append(item)
        order.insert(items.count - 1, at: min(cursor + 1, order.count))
        if order.count == 1 { cursor = 0 }
    }
}
