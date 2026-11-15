import SwiftUI
import AVKit

struct VideoControllerView: UIViewControllerRepresentable {
    let controller: AVPlayerViewController
    func makeUIViewController(context: Context) -> AVPlayerViewController { controller }
    func updateUIViewController(_ vc: AVPlayerViewController, context: Context) {}
}

struct VideoPlayerScreen: View {
    @EnvironmentObject var playback: PlaybackController
    @State private var showPanel = false
    @State private var brightness = Double(UIScreen.main.brightness)
    @State private var originalBrightness = UIScreen.main.brightness

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()
            VideoControllerView(controller: playback.video.controller).ignoresSafeArea()
            VStack(spacing: 8) {
                HStack(spacing: 18) {
                    Button { playback.videoPresented = false; playback.pause() } label: { Image(systemName: "xmark") }.accessibilityLabel("Fermer")
                    Spacer()
                    Button { playback.videoPresented = false } label: { Image(systemName: "speaker.wave.2") }.accessibilityLabel("Audio seul")
                    Menu {
                        ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { r in
                            Button(String(format: "%.2g×", r)) { playback.setRate(Float(r)) }
                        }
                    } label: { Image(systemName: "speedometer") }
                    Button { withAnimation { showPanel.toggle() } } label: { Image(systemName: "sun.max") }.accessibilityLabel("Luminosité et volume")
                }
                .font(.title3).foregroundColor(.white).padding(12)
                .glassSurface(radius: 20)
                if showPanel {
                    VStack(spacing: 10) {
                        HStack { Image(systemName: "sun.min"); Slider(value: $brightness, in: 0.05...1) { _ in UIScreen.main.brightness = CGFloat(brightness) }; Image(systemName: "sun.max") }
                        HStack { Image(systemName: "speaker"); SystemVolumeView().frame(height: 30); Image(systemName: "speaker.wave.3") }
                    }
                    .foregroundColor(.white).padding(12)
                    .glassSurface(radius: 20)
                }
            }
            .padding(.horizontal, 12).padding(.top, 8)
        }
        .onAppear { originalBrightness = UIScreen.main.brightness; brightness = Double(originalBrightness) }
        .onDisappear { UIScreen.main.brightness = originalBrightness }
    }
}
