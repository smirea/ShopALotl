import Feedback
import SwiftUI

@main
struct ShopALotlApp: App {
    @State private var store: LocalStore
    @State private var app: AppModel
    private let inference: CategoryInference?

    @Environment(\.scenePhase) private var scenePhase

    init() {
        AppGroup.adoptStandardDefaults()
        let store = LocalStore()
        let app = AppModel(store: store)
        _store = State(initialValue: store)
        _app = State(initialValue: app)
        #if canImport(FoundationModels)
        inference = CategoryInference(model: OnDeviceCategoryModel())
        inference?.start(store: store)
        #else
        inference = nil
        #endif
        #if os(iOS)
        Task.detached(priority: .utility) { SharedLink.write() }
        #endif
        #if canImport(UIKit)
        Feedback.enable()
        Feedback.pinned = ["ProcrastiMate"]
        Feedback.webhooks = [
            FeedbackWebhook(
                name: "GitHub Issue",
                url: AppEnvironment.apiURL.appending(path: "api/feedback"),
                image: Feedback.githubIcon,
                headers: ["Authorization": "Bearer \(AppEnvironment.ownerToken)"]
            ),
        ]
        Feedback.context("Sync") {
            (
                api: AppEnvironment.apiURL.absoluteString, status: String(describing: store.syncStatus),
                unsyncedChanges: store.unsyncedChanges, cursor: store.cursor
            )
        }
        Feedback.context("List") {
            (id: app.current.listID, name: app.current.list.name, grouping: app.current.list.grouping.rawValue, rows: app.current.snapshot.items.count)
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ListScreen(model: app.current)
                .environment(store)
                .environment(app)
                // The catalog's global accent alone left controls blue on iOS 27, so the tint is set here too.
                .tint(Color("AccentColor"))
                // `shopalotl://list?id=<listId>` opens a list, as A Better Me links to the one it just added to.
                .onOpenURL { url in
                    guard url.host() == "list",
                          let id = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "id" })?.value
                    else { return }
                    app.openLinked(id)
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { store.refreshFromOtherProcesses() }
                }
        }
    }
}
