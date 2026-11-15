import Foundation
import AVFoundation
import Combine

enum EQPreset: String, CaseIterable, Identifiable {
    case flat, bass, treble, vocal, rock, electronic, acoustic, classical
    var id: String { rawValue }
    var label: String {
        switch self {
        case .flat: return "Neutre"
        case .bass: return "Basses"
        case .treble: return "Aigus"
        case .vocal: return "Voix"
        case .rock: return "Rock"
        case .electronic: return "Électro"
        case .acoustic: return "Acoustique"
        case .classical: return "Classique"
        }
    }
    var gains: [Float] {
        switch self {
        case .flat: return [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        case .bass: return [6, 5, 4, 2, 0, 0, 0, 0, 0, 0]
        case .treble: return [0, 0, 0, 0, 0, 1, 2, 4, 5, 6]
        case .vocal: return [-2, -2, -1, 1, 3, 3, 2, 1, 0, -1]
        case .rock: return [5, 4, 2, -1, -2, -1, 2, 4, 5, 5]
        case .electronic: return [5, 4, 1, 0, -2, 2, 1, 3, 5, 5]
        case .acoustic: return [4, 4, 3, 1, 2, 2, 3, 3, 3, 2]
        case .classical: return [4, 3, 2, 2, -1, -1, 0, 2, 3, 4]
        }
    }
}

/// Moteur audio : AVAudioEngine + AVAudioPlayerNode (lecture en flux depuis le disque, jamais le fichier entier en RAM).
@MainActor
final class AudioEngine: ObservableObject {
    enum State { case stopped, playing, paused }

    @Published private(set) var state: State = .stopped
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var eqPreset: EQPreset = .flat
    @Published var rate: Float = 1.0 {
        didSet {
            timePitch.rate = rate
            timePitch.bypass = abs(rate - 1) < 0.01
            if state == .playing { setAnchor(position, playing: true) }
        }
    }
    var onTrackFinished: (() -> Void)?
    var fadeSeconds: Double = 0

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let eq = AVAudioUnitEQ(numberOfBands: 10)
    private let timePitch = AVAudioUnitTimePitch()
    private var file: AVAudioFile?
    private var graphFormat: AVAudioFormat?
    private var generation = 0
    private var segmentStart: TimeInterval = 0
    private var pausedPosition: TimeInterval = 0
    private var anchorPos: TimeInterval = 0
    private var anchorDate: Date?
    private var fadeTask: Task<Void, Never>?
    private var fadeOutTask: Task<Void, Never>?
    private var bag = Set<AnyCancellable>()

    var hasFile: Bool { file != nil }
    var masterVolume: Float {
        get { engine.mainMixerNode.outputVolume }
        set { engine.mainMixerNode.outputVolume = newValue }
    }

