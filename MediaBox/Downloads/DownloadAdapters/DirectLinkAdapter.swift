import Foundation

/// Liens directs vers des fichiers MP3/M4A/MP4… auxquels l'utilisateur a légitimement accès.
struct DirectLinkAdapter: DownloadSourceAdapter {
    func canHandle(_ url: URL) -> Bool {
        if case .directMedia = SourceResolver.classify(url) { return true }
        return false
    }
    func resolve(_ url: URL) -> AdapterResult {
        let kind = SourceResolver.classify(url)
        return .download(url: url, filename: SourceResolver.suggestedFileName(for: url),
                         destination: SourceResolver.destination(for: kind))
    }
}
