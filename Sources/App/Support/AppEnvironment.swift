import Foundation

/// Build settings the app cannot run without, read once at launch so a bad build stops there.
enum AppEnvironment {
    static let apiURL: URL = {
        guard let url = URL(string: setting("API_URL")), let scheme = url.scheme, ["http", "https"].contains(scheme),
              url.host != nil
        else {
            fatalError("API_URL is not an http(s) URL. Run bun run env:generate, and bun run env:ios before a device or Release build.")
        }
        return url
    }()

    /// Bundled at build time: the local servers' development token, or production's on a device and in Release.
    static let ownerToken: String = {
        let token = setting("OWNER_TOKEN")
        if token.isEmpty { fatalError("Missing OWNER_TOKEN. Run bun run env:ios before a device or Release build.") }
        return token
    }()

    private static func setting(_ key: String) -> String {
        (Bundle.main.object(forInfoDictionaryKey: key) as? String)?.trimmingCharacters(in: .whitespaces) ?? ""
    }
}
