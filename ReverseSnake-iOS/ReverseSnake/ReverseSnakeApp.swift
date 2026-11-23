import SwiftUI

@main
struct ReverseSnakeApp: App {
    init() {
        // Warm up audio + haptics while the start screen is shown, so the
        // first beep / vibration has no warm-up latency.
        _ = SoundEngine.shared
        _ = Haptics.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
