import SwiftUI
import UIKit

// MARK: - Core Graphics helpers

private func radialFill(_ ctx: CGContext, center: CGPoint, r0: CGFloat, r1: CGFloat,
                        stops: [(CGFloat, UIColor)], rect: CGRect) {
    let colors = stops.map { $0.1.cgColor } as CFArray
    let locations = stops.map { $0.0 }
    guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                    colors: colors, locations: locations) else { return }
    ctx.saveGState()
    ctx.addRect(rect)
    ctx.clip()
    ctx.drawRadialGradient(gradient,
                           startCenter: center, startRadius: max(0, r0),
                           endCenter: center, endRadius: max(r0 + 0.01, r1),
                           options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    ctx.restoreGState()
}

private func fillRoundRect(_ ctx: CGContext, _ rect: CGRect, _ r: CGFloat, _ color: UIColor) {
    ctx.beginPath()
    ctx.addPath(UIBezierPath(roundedRect: rect, cornerRadius: r).cgPath)
    ctx.setFillColor(color.cgColor)
    ctx.fillPath()
}

private func fillCircle(_ ctx: CGContext, _ c: CGPoint, _ r: CGFloat, _ color: UIColor) {
    ctx.setFillColor(color.cgColor)
    ctx.fillEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
}

private func strokeCircle(_ ctx: CGContext, _ c: CGPoint, _ r: CGFloat, _ color: UIColor, _ w: CGFloat) {
    ctx.setStrokeColor(color.cgColor)
    ctx.setLineWidth(w)
    ctx.strokeEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
}

private func roundedFont(_ size: CGFloat, _ weight: UIFont.Weight) -> UIFont {
    let base = UIFont.systemFont(ofSize: size, weight: weight)
    guard let d = base.fontDescriptor.withDesign(.rounded) else { return base }
    return UIFont(descriptor: d, size: size)
}

private func drawCentered(_ text: String, at c: CGPoint, font: UIFont, color: UIColor) {
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
    let size = (text as NSString).size(withAttributes: attrs)
    (text as NSString).draw(at: CGPoint(x: c.x - size.width / 2, y: c.y - size.height / 2),
                            withAttributes: attrs)
}

// MARK: - Scene: everything the renderer needs for one frame

struct BoardScene {
    var cols: Int
    var rows: Int
    var cell: CGFloat
    var time: Double
    var snake: [GridPoint]
    var player: GridPoint
    var food: GridPoint?
    /// 0...1, 1 = dash ready (drives the player's cooldown ring).
    var dashCharge: CGFloat = 1
    var dead = false
    /// 0...1 red edge vignette while the snake head is close.
    var threat: CGFloat = 0
    var flash: CGFloat = 0
    var particles: [Particle] = []
    var eatFx: [EatFx] = []
    var dashFx: DashFx?
    /// Remaining countdown in ms, nil when not counting down.
    var countdown: Double?
}

extension BoardScene {
    init(engine: GameEngine, cols: Int, rows: Int, cell: CGFloat) {
        let t = engine.renderTime
        var threat: CGFloat = 0
        if engine.phase == .running, let head = engine.snake.first {
            let d = engine.dist(head, engine.player)
            if d <= 3 { threat = CGFloat(Double(4 - d) / 4 * (0.75 + 0.25 * sin(t / 130))) }
        }
        self.init(cols: cols, rows: rows, cell: cell, time: t,
                  snake: engine.snake, player: engine.player, food: engine.dot,
                  dashCharge: CGFloat(max(0, min(1, 1 - engine.dashCd / engine.dashCD))),
                  dead: engine.phase == .over, threat: threat, flash: engine.flash,
                  particles: engine.particles, eatFx: engine.eatFx, dashFx: engine.dashFx,
                  countdown: engine.phase == .countdown ? engine.countdown : nil)
    }
}

// MARK: - Renderer (design v2: dot lattice, tube snake, golden seed, orb player)

