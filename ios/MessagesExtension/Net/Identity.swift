import Foundation
import Security

// Player name persistence. UserDefaults is the live store the name field binds
// to, but it's wiped on a clean reinstall (and the free-signing 7-day recovery
// cycle). Mirroring to the keychain keeps the name across reinstalls so you only
// ever type it once.
enum NameStore {
    private static let account = "playerName"
    private static let service = "com.sachinsagrawal.tickettotext"

    static func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var out: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess,
              let data = out as? Data, let s = String(data: data, encoding: .utf8), !s.isEmpty
        else { return nil }
        return s
    }

    static func save(_ name: String?) {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(base as CFDictionary)
        guard let name, let data = name.data(using: .utf8) else { return }
        var add = base
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(add as CFDictionary, nil) // best-effort; UserDefaults remains the fallback
    }
}
