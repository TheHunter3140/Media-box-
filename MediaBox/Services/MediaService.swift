import Foundation

enum DownloadSupport: Equatable {
    /// Aucun téléchargement possible dans MediaBox (protection / conditions d'utilisation). Le texte explique pourquoi.
    case none(String)
    /// Téléchargement possible uniquement via l'API officielle, quand le propriétaire l'autorise (jeton personnel requis).
    case officialAPI(String)
}

enum MediaService: String, CaseIterable, Identifiable {
    case youtube, soundcloud, spotify, vimeo, dailymotion, tiktok, twitch
    var id: String { rawValue }

    var name: String {
        switch self {
        case .youtube: return "YouTube"
        case .soundcloud: return "SoundCloud"
        case .spotify: return "Spotify"
        case .vimeo: return "Vimeo"
        case .dailymotion: return "Dailymotion"
        case .tiktok: return "TikTok"
        case .twitch: return "Twitch"
        }
    }
    var symbol: String {
        switch self {
        case .youtube: return "play.rectangle.fill"
        case .soundcloud: return "waveform"
        case .spotify: return "music.note"
        case .vimeo: return "film.fill"
        case .dailymotion: return "play.tv.fill"
        case .tiktok: return "music.note.tv.fill"
        case .twitch: return "dot.radiowaves.left.and.right"
        }
    }
    var rgb: (Double, Double, Double) {
        switch self {
        case .youtube: return (1.00, 0.20, 0.25)
        case .soundcloud: return (1.00, 0.45, 0.10)
        case .spotify: return (0.12, 0.84, 0.38)
        case .vimeo: return (0.10, 0.72, 0.93)
        case .dailymotion: return (0.15, 0.45, 1.00)
        case .tiktok: return (0.95, 0.20, 0.55)
        case .twitch: return (0.60, 0.35, 1.00)
        }
    }
    var homeURL: URL {
        switch self {
        case .youtube: return URL(string: "https://m.youtube.com")!
        case .soundcloud: return URL(string: "https://soundcloud.com")!
        case .spotify: return URL(string: "https://open.spotify.com")!
        case .vimeo: return URL(string: "https://vimeo.com")!
        case .dailymotion: return URL(string: "https://www.dailymotion.com")!
        case .tiktok: return URL(string: "https://www.tiktok.com")!
        case .twitch: return URL(string: "https://m.twitch.tv")!
        }
    }
    var hosts: [String] {
        switch self {
        case .youtube: return ["youtube.com", "youtu.be", "youtube-nocookie.com"]
        case .soundcloud: return ["soundcloud.com", "snd.sc"]
        case .spotify: return ["spotify.com", "spotify.link"]
        case .vimeo: return ["vimeo.com"]
        case .dailymotion: return ["dailymotion.com", "dai.ly"]
        case .tiktok: return ["tiktok.com"]
        case .twitch: return ["twitch.tv"]
        }
    }
    var playbackNote: String {
        switch self {
        case .spotify: return "Lecture via le lecteur web officiel ou l'app Spotify (compte requis)."
        default: return "Lecture via le site officiel intégré au navigateur de MediaBox."
        }
    }
    var download: DownloadSupport {
        switch self {
        case .youtube: return .none("YouTube n'autorise pas le téléchargement hors de ses offres officielles (YouTube Premium, ou Google Takeout pour tes propres contenus). Importe ensuite les fichiers depuis Fichiers.")
        case .spotify: return .none("Les titres Spotify sont protégés (DRM) : écoute via l'app Spotify, et hors connexion avec Spotify Premium dans l'app.")
        case .tiktok: return .none("TikTok ne propose le téléchargement que depuis son app, sur les vidéos dont le créateur l'autorise.")
        case .twitch: return .none("Twitch ne permet pas d'enregistrer les directs ni les rediffusions d'autrui. Pour tes propres diffusions, utilise le tableau de bord créateur de Twitch.")
        case .dailymotion: return .none("Dailymotion ne propose pas de téléchargement public : lecture via le site officiel.")
        case .soundcloud: return .officialAPI("Titres que l'artiste a rendus téléchargeables, via l'API officielle de SoundCloud (jeton personnel requis).")
        case .vimeo: return .officialAPI("Vidéos dont le propriétaire autorise le téléchargement, via l'API Vimeo (jeton d'accès personnel requis).")
        }
    }
    var supportsAPIDownload: Bool { if case .officialAPI = download { return true } else { return false } }
}

enum ServiceRouter {
    static func service(for url: URL) -> MediaService? {
        guard let host = url.host?.lowercased() else { return nil }
        for s in MediaService.allCases {
            for h in s.hosts where host == h || host.hasSuffix("." + h) { return s }
        }
        return nil
    }
}
