import SwiftUI

@main
struct AntiIdleApp: App {
    var body: some Scene {
        MenuBarExtra("AntiIdle", systemImage: "play.fill") {
            Text("AntiIdle — Loading...")
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .menuBarExtraStyle(.menu)
    }
}
