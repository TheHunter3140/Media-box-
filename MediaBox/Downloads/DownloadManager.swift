import Foundation
import Combine

enum EnqueueResult {
    case added(DownloadTask)
    case duplicate(String)
    case alreadyActive
}

/// Délégué de session : tourne hors du thread principal, déplace le fichier immédiatement puis notifie le manager.
final class DownloadSessionDelegate: NSObject, URLSessionDownloadDelegate {
    weak var manager: DownloadManager?
    private let lock = NSLock()
    private var lastPublish: [String: Date] = [:]

    private func shouldPublish(_ id: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        let now = Date()
        if let last = lastPublish[id], now.timeIntervalSince(last) < 0.5 { return false }
        lastPublish[id] = now
        return true
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let info = DownloadTaskInfo.decode(downloadTask.taskDescription), shouldPublish(info.id) else { return }
        Task { @MainActor [weak manager] in
            manager?.progress(id: info.id, received: totalBytesWritten, total: totalBytesExpectedToWrite)
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let info = DownloadTaskInfo.decode(downloadTask.taskDescription) else { return }
        let http = downloadTask.response as? HTTPURLResponse
        if let h = http, !(200..<300).contains(h.statusCode) {
            let msg = "Le serveur a répondu \(h.statusCode)."
            Task { @MainActor [weak manager] in manager?.failed(id: info.id, message: msg, resumeData: nil) }
            return
        }
        var name = FileManagerService.sanitize(info.name)
        let contentType = (http?.value(forHTTPHeaderField: "Content-Type") ?? "").lowercased()
        let expectsMedia = MediaFormats.kind(forExtension: (name as NSString).pathExtension) != nil
        if expectsMedia && contentType.contains("text/html") {
            Task { @MainActor [weak manager] in
                manager?.failed(id: info.id, message: "Le serveur a renvoyé une page web, pas un fichier média.", resumeData: nil)
            }
            return
        }
        if (name as NSString).pathExtension.isEmpty, let sug = downloadTask.response?.suggestedFilename,
           !(sug as NSString).pathExtension.isEmpty {
            name += "." + (sug as NSString).pathExtension
        }
        let dir = FileManagerService.destinationDirectory(for: info.dest)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dest = FileManagerService.uniqueURL(in: dir, name: name)
        do {
            try FileManager.default.moveItem(at: location, to: dest)
            let size = Int64((try? dest.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
            Task { @MainActor [weak manager] in manager?.finished(id: info.id, fileURL: dest, bytes: size) }
        } catch {
            let msg = "Impossible d'enregistrer le fichier : \(error.localizedDescription)"
            Task { @MainActor [weak manager] in manager?.failed(id: info.id, message: msg, resumeData: nil) }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error = error, let info = DownloadTaskInfo.decode(task.taskDescription) else { return }
        let ns = error as NSError
        let data = ns.userInfo[NSURLSessionDownloadTaskResumeData] as? Data
        let msg = ns.localizedDescription
        Task { @MainActor [weak manager] in manager?.failed(id: info.id, message: msg, resumeData: data) }
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        DispatchQueue.main.async {
            AppDelegate.backgroundCompletionHandler?()
            AppDelegate.backgroundCompletionHandler = nil
        }
    }
}

@MainActor
final class DownloadManager: ObservableObject {
    @Published private(set) var tasks: [DownloadTask] = []
    let history: DownloadHistory
    var onCompleted: ((URL) -> Void)?

    private let settings: AppSettings
    private let eco = EcoCore.shared
    private let delegate = DownloadSessionDelegate()
    private var session: URLSession!
    private var bag = Set<AnyCancellable>()
    private var saveTask: Task<Void, Never>?
    private let stateURL = FileManagerService.supportDir.appendingPathComponent("downloads.json")
    private let resumeDir = FileManagerService.supportDir.appendingPathComponent("resume", isDirectory: true)

    init(settings: AppSettings, history: DownloadHistory) {
        self.settings = settings
        self.history = history
        delegate.manager = self
        let cfg = URLSessionConfiguration.background(withIdentifier: "com.local.mediabox.downloads")
        cfg.sessionSendsLaunchEvents = true
        cfg.isDiscretionary = false
        cfg.waitsForConnectivity = true
        cfg.httpMaximumConnectionsPerHost = 3
        cfg.allowsCellularAccess = !settings.wifiOnlyDownloads
        session = URLSession(configuration: cfg, delegate: delegate, delegateQueue: nil)
        try? FileManager.default.createDirectory(at: resumeDir, withIntermediateDirectories: true)
        loadPersisted()
        eco.profileChanged.sink { [weak self] _ in self?.applyEco() }.store(in: &bag)
        Task { await reconcile() }
    }

    // MARK: Ajout
    func enqueue(url: URL, name: String?, destination: DownloadDestination, force: Bool = false) -> EnqueueResult {
        let filename = FileManagerService.sanitize(name ?? SourceResolver.suggestedFileName(for: url))
        if tasks.contains(where: { $0.url == url && $0.isActive }) { return .alreadyActive }
        if !force, let e = history.contains(url: url.absoluteString) {
            return .duplicate("« \(e.filename) » a déjà été téléchargé depuis ce lien.")
        }
        var dest = destination
        if dest == .auto { dest = SourceResolver.destination(for: SourceResolver.classify(url)) }
        let t = DownloadTask(url: url, filename: filename, destination: dest)
        tasks.insert(t, at: 0)
        persistSoon()
        pump()
        return .added(t)
    }

    // MARK: Contrôle
    func pause(_ t: DownloadTask) {
        guard t.state == .running || t.state == .queued else { return }
        let wasRunning = t.state == .running
        t.state = .paused
        t.speed = 0
        if wasRunning, let u = t.urlTask {
            u.cancel(byProducingResumeData: { [weak self] data in
                Task { @MainActor in self?.storeResume(data, for: t) }
            })
        }
        t.urlTask = nil
        persistSoon(); updateActivity(); pump()
    }

    func resume(_ t: DownloadTask) {
        guard t.state == .paused || t.state == .failed else { return }
        t.state = .queued; t.errorMessage = nil; t.ecoPaused = false
        persistSoon(); pump()
    }

    func retry(_ t: DownloadTask) {
        t.resumeData = nil
        t.received = 0
        resume(t)
    }

    func cancel(_ t: DownloadTask) {
        t.urlTask?.cancel(); t.urlTask = nil
        t.state = .cancelled
        removeResume(t)
        tasks.removeAll { $0.id == t.id }
        persistSoon(); updateActivity(); pump()
    }

    func removeFinished() {
        tasks.removeAll { !$0.isActive }
        persistSoon()
    }

    // MARK: Ordonnancement
    private var limit: Int { DownloadQueue.effectiveLimit(userMax: settings.maxDownloads, ecoMax: eco.policy.maxDownloads) }

    private func pump() {
        let states = tasks.reversed().map { (id: $0.id, state: $0.state) }
        for id in DownloadQueue.idsToStart(states: states, limit: limit) {
            if let t = tasks.first(where: { $0.id == id }) { start(t) }
        }
        updateActivity()
    }

    private func start(_ t: DownloadTask) {
        let urlTask: URLSessionDownloadTask
        if t.resumeData == nil, let data = try? Data(contentsOf: resumeFile(t)) { t.resumeData = data }
        if let data = t.resumeData {
            urlTask = session.downloadTask(withResumeData: data)
        } else {
            var req = URLRequest(url: t.url)
            req.timeoutInterval = 60
            urlTask = session.downloadTask(with: req)
        }
        t.resumeData = nil
        removeResume(t)
        urlTask.taskDescription = DownloadTaskInfo(id: t.id.uuidString, dest: t.destination.rawValue, name: t.filename).encoded()
        t.urlTask = urlTask
        t.state = .running
        urlTask.resume()
        persistSoon()
    }

    /// Thermique critique ou limite réduite : suspend les téléchargements en excès, reprend automatiquement ensuite.
    private func applyEco() {
        let states = tasks.reversed().map { (id: $0.id, state: $0.state) }
        for id in DownloadQueue.idsToSuspend(states: states, limit: limit) {
            if let t = tasks.first(where: { $0.id == id }) { pause(t); t.ecoPaused = true }
        }
        if limit > 0 {
            for t in tasks where t.ecoPaused && t.state == .paused { t.ecoPaused = false; t.state = .queued }
        }
        pump()
    }

    private func updateActivity() {
        eco.setDownloadsActive(tasks.contains { $0.state == .running })
    }

    // MARK: Callbacks du délégué
    func progress(id: String, received: Int64, total: Int64) {
        guard let t = task(id) else { return }
        if t.state == .running { t.updateProgress(received: received, total: total) }
    }

    func finished(id: String, fileURL: URL, bytes: Int64) {
        guard let t = task(id) else { return }
        t.state = .completed; t.received = bytes; t.total = bytes; t.speed = 0; t.urlTask = nil
        let rel = fileURL.path.replacingOccurrences(of: FileManagerService.mediaRoot.path + "/", with: "")
        history.add(DownloadHistoryEntry(url: t.url.absoluteString, filename: fileURL.lastPathComponent,
                                         destination: t.destination.rawValue, bytes: bytes, date: Date(), success: true, path: rel))
        tasks.removeAll { $0.id == t.id }
        persistSoon(); updateActivity(); pump()
        onCompleted?(fileURL)
    }

    func failed(id: String, message: String, resumeData: Data?) {
        guard let t = task(id), t.state == .running || t.state == .queued else { return }
        t.state = .failed; t.errorMessage = message; t.speed = 0; t.urlTask = nil
        if let d = resumeData { storeResume(d, for: t) }
        history.add(DownloadHistoryEntry(url: t.url.absoluteString, filename: t.filename, destination: t.destination.rawValue,
                                         bytes: t.received, date: Date(), success: false, path: nil))
        persistSoon(); updateActivity(); pump()
    }

    private func task(_ id: String) -> DownloadTask? { tasks.first { $0.id.uuidString == id } }

    // MARK: Données de reprise
    private func resumeFile(_ t: DownloadTask) -> URL { resumeDir.appendingPathComponent(t.id.uuidString + ".bin") }
    private func storeResume(_ data: Data?, for t: DownloadTask) {
        guard let d = data else { return }
        t.resumeData = d
        try? d.write(to: resumeFile(t), options: .atomic)
    }
    private func removeResume(_ t: DownloadTask) { try? FileManager.default.removeItem(at: resumeFile(t)) }

    // MARK: Persistance
    private func persistSoon() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled, let self = self else { return }
            let list = self.tasks.filter { $0.isActive }.map { $0.persisted }
            if let d = try? JSONEncoder().encode(list) { try? d.write(to: self.stateURL, options: .atomic) }
        }
    }

    private func loadPersisted() {
        guard let d = try? Data(contentsOf: stateURL), let list = try? JSONDecoder().decode([PersistedDownload].self, from: d) else { return }
        tasks = list.map {
            // Un téléchargement « en cours » avant fermeture est rattaché à la session d'arrière-plan par reconcile().
            DownloadTask(id: $0.id, url: $0.url, filename: $0.filename, destination: $0.destination,
                         state: $0.state == .running ? .queued : $0.state, received: $0.received, total: $0.total, created: $0.created)
        }
    }

    /// Rattache les tâches encore vivantes de la session d'arrière-plan ; annule les orphelines.
    private func reconcile() async {
        let alive = await session.allTasks
        for u in alive {
            guard let dt = u as? URLSessionDownloadTask, let info = DownloadTaskInfo.decode(dt.taskDescription) else { u.cancel(); continue }
            if let t = task(info.id) { t.urlTask = dt; t.state = .running } else { dt.cancel() }
        }
        pump()
    }
}
