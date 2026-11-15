import Foundation
import Combine
import UIKit

/// Étapes de délestage dans l'ordre du cahier des charges.
enum ShedStage: Int, CaseIterable {
    case stopPrefetch = 1, releaseImages, reduceCaches, suspendIndexing, limitTasks, freeInactiveModules
}

@MainActor
final class MemoryManager: ObservableObject {
    static let shared = MemoryManager()
    static let defaultBudget: UInt64 = 100 * 1024 * 1024

    @Published private(set) var currentBytes: UInt64 = 0
    @Published private(set) var peakBytes: UInt64 = 0
    @Published private(set) var lastShedReport = ""

    var budget: UInt64 = MemoryManager.defaultBudget
    var footprintProvider: () -> UInt64 = { MemoryFootprint.currentBytes() }

    private struct Step { let stage: ShedStage; let name: String; let handler: () -> Void }
    private var steps: [Step] = []
    private var source: DispatchSourceMemoryPressure?

    init() {
        peakBytes = UInt64(max(0, UserDefaults.standard.integer(forKey: "mem.peak")))
    }

    func registerShedStep(_ stage: ShedStage, name: String, handler: @escaping () -> Void) {
        steps.append(Step(stage: stage, name: name, handler: handler))
    }

    /// Écoute des événements de pression mémoire (événementiel, sans polling).
    func startObserving() {
        guard source == nil else { return }
        let src = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .main)
        src.setEventHandler { [weak self, weak src] in
            guard let src = src else { return }
            let critical = src.data.contains(.critical)
            Task { @MainActor in self?.handlePressure(critical: critical) }
        }
        src.resume()
        source = src
    }

    @discardableResult
    func sample() -> UInt64 {
        let v = footprintProvider()
        currentBytes = v
        if v > peakBytes {
            peakBytes = v
            UserDefaults.standard.set(Int(v), forKey: "mem.peak")
        }
        return v
    }

    func resetPeak() {
        peakBytes = sample()
        UserDefaults.standard.set(Int(peakBytes), forKey: "mem.peak")
    }

    /// À appeler après un événement coûteux (lot d'indexation, chargement de page…).
    func checkBudget(reason: String) {
        if sample() > budget { shed(upTo: .freeInactiveModules, reason: reason, stopWhenUnderBudget: true) }
    }

    func handlePressure(critical: Bool) {
        EcoCore.shared.noteMemoryPressure()
        shed(upTo: critical ? .freeInactiveModules : .reduceCaches,
             reason: critical ? "pression critique" : "pression mémoire", stopWhenUnderBudget: false)
    }

    func shed(upTo limit: ShedStage, reason: String, stopWhenUnderBudget: Bool) {
        var log: [String] = []
        let before = currentBytes
        for step in steps.sorted(by: { $0.stage.rawValue < $1.stage.rawValue }) where step.stage.rawValue <= limit.rawValue {
            step.handler()
            log.append(step.name)
            if stopWhenUnderBudget && sample() <= budget { break }
        }
        sample()
        lastShedReport = "\(reason) : \(log.joined(separator: " > ")) (\(before / 1_048_576) Mo → \(currentBytes / 1_048_576) Mo)"
        PerformanceLogger.shared.info("shed " + lastShedReport)
    }
}