enum BoardRenderer {
    static func draw(_ ctx: CGContext, scene s: BoardScene, palette p: Palette) {
        UIGraphicsPushContext(ctx)
        defer { UIGraphicsPopContext() }

        let cell = s.cell
        let W = CGFloat(s.cols) * cell, H = CGFloat(s.rows) * cell
        let board = CGRect(x: 0, y: 0, width: W, height: H)
        let t = s.time
        func center(_ g: GridPoint) -> CGPoint {
            CGPoint(x: (CGFloat(g.x) + 0.5) * cell, y: (CGFloat(g.y) + 0.5) * cell)
        }

        ctx.clear(board)

        // Backdrop: soft centre light
        radialFill(ctx, center: CGPoint(x: W * 0.5, y: H * 0.42), r0: 0, r1: max(W, H) * 0.8,
                   stops: [(0, p.boardCenter), (1, p.board)], rect: board)

        // Dot lattice at grid intersections (replaces grid lines)
        let dr = max(0.8, cell * 0.055)
        ctx.beginPath()
        for x in 1..<s.cols {
            for y in 1..<s.rows {
                ctx.addEllipse(in: CGRect(x: CGFloat(x) * cell - dr, y: CGFloat(y) * cell - dr,
                                          width: dr * 2, height: dr * 2))
            }
        }
        ctx.setFillColor(p.gridDot.cgColor)
        ctx.fillPath()

        // Golden seed: rounded diamond + highlight, breathing glow
        if let f = s.food {
            let c = center(f)
            let pulse = CGFloat(0.5 + 0.5 * sin(t / 420))
            radialFill(ctx, center: c, r0: 0, r1: cell * 0.72,
                       stops: [(0, p.food.alpha(0.30 + 0.18 * pulse)), (1, p.food.alpha(0))],
                       rect: CGRect(x: c.x - cell * 0.75, y: c.y - cell * 0.75,
                                    width: cell * 1.5, height: cell * 1.5))
            ctx.saveGState()
            ctx.translateBy(x: c.x, y: c.y)
            ctx.rotate(by: .pi / 4)
            let k = cell * (0.23 + 0.015 * pulse)
            fillRoundRect(ctx, CGRect(x: -k, y: -k, width: k * 2, height: k * 2), k * 0.32, p.food)
            fillRoundRect(ctx, CGRect(x: -k * 0.55, y: -k * 0.55, width: k * 0.5, height: k * 0.5),
                          k * 0.14, p.foodHi.alpha(0.9))
            ctx.restoreGState()
        }

        // Eat feedback: expanding gold ring + rising "+1"
        for fx in s.eatFx {
            let k = CGFloat(fx.age / EatFx.life)
            let c = center(fx.cell)
            strokeCircle(ctx, c, cell * (0.45 + 0.9 * k), p.food.alpha(0.7 * (1 - k)), max(1.5, cell * 0.08))
            drawCentered("+1", at: CGPoint(x: c.x + cell * 0.55, y: c.y - cell * (0.8 + 0.9 * k)),
                         font: roundedFont(max(11, cell * 0.8), .heavy), color: p.food.alpha(1 - k))
        }

        // Snake: one continuous tube, thin/dark tail -> thick/bright head
        let n = s.snake.count
        if n > 0 {
            let head = s.snake[0], hc = center(head)
            if !s.dead {
                radialFill(ctx, center: hc, r0: 0, r1: cell * 1.1,
                           stops: [(0, p.snakeHead.alpha(p.isDark ? 0.40 : 0.22)), (1, p.snakeHead.alpha(0))],
                           rect: CGRect(x: hc.x - cell * 1.1, y: hc.y - cell * 1.1,
                                        width: cell * 2.2, height: cell * 2.2))
            }
            ctx.setLineCap(.round)
            let last = CGFloat(max(1, n - 1))
            if n > 1 {
                for i in stride(from: n - 1, through: 1, by: -1) {
                    let k = 1 - CGFloat(i) / last
                    let col = s.dead ? UIColor.mix(p.deadTail, p.danger, k * 0.9)
                                     : UIColor.mix(p.snakeTail, p.snakeHead, pow(k, 0.85))
                    ctx.setStrokeColor(col.cgColor)
                    ctx.setLineWidth(cell * (0.46 + 0.26 * k))
                    ctx.beginPath()
                    ctx.move(to: center(s.snake[i]))
                    ctx.addLine(to: center(s.snake[i - 1]))
                    ctx.strokePath()
                }
                // Spine highlight along the front 60%
                let front = min(n - 1, Int((Double(n) * 0.6).rounded()))
                if front >= 1 {
                    ctx.setLineWidth(cell * 0.1)
                    for i in stride(from: front, through: 1, by: -1) {
                        let k = 1 - CGFloat(i) / last
                        ctx.setStrokeColor(p.spine.alpha(k * (p.isDark ? 0.16 : 0.26)).cgColor)
                        ctx.beginPath()
                        ctx.move(to: center(s.snake[i]))
                        ctx.addLine(to: center(s.snake[i - 1]))
                        ctx.strokePath()
                    }
                }
            }
            // Head with two eyes looking forward
            fillCircle(ctx, hc, cell * 0.42, s.dead ? p.danger : p.snakeHead)
            let neck = n > 1 ? s.snake[1] : GridPoint(x: head.x - 1, y: head.y)
            let dx = CGFloat(head.x - neck.x), dy = CGFloat(head.y - neck.y)
            let ex = -dy, ey = dx
            for side in [-1.0, 1.0] as [CGFloat] {
                let eye = CGPoint(x: hc.x + dx * cell * 0.12 + ex * side * cell * 0.18,
                                  y: hc.y + dy * cell * 0.12 + ey * side * cell * 0.18)
                fillCircle(ctx, eye, cell * 0.11, .white)
                fillCircle(ctx, CGPoint(x: eye.x + dx * cell * 0.04, y: eye.y + dy * cell * 0.04),
                           cell * 0.055, p.pupil)
            }
        }

        // Dash afterimages
        if let d = s.dashFx {
            let fade = 1 - CGFloat(d.age / DashFx.life)
            for j in 0..<d.steps {
                let g = GridPoint(x: d.origin.x + d.dir.x * j, y: d.origin.y + d.dir.y * j)
                let q = CGFloat(j + 1) / CGFloat(d.steps + 1)
                fillCircle(ctx, center(g), cell * 0.26 * (0.6 + 0.4 * q), p.player.alpha(0.5 * q * fade))
            }
        }

        // Player: glow + cooldown ring + core + highlight
        let pc = center(s.player)
        let tint = s.dead ? p.danger : p.player
        radialFill(ctx, center: pc, r0: 0, r1: cell * 0.95,
                   stops: [(0, tint.alpha(p.isDark ? 0.5 : 0.32)), (1, tint.alpha(0))],
                   rect: CGRect(x: pc.x - cell, y: pc.y - cell, width: cell * 2, height: cell * 2))
        let rr = cell * 0.46, lw = max(1.4, cell * 0.07)
        if s.dashCharge < 1 && !s.dead {
            strokeCircle(ctx, pc, rr, tint.alpha(0.22), lw)
            ctx.setStrokeColor(tint.cgColor)
            ctx.setLineWidth(lw)
            ctx.setLineCap(.round)
            ctx.beginPath()
            ctx.addArc(center: pc, radius: rr, startAngle: -.pi / 2,
                       endAngle: -.pi / 2 + 2 * .pi * s.dashCharge, clockwise: false)
            ctx.strokePath()
        } else {
            strokeCircle(ctx, pc, rr, tint.alpha(0.9), lw)
        }
        fillCircle(ctx, pc, cell * 0.29, tint)
        fillCircle(ctx, CGPoint(x: pc.x - cell * 0.08, y: pc.y - cell * 0.08), cell * 0.1,
                   s.dead ? UIColor.mix(p.danger, .white, 0.5) : p.playerHi)

        // Particles
        for pt in s.particles {
            let c: UIColor
            switch pt.kind {
            case .food: c = p.food
            case .danger: c = p.danger
            case .player: c = p.player
            case .snake: c = p.snakeHead
            }
            fillCircle(ctx, CGPoint(x: pt.x, y: pt.y), cell * 0.085, c.alpha(max(0, min(1, pt.life))))
        }

        // Threat: red breathing vignette
        if s.threat > 0 {
            radialFill(ctx, center: CGPoint(x: W / 2, y: H / 2),
                       r0: max(W, H) * 0.30, r1: hypot(W, H) * 0.56,
                       stops: [(0, p.danger.alpha(0)), (1, p.danger.alpha(0.5 * s.threat))], rect: board)
        }

        if s.flash > 0 {
            ctx.setFillColor(p.food.alpha(s.flash * 0.06).cgColor)
            ctx.fill(board)
        }

        // Countdown
        if let cd = s.countdown {
            ctx.setFillColor(p.scrim.cgColor)
            ctx.fill(board)
            let n = Int(ceil(cd / 1000))
            let big = n > 0 ? String(n) : L10n.s(L10n.K.boardGo)
            let bigSize = min(cell * 6.5, min(W, H) * 0.42)
            let mid = CGPoint(x: W / 2, y: H / 2 - bigSize * 0.18)
            drawCentered(big, at: mid, font: roundedFont(bigSize, .heavy), color: p.text)
            let hintFont = UIFont.systemFont(ofSize: max(12, min(16, cell * 0.68)), weight: .semibold)
            let hintY = mid.y + bigSize * 0.62
            drawCentered(L10n.s(L10n.K.boardCountdownHint), at: CGPoint(x: W / 2, y: hintY),
                         font: hintFont, color: p.text2)
            // Progress dots: active one is a capsule
            let step = max(0, min(2, 3 - n))
            let h = max(6, cell * 0.32), on = h * 2.8, gap = h * 0.8
            let total = on + h * 2 + gap * 2
            var x = W / 2 - total / 2
            let y = hintY + max(22, cell * 1.2)
            for i in 0..<3 {
                let w = i == step ? on : h
                fillRoundRect(ctx, CGRect(x: x, y: y - h / 2, width: w, height: h), h / 2,
                              i == step ? p.player : p.surface2)
                x += w + gap
            }
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
        BoardRenderer.draw(ctx, scene: BoardScene(engine: engine, cols: cols, rows: rows, cell: cell),
                           palette: Palette.resolve(traitCollection))
    }

    // Swipe = turn (continuous, no lift needed); tap = dash.
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

// MARK: - Home preview: a static demo chase with a breathing seed

final class PreviewBoardUIView: UIView {
    private var link: CADisplayLink?
    private var start: CFTimeInterval = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        isUserInteractionEnabled = false
        contentMode = .redraw
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            guard link == nil else { return }
            let l = CADisplayLink(target: self, selector: #selector(step))
            l.preferredFrameRateRange = CAFrameRateRange(minimum: 20, maximum: 30, preferred: 30)
            l.add(to: .main, forMode: .common)
            link = l
        } else {
            link?.invalidate()
            link = nil
        }
    }

    @objc private func step() { setNeedsDisplay() }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext(), bounds.width > 40, bounds.height > 40 else { return }
        let p = Palette.resolve(traitCollection)
        let cols = bounds.width > bounds.height * 1.2 ? 18 : 14
        let cell = floor(bounds.width / CGFloat(cols))
        let rows = max(7, Int(bounds.height / cell))
        if start == 0 { start = CACurrentMediaTime() }
        let t = (CACurrentMediaTime() - start) * 1000

        // Demo chase: snake winds up from the bottom-left towards the player.
        let u = max(1, (rows - 4) / 3)
        var g = GridPoint(x: 1, y: rows - 2)
        var cells = [g]
        for (dx, dy, n) in [(1, 0, cols / 2 - 1), (0, -1, u), (1, 0, 3), (0, -1, max(1, u - 1))] {
            for _ in 0..<n { g = GridPoint(x: g.x + dx, y: g.y + dy); cells.append(g) }
        }
        let head = cells.last!
        let scene = BoardScene(cols: cols, rows: rows, cell: cell, time: t,
                               snake: cells.reversed(),
                               player: GridPoint(x: min(cols - 2, head.x + 2), y: max(1, head.y - 1)),
                               food: GridPoint(x: 2, y: 2),
                               dashCharge: 1)
        ctx.setFillColor(p.board.cgColor)
        ctx.fill(bounds)
        let ox = floor((bounds.width - CGFloat(cols) * cell) / 2)
        ctx.translateBy(x: ox, y: 0)
        BoardRenderer.draw(ctx, scene: scene, palette: p)
    }
}

struct BoardPreview: UIViewRepresentable {
    func makeUIView(context: Context) -> PreviewBoardUIView { PreviewBoardUIView() }
    func updateUIView(_ view: PreviewBoardUIView, context: Context) { view.setNeedsDisplay() }
}
