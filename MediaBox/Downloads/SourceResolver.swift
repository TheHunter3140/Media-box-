import Foundation

enum SourceKind: Equatable {
    case directMedia(ext: String, isVideo: Bool)
    case youtube
    case webPage
    case unknown
}

enum AdapterResult {
    case download(url: URL, filename: String, destination: DownloadDestination)
    case refused(String)
}

/// Classe les liens. Aucune extraction de flux : seuls les fichiers directement téléchargeables sont acceptés.
enum SourceResolver {
    static let audioExt: Set<String> = ["mp3", "m4a", "aac", "wav", "aif", "aiff", "caf", "flac", "alac"]
    static let videoExt: Set<String> = ["mp4", "m4v", "mov"]

    static func isYouTube(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host == "youtu.be" || host.hasSuffix("youtube.com") || host.hasSuffix("youtube-nocookie.com")
    }

    static func classify(_ url: URL) -> SourceKind {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else { return .unknown }
        if isYouTube(url) { return .youtube }
        let ext = url.pathExtension.lowercased()
        if audioExt.contains(ext) { return .directMedia(ext: ext, isVideo: false) }
        if videoExt.contains(ext) { return .directMedia(ext: ext, isVideo: true) }
        return .webPage
    }

    static func suggestedFileName(for url: URL) -> String {
        var name = url.lastPathComponent.removingPercentEncoding ?? url.lastPathComponent
        if name.isEmpty || name == "/" { name = url.host ?? "fichier" }
        return FileManagerService.sanitize(name)
    }

    static func destination(for kind: SourceKind) -> DownloadDestination {
        if case .directMedia(_, let isVideo) = kind { return isVideo ? .videos : .music }
        return .other
    }

    /// Vérification réseau explicite (action utilisateur uniquement) : requête HEAD.
    static func probe(_ url: URL) async -> SourceKind {
        let initial = classify(url)
        if initial != .webPage { return initial }
        var req = URLRequest(url: url)
        req.httpMethod = "HEAD"
        req.timeoutInterval = 8
        guard let (_, resp) = try? await URLSession(configuration: .ephemeral).data(for: req),
              let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return .unknown }
        let type = (http.value(forHTTPHeaderField: "Content-Type") ?? "").lowercased()
        if type.hasPrefix("audio/") { return .directMedia(ext: "mp3", isVideo: false) }
        if type.hasPrefix("video/") { return .directMedia(ext: "mp4", isVideo: true) }
        return .webPage
    }
}

protocol DownloadSourceAdapter {
    func canHandle(_ url: URL) -> Bool
    func resolve(_ url: URL) -> AdapterResult
}

enum SourceAdapters {
    static let all: [DownloadSourceAdapter] = [PlatformPolicyAdapter(), DirectLinkAdapter()]
    static func resolve(_ url: URL) -> AdapterResult {
        for a in all where a.canHandle(url) { return a.resolve(url) }
        return .refused("Ce lien n'est pas un fichier audio ou vidéo téléchargeable directement.")
    }
}
