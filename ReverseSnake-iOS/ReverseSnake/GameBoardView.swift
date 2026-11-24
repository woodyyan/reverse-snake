import SwiftUI
import UIKit

// MARK: - Core Graphics helpers (Canvas 2D equivalents)

private func radialFill(_ ctx: CGContext,
                        center: CGPoint, r0: CGFloat, r1: CGFloat,
                        stops: [(CGFloat, UIColor)], rect: CGRect) {
    let colors = stops.map { $0.1.cgColor } as CFArray
    let locations = stops.map { $0.0 }
    guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                    colors: colors, locations: locations) else { return }
    ctx.saveGState()
    ctx.addRect(rect)
    ctx.clip()
    // Canvas 2D fills the area inside r0 with the first stop and beyond r1
    // with the last stop; CGGradient needs both options to behave the same.
    ctx.drawRadialGradient(gradient,
                           startCenter: center, startRadius: max(0, r0),
                           endCenter: center, endRadius: max(r0 + 0.01, r1),
                           options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    ctx.restoreGState()
}

private func linearFill(_ ctx: CGContext,
                        from: CGPoint, to: CGPoint,
                        stops: [(CGFloat, UIColor)], rect: CGRect) {
    let colors = stops.map { $0.1.cgColor } as CFArray
    let locations = stops.map { $0.0 }
    guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                    colors: colors, locations: locations) else { return }
    ctx.saveGState()
    ctx.addRect(rect)
    ctx.clip()
    ctx.drawLinearGradient(gradient, start: from, end: to, options: [])
    ctx.restoreGState()
}

private func addRoundRect(_ ctx: CGContext, _ rect: CGRect, _ r: CGFloat) {
    ctx.addPath(UIBezierPath(roundedRect: rect, cornerRadius: r).cgPath)
}

private func fillRoundRect(_ ctx: CGContext, _ rect: CGRect, _ r: CGFloat, _ color: UIColor) {
    ctx.beginPath()
    addRoundRect(ctx, rect, r)
    ctx.setFillColor(color.cgColor)
    ctx.fillPath()
}

private func strokeRoundRect(_ ctx: CGContext, _ rect: CGRect, _ r: CGFloat, _ color: UIColor, _ width: CGFloat) {
    ctx.beginPath()
    addRoundRect(ctx, rect, r)
    ctx.setStrokeColor(color.cgColor)
    ctx.setLineWidth(width)
    ctx.strokePath()
}

private func fillCircle(_ ctx: CGContext, _ center: CGPoint, _ r: CGFloat, _ color: UIColor) {
    ctx.beginPath()
    ctx.addArc(center: center, radius: r, startAngle: 0, endAngle: 2 * CGFloat.pi, clockwise: false)
    ctx.setFillColor(color.cgColor)
    ctx.fillPath()
}

private func textSize(_ text: String, _ font: UIFont) -> CGSize {
    (text as NSString).size(withAttributes: [.font: font])
}

private func drawText(_ text: String, at point: CGPoint, font: UIFont, color: UIColor) {
    (text as NSString).draw(at: point, withAttributes: [.font: font, .foregroundColor: color])
}

/// Rotating dashed ring, radius .40 cell — all marks stay inside one cell.
private func inCellRing(_ ctx: CGContext, cx: CGFloat, cy: CGFloat,
                        color: UIColor, phase: Double, cell: CGFloat) {
    ctx.saveGState()
    ctx.translateBy(x: cx, y: cy)
    ctx.rotate(by: CGFloat(phase))
    ctx.setLineDash(phase: 0, lengths: [cell * 0.10, cell * 0.09])
    ctx.setStrokeColor(color.cgColor)
    ctx.setLineWidth(1.2)
    ctx.beginPath()
    ctx.addArc(center: .zero, radius: cell * 0.40,
               startAngle: 0, endAngle: 2 * CGFloat.pi, clockwise: false)
    ctx.strokePath()
    ctx.setLineDash(phase: 0, lengths: [])
    ctx.restoreGState()
}

