// Snake Feast logo / App Icon generator (macOS, no dependencies).
//
// Build & run:
//   swiftc -O Design/generate_icon.swift -o /tmp/rs-icon-gen
//   /tmp/rs-icon-gen ReverseSnake/Assets.xcassets/AppIcon.appiconset/Icon-1024.png icon
//   /tmp/rs-icon-gen /tmp/SnakeFeast-Mark.png mark   // then sips -z 128/256/384 -> Logo.imageset
//
// Concept "S-Chase": two elements only.
//   - One continuous energy ribbon drawn with the game's right-angle moves,
//     shaped as an "S" (Snake / SNAKE FEAST). It rises from a dim, thin tail
//     (bottom-left) to a bright, thick head (top-right).
//   - One orange orb — the player — just ahead of the head. The chase is the
//     whole game; nothing else is drawn.
// Deep-navy gradient backdrop, no grid / eyes / crystals / reticles.
// 1024x1024, opaque (App Store rejects icons with alpha), no rounded corners
// (iOS applies the icon mask; SwiftUI clips the header logo).
//
// "mark" is the identical artwork, slightly enlarged, for the ~26pt header logo.

import AppKit
import CoreGraphics
import Foundation

let S: CGFloat = 1024
let cs = CGColorSpaceCreateDeviceRGB()
let args = CommandLine.arguments
let out = args.count > 1 ? args[1] : "SnakeFeast-Icon.png"
let mode = args.count > 2 ? args[2] : "icon"   // "icon" | "mark"

guard let ctx = CGContext(data: nil, width: Int(S), height: Int(S),
                          bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                          bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
    fatalError("Unable to create bitmap context")
}
// UIKit-style top-left origin, y increasing downwards.
ctx.translateBy(x: 0, y: S)
ctx.scaleBy(x: 1, y: -1)

// MARK: - Helpers

func rgba(_ h: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: cs, components: [CGFloat((h >> 16) & 255) / 255,
                                         CGFloat((h >> 8) & 255) / 255,
                                         CGFloat(h & 255) / 255, a])!
}

func mix(_ x: CGColor, _ y: CGColor, _ t: CGFloat) -> CGColor {
    let p = x.components!, q = y.components!
    return CGColor(colorSpace: cs, components: (0..<4).map { p[$0] + (q[$0] - p[$0]) * t })!
}

func gradient(_ stops: [(CGFloat, CGColor)]) -> CGGradient {
    CGGradient(colorsSpace: cs, colors: stops.map { $0.1 } as CFArray, locations: stops.map { $0.0 })!
}

func glow(_ c: CGPoint, _ r: CGFloat, _ hex: UInt32, _ a: CGFloat) {
    ctx.drawRadialGradient(gradient([(0, rgba(hex, a)), (1, rgba(hex, 0))]),
                           startCenter: c, startRadius: 0, endCenter: c, endRadius: r, options: [])
}

/// Dense polyline through axis-aligned way-points with rounded corners
/// (quadratic corners), so the ribbon can be shaded along its length.
func roundedPolyline(_ p: [CGPoint], radius r: CGFloat) -> [CGPoint] {
    func unit(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        let l = hypot(b.x - a.x, b.y - a.y)
        return CGPoint(x: (b.x - a.x) / l, y: (b.y - a.y) / l)
    }
    func line(_ a: CGPoint, _ b: CGPoint) -> [CGPoint] {
        let n = max(2, Int(hypot(b.x - a.x, b.y - a.y) / 2))
        return (0...n).map {
            let t = CGFloat($0) / CGFloat(n)
            return CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
        }
    }
    func quad(_ a: CGPoint, _ c: CGPoint, _ b: CGPoint) -> [CGPoint] {
        (0...90).map { i in
            let t = CGFloat(i) / 90, u = 1 - t
            return CGPoint(x: u * u * a.x + 2 * u * t * c.x + t * t * b.x,
                           y: u * u * a.y + 2 * u * t * c.y + t * t * b.y)
        }
    }
    var pts: [CGPoint] = [], cur = p[0]
    for i in 1..<(p.count - 1) {
        let d1 = unit(p[i - 1], p[i]), d2 = unit(p[i], p[i + 1])
        let s = CGPoint(x: p[i].x - d1.x * r, y: p[i].y - d1.y * r)
        let e = CGPoint(x: p[i].x + d2.x * r, y: p[i].y + d2.y * r)
        pts += line(cur, s); pts += quad(s, p[i], e); cur = e
    }
    return pts + line(cur, p[p.count - 1])
}

// MARK: - Backdrop: deep navy, lit from above

ctx.drawLinearGradient(gradient([(0, rgba(0x1A2747)), (1, rgba(0x05080F))]),
                       start: CGPoint(x: 512, y: 0), end: CGPoint(x: 512, y: S), options: [])
glow(CGPoint(x: 512, y: 470), 640, 0x2A6BFF, 0.10)

// The header mark is the same artwork, slightly enlarged for ~26pt.
if mode == "mark" {
    ctx.translateBy(x: 512, y: 512)
    ctx.scaleBy(x: 1.14, y: 1.14)
    ctx.translateBy(x: -512, y: -512)
}

// MARK: - Prey: the orange player orb

let prey = CGPoint(x: 730, y: 338)
let orbR: CGFloat = 72
glow(prey, orbR * 3.2, 0xFF8A3D, 0.35)
ctx.saveGState()
ctx.addEllipse(in: CGRect(x: prey.x - orbR, y: prey.y - orbR, width: orbR * 2, height: orbR * 2))
ctx.clip()
ctx.drawLinearGradient(gradient([(0, rgba(0xFFC48A)), (1, rgba(0xFF6F24))]),
                       start: CGPoint(x: prey.x - orbR * 0.6, y: prey.y - orbR),
                       end: CGPoint(x: prey.x + orbR * 0.6, y: prey.y + orbR), options: [])
ctx.restoreGState()

// MARK: - Snake: one S-shaped energy ribbon, tail (bottom-left) -> head (top-right)

let spine = roundedPolyline([
    CGPoint(x: 294, y: 714), CGPoint(x: 670, y: 714),
    CGPoint(x: 670, y: 526), CGPoint(x: 282, y: 526),
    CGPoint(x: 282, y: 338), CGPoint(x: 560, y: 338)
], radius: 94)

let tailC = rgba(0x10345E), midC = rgba(0x1F8FE0), headC = rgba(0x8FF0FF)
let tailW: CGFloat = 30, headW: CGFloat = 104

ctx.saveGState()
ctx.setShadow(offset: .zero, blur: 46, color: rgba(0x38C8FF, 0.45))
ctx.beginTransparencyLayer(auxiliaryInfo: nil)
ctx.setLineCap(.round)
let n = spine.count
for i in 0..<(n - 1) {
    let t = CGFloat(i) / CGFloat(n - 1)
    ctx.setStrokeColor(t < 0.6 ? mix(tailC, midC, t / 0.6) : mix(midC, headC, (t - 0.6) / 0.4))
    ctx.setLineWidth(tailW + (headW - tailW) * pow(t, 0.7))
    ctx.beginPath()
    ctx.move(to: spine[i])
    ctx.addLine(to: spine[i + 1])
    ctx.strokePath()
}
ctx.endTransparencyLayer()
ctx.restoreGState()

// MARK: - Export

guard let image = ctx.makeImage(),
      let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
    fatalError("Unable to encode PNG")
}
try data.write(to: URL(fileURLWithPath: out))
print("wrote \(out) (\(mode))")
