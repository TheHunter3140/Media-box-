import Foundation

struct BrowserHistoryEntry: Codable, Identifiable, Hashable {
    var id = UUID()
    var url: String
    var title: String
    var date: Date
}

@MainActor
final class BrowserHistory: ObservableObject {
    @Published private(set) var entries: [BrowserHistoryEntry] = []
    private let fileURL: URL
    private let cap = 300

    init(fileURL: URL = FileManagerService.supportDir.appendingPathComponent("browser-history.json")) {
        self.fileURL = fileURL
        if let d = try? Data(contentsOf: fileURL), let e = try? JSONDecoder().decode([BrowserHistoryEntry].self, from: d) { entries = e }
    }

    func add(url: String, title: String) {
        if let first = entries.first, first.url == url { return }
        entries.insert(BrowserHistoryEntry(url: url, title: title.isEmpty ? url : title, date: Date()), at: 0)
        if entries.count > cap { entries.removeLast(entries.count - cap) }
        save()
    }
    func clear() { entries = []; save() }
    private func save() {
        if let d = try? JSONEncoder().encode(entries) { try? d.write(to: fileURL, options: .atomic) }
    }
}
