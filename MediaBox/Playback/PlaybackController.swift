import Foundation
import Combine
import UIKit

/// Horloge de position : seul le lecteur plein écran l'observe, et elle ne tourne que si l'UI est visible.
@MainActor
final class PlaybackClock: ObservableObject {
    @Published private(set) var position: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    var provider: (() -> (TimeInterval, TimeInterval))?
    private var task: Task<Void, Never>?
    private var wanted = false
    private var appActive = true

    func tick() { if let p = provider?() { position = p.0; duration = p.1 } }
    func setWanted(_ v: Bool) { wanted = v; reevaluate() }
    func setAppActive(_ v: Bool) { appActive = v; reevaluate() }

    private func reevaluate() {
        if wanted && appActive {
            guard task == nil else { return }
            task = Task { [weak self] in
                while !Task.isCancelled {
                    self?.tick()
                    let interval = EcoCore.shared.policy.clockInterval
                    try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                }
            }
        } else {
            task?.cancel(); task = nil
            tick()
        }
    }
}

private struct ResumeState: Codable {
    var ids: [String]
    var index: Int
    var position: Double
    var shuffle: Bool
    var repeatMode: RepeatMode
}

@MainActor
final class PlaybackController: ObservableObject {
    enum Active { case none, audio, video }

    @Published private(set) var active: Active = .none
    @Published private(set) var current: MediaItem?
    @Published private(set) var isPlaying = false
    @Published private(set) var queue = PlaybackQueue()
    @Published var errorMessage: String?
    @Published var videoPresented = false
    @Published var playerPresented = false

    let audio = AudioEngine()
    let video = VideoEngine()
    let clock: PlaybackClock
    let sleepTimer: SleepTimer
    var onSecondaryCleanup: (() -> Void)?

    private let library: MediaLibrary
    private let settings: AppSettings
    private let eco = EcoCore.shared
    private let session = PlaybackSession.shared
    private let nowPlaying = NowPlayingManager()
    private var bag = Set<AnyCancellable>()
    private var audioPlaying = false
    private var videoPlaying = false
    private var wasPlayingBeforeInterruption = false
    private var playStartedAt: Date?
    private var failureStreak = 0
    private var artwork: UIImage?
    private var savedPosition: TimeInterval = 0

    init(library: MediaLibrary, clock: PlaybackClock, sleepTimer: SleepTimer, settings: AppSettings) {
        self.library = library
        self.clock = clock
        self.sleepTimer = sleepTimer
        self.settings = settings
        wire()
    }

    private func wire() {
        audio.onTrackFinished = { [weak self] in self?.audioTrackFinished() }
        audio.$state.sink { [weak self] s in self?.audioPlaying = (s == .playing); self?.refreshPlaying() }.store(in: &bag)
        video.$isPlaying.sink { [weak self] v in self?.videoPlaying = v; self?.refreshPlaying() }.store(in: &bag)
        video.onSavePosition = { [weak self] item, s in self?.library.setPosition(s, for: item) }
        video.onFinished = { [weak self] in self?.videoFinished() }
        video.pipDelegate.onStart = { [weak self] in self?.videoPresented = false }
        video.pipDelegate.onRestore = { [weak self] in self?.videoPresented = true }
        session.onInterruptionBegan = { [weak self] in
            guard let self = self else { return }
            self.wasPlayingBeforeInterruption = self.enginePlaying
            self.pause()
        }
        session.onInterruptionEnded = { [weak self] shouldResume in
            guard let self = self else { return }
            if shouldResume && self.settings.autoResume && self.wasPlayingBeforeInterruption { self.resume() }
            self.wasPlayingBeforeInterruption = false
        }
        session.onRouteLost = { [weak self] in self?.pause() }
        sleepTimer.onFire = { [weak self] in self?.sleepFired() }
        sleepTimer.onVolume = { [weak self] v in self?.audio.masterVolume = v }
        clock.provider = { [weak self] in (self?.position ?? 0, self?.duration ?? 0) }
        nowPlaying.configure(NowPlayingHandlers(
            play: { [weak self] in self?.resume() },
            pause: { [weak self] in self?.pause() },
            toggle: { [weak self] in self?.toggle() },
            next: { [weak self] in self?.next() },
            previous: { [weak self] in self?.previous() },
            seek: { [weak self] t in
                guard let self = self else { return }
                self.seek(to: t < 0 ? self.position + 15 : t)
            }))
    }

