import Foundation
import SwiftUI

// MARK: - Localization
// User-facing copy lives in *.lproj/Localizable.strings. There is no in-app
// language picker: the app always follows the system (or per-app) language.
//
//   zh-Hans.lproj  简体中文
//   zh-Hant.lproj  繁體中文
//   en-US.lproj    English (United States)
//   en.lproj       English fallback (en-GB, en-AU, ... and the dev region)
//
// SwiftUI views use LocalizedStringKey so locale changes re-resolve without a
// view rebuild. Core Graphics text uses L10n.s(), which resolves against the
// current preferred languages on every call.

enum L10n {

    /// Stable keys. Values are never hard-coded in Swift.
    enum K {
        // Top bar (VoiceOver)
        static let controlPause = "control.pause"
        static let controlResume = "control.resume"
        static let controlSoundOn = "control.sound.on"
        static let controlSoundOff = "control.sound.off"
        static let controlRestart = "control.restart"

        // HUD primary labels
        static let hudScore = "hud.score"
        static let hudBest = "hud.best"
        static let hudLength = "hud.length"
        static let hudSpace = "hud.space"
        static let hudThreat = "hud.threat"

        // HUD secondary short descriptors
        static let hudSubScore = "hud.sub.score"
        static let hudSubBest = "hud.sub.best"
        static let hudSubLength = "hud.sub.length"
        static let hudSubSpace = "hud.sub.space"
        static let hudSubThreat = "hud.sub.threat"

        // HUD state lamp
        static let stateReady = "hud.state.ready"
        static let stateCountdown = "hud.state.countdown"
        static let stateRunning = "hud.state.running"
        static let statePaused = "hud.state.paused"
        static let stateOver = "hud.state.over"
        static let dashReady = "hud.dash.ready"

        // Core Graphics board
        static let boardGrid = "board.grid"
        static let boardGo = "board.go"
        static let boardCountdownHint = "board.countdown.hint"

        // Panels
        static let badgeReady = "panel.badge.ready"
        static let badgePaused = "panel.badge.paused"
        static let badgeOver = "panel.badge.over"
        static let readyTitle = "panel.ready.title"
        static let readyBody = "panel.ready.body"
        static let hintSwipeTitle = "panel.hint.swipe.title"
        static let hintSwipeDetail = "panel.hint.swipe.detail"
        static let hintDashTitle = "panel.hint.dash.title"
        static let hintDashDetail = "panel.hint.dash.detail"
        static let start = "panel.start"
        static let pausedTitle = "panel.paused.title"
        static let pausedBody = "panel.paused.body"
        static let resume = "panel.resume"
        static let overTitle = "panel.over.title"
        static let score = "panel.score"
        static let replay = "panel.replay"
        static let overHitBody = "panel.over.hit"
        static let overCaught = "panel.over.caught"
    }

    /// SwiftUI text. LocalizedStringKey keeps locale changes reactive.
    static func t(_ key: String) -> Text { Text(LocalizedStringKey(key)) }

    /// Plain String for Core Graphics and other non-View contexts.
    static func s(_ key: String) -> String {
        for preferred in Locale.preferredLanguages {
            for loc in candidates(for: preferred) {
                if let value = table(loc)?[key], !value.isEmpty { return value }
            }
        }
        for loc in ["en", "en-US", "Base"] {
            if let value = table(loc)?[key], !value.isEmpty { return value }
        }
        let fallback = Bundle.main.localizedString(forKey: key, value: nil, table: nil)
        return fallback.isEmpty ? key : fallback
    }

    /// Locale injected into SwiftUI. A system language change publishes a new
    /// value, which re-resolves LocalizedStringKey without resetting the game.
    static var currentLocale: Locale {
        let supported = Set(Bundle.main.localizations)
        for preferred in Locale.preferredLanguages {
            for loc in candidates(for: preferred) {
                if supported.contains(loc) { return Locale(identifier: loc) }
            }
        }
        return Locale(identifier: "en")
    }

    /// "zh-Hant-HK" -> ["zh-Hant-HK", "zh-Hant", "zh"].
    /// Chinese region tags without a script (zh-HK / zh-TW / zh-CN) are
    /// aliased so they never fall back to English.
    private static func candidates(for language: String) -> [String] {
        var parts = language.split(separator: "-").map(String.init)
        var result: [String] = []
        while !parts.isEmpty {
            result.append(parts.joined(separator: "-"))
            parts.removeLast()
        }
        let lower = language.lowercased()
        if lower.hasPrefix("zh") {
            let traditional = ["hant", "hk", "tw", "mo"].contains { lower.contains($0) }
            result.append(traditional ? "zh-Hant" : "zh-Hans")
        }
        return result
    }

    private static var tables: [String: [String: String]] = [:]
    private static let lock = NSLock()

    private static func table(_ localization: String) -> [String: String]? {
        lock.lock()
        defer { lock.unlock() }
        if let cached = tables[localization] { return cached }
        guard let url = Bundle.main.url(forResource: "Localizable",
                                        withExtension: "strings",
                                        subdirectory: nil,
                                        localization: localization),
              let dict = NSDictionary(contentsOf: url) as? [String: String] else {
            tables[localization] = [:]
            return tables[localization]
        }
        tables[localization] = dict
        return dict
    }
}

/// Publishes a fresh Locale when the system language changes.
final class LocalizationCenter: ObservableObject {
    static let shared = LocalizationCenter()

    @Published private(set) var locale: Locale
    private var observer: NSObjectProtocol?

    private init() {
        locale = L10n.currentLocale
        observer = NotificationCenter.default.addObserver(
            forName: NSLocale.currentLocaleDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.locale = L10n.currentLocale
        }
    }
}
