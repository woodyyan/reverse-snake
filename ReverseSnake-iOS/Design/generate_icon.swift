// Reverse Snake logo / App Icon generator (macOS, no dependencies).
//
// Build & run:
//   swiftc -O Design/generate_icon.swift -o /tmp/rs-icon-gen
//   /tmp/rs-icon-gen /tmp/ReverseSnake-Icon.png icon   // full AppIcon artwork
//   /tmp/rs-icon-gen /tmp/ReverseSnake-Mark.png mark   // compact header logo
//
// The artwork mirrors the in-game palette: an orange player dot fleeing a
// cyan energy snake on a deep-space precision grid. 1024x1024, opaque,
// no rounded corners (iOS applies the icon mask, SwiftUI clips the header logo).
//
// "mark" drops the grid / reticles / crystal and enlarges the emblem, so the
// logo stays legible at ~26pt in the top-left of the game HUD.

import AppKit
import CoreGraphics
import Foundation

let S: CGFloat = 1024
let colorSpace = CGColorSpaceCreateDeviceRGB()
let args = CommandLine.arguments
let out = args.count > 1 ? args[1] : "ReverseSnake-Icon.png"
let mode = args.count > 2 ? args[2] : "icon"   // "icon" | "mark"

guard let ctx = CGContext(data: nil,
                          width: Int(S), height: Int(S),
                          bitsPerComponent: 8, bytesPerRow: 0,
                          space: colorSpace,
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
    fatalError("Unable to create bitmap context")
}

// UIKit-style top-left origin, y increasing downwards (same as the game canvas).
ctx.translateBy(x: 0, y: S)
ctx.scaleBy(x: 1, y: -1)

func rgba(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: colorSpace,
            components: [CGFloat((hex >> 16) & 0xFF) / 255,
                         CGFloat((hex >> 8) & 0xFF) / 255,
                         CGFloat(hex & 0xFF) / 255,
                         a])!
}

func mix(_ a: CGColor, _ b: CGColor, _ t: CGFloat) -> CGColor {
    let ca = a.components!, cb = b.components!
    return CGColor(colorSpace: colorSpace,
                   components: [ca[0] + (cb[0] - ca[0]) * t,
                                ca[1] + (cb[1] - ca[1]) * t,
                                ca[2] + (cb[2] - ca[2]) * t,
                                1])!
}

func fillRect(_ r: CGRect, _ c: CGColor) {
    ctx.setFillColor(c)
    ctx.fill(r)
}

func roundPath(_ r: CGRect, _ radius: CGFloat) {
    ctx.addPath(CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: nil))
}

func fillRound(_ r: CGRect, _ radius: CGFloat, _ c: CGColor) {
    ctx.beginPath()
    roundPath(r, radius)
    ctx.setFillColor(c)
    ctx.fillPath()
}

func strokeRound(_ r: CGRect, _ radius: CGFloat, _ c: CGColor, _ width: CGFloat) {
    ctx.beginPath()
    roundPath(r, radius)
    ctx.setStrokeColor(c)
    ctx.setLineWidth(width)
    ctx.strokePath()
}

func fillCircle(_ center: CGPoint, _ radius: CGFloat, _ c: CGColor) {
    ctx.beginPath()
    ctx.addArc(center: center, radius: radius, startAngle: 0,
               endAngle: 2 * CGFloat.pi, clockwise: false)
    ctx.setFillColor(c)
    ctx.fillPath()
}

func radial(_ center: CGPoint, _ r0: CGFloat, _ r1: CGFloat,
            _ stops: [(CGFloat, CGColor)], _ rect: CGRect) {
    let colors = stops.map { $0.1 } as CFArray
    let locations = stops.map { $0.0 }
    guard let g = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations) else { return }
    ctx.saveGState()
    ctx.addRect(rect)
    ctx.clip()
    ctx.drawRadialGradient(g, startCenter: center, startRadius: r0,
                           endCenter: center, endRadius: r1,
                           options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    ctx.restoreGState()
}

// MARK: - Backdrop

radial(CGPoint(x: S * 0.5, y: S * 0.42), 40, S * 0.82,
       [(0, rgba(0x12223C)), (0.6, rgba(0x0A1426)), (1, rgba(0x050A14))],
       CGRect(x: 0, y: 0, width: S, height: S))