    private func refreshPlaying() {
        let v: Bool
        switch active { case .audio: v = audioPlaying; case .video: v = videoPlaying; case .none: v = false }
        if v != isPlaying { isPlaying = v }
    }

    private var enginePlaying: Bool { audioPlaying || videoPlaying }

    var position: TimeInterval { active == .video ? video.seconds : audio.position }
    var duration: TimeInterval { active == .video ? video.duration : audio.duration }
    var rate: Float { active == .video ? video.rate : audio.rate }

    // MARK: Lancer
    func play(_ items: [MediaItem], startAt index: Int = 0, shuffle: Bool = false) {
        guard !items.isEmpty else { return }
        var q = PlaybackQueue()
        q.set(items: items, startIndex: index, shuffle: shuffle)
        queue = q
        failureStreak = 0
        if let c = queue.current { start(c, resumeAt: nil) }
    }

    func playNext(_ item: MediaItem) {
        var q = queue
        q.playNext(item)
        queue = q
        if current == nil { play([item]) }
    }

    func jump(to item: MediaItem) {
        var q = queue
        if let it = q.jump(toID: item.id) { queue = q; start(it, resumeAt: nil) }
    }

    private func start(_ item: MediaItem, resumeAt: TimeInterval?) {
        guard let url = library.url(for: item) else {
            fail("Fichier introuvable : \(item.title)", item); return
        }
        if item.kind == .audio { startAudio(item, url, resumeAt: resumeAt) } else { startVideo(item, url) }
    }

    private func startAudio(_ item: MediaItem, _ url: URL, resumeAt: TimeInterval?) {
        accumulateStats()
        video.close()
        session.activate(.audio)
        audio.fadeSeconds = settings.fadeSeconds
        let from = resumeAt ?? (item.duration > 600 ? library.position(for: item) : 0)
        do {
            try audio.load(url: url, startAt: from, autoplay: true)
            failureStreak = 0
            current = item; active = .audio
            library.recordPlay(item)
            playStartedAt = Date()
            eco.setPlaying(true)
            artwork = nil
            updateNowPlaying()
            loadArtwork(for: item, url: url)
            saveSession()
            MemoryManager.shared.checkBudget(reason: "chargement audio")
        } catch {
            fail("Lecture impossible (format non pris en charge ?) : \(item.title)", item)
        }
    }

    private func startVideo(_ item: MediaItem, _ url: URL) {
        accumulateStats()
        audio.stop()
        session.activate(.video)
        video.open(item: item, url: url, startAt: library.position(for: item))
        current = item; active = .video
        library.recordPlay(item)
        eco.setPlaying(true)
        videoPresented = true
        artwork = nil
        updateNowPlaying()
        MemoryManager.shared.checkBudget(reason: "chargement vidéo")
    }

    private func fail(_ message: String, _ item: MediaItem) {
        failureStreak += 1
        errorMessage = message
        if failureStreak < queue.count, let n = queue.advance(auto: true) { start(n, resumeAt: nil) } else { stopPlayback() }
    }

    private func loadArtwork(for item: MediaItem, url: URL) {
        Task { [weak self] in
            let img = await ArtworkLoader.load(item: item, url: url, maxPixel: 600)
            guard let self = self, self.current?.id == item.id else { return }
            self.artwork = img
            self.updateNowPlaying()
        }
    }

    // MARK: Transport
    func toggle() { if isPlaying { pause() } else { resume() } }

    func pause() {
        switch active {
        case .audio: audio.pause(); accumulateStats(); savedPosition = audio.position
        case .video: video.pause()
        case .none: break
        }
        eco.setPlaying(false)
        updateNowPlaying()
        saveSession()
    }

