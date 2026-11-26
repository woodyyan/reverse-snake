// Snake Feast App Icon generator (macOS, no dependencies).
//
// Build & run (from ReverseSnake-iOS/):
//   swiftc -O Design/generate_icon.swift -o /tmp/sf-icon-gen
//   /tmp/sf-icon-gen ReverseSnake/Assets.xcassets/AppIcon.appiconset/Icon-1024.png        icon
//   /tmp/sf-icon-gen ReverseSnake/Assets.xcassets/AppIcon.appiconset/Icon-1024-Dark.png   dark
//   /tmp/sf-icon-gen ReverseSnake/Assets.xcassets/AppIcon.appiconset/Icon-1024-Tinted.png tinted
//   then: sips -z 128/256/384 Icon-1024.png -> Logo.imageset (home brand mark)
//
// Concept "S-Evolve" (design proposal v2, icon I3): two elements only.
//   - One continuous snake drawn with the game's right-angle moves, shaped as
//     an "S". Thin, dark tail (bottom-left) -> thick, bright head (top-right).
//     Flat: no outer glow, matching the in-game tube snake.
//   - One orange orb — the player — just ahead of the head, with a soft halo.
// Palette = Nocturne theme: snake #0F2C45 -> #5CC8FF, player #FF7A2F.
// 1024x1024, opaque (App Store rejects alpha), square (iOS applies the mask).
//
// Variants for iOS 18+ home-screen appearances:
//   icon    default
//   dark    deeper, near-black backdrop
//   tinted  grayscale artwork on black; iOS colourises it with the user's tint

import AppKit
import CoreGraphics
import Foundation

let S: CGFloat = 1024
let cs = CGColorSpaceCreateDeviceRGB()
let args = CommandLine.arguments
let out = args.count > 1 ? args[1] : "SnakeFeast-Icon.png"
let mode = args.count > 2 ? args[2] : "icon"   // "icon" | "dark" | "tinted"

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

func glow(_ c: CGPoint, _ r: CGFloat, _ color: CGColor, _ a: CGFloat) {
    ctx.drawRadialGradient(gradient([(0, color.copy(alpha: a)!), (1, color.copy(alpha: 0)!)]),
                           startCenter: c, startRadius: 0, endCenter: c, endRadius: r, options: [])
}

/// Dense polyline through axis-aligned way-points with rounded (quadratic)
/// corners, so the snake can be shaded and tapered along its length.
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

// MARK: - Palette per variant

struct Look {
    let bgTop: CGColor, bgBottom: CGColor
    let tail: CGColor, head: CGColor
    let orb: CGColor, orbHi: CGColor
    let halo: CGFloat
}

let look: Look
switch mode {
case "dark":
    look = Look(bgTop: rgba(0x0D1118), bgBottom: rgba(0x000000),
                tail: rgba(0x0F2C45), head: rgba(0x5CC8FF),
                orb: rgba(0xFF7A2F), orbHi: rgba(0xFFC08F), halo: 0.40)
case "tinted":
    look = Look(bgTop: rgba(0x1B1B1D), bgBottom: rgba(0x0A0A0B),
                tail: rgba(0x3A3A3E), head: rgba(0xE9E9EE),
                orb: rgba(0xBDBDC4), orbHi: rgba(0xFFFFFF), halo: 0.25)
default:
    look = Look(bgTop: rgba(0x1A2130), bgBottom: rgba(0x06080D),
                tail: rgba(0x0F2C45), head: rgba(0x5CC8FF),
                orb: rgba(0xFF7A2F), orbHi: rgba(0xFFC08F), halo: 0.45)
}

// MARK: - Backdrop

ctx.drawLinearGradient(gradient([(0, look.bgTop), (1, look.bgBottom)]),
                       start: CGPoint(x: 512, y: 0), end: CGPoint(x: 512, y: S), options: [])

// MARK: - Snake: flat S, tail (bottom-left) -> head (top-right)

let spine = roundedPolyline([
    CGPoint(x: 300, y: 742), CGPoint(x: 660, y: 742),
    CGPoint(x: 660, y: 516), CGPoint(x: 350, y: 516),
    CGPoint(x: 350, y: 290), CGPoint(x: 566, y: 290)
], radius: 104)

let tailW: CGFloat = 62, headW: CGFloat = 124
ctx.setLineCap(.round)
let n = spine.count
for i in 0..<(n - 1) {
    let t = CGFloat(i) / CGFloat(n - 1)
    ctx.setStrokeColor(mix(look.tail, look.head, pow(t, 0.9)))
    ctx.setLineWidth(tailW + (headW - tailW) * t)
    ctx.beginPath()
    ctx.move(to: spine[i])
    ctx.addLine(to: spine[i + 1])
    ctx.strokePath()
}

// MARK: - Player orb: halo + radial core with highlight

let prey = CGPoint(x: 742, y: 290)
let orbR: CGFloat = 78
glow(prey, orbR * 2.4, look.orb, look.halo)
ctx.saveGState()
ctx.addEllipse(in: CGRect(x: prey.x - orbR, y: prey.y - orbR, width: orbR * 2, height: orbR * 2))
ctx.clip()
let hi = CGPoint(x: prey.x - orbR * 0.24, y: prey.y - orbR * 0.30)
ctx.drawRadialGradient(gradient([(0, look.orbHi), (0.45, look.orb), (1, look.orb)]),
                       startCenter: hi, startRadius: 0, endCenter: hi, endRadius: orbR * 1.4,
                       options: [.drawsAfterEndLocation])
ctx.restoreGState()

// MARK: - Export

guard let image = ctx.makeImage(),
      let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
    fatalError("Unable to encode PNG")
}
try data.write(to: URL(fileURLWithPath: out))
print("wrote \(out) (\(mode))")
