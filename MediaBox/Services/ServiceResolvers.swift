import Foundation

struct ServiceError: Error { let message: String; init(_ m: String) { message = m } }

struct ResolvedDownload {
    let url: URL
    let filename: String
    let destination: DownloadDestination
    let headers: [String: String]
}

/// Résolution via API officielles uniquement (NON TESTÉ sur de vrais comptes : à valider avec un jeton).
enum ServiceResolvers {
    static func resolve(_ s: MediaService, url: URL, token: String) async throws -> ResolvedDownload {
        switch s {
        case .vimeo: return try await vimeo(url, token)
        case .soundcloud: return try await soundcloud(url, token)
        default: throw ServiceError("Ce service ne propose pas de téléchargement officiel.")
        }
    }

    private static func json(_ req: URLRequest) async throws -> [String: Any] {
        var r = req
        r.timeoutInterval = 20
        let (data, resp) = try await URLSession.shared.data(for: r)
        guard let http = resp as? HTTPURLResponse else { throw ServiceError("Réponse invalide du service.") }
        if http.statusCode == 401 || http.statusCode == 403 {
            throw ServiceError("Jeton refusé (\(http.statusCode)). Vérifie le jeton et ses autorisations.")
        }
        guard (200..<300).contains(http.statusCode) else { throw ServiceError("Erreur du service (\(http.statusCode)).") }
        guard let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { throw ServiceError("Réponse illisible.") }
        return obj
    }

    private static func vimeo(_ url: URL, _ token: String) async throws -> ResolvedDownload {
        guard let id = url.pathComponents.reversed().first(where: { Int($0) != nil }),
              let api = URL(string: "https://api.vimeo.com/videos/\(id)?fields=name,download") else { throw ServiceError("Lien Vimeo non reconnu.") }
        var req = URLRequest(url: api)
        req.setValue("bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/vnd.vimeo.*+json;version=3.4", forHTTPHeaderField: "Accept")
        let obj = try await json(req)
        let name = (obj["name"] as? String) ?? "vimeo-\(id)"
        guard let files = obj["download"] as? [[String: Any]], !files.isEmpty else {
            throw ServiceError("Le propriétaire n'a pas autorisé le téléchargement de cette vidéo (ou ton jeton n'y a pas accès).")
        }
        let best = files.max { (($0["size"] as? Double) ?? 0) < (($1["size"] as? Double) ?? 0) }
        guard let link = best?["link"] as? String, let u = URL(string: link) else { throw ServiceError("Aucun lien de téléchargement fourni.") }
        return ResolvedDownload(url: u, filename: FileManagerService.sanitize(name) + ".mp4", destination: .videos, headers: [:])
    }

    private static func soundcloud(_ url: URL, _ token: String) async throws -> ResolvedDownload {
        var comps = URLComponents(string: "https://api.soundcloud.com/resolve")!
        comps.queryItems = [URLQueryItem(name: "url", value: url.absoluteString)]
        guard let api = comps.url else { throw ServiceError("Lien SoundCloud invalide.") }
        var req = URLRequest(url: api)
        req.setValue("OAuth \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Accept")
        let obj = try await json(req)
        guard (obj["downloadable"] as? Bool) == true, let dl = obj["download_url"] as? String, let u = URL(string: dl) else {
            throw ServiceError("L'artiste n'a pas activé le téléchargement pour ce titre.")
        }
        let title = (obj["title"] as? String) ?? "soundcloud"
        let ext = (obj["original_format"] as? String) ?? "mp3"
        return ResolvedDownload(url: u, filename: FileManagerService.sanitize(title) + "." + ext,
                                destination: .music, headers: ["Authorization": "OAuth \(token)"])
    }
}

@MainActor
enum ServiceDownloader {
    /// Retourne le message à afficher à l'utilisateur.
    static func start(url: URL, downloads: DownloadManager) async -> String {
        guard let s = ServiceRouter.service(for: url) else { return "Lien non reconnu." }
        switch s.download {
        case .none(let why): return why
        case .officialAPI:
            guard let token = ServiceCredentials.token(for: s) else {
                return "Ajoute ton jeton \(s.name) dans Réglages > Services pour utiliser l'API officielle."
            }
            do {
                let r = try await ServiceResolvers.resolve(s, url: url, token: token)
                switch downloads.enqueue(url: r.url, name: r.filename, destination: r.destination, headers: r.headers) {
                case .added: return "Ajouté à la file de téléchargements."
                case .duplicate(let m): return m
                case .alreadyActive: return "Ce fichier est déjà dans la file."
                }
            } catch let e as ServiceError { return e.message }
            catch { return error.localizedDescription }
        }
    }
}
