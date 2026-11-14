import SwiftUI

@main
struct ShopALotlApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image("Mascot")
                .resizable()
                .scaledToFit()
                .frame(width: 160, height: 160)
                .accessibilityHidden(true)
            Text("ShopALotl")
                .font(.largeTitle.bold())
        }
        .padding()
    }
}
