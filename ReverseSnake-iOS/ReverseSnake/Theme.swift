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
}

// MARK: - Palette (mirrors index.html :root and the canvas palette)

enum Theme {
    static let bg = Color(hex: 0xFAFAFA)
    static let card = Color.white
    static let line = Color(hex: 0xE6EAF0)
    static let ink = Color(hex: 0x111827)
    static let ink2 = Color(hex: 0x5B6577)
    static let blue = Color(hex: 0x1D4ED8)
    static let cyan = Color(hex: 0x3FC8FF)
    static let orange = Color(hex: 0xFF9A4D)
    static let green = Color(hex: 0x3DFFC0)
    static let red = Color(hex: 0xE5484D)
    static let danger = Color(hex: 0xFF5C6E)

    static let hudTop = Color(hex: 0x0D1728)
    static let hudBottom = Color(hex: 0x080E1B)
    static let hudBorder = Color(hex: 0x1E3452)
    static let hudLabel = Color(hex: 0x7189AC)
    static let hudValue = Color(hex: 0xEAF4FF)

    static let stage = Color(hex: 0x070C17)
    static let stageBorder = Color(hex: 0x1B2A44)
}

// MARK: - Responsive layout metrics
// Equivalent of the CSS media queries in index.html, driven by the actual
// safe-area size so iPhone / iPad / portrait / landscape / Split View all work.

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

    /// Portrait / landscape orientation, used for the start layout.
    var gridMode: GridMode { height > width * 1.15 ? .tall : .wide }

    /// Pick a grid whose shape matches the stage so the board fills nearly all
    /// of it. Total cells stay near 468 (same as the web 18x26 / 26x18 grids),
    /// therefore difficulty and HUD "SPACE" semantics are preserved.
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

    var hudHeight: CGFloat { isShortLandscape ? 40 : (compact ? 44 : 73) }
    var hudRadius: CGFloat { compact ? 9 : 10 }
    var stagePad: CGFloat { isShortLandscape ? 4 : (compact ? 5 : 12) }
    var stageRadius: CGFloat { isShortLandscape ? 10 : (compact ? 12 : 16) }

    var kpiLabel: CGFloat { isShortLandscape ? 8 : (compact ? 7 : 9) }
    var kpiValue: CGFloat { compact ? 14 : 23 }
    var kpiScore: CGFloat { isShortLandscape ? 18 : (compact ? 19 : 34) }
    var kpiWeights: [CGFloat] { compact ? [1, 1, 1, 1, 1] : [1.25, 0.9, 1, 1, 1.1] }

    var brandSize: CGFloat { isShortLandscape ? 14 : (compact ? 16 : 22) }
    var logoSize: CGFloat { isShortLandscape ? 20 : (compact ? 26 : 34) }
    var buttonFont: CGFloat { isShortLandscape ? 10 : (compact ? 11 : 13) }
    var buttonPadV: CGFloat { isShortLandscape ? 4 : (compact ? 6 : 8) }
    var buttonPadH: CGFloat { isShortLandscape ? 8 : (compact ? 9 : 13) }

    // No bottom controls anymore: keep the chrome minimal so the board can
    // use all remaining vertical space.
    var outerPadH: CGFloat { compact ? 8 : 16 }
    var outerPadTop: CGFloat { isShortLandscape ? 6 : (compact ? 8 : 16) }
    var outerPadBottom: CGFloat { isShortLandscape ? 6 : (compact ? 8 : 12) }
    var headerGap: CGFloat { isShortLandscape ? 5 : (compact ? 6 : 10) }
    var hudGap: CGFloat { isShortLandscape ? 5 : (compact ? 6 : 8) }
}