if mode == "icon" {
    // Precision grid (major tick every 256)
    for i in 1..<8 {
        let p = CGFloat(i) * 128
        let major = i % 2 == 0
        ctx.setStrokeColor(rgba(0x6EAFFF, major ? 0.13 : 0.055))
        ctx.setLineWidth(major ? 3 : 2)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: p + 1, y: 0))
        ctx.addLine(to: CGPoint(x: p + 1, y: S))
        ctx.strokePath()
        ctx.beginPath()
        ctx.move(to: CGPoint(x: 0, y: p + 1))
        ctx.addLine(to: CGPoint(x: S, y: p + 1))
        ctx.strokePath()
    }

    // Corner reticles
    let off: CGFloat = 56, L: CGFloat = 92
    ctx.setStrokeColor(rgba(0x7DC8FF, 0.38))
    ctx.setLineWidth(6)
    ctx.beginPath()
    for c in [(off, off, 1, 1), (S - off, off, -1, 1),
              (off, S - off, 1, -1), (S - off, S - off, -1, -1)] {
        ctx.move(to: CGPoint(x: c.0, y: c.1 + CGFloat(c.3) * L))
        ctx.addLine(to: CGPoint(x: c.0, y: c.1))
        ctx.addLine(to: CGPoint(x: c.0 + CGFloat(c.2) * L, y: c.1))
    }
    ctx.strokePath()

    // Target crystal accent (bottom right)
    let crystal = CGPoint(x: 846, y: 846)
    radial(crystal, 4, 96,
           [(0, rgba(0x3DFFC0, 0.24)), (1, rgba(0x3DFFC0, 0))],
           CGRect(x: 750, y: 750, width: 192, height: 192))
    ctx.saveGState()
    ctx.translateBy(x: crystal.x, y: crystal.y)
    ctx.rotate(by: CGFloat.pi / 4)
    let s: CGFloat = 42
    fillRound(CGRect(x: -s, y: -s, width: s * 2, height: s * 2), 10, rgba(0x3DFFC0))
    fillRect(CGRect(x: -s * 0.24, y: -s * 0.24, width: s * 0.48, height: s * 0.48),
             rgba(0xFFFFFF, 0.92))
    ctx.restoreGState()
} else {
    // A whisper of structure for the compact mark — no reticles, no crystal.
    ctx.setStrokeColor(rgba(0x6EAFFF, 0.055))
    ctx.setLineWidth(3)
    ctx.beginPath()
    for i in 1..<4 {
        let p = CGFloat(i) * 256
        ctx.move(to: CGPoint(x: p, y: 0)); ctx.addLine(to: CGPoint(x: p, y: S))
        ctx.move(to: CGPoint(x: 0, y: p)); ctx.addLine(to: CGPoint(x: S, y: p))
    }
    ctx.strokePath()
}

// MARK: - Emblem: player fleeing the snake (shared by both variants)