    init() {
        engine.attach(player); engine.attach(timePitch); engine.attach(eq)
        let freqs: [Float] = [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
        for (i, band) in eq.bands.enumerated() {
            band.filterType = .parametric
            band.frequency = freqs[i]
            band.bandwidth = 1.0
            band.gain = 0
            band.bypass = false
        }
        eq.bypass = true
        timePitch.bypass = true
        NotificationCenter.default.publisher(for: Notification.Name.AVAudioEngineConfigurationChange, object: engine)
            .sink { [weak self] _ in self?.handleConfigurationChange() }
            .store(in: &bag)
    }

    // MARK: Chargement
    func load(url: URL, startAt: TimeInterval, autoplay: Bool) throws {
        stop()
        let f = try AVAudioFile(forReading: url)
        file = f
        duration = Double(f.length) / f.processingFormat.sampleRate
        try connectGraph(format: f.processingFormat)
        segmentStart = min(max(0, startAt), max(0, duration - 0.1))
        pausedPosition = segmentStart
        setAnchor(segmentStart, playing: false)
        scheduleSegment(from: segmentStart)
        state = .paused
        if autoplay { play(fadeIn: true) }
    }

    private func connectGraph(format: AVAudioFormat) throws {
        if let g = graphFormat, g.sampleRate == format.sampleRate, g.channelCount == format.channelCount { return }
        if engine.isRunning { engine.stop() }
        engine.disconnectNodeOutput(player)
        engine.disconnectNodeOutput(timePitch)
        engine.disconnectNodeOutput(eq)
        engine.connect(player, to: timePitch, format: format)
        engine.connect(timePitch, to: eq, format: format)
        engine.connect(eq, to: engine.mainMixerNode, format: format)
        graphFormat = format
        engine.prepare()
    }

    private func scheduleSegment(from seconds: TimeInterval) {
        guard let f = file else { return }
        generation += 1
        let gen = generation
        let start = AVAudioFramePosition(seconds * f.processingFormat.sampleRate)
        let frames = AVAudioFrameCount(max(0, f.length - start))
        guard frames > 0 else { return }
        player.scheduleSegment(f, startingFrame: start, frameCount: frames, at: nil,
                               completionCallbackType: .dataPlayedBack) { [weak self] _ in
            Task { @MainActor in self?.segmentFinished(gen) }
        }
    }

    private func segmentFinished(_ gen: Int) {
        guard gen == generation, state == .playing else { return }
        state = .stopped
        pausedPosition = duration
        setAnchor(duration, playing: false)
        fadeOutTask?.cancel()
        player.volume = 1
        onTrackFinished?()
    }

    // MARK: Transport
    func play(fadeIn: Bool = false) {
        guard file != nil else { return }
        do { if !engine.isRunning { try engine.start() } } catch {
            PerformanceLogger.shared.warn("engine.start: \(error.localizedDescription)"); return
        }
        if state == .stopped { segmentStart = 0; scheduleSegment(from: 0); setAnchor(0, playing: false) }
        if fadeIn && fadeSeconds > 0 { player.volume = 0; ramp(from: 0, to: 1, seconds: min(fadeSeconds, 2)) } else { player.volume = 1 }
        player.play()
        state = .playing
        setAnchor(pausedPosition, playing: true)
        scheduleFadeOut()
    }

    func pause() {
        guard state == .playing else { return }
        let p = position
        player.pause()
        engine.pause()
        pausedPosition = p
        setAnchor(p, playing: false)
        state = .paused
        fadeOutTask?.cancel(); fadeTask?.cancel()
        player.volume = 1
    }

    func seek(to t: TimeInterval) {
        guard file != nil else { return }
        let wasPlaying = state == .playing
        let target = min(max(0, t), max(0, duration - 0.05))
        generation += 1
        player.stop()
        segmentStart = target
        pausedPosition = target
        setAnchor(target, playing: wasPlaying)
        scheduleSegment(from: target)
        if wasPlaying {
            try? engine.start()
            player.play()
            scheduleFadeOut()
        }
    }

    /// Arrête et libère le fichier, le moteur et ses buffers.
    func stop() {
        generation += 1
        fadeTask?.cancel(); fadeOutTask?.cancel()
        player.stop()
        if engine.isRunning { engine.stop() }
        file = nil
        graphFormat = nil
        duration = 0; segmentStart = 0; pausedPosition = 0
        setAnchor(0, playing: false)
        player.volume = 1
        state = .stopped
    }

    // MARK: Position
    private func setAnchor(_ pos: TimeInterval, playing: Bool) {
        anchorPos = pos
        anchorDate = playing ? Date() : nil
    }

    var position: TimeInterval {
        guard file != nil else { return 0 }
        guard state == .playing else { return pausedPosition }
        if engine.isRunning, let nt = player.lastRenderTime, let pt = player.playerTime(forNodeTime: nt), pt.sampleRate > 0 {
            return min(max(0, segmentStart + Double(pt.sampleTime) / pt.sampleRate), duration)
        }
        guard let d = anchorDate else { return anchorPos }
        return min(duration, anchorPos + Date().timeIntervalSince(d) * Double(rate))
    }

    // MARK: Égaliseur
    func apply(preset: EQPreset) {
        eqPreset = preset
        for (i, g) in preset.gains.enumerated() where i < eq.bands.count { eq.bands[i].gain = g }
        eq.globalGain = preset == .flat ? 0 : -3
        eq.bypass = preset == .flat
    }

    // MARK: Fondu (fin de morceau et début du suivant)
    private func scheduleFadeOut() {
        fadeOutTask?.cancel()
        guard fadeSeconds > 0, duration > 0 else { return }
        let remaining = (duration - position) / Double(max(rate, 0.1)) - fadeSeconds
        guard remaining > 0 else { return }
        let fade = fadeSeconds
        fadeOutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.ramp(from: 1, to: 0, seconds: fade)
        }
    }

    private func ramp(from a: Float, to b: Float, seconds: Double) {
        fadeTask?.cancel()
        fadeTask = Task { [weak self] in
            let steps = 20
            for i in 0...steps {
                guard !Task.isCancelled, let self = self else { return }
                self.player.volume = a + (b - a) * Float(i) / Float(steps)
                try? await Task.sleep(nanoseconds: UInt64(seconds / Double(steps) * 1_000_000_000))
            }
        }
    }

    // MARK: Changement de route audio (casque débranché, Bluetooth…)
    private func handleConfigurationChange() {
        guard file != nil else { return }
        let wasPlaying = state == .playing
        let pos = wasPlaying ? min(duration, anchorPos + (anchorDate.map { Date().timeIntervalSince($0) } ?? 0) * Double(rate)) : pausedPosition
        generation += 1
        player.stop()
        segmentStart = pos
        pausedPosition = pos
        setAnchor(pos, playing: wasPlaying)
        scheduleSegment(from: pos)
        if wasPlaying { try? engine.start(); player.play() }
    }
}
