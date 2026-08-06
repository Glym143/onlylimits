import SwiftUI

@main
struct OnlyLimitsApp: App {
    @StateObject private var store = UsageStore()

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(store: store)
        } label: {
            // Custom-drawn mini bar chart. Template image → the system tints it
            // white on a dark menu bar / black on a light one (always legible).
            Image(nsImage: store.statusImage)
        }
        .menuBarExtraStyle(.window)
    }
}
