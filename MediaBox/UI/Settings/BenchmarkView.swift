import SwiftUI

struct BenchmarkView: View {
    @EnvironmentObject var bench: BenchmarkRecorder
    @State private var exportURL: URL?

    var body: some View {
        Form {
            GSection("Scénario") {
                Picker("Scénario", selection: $bench.scenario) { ForEach(BenchmarkRecorder.scenarios, id: \.self) { Text($0).tag($0) } }
                Stepper("Intervalle : \(Int(bench.intervalSeconds)) s", value: $bench.intervalSeconds, in: 2...30, step: 1)
                Button(bench.isRecording ? "Arrêter" : "Démarrer l'enregistrement") {
                    if bench.isRecording { bench.stop(); exportURL = bench.exportCSV() } else { bench.start() }
                }.foregroundColor(bench.isRecording ? .red : Theme.accent)
                Button("Ajouter un repère") { bench.mark("repère") }.disabled(!bench.isRecording)
            }
            GSection("Résultat") {
                Text(bench.summary)
                if let u = exportURL, !bench.isRecording { ShareLink("Exporter le CSV", item: u) }
            }
            GSection("Dernières mesures") {
                ForEach(bench.samples.suffix(12).reversed()) { s in
                    Text(String(format: "%.0f s · %.1f Mo · CPU %.0f %% · %@", s.t, s.memMB, s.cpu, s.thermal)).font(.caption).monospacedDigit()
                }
            }
            GSection { Text("L'échantillonnage ne tourne que pendant l'enregistrement. Mesures valides uniquement sur appareil réel ; le simulateur n'est pas représentatif.").font(.footnote).foregroundColor(.secondary) }
        }.navigationTitle("Benchmark")
    }
}
