import Foundation

/// YouTube : aucune extraction de flux ni contournement. Les liens s'ouvrent dans le navigateur (lecture officielle).
struct YouTubePolicyAdapter: DownloadSourceAdapter {
    func canHandle(_ url: URL) -> Bool { SourceResolver.isYouTube(url) }
    func resolve(_ url: URL) -> AdapterResult {
        .refused("Le téléchargement depuis YouTube n'est pas pris en charge : les conditions d'utilisation de YouTube ne l'autorisent pas. La vidéo peut être lue via le site officiel dans le navigateur. Pour tes propres contenus, utilise les exports officiels (Google Takeout), puis importe les fichiers depuis Fichiers.")
    }
}
