import SwiftUI

/// The owner's other apps that add items, bundled here because both apps are the owner's. An app this version does not
/// know shows a generic icon under its id.
enum SourceApp {
    static func name(_ app: String) -> String {
        app == "a-better-me" ? "A Better Me" : app
    }
}

/// The tiny icon of the app that put an item on the list.
struct SourceIcon: View {
    let app: String
    var size: CGFloat = 14

    var body: some View {
        Group {
            if app == "a-better-me" {
                Image("SourceABetterMe").resizable().scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.225, style: .continuous))
            } else {
                Image(systemName: "arrow.down.app").resizable().scaledToFit().foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel("From \(SourceApp.name(app))")
    }
}
