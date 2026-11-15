import SwiftUI
import BackgroundTasks

final class AppDelegate: NSObject, UIApplicationDelegate {
    static var backgroundCompletionHandler: (() -> Void)?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        BackgroundTasksRegistrar.register()
        return true
    }

    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String,
                     completionHandler: @escaping () -> Void) {
        AppDelegate.backgroundCompletionHandler = completionHandler
    }
}

enum BackgroundTasksRegistrar {
    static let reindexID = "com.local.mediabox.reindex"

    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: reindexID, using: nil) { task in
            guard let t = task as? BGProcessingTask else { task.setTaskCompleted(success: false); return }
            let work = Task { @MainActor in
                AppCoordinator.shared.library.scanAll()
                try? await Task.sleep(nanoseconds: 20_000_000_000)
                t.setTaskCompleted(success: true)
            }
            t.expirationHandler = {
                work.cancel()
                Task { @MainActor in AppCoordinator.shared.library.cancelIndexing() }
            }
        }
    }

    static func schedule() {
        let req = BGProcessingTaskRequest(identifier: reindexID)
        req.requiresNetworkConnectivity = false
        req.requiresExternalPower = false
        req.earliestBeginDate = Date(timeIntervalSinceNow: 6 * 3600)
        try? BGTaskScheduler.shared.submit(req)
    }
}

@main
struct MediaBoxApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var coordinator = AppCoordinator.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(coordinator)
                .environmentObject(coordinator.settings)
                .environmentObject(EcoCore.shared)
                .environmentObject(MemoryManager.shared)
                .environmentObject(coordinator.library)
                .environmentObject(coordinator.playlists)
                .environmentObject(coordinator.playback)
                .environmentObject(coordinator.clock)
                .environmentObject(coordinator.sleepTimer)
                .environmentObject(coordinator.downloads)
                .environmentObject(coordinator.browser)
                .environmentObject(coordinator.storage)
                .environmentObject(coordinator.benchmark)
                .tint(Theme.accent)
                .onOpenURL { coordinator.handleIncoming($0) }
                .task { await coordinator.start() }
        }
        .onChange(of: scenePhase) { phase in coordinator.scenePhaseChanged(phase) }
    }
}
