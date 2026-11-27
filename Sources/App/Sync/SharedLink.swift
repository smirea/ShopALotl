#if os(iOS)
import Foundation
import OSLog
import Security

/// The server and owner token, shared with the owner's other apps through the team's keychain access group, so A Better
/// Me can add a recipe's ingredients to a list (`server/add-items.ts`) with no setup. The same paradigm as
/// ProcrastiMate's `procrastimate-link`: one generic password, service `shopalotl-link`, account `default`, whose data
/// is `{ "apiURL": "…", "token": "…" }`. There is no sign-in, so it is written at every launch, which also points it
/// at whichever build (local server or production) was installed last.
enum SharedLink {
    private static let log = Logger(subsystem: "com.stefan.shopalotl", category: "shopalotl-link")

    private static var query: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "shopalotl-link",
            kSecAttrAccount as String: "default",
            kSecAttrAccessGroup as String: "FNYFHG5SV7.com.stefan.shared",
        ]
    }

    static func write() {
        let link = ["apiURL": AppEnvironment.apiURL.absoluteString, "token": AppEnvironment.ownerToken]
        guard let data = try? JSONSerialization.data(withJSONObject: link, options: .sortedKeys) else { return }
        SecItemDelete(query as CFDictionary)
        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let status = SecItemAdd(item as CFDictionary, nil)
        if status != errSecSuccess { log.error("write failed, status \(status)") }
    }
}
#endif
