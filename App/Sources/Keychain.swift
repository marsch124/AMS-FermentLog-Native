import Foundation
import Security

/// One generic-password item in this device's Keychain. Never synced, never in the data file, never printed.
enum Keychain {
    static func read(service: String, account: String = "key") -> String {
        var q = base(service, account)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let d = out as? Data else { return "" }
        return String(data: d, encoding: .utf8) ?? ""
    }

    /// An empty value removes the item.
    static func write(_ value: String, service: String, account: String = "key") {
        let q = base(service, account)
        SecItemDelete(q as CFDictionary)
        guard !value.isEmpty, let d = value.data(using: .utf8) else { return }
        var add = q
        add[kSecValueData as String] = d
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(add as CFDictionary, nil)
    }

    private static func base(_ service: String, _ account: String) -> [String: Any] {
        var q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account,
                                kSecAttrSynchronizable as String: false]
        #if os(macOS)
        q[kSecUseDataProtectionKeychain as String] = true
        #endif
        return q
    }
}
