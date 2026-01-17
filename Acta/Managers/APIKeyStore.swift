import Foundation
import KeychainAccess

enum APIKeyStore {
    private static let service = "xyz.no-comment.Acta"
    private static let openRouterKey = "openrouter_api_key"

    static func loadOpenRouterKey() -> String? {
        let keychain = makeKeychain()
        return try? keychain.get(openRouterKey)
    }

    static func hasOpenRouterKey() -> Bool {
        guard let value = loadOpenRouterKey() else { return false }
        return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func saveOpenRouterKey(_ value: String) throws {
        let keychain = makeKeychain()
        if value.isEmpty {
            try keychain.remove(openRouterKey)
        } else {
            try keychain.set(value, key: openRouterKey)
        }
    }

    private static func makeKeychain() -> Keychain {
        Keychain(service: service)
    }
}
