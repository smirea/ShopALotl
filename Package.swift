// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "ShopALotl",
    platforms: [.iOS(.v27), .macOS(.v27)],
    products: [.executable(name: "ShopALotl", targets: ["App"])],
    dependencies: [
        .package(url: "https://github.com/smirea/feedback-engine", branch: "master"),
        .package(url: "https://github.com/smirea/sync-engine", branch: "master"),
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.11.1"),
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [
                .product(name: "Feedback", package: "feedback-engine"),
                .product(name: "SyncEngine", package: "sync-engine"),
                .product(name: "GRDB", package: "GRDB.swift"),
            ],
            // SwiftPM cannot compile an asset catalog; Xcode builds it and the privacy manifest into the app.
            exclude: ["Assets.xcassets", "PrivacyInfo.xcprivacy"]
        ),
        .testTarget(name: "AppTests", dependencies: ["App", .product(name: "GRDB", package: "GRDB.swift")]),
    ]
)