private func inCellBrackets(_ ctx: CGContext, cx: CGFloat, cy: CGFloat,
                            color: UIColor, width: CGFloat, cell: CGFloat) {
    let inset = cell * 0.40, tick = cell * 0.09
    ctx.setStrokeColor(color.cgColor)
    ctx.setLineWidth(width)
    ctx.beginPath()
    for c in [(-1, -1), (1, -1), (-1, 1), (1, 1)] {
        let bx = cx + CGFloat(c.0) * inset
        let by = cy + CGFloat(c.1) * inset
        ctx.move(to: CGPoint(x: bx - CGFloat(c.0) * tick, y: by))
        ctx.addLine(to: CGPoint(x: bx, y: by))
        ctx.addLine(to: CGPoint(x: bx, y: by - CGFloat(c.1) * tick))
    }
    ctx.strokePath()
}

// MARK: - Renderer: 1:1 port of render() in index.html

enum BoardRenderer {
    static func draw(_ ctx: CGContext, engine: GameEngine,
                     cols: Int, rows: Int, cell: CGFloat) {
        let W = CGFloat(cols) * cell
        let H = CGFloat(rows) * cell
        let board = CGRect(x: 0, y: 0, width: W, height: H)
        let t = engine.renderTime                 // ms, same clock as rAF

        ctx.clear(board)

        // Deep-space backdrop + cold centre light
        radialFill(ctx,
                   center: CGPoint(x: W * 0.5, y: H * 0.42),
                   r0: W * 0.04, r1: W * 0.80,
                   stops: [(0, UIColor(hex: 0x12223C)),
                           (0.6, UIColor(hex: 0x0A1426)),
                           (1, UIColor(hex: 0x050A14))],
                   rect: board)

        // Precision grid: a major tick every 5 cells
        ctx.setLineWidth(1)
        for x in 1..<cols {
            let major = x % 5 == 0
            ctx.setStrokeColor(UIColor(hex: 0x6EAFFF, alpha: major ? 0.13 : 0.055).cgColor)
            let px = CGFloat(x) * cell + 0.5
            ctx.beginPath()
            ctx.move(to: CGPoint(x: px, y: 0))
            ctx.addLine(to: CGPoint(x: px, y: H))
            ctx.strokePath()
        }
        for y in 1..<rows {
            let major = y % 5 == 0
            ctx.setStrokeColor(UIColor(hex: 0x6EAFFF, alpha: major ? 0.13 : 0.055).cgColor)
            let py = CGFloat(y) * cell + 0.5
            ctx.beginPath()
            ctx.move(to: CGPoint(x: 0, y: py))
            ctx.addLine(to: CGPoint(x: W, y: py))
            ctx.strokePath()
        }

        // Slow scanning band
        let period = H + 120
        let scanY = CGFloat(t * 0.032).truncatingRemainder(dividingBy: period) - 60
        linearFill(ctx,
                   from: CGPoint(x: 0, y: scanY - 34),
                   to: CGPoint(x: 0, y: scanY + 34),
                   stops: [(0, UIColor(hex: 0x5ABEFF, alpha: 0)),
                           (0.5, UIColor(hex: 0x5ABEFF, alpha: 0.055)),
                           (1, UIColor(hex: 0x5ABEFF, alpha: 0))],
                   rect: CGRect(x: 0, y: scanY - 34, width: W, height: 68))

        // Corner reticles + coordinate plate
        let L = cell * 1.15, off: CGFloat = 6
        ctx.setStrokeColor(UIColor(hex: 0x7DC8FF, alpha: 0.38).cgColor)
        ctx.setLineWidth(1.4)
        ctx.beginPath()
        for c in [(off, off, 1, 1), (W - off, off, -1, 1),
                  (off, H - off, 1, -1), (W - off, H - off, -1, -1)] {
            ctx.move(to: CGPoint(x: c.0, y: c.1 + CGFloat(c.3) * L))
            ctx.addLine(to: CGPoint(x: c.0, y: c.1))
            ctx.addLine(to: CGPoint(x: c.0 + CGFloat(c.2) * L, y: c.1))
        }
        ctx.strokePath()

        let plateFont = UIFont.monospacedSystemFont(ofSize: max(8, round(cell * 0.30)), weight: .semibold)
        let plate = String(format: L10n.s(L10n.K.boardGrid), cols, rows)
        let plateSize = textSize(plate, plateFont)
        drawText(plate,
                 at: CGPoint(x: W - 12 - plateSize.width, y: 10),
                 font: plateFont, color: UIColor(hex: 0x8CB9EB, alpha: 0.34))

        // Edge threat glow when the head is within 3 cells
        let dhead = engine.dist(engine.snake[0], engine.player)
        if engine.phase == .running && dhead <= 3 {
            let a = CGFloat(Double(4 - dhead) / 4 * 0.20 * (0.75 + 0.25 * sin(t / 130)))
            radialFill(ctx,
                       center: CGPoint(x: W / 2, y: H / 2),
                       r0: W * 0.28, r1: W * 0.74,
                       stops: [(0, UIColor(hex: 0xFF465A, alpha: 0)),
                               (1, UIColor(hex: 0xFF465A, alpha: a))],
                       rect: board)
        }

        // Target crystal: cell-locked ring + brackets + rotating diamond
        if let dot = engine.dot {
            let cx = (CGFloat(dot.x) + 0.5) * cell
            let cy = (CGFloat(dot.y) + 0.5) * cell
            let pulse = 0.5 + 0.5 * sin(t / 240)
            radialFill(ctx, center: CGPoint(x: cx, y: cy),
                       r0: cell * 0.04, r1: cell * 0.48,
                       stops: [(0, UIColor(hex: 0x3DFFC0, alpha: 0.22 + CGFloat(pulse) * 0.18)),
                               (1, UIColor(hex: 0x3DFFC0, alpha: 0))],
                       rect: CGRect(x: cx - cell * 0.5, y: cy - cell * 0.5,
                                    width: cell, height: cell))
            inCellRing(ctx, cx: cx, cy: cy,
                       color: UIColor(hex: 0x3DFFC0, alpha: 0.45 + CGFloat(pulse) * 0.35),
                       phase: t / 1600, cell: cell)
            inCellBrackets(ctx, cx: cx, cy: cy,
                           color: UIColor(hex: 0x3DFFC0, alpha: 0.75),
                           width: 1.2, cell: cell)

            ctx.saveGState()
            ctx.translateBy(x: cx, y: cy)
            ctx.rotate(by: CGFloat(Double.pi / 4 + t / 3000))
            let s = cell * 0.22 + CGFloat(pulse) * cell * 0.02
            let crystal = CGRect(x: -s, y: -s, width: s * 2, height: s * 2)
            fillRoundRect(ctx, crystal, cell * 0.06, UIColor(hex: 0x3DFFC0))
            strokeRoundRect(ctx, crystal, cell * 0.06, UIColor(hex: 0xDCFFF5, alpha: 0.9), 1)
            ctx.setFillColor(UIColor(hex: 0xFFFFFF, alpha: 0.92).cgColor)
            ctx.fill(CGRect(x: -s * 0.24, y: -s * 0.24, width: s * 0.48, height: s * 0.48))
            ctx.restoreGState()
        }

        // Snake: energy vertebrae, brightness flowing from tail to head
        let last = max(1, engine.snake.count - 1)
        if engine.snake.count > 1 {
            for i in stride(from: engine.snake.count - 1, through: 1, by: -1) {
                let ratio = 1 - Double(i) / Double(last)
                let flow = 0.5 + 0.5 * sin(t / 240 - Double(i) * 0.42)
                let mix = max(0, min(1, ratio * 0.95 + flow * 0.06))
                let col = UIColor.mix(UIColor(hex: 0x0A2A55), UIColor(hex: 0x5AD8FF), CGFloat(mix))
                let x0 = CGFloat(engine.snake[i].x) * cell
                let y0 = CGFloat(engine.snake[i].y) * cell
                let p = cell * 0.085
                let body = CGRect(x: x0 + p, y: y0 + p, width: cell - p * 2, height: cell - p * 2)
                fillRoundRect(ctx, body, cell * 0.27, col)
                fillRoundRect(ctx,
                              CGRect(x: x0 + p + cell * 0.10, y: y0 + p + cell * 0.07,
                                     width: cell * 0.22, height: cell * 0.13),
                              cell * 0.06,
                              UIColor(hex: 0xBEF0FF, alpha: 0.06 + CGFloat(ratio) * 0.13 + CGFloat(flow) * 0.05))
                strokeRoundRect(ctx, body, cell * 0.27,
                                UIColor(hex: 0x78DCFF, alpha: 0.10 + CGFloat(ratio) * 0.18), 1)
            }
        }

        // Snake head: glowing core + forward scanning bar
        let h = engine.snake[0]
        let pad = cell * 0.07
        let hx = CGFloat(h.x) * cell + pad, hy = CGFloat(h.y) * cell + pad
        let hs = cell - pad * 2
        let hc = (CGFloat(h.x) + 0.5) * cell, hcY = (CGFloat(h.y) + 0.5) * cell
        ctx.saveGState()
        radialFill(ctx, center: CGPoint(x: hc, y: hcY), r0: cell * 0.02, r1: cell * 0.48,
                   stops: [(0, UIColor(hex: 0x7DF3FF, alpha: 0.32)),
                           (1, UIColor(hex: 0x7DF3FF, alpha: 0))],
                   rect: CGRect(x: CGFloat(h.x) * cell, y: CGFloat(h.y) * cell,
                                width: cell, height: cell))
        let headRect = CGRect(x: hx, y: hy, width: hs, height: hs)
        fillRoundRect(ctx, headRect, cell * 0.28, UIColor(hex: 0x0C3358))
        strokeRoundRect(ctx, headRect, cell * 0.28, UIColor(hex: 0x8DF6FF), 1.6)
        let neck = engine.snake.count > 1 ? engine.snake[1] : GridPoint(x: h.x - 1, y: h.y)
        let fx = CGFloat(h.x - neck.x), fy = CGFloat(h.y - neck.y)
        let ex: CGFloat = fx != 0 ? -fy : 0
        let ey: CGFloat = fy != 0 ? -fx : 0
        ctx.setStrokeColor(UIColor(hex: 0x7DF3FF, alpha: 0.85).cgColor)
        ctx.setLineWidth(1.6)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: hc + fx * cell * 0.30 + ex * cell * 0.16,
                             y: hcY + fy * cell * 0.30 + ey * cell * 0.16))
        ctx.addLine(to: CGPoint(x: hc + fx * cell * 0.30 - ex * cell * 0.16,
                                y: hcY + fy * cell * 0.30 - ey * cell * 0.16))
        ctx.strokePath()
        for s in [-1, 1] {
            fillCircle(ctx,
                       CGPoint(x: hc + fx * cell * 0.06 + ex * CGFloat(s) * cell * 0.16,
                               y: hcY + fy * cell * 0.06 + ey * CGFloat(s) * cell * 0.16),
                       cell * 0.075, UIColor(hex: 0xDDFBFF))
        }
        ctx.restoreGState()

        // Player: rotating dashed ring + solid core + direction pointer
        let px = (CGFloat(engine.player.x) + 0.5) * cell
        let py = (CGFloat(engine.player.y) + 0.5) * cell
        radialFill(ctx, center: CGPoint(x: px, y: py), r0: cell * 0.04, r1: cell * 0.48,
                   stops: [(0, UIColor(hex: 0xFF9A4D, alpha: 0.42)),
                           (1, UIColor(hex: 0xFF9A4D, alpha: 0))],
                   rect: CGRect(x: px - cell * 0.5, y: py - cell * 0.5,
                                width: cell, height: cell))
        inCellRing(ctx, cx: px, cy: py,
                   color: UIColor(hex: 0xFFBE82, alpha: 0.85),
                   phase: -t / 1100, cell: cell)
        fillCircle(ctx, CGPoint(x: px, y: py), cell * 0.27, UIColor(hex: 0xFF9A4D))
        fillCircle(ctx, CGPoint(x: px, y: py), cell * 0.12, .white)
        if engine.dir.x != 0 || engine.dir.y != 0 {
            let a = atan2(CGFloat(engine.dir.y), CGFloat(engine.dir.x))
            let tipX = px + cos(a) * cell * 0.44, tipY = py + sin(a) * cell * 0.44
            ctx.setStrokeColor(UIColor(hex: 0xFFE1C3, alpha: 0.95).cgColor)
            ctx.setLineWidth(1.5)
            ctx.beginPath()
            ctx.move(to: CGPoint(x: px + cos(a) * cell * 0.30, y: py + sin(a) * cell * 0.30))
            ctx.addLine(to: CGPoint(x: tipX, y: tipY))
            ctx.strokePath()
            fillCircle(ctx, CGPoint(x: tipX, y: tipY), cell * 0.04, .white)
        }

        // Particles
        for p in engine.particles {
            ctx.setAlpha(max(0, min(1, p.life)))
            fillCircle(ctx, CGPoint(x: p.x, y: p.y), cell * 0.085, p.color)
        }
        ctx.setAlpha(1)

        if engine.flash > 0 {
            ctx.setFillColor(UIColor(hex: 0x3DFFC0, alpha: engine.flash * 0.075).cgColor)
            ctx.fill(board)
        }

        // Countdown overlay
        if engine.phase == .countdown {
            ctx.setFillColor(UIColor(hex: 0x050A14, alpha: 0.62).cgColor)
            ctx.fill(board)
            let n = Int(ceil(engine.countdown / 1000))
            let big = n > 0 ? String(n) : L10n.s(L10n.K.boardGo)
            let bigFont = UIFont.systemFont(ofSize: round(cell * 4), weight: .heavy)
            let bigSize = textSize(big, bigFont)
            ctx.saveGState()
            ctx.setShadow(offset: .zero, blur: cell * 1.2, color: UIColor(hex: 0x42CBFF).cgColor)
            drawText(big,
                     at: CGPoint(x: W / 2 - bigSize.width / 2,
                                 y: H / 2 - cell * 0.4 - bigSize.height / 2),
                     font: bigFont, color: UIColor(hex: 0xEAF6FF))
            ctx.restoreGState()
            let subFont = UIFont.systemFont(ofSize: max(9, round(cell * 0.85)), weight: .semibold)
            let sub = L10n.s(L10n.K.boardCountdownHint)
            let subSize = textSize(sub, subFont)
            drawText(sub,
                     at: CGPoint(x: W / 2 - subSize.width / 2,
                                 y: H / 2 + cell * 1.9 - subSize.height / 2),
                     font: subFont, color: UIColor(hex: 0xA0C3EB, alpha: 0.85))
        }
    }
}

