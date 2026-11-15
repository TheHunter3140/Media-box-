import SwiftUI
import Combine

enum AppTab: Hashable { case home, library, browser, downloads, settings }

@MainActor
final class AppCoordinator: ObservableObject {
    static let shared = AppCoordinator()

    let settings = AppSettings()
    let library = MediaLibrary()
    let playlists = PlaylistManager()
    let clock = PlaybackClock()
    let sleepTimer = SleepTimer()
    let playback: PlaybackController
    let downloadHistory = DownloadHistory()
    let downloads: DownloadManager
    let browser: BrowserManager
    let storage: StorageAnalyzer
    let benchmark = BenchmarkRecorder()
    @Published var selectedTab: AppTab = .home
    private var started = false
    private var bag = Set<AnyCancellable>()

    init() {
        FileManagerService.bootstrap()
        playback = PlaybackController(library: library, clock: clock, sleepTimer: sleepTimer, settings: settings)
        downloads = DownloadManager(settings: settings, history: downloadHistory)
        browser = BrowserManager(history: BrowserHistory())
        storage = StorageAnalyzer(library: library, history: downloadHistory)
        wire()
    }

    private func wire() {
        let mm = MemoryManager.shared
        let cache = CacheManager.shared
        // Ordre de délestage du cahier des charges.
        mm.registerShedStep(.stopPrefetch, name: "préchargements") { }
        mm.registerShedStep(.releaseImages, name: "images") { cache.purgeMemory() }
        mm.registerShedStep(.reduceCaches, name: "caches") { cache.trimDisk(to: 5 * 1024 * 1024) }
        mm.registerShedStep(.suspendIndexing, name: "indexation") { [weak self] in self?.library.cancelIndexing() }
        mm.registerShedStep(.limitTasks, name: "tâches") { }
        mm.registerShedStep(.freeInactiveModules, name: "modules inactifs") { [weak self] in
            guard let self = self, self.selectedTab != .browser else { return }
            self.browser.discard()
        }
        playback.onSecondaryCleanup = { [weak self] in
            self?.library.cancelIndexing()
            cache.purgeMemory()
            self?.browser.discard()
        }
        downloads.onCompleted = { [weak self] _ in self?.library.scanAll() }
        $selectedTab.removeDuplicates().sink { [weak self] tab in
            guard let self = self, self.started else { return }
            if tab == .browser { self.browser.pageShown() } else { self.browser.pageHidden() }
        }.store(in: &bag)
    }

    func start() async {
        guard !started else { return }
        MemoryManager.shared.startObserving()
        await library.load()
        started = true
        playback.restoreSession()
        if EcoCore.shared.policy.indexing { library.scanAll() }
        MemoryManager.shared.sample()
    }

    func scenePhaseChanged(_ phase: ScenePhase) {
        clock.setAppActive(phase == .active)
        switch phase {
        case .background:
            playback.appDidEnterBackground()
            if !library.roots.isEmpty { BackgroundTasksRegistrar.schedule() }
            CacheManager.shared.trimDisk(to: CacheManager.shared.diskLimitBytes)
        case .active:
            MemoryManager.shared.sample()
        default: break
        }
    }

    /// Fichiers ouverts depuis Fichiers / menu de partage, ou liens http(s).
    func handleIncoming(_ url: URL) {
        if url.isFileURL {
            library.addFiles([url], copy: false)
            selectedTab = .library
        } else if url.scheme == "http" || url.scheme == "https" {
            selectedTab = .browser
            browser.open(url)
        }
    }
}
