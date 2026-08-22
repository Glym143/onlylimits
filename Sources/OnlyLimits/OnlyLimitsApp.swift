import SwiftUI

@main
struct OnlyLimitsApp: App {
    @StateObject private var store = UsageStore()
    // With an isInserted binding the app survives the status item being
    // removed (⌘-drag off / Control Center hiding it) instead of AppKit's
    // default terminate-on-removal, so the icon can be re-enabled later.
    @State private var isInserted = true

    var body: some Scene {
        MenuBarExtra(isInserted: $isInserted) {
            MenuContentView(store: store)
        } label: {
            // Custom-drawn mini bar chart. Template image → the system tints it
            // white on a dark menu bar / black on a light one (always legible).
            Image(nsImage: store.statusImage)
        }
        .menuBarExtraStyle(.window)
    }
}
