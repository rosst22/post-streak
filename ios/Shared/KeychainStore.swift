import Foundation
import Security

struct KeychainStore: Sendable {
    private let service = "com.rosstoma.PostStreak.session"
    private let account = "supabase-session"
    private let accessGroup: String

    init(accessGroup: String) {
        self.accessGroup = accessGroup
    }

    func save(_ tokens: SessionTokens) throws {
        let data = try JSONEncoder().encode(tokens)
        let query = baseQuery
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else { throw AppError.keychain(status) }
    }

    func load() throws -> SessionTokens? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw AppError.keychain(status)
        }
        return try JSONDecoder().decode(SessionTokens.self, from: data)
    }

    func clear() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AppError.keychain(status)
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessGroup as String: accessGroup,
        ]
    }
}

