import SwiftUI
import UIKit

// MARK: - Color helpers

extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255.0,
                  green: Double((hex >> 8) & 0xFF) / 255.0,
                  blue: Double(hex & 0xFF) / 255.0,
                  opacity: alpha)
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1.0) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255.0,
                  green: CGFloat((hex >> 8) & 0xFF) / 255.0,
                  blue: CGFloat(hex & 0xFF) / 255.0,
                  alpha: alpha)
    }

    static func mix(_ a: UIColor, _ b: UIColor, _ t: CGFloat) -> UIColor {
        var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        a.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
        b.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        let k = max(0, min(1, t))
        return UIColor(red: ar + (br - ar) * k,
                       green: ag + (bg - ag) * k,
                       blue: ab + (bb - ab) * k,
                       alpha: aa + (ba - aa) * k)
    }

    func alpha(_ a: CGFloat) -> UIColor { withAlphaComponent(a) }
}

extension Font {
    /// SF Pro Rounded — used for every number (score, stats, countdown).
    static func rounded(_ size: CGFloat, _ weight: Font.Weight = .heavy) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

// MARK: - Palettes
// Two themes, one semantic token set (design proposal v2):
//   Nocturne  (dark)  — cool-blue snake vs warm-orange player on near-black.
//   Daylight  (light) — ink-green snake vs coral player on warm paper.
// One colour = one meaning: player/primary, snake, food/gold, danger.

struct Palette {
    let isDark: Bool
    // Chrome
    let bg: UIColor
    let surface: UIColor
    let surface2: UIColor
    let hairline: UIColor
    let text: UIColor
    let text2: UIColor
    let text3: UIColor
    let shadow: UIColor
    let scrim: UIColor
    // Board
    let board: UIColor
    let boardCenter: UIColor
    let gridDot: UIColor
    // Actors
    let snakeTail: UIColor
    let snakeHead: UIColor
    let deadTail: UIColor
    let pupil: UIColor
    let spine: UIColor
    let player: UIColor
    let playerHi: UIColor
    let food: UIColor
    let foodHi: UIColor
    let danger: UIColor
    // Actions / medals
    let primary: UIColor
    let onPrimary: UIColor
    let gold: UIColor
    let onGold: UIColor
    let silver: UIColor
    let bronze: UIColor

    /// A · Nocturne
    static let night = Palette(
        isDark: true,
        bg: UIColor(hex: 0x07090E), surface: UIColor(hex: 0x11151E), surface2: UIColor(hex: 0x1A1F2B),
        hairline: UIColor(white: 1, alpha: 0.07),
        text: UIColor(hex: 0xF3F5F9), text2: UIColor(hex: 0x8C95A8), text3: UIColor(hex: 0x596275),
        shadow: UIColor(white: 0, alpha: 0.5), scrim: UIColor(hex: 0x05070C, alpha: 0.58),
        board: UIColor(hex: 0x0B0E15), boardCenter: UIColor(hex: 0x121826),
        gridDot: UIColor(white: 1, alpha: 0.075),
        snakeTail: UIColor(hex: 0x0F2C45), snakeHead: UIColor(hex: 0x5CC8FF),
        deadTail: UIColor(hex: 0x3A1018), pupil: UIColor(hex: 0x07090E), spine: UIColor(white: 1, alpha: 1),
        player: UIColor(hex: 0xFF7A2F), playerHi: UIColor(hex: 0xFFC08F),
        food: UIColor(hex: 0xFFC83D), foodHi: UIColor(hex: 0xFFF0B8), danger: UIColor(hex: 0xFF4D5E),
        primary: UIColor(hex: 0xFF7A2F), onPrimary: UIColor(hex: 0x1A0B02),
        gold: UIColor(hex: 0xFFC83D), onGold: UIColor(hex: 0x2A1A00),
        silver: UIColor(hex: 0xC9D3E3), bronze: UIColor(hex: 0xD9935B))

    /// B · Daylight
    static let daylight = Palette(
        isDark: false,
        bg: UIColor(hex: 0xF3EFE6), surface: UIColor(hex: 0xFFFFFF), surface2: UIColor(hex: 0xEAE4D7),
        hairline: UIColor(hex: 0x281E0A, alpha: 0.09),
        text: UIColor(hex: 0x1E1B16), text2: UIColor(hex: 0x7A7264), text3: UIColor(hex: 0xA69E8F),
        shadow: UIColor(hex: 0x281E0A, alpha: 0.16), scrim: UIColor(hex: 0xF3EFE6, alpha: 0.62),
        board: UIColor(hex: 0xE6DFCF), boardCenter: UIColor(hex: 0xEFE9DD),
        gridDot: UIColor(hex: 0x3C2D14, alpha: 0.16),
        snakeTail: UIColor(hex: 0xB9D6C3), snakeHead: UIColor(hex: 0x1F6B52),
        deadTail: UIColor(hex: 0xF2C9C9), pupil: UIColor(hex: 0x1E1B16), spine: UIColor(white: 1, alpha: 1),
        player: UIColor(hex: 0xFF5A47), playerHi: UIColor(hex: 0xFFB2A8),
        food: UIColor(hex: 0xE9A410), foodHi: UIColor(hex: 0xFFE3A0), danger: UIColor(hex: 0xE5484D),
        primary: UIColor(hex: 0x1E1B16), onPrimary: UIColor(hex: 0xFFFFFF),
        gold: UIColor(hex: 0xE9A410), onGold: UIColor(hex: 0x2A1A00),
        silver: UIColor(hex: 0xB8B2A6), bronze: UIColor(hex: 0xC88A5A))