// MARK: - UIKit board view: display link + touch

final class GameBoardUIView: UIView {
    var engine: GameEngine?
    var cols = 26
    var rows = 18
    var cell: CGFloat = 24

    private(set) var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private var touchStart: CGPoint?
    private var touchLast: CGPoint?
    private var touchMoved = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        backgroundColor = .clear
        isOpaque = false
        isMultipleTouchEnabled = false
        contentMode = .redraw
    }

    func startLoop() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(frame(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stopLoop() {
        displayLink?.invalidate()
        displayLink = nil
        lastTimestamp = 0
    }

    @objc private func frame(_ link: CADisplayLink) {
        if lastTimestamp == 0 {
            lastTimestamp = link.timestamp
            return
        }
        let dt = (link.timestamp - lastTimestamp) * 1000
        lastTimestamp = link.timestamp
        guard let engine else { return }
        engine.tick(dt: dt)
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext(), let engine else { return }
        BoardRenderer.draw(ctx, engine: engine, cols: cols, rows: rows, cell: cell)
    }

    // Swipe = turn (continuous, no lift needed); tap = dash. Mirrors
    // touchstart / touchmove / touchend in the web version.
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let p = touches.first?.location(in: self) else { return }
        touchStart = p
        touchLast = p
        touchMoved = false
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let p = touches.first?.location(in: self),
              let last = touchLast, touchStart != nil else { return }
        let dx = p.x - last.x, dy = p.y - last.y
        if max(abs(dx), abs(dy)) < 16 { return }
        touchMoved = true
        let name = abs(dx) > abs(dy) ? (dx > 0 ? "right" : "left") : (dy > 0 ? "down" : "up")
        engine?.setDir(name)
        touchLast = p
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { endTouch() }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { endTouch() }

    private func endTouch() {
        if touchStart != nil && !touchMoved { engine?.dash() }
        touchStart = nil
        touchLast = nil
        touchMoved = false
    }

}

// MARK: - SwiftUI bridge

struct GameBoardView: UIViewRepresentable {
    @ObservedObject var engine: GameEngine
    var cols: Int
    var rows: Int
    var cell: CGFloat

    func makeUIView(context: Context) -> GameBoardUIView {
        let view = GameBoardUIView()
        view.engine = engine
        view.cols = cols
        view.rows = rows
        view.cell = cell
        engine.cellSize = cell
        view.startLoop()
        return view
    }

    func updateUIView(_ view: GameBoardUIView, context: Context) {
        let changed = view.cols != cols || view.rows != rows || abs(view.cell - cell) > 0.5
        view.engine = engine
        view.cols = cols
        view.rows = rows
        view.cell = cell
        engine.cellSize = cell
        if changed { view.setNeedsDisplay() }
        if view.displayLink == nil { view.startLoop() }
    }

    static func dismantleUIView(_ view: GameBoardUIView, coordinator: ()) {
        view.stopLoop()
    }
}
