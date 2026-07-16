//
//  KeychainVault.swift
//  AsunaTracks
//

import Foundation
import Security

/// Stores authentication secrets in the device Keychain rather than UserDefaults.
enum KeychainVault {
    static let defaultAccount = "AsunaTracksToken"

    @discardableResult
    static func saveToken(_ token: String, account: String = defaultAccount) -> Bool {
        guard let data = token.data(using: .utf8) else { return false }
        deleteToken(account: account)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: account,
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func readToken(account: String = defaultAccount) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8),
              !token.isEmpty else { return nil }
        return token
    }

    @discardableResult
    static func deleteToken(account: String = defaultAccount) -> Bool {
        let query: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrAccount: account]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
