import Foundation
import Combine

@MainActor
final class ThermalMonitor: ObservableObject {
    static let shared = ThermalMonitor()
    @Published private(set) var state: ProcessInfo.ThermalState = ProcessInfo.processInfo.thermalState
    private var cancellable: AnyCancellable?

    init() {
        cancellable = NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)
            .sink { [weak self] _ in self?.state = ProcessInfo.processInfo.thermalState }
    }

    static func label(_ s: ProcessInfo.ThermalState) -> String {
        switch s {
        case .nominal: return "Normal"
        case .fair: return "Tiède"
        case .serious: return "Chaud"
        case .critical: return "Critique"
        @unknown default: return "Inconnu"
        }
    }
}