    func resume() {
        switch active {
        case .audio:
            session.activate(.audio)
            if audio.hasFile { audio.play(); playStartedAt = Date() }
            else if let c = current, let u = library.url(for: c) { startAudio(c, u, resumeAt: savedPosition) }
        case .video:
            session.activate(.video); video.play()
        case .none: break
        }
        eco.setPlaying(true)
        updateNowPlaying()
    }

    func next() {
        var q = queue
        if let n = q.advance(auto: false) { queue = q; start(n, resumeAt: nil) }
    }

    func previous() {
        if position > 3 { seek(to: 0); return }
        var q = queue
        if let p = q.back() { queue = q; start(p, resumeAt: nil) } else { seek(to: 0) }
    }

    func seek(to t: TimeInterval) {
        if active == .video { video.seek(to: t) } else { audio.seek(to: t) }
        clock.tick()
        updateNowPlaying()
    }

    func setRate(_ r: Float) {
        if active == .video { video.setRate(r) } else { audio.rate = r }
        updateNowPlaying()
    }

    func setShuffle(_ on: Bool) { var q = queue; q.setShuffle(on); queue = q }
    func cycleRepeat() { var q = queue; q.repeatMode = q.repeatMode.next; queue = q }

    // MARK: Fins de lecture
    private func audioTrackFinished() {
        accumulateStats()
        if sleepTimer.isActive && sleepTimer.trackEnded(queueWillEnd: queue.wouldEndAfterCurrent) {
            sleepTimer.finish(); return
        }
        var q = queue
        if let n = q.advance(auto: true) { queue = q; start(n, resumeAt: 0) } else { stopPlayback() }
    }

    private func videoFinished() {
        eco.setPlaying(false)
        updateNowPlaying()
    }

    func stopPlayback() {
        accumulateStats()
        audio.stop(); video.close()
        active = .none; current = nil; isPlaying = false
        videoPresented = false
        nowPlaying.clear()
        session.deactivate()
        eco.setPlaying(false)
    }

    /// Minuteur de sommeil : pause, sauvegarde de la position, libération du moteur et des tâches secondaires.
    private func sleepFired() {
        pause()
        saveSession()
        if active == .audio { savedPosition = audio.position; audio.stop() }
        session.deactivate()
        onSecondaryCleanup?()
    }

    private func accumulateStats() {
        if let s = playStartedAt { library.addListening(seconds: Date().timeIntervalSince(s)); playStartedAt = nil }
    }

    // MARK: Now Playing
    private func updateNowPlaying() {
        guard let c = current else { nowPlaying.clear(); return }
        nowPlaying.update(title: c.title, artist: c.artist ?? "", album: c.album ?? "",
                          duration: duration, position: position, rate: rate, playing: enginePlaying, artwork: artwork)
    }

    // MARK: Reprise de session
    func saveSession() {
        guard active == .audio, current != nil else { return }
        let st = ResumeState(ids: queue.items.map { $0.id }, index: queue.items.firstIndex { $0.id == current?.id } ?? 0,
                             position: audio.hasFile ? audio.position : savedPosition,
                             shuffle: queue.shuffled, repeatMode: queue.repeatMode)
        if let d = try? JSONEncoder().encode(st) { UserDefaults.standard.set(d, forKey: "playback.session") }
    }

    func restoreSession() {
        guard settings.restoreSession, current == nil,
              let d = UserDefaults.standard.data(forKey: "playback.session"),
              let st = try? JSONDecoder().decode(ResumeState.self, from: d) else { return }
        let items = st.ids.compactMap { library.item(id: $0) }
        guard !items.isEmpty else { return }
        let idx = items.firstIndex { $0.id == st.ids[min(st.index, st.ids.count - 1)] } ?? 0
        var q = PlaybackQueue()
        q.set(items: items, startIndex: idx, shuffle: false)
        q.repeatMode = st.repeatMode
        queue = q
        guard let item = q.current, let url = library.url(for: item) else { return }
        do {
            audio.fadeSeconds = settings.fadeSeconds
            try audio.load(url: url, startAt: st.position, autoplay: false)
            current = item; active = .audio
            savedPosition = st.position
            loadArtwork(for: item, url: url)
        } catch { }
    }

    func appDidEnterBackground() {
        saveSession()
        video.savePosition()
        library.saveNow()
    }
}
