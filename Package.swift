// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "ShopALotl",
    platforms: [.iOS(.v27), .macOS(.v27)],
    products: [.executable(name: "ShopALotl", targets: ["App"])],
    dependencies: [
        .package(url: "https://github.com/smirea/feedback-engine", branch: "master"),
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [.product(name: "Feedback", package: "feedback-engine")],
            // SwiftPM cannot compile an asset catalog; Xcode builds it into the app.
            exclude: ["Assets.xcassets"]
        ),
    ]
)
