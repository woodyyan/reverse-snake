import SwiftUI

@main
struct ReverseSnakeApp: App {
    @StateObject private var localization = LocalizationCenter.shared

    init() {
        // Warm up audio + haptics while the start screen is shown, so the
        // first beep / vibration has no warm-up latency.
        _ = SoundEngine.shared
        _ = Haptics.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                // Follows the system language; changing it re-resolves every
                // LocalizedStringKey without rebuilding the game state.
                .environment(\.locale, localization.locale)
        }
    }
}
