import Foundation

/// Plateformes (YouTube, Spotify, TikTok, Twitch, Dailymotion…) : aucune extraction de flux ni contournement.
struct PlatformPolicyAdapter: DownloadSourceAdapter {
    func canHandle(_ url: URL) -> Bool { ServiceRouter.service(for: url) != nil }
    func resolve(_ url: URL) -> AdapterResult {
        guard let s = ServiceRouter.service(for: url) else { return .refused("Lien non reconnu.") }
        switch s.download {
        case .none(let why): return .refused(why)
        case .officialAPI(let note): return .refused("\(s.name) : \(note)")
        }
    }
}
