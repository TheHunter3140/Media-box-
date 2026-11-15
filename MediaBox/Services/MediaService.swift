import Foundation

/// Services accessibles via leurs sites officiels. L'ouverture web ne constitue
/// pas une intégration SDK ni une autorisation de télécharger leurs contenus.
struct MediaService: Identifiable, Hashable {
    let id: String
    let name: String
    let subtitle: String
    let symbol: String
    let host: String
    let url: URL
    let tintName: String
    let downloadNote: String

    static let all: [MediaService] = [
        .init(id: "youtube", name: "YouTube", subtitle: "Vidéos & musique", symbol: "play.rectangle.fill", host: "youtube.com", url: URL(string: "https://www.youtube.com")!, tintName: "red", downloadNote: "Lecture via le site officiel. Aucun extracteur ni contournement de téléchargement."),
        .init(id: "soundcloud", name: "SoundCloud", subtitle: "Découvertes audio", symbol: "waveform", host: "soundcloud.com", url: URL(string: "https://soundcloud.com")!, tintName: "orange", downloadNote: "Téléchargement uniquement si le créateur active l'option officielle ou fournit un fichier autorisé."),
        .init(id: "spotify", name: "Spotify", subtitle: "Musique & podcasts", symbol: "waveform.circle.fill", host: "open.spotify.com", url: URL(string: "https://open.spotify.com")!, tintName: "green", downloadNote: "Le mode hors ligne reste géré par Spotify. MediaBox ne copie pas les titres protégés."),
        .init(id: "vimeo", name: "Vimeo", subtitle: "Vidéo & création", symbol: "v.circle.fill", host: "vimeo.com", url: URL(string: "https://vimeo.com")!, tintName: "blue", downloadNote: "Import possible depuis un lien ou export explicitement autorisé par le propriétaire."),
        .init(id: "dailymotion", name: "Dailymotion", subtitle: "Actualités & vidéos", symbol: "play.tv.fill", host: "dailymotion.com", url: URL(string: "https://www.dailymotion.com")!, tintName: "indigo", downloadNote: "Lecture web officielle. Pas d'extraction de flux protégés."),
        .init(id: "tiktok", name: "TikTok", subtitle: "Clips & tendances", symbol: "music.note", host: "tiktok.com", url: URL(string: "https://www.tiktok.com")!, tintName: "pink", downloadNote: "Utiliser les fonctions de partage/enregistrement prévues par TikTok et les droits du créateur."),
        .init(id: "twitch", name: "Twitch", subtitle: "Live & replay", symbol: "dot.radiowaves.left.and.right", host: "twitch.tv", url: URL(string: "https://www.twitch.tv")!, tintName: "purple", downloadNote: "Les VOD et clips ne sont importables que via une exportation autorisée."),
    ]
}