func drawEmblem() {
    let player = CGPoint(x: 232, y: 512)
    radial(player, 10, 270,
           [(0, rgba(0xFF9A4D, 0.34)), (1, rgba(0xFF9A4D, 0))],
           CGRect(x: 0, y: 240, width: 480, height: 544))

    ctx.saveGState()
    ctx.setLineDash(phase: 0, lengths: [22, 20])
    ctx.setStrokeColor(rgba(0xFFBE82, 0.85))
    ctx.setLineWidth(8)
    ctx.beginPath()
    ctx.addArc(center: player, radius: 112, startAngle: 0,
               endAngle: 2 * CGFloat.pi, clockwise: false)
    ctx.strokePath()
    ctx.setLineDash(phase: 0, lengths: [])
    ctx.restoreGState()

    fillCircle(player, 76, rgba(0xFF9A4D))
    fillCircle(player, 32, rgba(0xFFFFFF))

    let dark = rgba(0x0A2A55)
    let bright = rgba(0x5AD8FF)
    let body: [(CGFloat, CGFloat)] = [(520, 0.72), (670, 0.42), (820, 0.16)]
    let seg: CGFloat = 130, y: CGFloat = 447, corner: CGFloat = 34

    for (x, t) in body {
        let r = CGRect(x: x, y: y, width: seg, height: seg)
        fillRound(r, corner, mix(dark, bright, t))
        fillRound(CGRect(x: x + 18, y: y + 14, width: 40, height: 22), 8,
                  rgba(0xBEF0FF, 0.06 + 0.14 * t))
        strokeRound(r, corner, rgba(0x78DCFF, 0.10 + 0.22 * t), 3)
    }

    // Head: faces left (toward the player). A small pointed snout plus a single
    // horizontal scan-eye reads as a direction, not a dice face.
    let head = CGRect(x: 370, y: y, width: seg, height: seg)
    radial(CGPoint(x: head.midX, y: head.midY), 4, 190,
           [(0, rgba(0x7DF3FF, 0.30)), (1, rgba(0x7DF3FF, 0))],
           head.insetBy(dx: -130, dy: -130))

    ctx.saveGState()
    ctx.beginPath()
    ctx.move(to: CGPoint(x: 328, y: 512))
    ctx.addLine(to: CGPoint(x: 398, y: 470))
    ctx.addLine(to: CGPoint(x: 398, y: 554))
    ctx.closePath()
    ctx.setFillColor(rgba(0x7DE9FF))
    ctx.fillPath()
    ctx.restoreGState()

    fillRound(head, corner, rgba(0x0C3358))
    strokeRound(head, corner, rgba(0x8DF6FF), 7)
    fillRound(CGRect(x: 404, y: 503, width: 62, height: 18), 9, rgba(0xDDFBFF))
}

// Compact square mark: only the two lead actors (player dot + snake head),
// enlarged so they stay readable at ~26pt in the HUD header.
func drawCompactMark() {
    let player = CGPoint(x: 266, y: 512)
    radial(player, 10, 400,
           [(0, rgba(0xFF9A4D, 0.36)), (1, rgba(0xFF9A4D, 0))],
           CGRect(x: 0, y: 60, width: 700, height: 900))

    ctx.saveGState()
    ctx.setLineDash(phase: 0, lengths: [42, 34])
    ctx.setStrokeColor(rgba(0xFFBE82, 0.90))
    ctx.setLineWidth(16)
    ctx.beginPath()
    ctx.addArc(center: player, radius: 214, startAngle: 0,
               endAngle: 2 * CGFloat.pi, clockwise: false)
    ctx.strokePath()
    ctx.restoreGState()

    fillCircle(player, 154, rgba(0xFF9A4D))
    fillCircle(player, 64, rgba(0xFFFFFF))

    // A single dim vertebra behind the head hints at the snake body.
    fillRound(CGRect(x: 866, y: 372, width: 118, height: 280), 36, rgba(0x1B4E7A))
    strokeRound(CGRect(x: 866, y: 372, width: 118, height: 280), 36,
                rgba(0x78DCFF, 0.20), 4)

    let head = CGRect(x: 546, y: 362, width: 300, height: 300)
    radial(CGPoint(x: head.midX, y: head.midY), 4, 300,
           [(0, rgba(0x7DF3FF, 0.30)), (1, rgba(0x7DF3FF, 0))],
           head.insetBy(dx: -150, dy: -150))

    // Pointed snout facing left, toward the player.
    ctx.saveGState()
    ctx.beginPath()
    ctx.move(to: CGPoint(x: 496, y: 512))
    ctx.addLine(to: CGPoint(x: 580, y: 442))
    ctx.addLine(to: CGPoint(x: 580, y: 582))
    ctx.closePath()
    ctx.setFillColor(rgba(0x7DE9FF))
    ctx.fillPath()
    ctx.restoreGState()

    fillRound(head, 76, rgba(0x0C3358))
    strokeRound(head, 76, rgba(0x8DF6FF), 14)
    fillRound(CGRect(x: 608, y: 490, width: 168, height: 44), 22, rgba(0xDDFBFF))
}

if mode == "mark" {
    drawCompactMark()
} else {
    drawEmblem()
}

// MARK: - Export

guard let image = ctx.makeImage() else { fatalError("Unable to make image") }
let rep = NSBitmapImageRep(cgImage: image)
guard let data = rep.representation(using: .png, properties: [:]) else {
    fatalError("Unable to encode PNG")
}
try data.write(to: URL(fileURLWithPath: out))
print("wrote \(out) (\(mode))")