    static func resolve(_ traits: UITraitCollection) -> Palette {
        traits.userInterfaceStyle == .dark ? .night : .daylight
    }
}

// MARK: - SwiftUI tokens (dynamic: follow the window's interface style)

enum Theme {
    private static func dyn(_ key: KeyPath<Palette, UIColor>) -> Color {
        Color(UIColor { Palette.resolve($0)[keyPath: key] })
    }

    static let bg = dyn(\.bg)
    static let surface = dyn(\.surface)
    static let surface2 = dyn(\.surface2)
    static let hairline = dyn(\.hairline)
    static let text = dyn(\.text)
    static let text2 = dyn(\.text2)
    static let text3 = dyn(\.text3)
    static let shadow = dyn(\.shadow)
    static let scrim = dyn(\.scrim)
    static let board = dyn(\.board)
    static let snakeTail = dyn(\.snakeTail)
    static let snakeHead = dyn(\.snakeHead)
    static let player = dyn(\.player)
    static let playerHi = dyn(\.playerHi)
    static let food = dyn(\.food)
    static let foodHi = dyn(\.foodHi)
    static let danger = dyn(\.danger)
    static let primary = dyn(\.primary)
    static let onPrimary = dyn(\.onPrimary)
    static let gold = dyn(\.gold)
    static let onGold = dyn(\.onGold)
    static let silver = dyn(\.silver)
    static let bronze = dyn(\.bronze)
}

// MARK: - Appearance: follow system / light / dark

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }
    var titleKey: String { "appearance.\(rawValue)" }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }

    var style: UIUserInterfaceStyle {
        switch self {
        case .system: return .unspecified
        case .light: return .light
        case .dark: return .dark
        }
    }

    var next: AppearanceMode {
        let all = AppearanceMode.allCases
        return all[(all.firstIndex(of: self)! + 1) % all.count]
    }
}

/// Applies the choice as a window override, so SwiftUI, UIKit (the board
/// renderer) and the status bar all switch together. A window override is
/// used instead of .preferredColorScheme(nil), which does not reliably return
/// to the system style once a fixed scheme has been set.
final class AppearanceStore: ObservableObject {
    static let shared = AppearanceStore()
    private let key = "snakefeast-appearance"

    @Published var mode: AppearanceMode {
        didSet {
            guard mode != oldValue else { return }
            UserDefaults.standard.set(mode.rawValue, forKey: key)
            apply(animated: true)
        }
    }

    private init() {
        mode = AppearanceMode(rawValue: UserDefaults.standard.string(forKey: key) ?? "") ?? .system
    }

    func apply(animated: Bool = false) {
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            for window in scene.windows {
                if animated {
                    UIView.transition(with: window, duration: 0.35, options: .transitionCrossDissolve) {
                        window.overrideUserInterfaceStyle = self.mode.style
                    }
                } else {
                    window.overrideUserInterfaceStyle = mode.style
                }
            }
        }
    }
}

// MARK: - Responsive layout metrics

enum GridMode: String {
    case tall
    case wide
}

struct LayoutMetrics {
    let size: CGSize

    var width: CGFloat { size.width }
    var height: CGFloat { size.height }

    var isPhoneWidth: Bool { width <= 640 }
    var isShortLandscape: Bool { width > height && height <= 560 }
    var compact: Bool { width <= 640 || height <= 560 }
    /// Landscape-ish: home and results switch to two columns.
    var isWide: Bool { width > height * 1.05 }

    /// Portrait / landscape orientation, used for the start layout.
    var gridMode: GridMode { height > width * 1.15 ? .tall : .wide }

    /// Pick a grid whose shape matches the stage so the board fills nearly all
    /// of it. Total cells stay near 468 (same as the web 18x26 / 26x18 grids),
    /// therefore difficulty and the SPACE stat keep their meaning.
    func gridDimensions(available: CGSize) -> (cols: Int, rows: Int) {
        let pad = stagePad * 2
        let w = max(160, available.width - pad)
        let h = max(160, available.height - pad)
        let area = 468.0
        let ratio = Double(w / h)
        var c = Int(round(sqrt(area * ratio)))
        c = min(max(c, 12), 36)
        var r = Int(round(area / Double(c)))
        r = min(max(r, 12), 40)
        return (c, r)
    }

    // Board stage
    var stagePad: CGFloat { isShortLandscape ? 3 : (compact ? 4 : 8) }
    var stageRadius: CGFloat { isShortLandscape ? 14 : (compact ? 20 : 26) }

    // Game top bar: pause | score | best, then three stat chips
    var topBarHeight: CGFloat { isShortLandscape ? 38 : (compact ? 54 : 68) }
    var scoreFont: CGFloat { isShortLandscape ? 24 : (compact ? 36 : 46) }
    var bestFont: CGFloat { isShortLandscape ? 17 : (compact ? 19 : 23) }
    var statsHeight: CGFloat { isShortLandscape ? 32 : (compact ? 30 : 36) }
    var roundButton: CGFloat { isShortLandscape ? 34 : (compact ? 40 : 46) }

    var outerPadH: CGFloat { compact ? 12 : 22 }
    var outerPadTop: CGFloat { isShortLandscape ? 4 : (compact ? 2 : 12) }
    var outerPadBottom: CGFloat { isShortLandscape ? 4 : (compact ? 6 : 16) }
    var rowGap: CGFloat { isShortLandscape ? 6 : (compact ? 8 : 12) }
}
