import SwiftUI
import UniformTypeIdentifiers
import UIKit
import MediaPlayer

enum Theme {
    static let accent = Color(red: 0.18, green: 0.45, blue: 0.98)
    static let corner: CGFloat = 20
    static let heroGradient = LinearGradient(colors: [Color(red: 0.08, green: 0.16, blue: 0.36), Color(red: 0.22, green: 0.20, blue: 0.52), Color(red: 0.36, green: 0.12, blue: 0.40)], startPoint: .topLeading, endPoint: .bottomTrailing)
}

/// Fond adaptatif : matériau translucide seulement si l'utilisateur ET EcoCore l'autorisent.
struct Surface: ViewModifier {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var eco: EcoCore
    var radius: CGFloat = Theme.corner
    func body(content: Content) -> some View {
        if settings.transparency && eco.policy.transparency {
            content.background(.regularMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        } else {
            content.background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        }
    }
}
extension View {
    func surface(radius: CGFloat = Theme.corner) -> some View { modifier(Surface(radius: radius)) }
}

struct ArtworkView: View {
    @EnvironmentObject var library: MediaLibrary
    let item: MediaItem
    var size: CGFloat = 48
    var pixel: Int = 160
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.18, style: .continuous).fill(Color(.tertiarySystemFill))
            if let image = image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: item.kind == .audio ? "music.note" : "film").foregroundColor(.secondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.18, style: .continuous))
        .task(id: item.id) {
            image = await ArtworkLoader.load(item: item, url: library.url(for: item), maxPixel: pixel)
        }
        .accessibilityHidden(true)
    }
}

struct DocumentPicker: UIViewControllerRepresentable {
    enum Mode { case files, folder }
    let mode: Mode
    let onPick: ([URL]) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types: [UTType] = mode == .folder ? [.folder] : [.audio, .movie]
        let p = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: false)
        p.allowsMultipleSelection = mode == .files
        p.delegate = context.coordinator
        return p
    }
    func updateUIViewController(_ vc: UIDocumentPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onPick) }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: ([URL]) -> Void
        init(_ f: @escaping ([URL]) -> Void) { onPick = f }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) { onPick(urls) }
    }
}

struct SystemVolumeView: UIViewRepresentable {
    func makeUIView(context: Context) -> MPVolumeView { MPVolumeView(frame: .zero) }
    func updateUIView(_ uiView: MPVolumeView, context: Context) {}
}
