import Foundation
import Security

/// Jetons personnels (SoundCloud, Vimeo) stockés dans le Trousseau, jamais dans les fichiers de l'app.
enum ServiceCredentials {
    private static let serviceName = "com.local.mediabox.tokens"

    private static func base(_ s: MediaService) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: serviceName,
         kSecAttrAccount as String: s.rawValue]
    }

    static func token(for s: MediaService) -> String? {
        var q = base(s)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let d = out as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }

    static func setToken(_ token: String?, for s: MediaService) {
        SecItemDelete(base(s) as CFDictionary)
        guard let t = token?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return }
        var add = base(s)
        add[kSecValueData as String] = Data(t.utf8)
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(add as CFDictionary, nil)
    }
}
