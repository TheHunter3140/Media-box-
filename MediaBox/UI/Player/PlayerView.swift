import SwiftUI

struct PlayerView: View {
    @EnvironmentObject var playback: PlaybackController
    @EnvironmentObject var clock: PlaybackClock
    @EnvironmentObject var settings: AppSettings
    @State private var dragging = false
    @State private var dragValue = 0.0
    @State private var showSleep = false
    @State private var showQueue = false

    var body: some View {
        VStack(spacing: 18) {
            Capsule().fill(Color.secondary.opacity(0.4)).frame(width: 40, height: 5).padding(.top, 8)
            Spacer(minLength: 0)
            if let c = playback.current {
                ArtworkView(item: c, size: 280, pixel: 600).shadow(radius: 12, y: 6)
                VStack(spacing: 4) {
                    Text(c.title).font(.title3.weight(.semibold)).multilineTextAlignment(.center).lineLimit(2)
                    Text(c.displayArtist).foregroundColor(.secondary)
                }
            }
            VStack(spacing: 2) {
                Slider(value: Binding(get: { dragging ? dragValue : clock.position }, set: { dragValue = $0 }),
                       in: 0...max(clock.duration, 1)) { editing in
                    dragging = editing
                    if !editing { playback.seek(to: dragValue) }
                }
                HStack {
                    Text(Format.time(dragging ? dragValue : clock.position))
                    Spacer()
                    Text("-" + Format.time(max(0, clock.duration - (dragging ? dragValue : clock.position))))
                }.font(.caption).monospacedDigit().foregroundColor(.secondary)
            }.padding(.horizontal)
            HStack(spacing: 34) {
                Button { settings.tap(); playback.previous() } label: { Image(systemName: "backward.fill").font(.title) }.accessibilityLabel("Précédent")
                Button { settings.tap(); playback.toggle() } label: {
                    Image(systemName: playback.isPlaying ? "pause.circle.fill" : "play.circle.fill").font(.system(size: 64))
                }.accessibilityLabel(playback.isPlaying ? "Pause" : "Lecture")
                Button { settings.tap(); playback.next() } label: { Image(systemName: "forward.fill").font(.title) }.accessibilityLabel("Suivant")
            }
            HStack(spacing: 22) {
                Button { playback.setShuffle(!playback.queue.shuffled) } label: {
                    Image(systemName: "shuffle").foregroundColor(playback.queue.shuffled ? Theme.accent : .secondary)
                }.accessibilityLabel("Aléatoire")
                Button { playback.cycleRepeat() } label: {
                    Image(systemName: playback.queue.repeatMode.icon).foregroundColor(playback.queue.repeatMode == .off ? .secondary : Theme.accent)
                }.accessibilityLabel("Répétition")
                Menu {
                    ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { r in
                        Button(String(format: "%.2g×", r)) { playback.setRate(Float(r)) }
                    }
                } label: { Image(systemName: "speedometer") }.accessibilityLabel("Vitesse")
                Menu {
                    ForEach(EQPreset.allCases) { p in
                        Button { playback.audio.apply(preset: p) } label: {
                            if playback.audio.eqPreset == p { Label(p.label, systemImage: "checkmark") } else { Text(p.label) }
                        }
                    }
                } label: { Image(systemName: "slider.vertical.3") }.accessibilityLabel("Égaliseur")
                Button { showSleep = true } label: { Image(systemName: "moon.zzz") }.accessibilityLabel("Minuteur de sommeil")
                Button { showQueue = true } label: { Image(systemName: "list.bullet") }.accessibilityLabel("File d'attente")
            }.font(.title3)
            Spacer(minLength: 0)
        }
        .padding(.bottom)
        .sheet(isPresented: $showSleep) { SleepTimerView() }
        .sheet(isPresented: $showQueue) { QueueView() }
        .onAppear { clock.setWanted(true); clock.tick() }
        .onDisappear { clock.setWanted(false) }
    }
}

struct QueueView: View {
    @EnvironmentObject var playback: PlaybackController
    var body: some View {
        NavigationStack {
            List {
                if let c = playback.current { Section("En lecture") { MediaRow(item: c) } }
                Section("À suivre") {
                    ForEach(playback.queue.upcoming.prefix(100)) { item in
                        Button { playback.jump(to: item) } label: { MediaRow(item: item) }.buttonStyle(.plain)
                    }
                }
            }.navigationTitle("File d'attente")
        }
    }
}

struct SleepTimerView: View {
    @EnvironmentObject var timer: SleepTimer
    @Environment(\.dismiss) private var dismiss
    @State private var customMinutes = 20
    @State private var clockTime = Date().addingTimeInterval(3600)

    var body: some View {
        NavigationStack {
            Form {
                if timer.isActive {
                    Section {
                        if let d = timer.fireDate { Text("Arrêt à \(d.formatted(date: .omitted, time: .shortened))") }
                        else { Text(timer.mode == .afterTrack ? "Arrêt après ce morceau" : "Arrêt après la file de lecture") }
                        Button("Annuler le minuteur", role: .destructive) { timer.cancel(); dismiss() }
                    }
                }
                Section("Durée") {
                    ForEach([15, 30, 45, 60, 90], id: \.self) { m in
                        Button(m == 60 ? "1 heure" : m == 90 ? "1 h 30" : "\(m) minutes") { timer.start(.duration(Double(m) * 60)); dismiss() }
                    }
                    Stepper("Personnalisée : \(customMinutes) min", value: $customMinutes, in: 1...600)
                    Button("Démarrer \(customMinutes) min") { timer.start(.duration(Double(customMinutes) * 60)); dismiss() }
                }
                Section("Heure précise") {
                    DatePicker("Arrêt à", selection: $clockTime, displayedComponents: .hourAndMinute)
                    Button("Programmer") { timer.start(.atTime(clockTime)); dismiss() }
                }
                Section("Fin de contenu") {
                    Button("Après ce morceau") { timer.start(.afterTrack); dismiss() }
                    Button("Après la playlist / file") { timer.start(.afterQueue); dismiss() }
                }
                Section("Diminution progressive du volume") {
                    Stepper("\(Int(timer.fadeSeconds)) secondes", value: $timer.fadeSeconds, in: 0...60, step: 5)
                }
            }
            .navigationTitle("Minuteur de sommeil")
            .toolbar { Button("Fermer") { dismiss() } }
        }
    }
}
