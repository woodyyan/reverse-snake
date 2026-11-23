import SwiftUI

@main
struct ReverseSnakeApp: App {
    init() {
        // Warm up the audio session off the main thread while the start screen
        // is shown, so the first beep is never lost to lazy initialization.
        _ = SoundEngine.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
