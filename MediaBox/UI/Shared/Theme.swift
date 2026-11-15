import SwiftUI
import UIKit
import MediaPlayer
import UniformTypeIdentifiers

enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: String { switch self { case .system: return "Système"; case .light: return "Clair"; case .dark: return "Sombre" } }
    var scheme: ColorScheme? { switch self { case .system: return nil; case .light: return .light; case .dark: return .dark } }
}

enum Theme {
    static let accent = Color(red: 0.38, green: 0.56, blue: 1.0)
    static let accent2 = Color(red: 0.72, green: 0.44, blue: 1.0)
    static let corner: CGFloat = 22

    static let cardFill = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 1, alpha: 0.07) : UIColor(white: 1, alpha: 0.62) })
    static let edge = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 1, alpha: 0.22) : UIColor(white: 1, alpha: 0.95) })
    static let edgeFade = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 1, alpha: 0.04) : UIColor(white: 0.8, alpha: 0.35) })
    static let solidFill = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.10, green: 0.11, blue: 0.18, alpha: 1) : UIColor(red: 0.95, green: 0.96, blue: 1.0, alpha: 1) })
}

/// Fond Liquid Glass : dégradé + deux halos lumineux. Dessiné une seule fois (statique, aucun flou).
struct GlassBackground: View {
    @Environment(\.colorScheme) private var scheme
    @EnvironmentObject private var settings: AppSettings
    var body: some View {
        let dark = scheme == .dark
        ZStack {
            LinearGradient(colors: dark
                           ? [Color(red: 0.02, green: 0.03, blue: 0.09), Color(red: 0.08, green: 0.05, blue: 0.19)]
                           : [Color(red: 0.93, green: 0.95, blue: 1.0), Color(red: 0.98, green: 0.94, blue: 1.0)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            if settings.glow {
                RadialGradient(colors: [Theme.accent.opacity(dark ? 0.38 : 0.28), .clear], center: .topTrailing, startRadius: 0, endRadius: 380)
                RadialGradient(colors: [Theme.accent2.opacity(dark ? 0.32 : 0.22), .clear], center: .bottomLeading, startRadius: 0, endRadius: 440)
            }
        }
        .ignoresSafeArea()
    }
}

/// Carte « verre à plat » : remplissage translucide + liseré lumineux, SANS flou (bon marché sur A12).
struct GlassCard: ViewModifier {
    var radius: CGFloat = Theme.corner
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content.background {
            shape.fill(Theme.cardFill)
                .overlay(shape.strokeBorder(LinearGradient(colors: [Theme.edge, Theme.edgeFade], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
        }
    }
}

/// Verre « flou » réservé aux 2 éléments du dock : Liquid Glass natif sur iOS 26 (si compilé avec Xcode 26),
/// sinon matériau translucide ; plein si transparence coupée par l'utilisateur ou EcoCore.
struct GlassSurface: ViewModifier {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var eco: EcoCore
    var radius: CGFloat = 30

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let blur = settings.transparency && eco.policy.transparency
        if blur {
            #if compiler(>=6.2)
            if #available(iOS 26.0, *) {
                content.glassEffect(.regular, in: shape)
            } else {
                legacy(content, shape)
            }
            #else
            legacy(content, shape)
            #endif
        } else {
            content
                .background(shape.fill(Theme.solidFill))
                .overlay(shape.strokeBorder(Theme.edge.opacity(0.6), lineWidth: 1))
        }
    }

    private func legacy(_ content: Content, _ shape: RoundedRectangle) -> some View {
        content
            .background(.ultraThinMaterial, in: shape)
            .overlay(shape.strokeBorder(LinearGradient(colors: [Theme.edge, Theme.edgeFade], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
            .shadow(color: .black.opacity(0.22), radius: 12, y: 5)
    }
}

extension View {
    func glassCard(radius: CGFloat = Theme.corner) -> some View { modifier(GlassCard(radius: radius)) }
    func glassSurface(radius: CGFloat = 30) -> some View { modifier(GlassSurface(radius: radius)) }
    /// Compatibilité avec l'ancien nom.
    func surface(radius: CGFloat = Theme.corner) -> some View { modifier(GlassCard(radius: radius)) }
}

/// Section de formulaire en verre à plat.
struct GSection<Content: View>: View {
    let title: String?
    let content: Content
    init(_ title: String, @ViewBuilder content: () -> Content) { self.title = title; self.content = content() }
    init(@ViewBuilder content: () -> Content) { self.title = nil; self.content = content() }
    var body: some View {
        if let t = title {
            SwiftUI.Section(t) { content }.listRowBackground(Theme.cardFill)
        } else {
            SwiftUI.Section { content }.listRowBackground(Theme.cardFill)
        }
    }
}

struct ArtworkView: View {
    @EnvironmentObject var library: MediaLibrary
    let item: MediaItem
    var size: CGFloat = 48
    var pixel: Int = 160
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous).fill(Theme.cardFill)
            if let image = image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: item.kind == .audio ? "music.note" : "film").foregroundColor(.secondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous).strokeBorder(Theme.edge.opacity(0.5), lineWidth: 0.5))
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
