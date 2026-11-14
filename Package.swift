// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "ShopALotl",
    platforms: [.iOS(.v27), .macOS(.v27)],
    products: [.executable(name: "ShopALotl", targets: ["App"])],
    targets: [.executableTarget(name: "App")]
)
