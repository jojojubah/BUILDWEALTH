import SwiftUI

@main
struct BUILDWEALTHApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        #if os(macOS)
        .defaultSize(width: 1280, height: 800)
        .windowStyle(.hiddenTitleBar)
        #endif
    }
}
