import Foundation
import Combine
import UIKit

enum EcoProfile: String, CaseIterable, Identifiable, Codable {
    case normal, economique, ultra, thermiqueCritique
    var id: String { rawValue }
    var label: String {
        switch self {
        case .normal: return "Normal"
        case .economique: return "Économique"
        case .ultra: return "Ultra-économique"
        case .thermiqueCritique: return "Thermique critique"
        }
    }
    var summary: String {
        switch self {
        case .normal: return "Toutes les fonctionnalités disponibles."
        case .economique: return "Moins d'animations, d'indexation et de préchargement."
        case .ultra: return "Lecture prioritaire, tâches facultatives suspendues."
        case .thermiqueCritique: return "Téléchargements non urgents et traitements lourds suspendus."
        }
    }
}

struct EcoPolicy: Equatable {
    let animations: Bool
    let transparency: Bool
    let prefetch: Bool
    let indexing: Bool
    let indexingConcurrency: Int
    let heavyTasks: Bool
    let maxDownloads: Int
    let clockInterval: Double

    static func make(for p: EcoProfile) -> EcoPolicy {
        switch p {
        case .normal:
            return EcoPolicy(animations: true, transparency: true, prefetch: true, indexing: true, indexingConcurrency: 3, heavyTasks: true, maxDownloads: 3, clockInterval: 0.5)
        case .economique:
            return EcoPolicy(animations: false, transparency: false, prefetch: false, indexing: true, indexingConcurrency: 2, heavyTasks: true, maxDownloads: 2, clockInterval: 1.0)
        case .ultra:
            return EcoPolicy(animations: false, transparency: false, prefetch: false, indexing: false, indexingConcurrency: 1, heavyTasks: false, maxDownloads: 1, clockInterval: 1.0)
        case .thermiqueCritique:
            return EcoPolicy(animations: false, transparency: false, prefetch: false, indexing: false, indexingConcurrency: 0, heavyTasks: false, maxDownloads: 0, clockInterval: 1.0)
        }
    }
}

/// Module central d'économie d'énergie. Piloté uniquement par événements système
/// (mode économie d'énergie, état thermique, pression mémoire) : aucun timer, aucun polling.
@MainActor
final class EcoCore: ObservableObject {
    static let shared = EcoCore()

    @Published private(set) var profile: EcoProfile = .normal
    @Published private(set) var policy = EcoPolicy.make(for: .normal)
    @Published private(set) var reason = "Conditions normales"
    @Published var manualProfile: EcoProfile? {
        didSet {
            UserDefaults.standard.set(manualProfile?.rawValue, forKey: "eco.manual")
            recompute()
        }
    }
    let profileChanged = PassthroughSubject<EcoProfile, Never>()

    private(set) var isPlaying = false
    private(set) var downloadsActive = false
    private(set) var browserActive = false
    private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    private var thermal = ProcessInfo.processInfo.thermalState
    private var memoryPressure = false
    private var pressureReset: Task<Void, Never>?
    private var bag = Set<AnyCancellable>()

    init() {
        if let raw = UserDefaults.standard.string(forKey: "eco.manual") { manualProfile = EcoProfile(rawValue: raw) }
        NotificationCenter.default.publisher(for: Notification.Name.NSProcessInfoPowerStateDidChange)
            .sink { [weak self] _ in
                self?.lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
                self?.recompute()
            }.store(in: &bag)
        ThermalMonitor.shared.$state
            .sink { [weak self] s in
                self?.thermal = s
                self?.recompute()
            }.store(in: &bag)
        recompute()
    }

    nonisolated static func derive(lowPower: Bool, thermal: ProcessInfo.ThermalState, memoryPressure: Bool, playing: Bool) -> (EcoProfile, String) {
        if thermal == .serious || thermal == .critical { return (.thermiqueCritique, "Appareil trop chaud") }
        if lowPower && (memoryPressure || thermal == .fair || playing) {
            return (.ultra, "Mode économie d'énergie iOS actif")
        }
        if lowPower { return (.economique, "Mode économie d'énergie iOS actif") }
        if memoryPressure { return (.economique, "Pression mémoire") }
        if thermal == .fair { return (.economique, "Appareil légèrement chaud") }
        return (.normal, "Conditions normales")
    }

    func noteMemoryPressure() {
        memoryPressure = true
        recompute()
        pressureReset?.cancel()
        pressureReset = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 45_000_000_000)
            guard !Task.isCancelled else { return }
            self?.memoryPressure = false
            self?.recompute()
        }
    }
    func setPlaying(_ v: Bool) { isPlaying = v; recompute() }
    func setDownloadsActive(_ v: Bool) { downloadsActive = v }
    func setBrowserActive(_ v: Bool) { browserActive = v }

    private func recompute() {
        let (derived, why) = EcoCore.derive(lowPower: lowPower, thermal: thermal, memoryPressure: memoryPressure, playing: isPlaying)
        let newProfile = manualProfile ?? derived
        reason = manualProfile != nil ? "Profil forcé dans les réglages" : why
        guard newProfile != profile else { return }
        profile = newProfile
        policy = EcoPolicy.make(for: newProfile)
        profileChanged.send(newProfile)
    }
}
