import SwiftUI
import CoreText

@main
struct HometsWatchApp: App {
    @State private var store = WatchStore()

    init() {
        ["Barlow-Regular", "Barlow-SemiBold", "Barlow-ExtraBold"].forEach { name in
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { return }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    var body: some Scene {
        WindowGroup {
            WatchRootView(store: store).task { store.start() }
        }
    }
}
