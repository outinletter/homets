import SwiftUI

@main
struct HometsWatchApp: App {
    @State private var store = WatchStore()

    var body: some Scene {
        WindowGroup {
            WatchRootView(store: store).task { store.start() }
        }
    }
}
