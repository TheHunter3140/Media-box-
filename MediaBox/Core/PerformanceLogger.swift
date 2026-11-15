import Foundation
import os
import UIKit

final class PerformanceLogger {
    static let shared = PerformanceLogger()
    private let log = Logger(subsystem: "com.local.mediabox", category: "perf")
    func info(_ message: String) { log.info("\(message, privacy: .public)") }
    func warn(_ message: String) { log.warning("\(message, privacy: .public)") }

    @discardableResult
    func measure<T>(_ name: String, _ body: () throws -> T) rethrows -> T {
        let t0 = CFAbsoluteTimeGetCurrent()
        let r = try body()
        info("\(name) : \(Int((CFAbsoluteTimeGetCurrent() - t0) * 1000)) ms")
        return r
    }
}

struct BenchSample: Identifiable {
    let id = UUID()
    let t: TimeInterval
    let scenario: String
    let memMB: Double
    let peakMB: Double
    let cpu: Double
    let thermal: String
    let lowPower: Bool
    let note: String
}

/// Enregistreur de benchmark : n'échantillonne que pendant une session lancée par l'utilisateur.
@MainActor
final class BenchmarkRecorder: ObservableObject {
    static let scenarios = [
        "A – App ouverte sans activité", "B – Bibliothèque de 1 000 fichiers",
        "C – Audio 30 min", "D – Vidéo 30 min", "E – Audio + navigateur ouvert",
        "F – Téléchargement pendant lecture audio", "G – Mode économie d'énergie",
        "H – Pression mémoire", "I – Arrêt de lecture / libération"
    ]
    @Published private(set) var samples: [BenchSample] = []
    @Published private(set) var isRecording = false
    @Published var scenario = BenchmarkRecorder.scenarios[0]
    @Published var intervalSeconds = 5.0
    private var startDate = Date()
    private var task: Task<Void, Never>?

    func start() {
        samples = []
        startDate = Date()
        isRecording = true
        mark("début")
        task = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64((self?.intervalSeconds ?? 5) * 1_000_000_000))
                guard !Task.isCancelled else { return }
                self?.mark("")
            }
        }
    }
    func stop() {
        mark("fin")
        task?.cancel(); task = nil
        isRecording = false
    }
    func mark(_ note: String) {
        let s = ResourceMonitor.shared.capture()
        samples.append(BenchSample(t: Date().timeIntervalSince(startDate), scenario: scenario,
                                   memMB: Double(s.footprint) / 1_048_576, peakMB: Double(s.peak) / 1_048_576,
                                   cpu: s.cpu, thermal: ThermalMonitor.label(s.thermal), lowPower: s.lowPower, note: note))
    }
    var summary: String {
        guard !samples.isEmpty else { return "Aucune mesure." }
        let mems = samples.map { $0.memMB }
        let avg = mems.reduce(0, +) / Double(mems.count)
        return String(format: "%d mesures · mémoire moy. %.1f Mo · max %.1f Mo", samples.count, avg, mems.max() ?? 0)
    }
    func exportCSV() -> URL? {
        var csv = "scenario;t_s;mem_mb;peak_mb;cpu_pct;thermal;low_power;note\n"
        for s in samples {
            csv += "\(s.scenario);" + String(format: "%.1f;%.1f;%.1f;%.1f;", s.t, s.memMB, s.peakMB, s.cpu)
            csv += "\(s.thermal);\(s.lowPower ? "oui" : "non");\(s.note)\n"
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("mediabox-benchmark.csv")
        do { try csv.write(to: url, atomically: true, encoding: .utf8); return url } catch { return nil }
    }
}
