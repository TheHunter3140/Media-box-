import Foundation

enum DownloadState: String, Codable {
    case queued, running, paused, completed, failed, cancelled
    var label: String {
        switch self {
        case .queued: return "En attente"
        case .running: return "En cours"
        case .paused: return "En pause"
        case .completed: return "Terminé"
        case .failed: return "Échec"
        case .cancelled: return "Annulé"
        }
    }
}

enum DownloadDestination: String, Codable, CaseIterable, Identifiable {
    case auto, music, videos, other
    var id: String { rawValue }
    var label: String {
        switch self {
        case .auto: return "Automatique"
        case .music: return "Musique"
        case .videos: return "Vidéos"
        case .other: return "Téléchargements"
        }
    }
}

/// Information embarquée dans `taskDescription` : survit à un relancement de l'app.
struct DownloadTaskInfo: Codable {
    var id: String
    var dest: String
    var name: String
    func encoded() -> String { (try? String(data: JSONEncoder().encode(self), encoding: .utf8)) ?? "" }
    static func decode(_ s: String?) -> DownloadTaskInfo? {
        guard let s = s, let d = s.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(DownloadTaskInfo.self, from: d)
    }
}

struct PersistedDownload: Codable {
    var id: UUID
    var url: URL
    var filename: String
    var destination: DownloadDestination
    var state: DownloadState
    var received: Int64
    var total: Int64
    var created: Date
}

/// Une instance par téléchargement : seule sa ligne d'interface se redessine lors de la progression.
@MainActor
final class DownloadTask: ObservableObject, Identifiable {
    let id: UUID
    let url: URL
    var filename: String
    var destination: DownloadDestination
    let created: Date
    @Published var state: DownloadState
    @Published var received: Int64
    @Published var total: Int64
    @Published var speed: Double = 0
    @Published var errorMessage: String?
    var resumeData: Data?
    var ecoPaused = false
    var urlTask: URLSessionDownloadTask?
    private var lastBytes: Int64 = 0
    private var lastDate = Date()

    init(id: UUID = UUID(), url: URL, filename: String, destination: DownloadDestination,
         state: DownloadState = .queued, received: Int64 = 0, total: Int64 = 0, created: Date = Date()) {
        self.id = id; self.url = url; self.filename = filename; self.destination = destination
        self.state = state; self.received = received; self.total = total; self.created = created
        self.lastBytes = received
    }

    var progress: Double { total > 0 ? min(1, Double(received) / Double(total)) : 0 }
    var eta: TimeInterval? { speed > 1 && total > received ? Double(total - received) / speed : nil }
    var isActive: Bool { state == .queued || state == .running || state == .paused }

    func updateProgress(received r: Int64, total t: Int64) {
        let now = Date()
        let dt = now.timeIntervalSince(lastDate)
        if dt > 0.2 {
            let inst = Double(r - lastBytes) / dt
            speed = speed == 0 ? inst : speed * 0.7 + inst * 0.3
            lastBytes = r; lastDate = now
        }
        received = r
        if t > 0 { total = t }
    }

    var persisted: PersistedDownload {
        PersistedDownload(id: id, url: url, filename: filename, destination: destination, state: state,
                          received: received, total: total, created: created)
    }
}
