import Foundation
import SwiftUI
import UIKit

// MARK: - Value types

struct GridPoint: Hashable {
    var x: Int
    var y: Int
}

struct Delta {
    var x: Int
    var y: Int
}

enum Phase: String {
    case ready
    case countdown
    case running
    case paused
    case over
}

struct Particle {
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat
    var vy: CGFloat
    var life: CGFloat
    var color: UIColor
}

struct HUDData {
    var score = 0
    var best = 0
    var length = 5
    var space = 100
    var threat = 0
    var dashText = L10n.s(L10n.K.dashReady)
    var dashReady = true
    var stateKey = L10n.K.stateReady
}

private func clamp(_ v: Int, _ a: Int, _ b: Int) -> Int { max(a, min(b, v)) }
private func clamp(_ v: Double, _ a: Double, _ b: Double) -> Double { max(a, min(b, v)) }
private func clamp(_ v: CGFloat, _ a: CGFloat, _ b: CGFloat) -> CGFloat { max(a, min(b, v)) }

// MARK: - Engine
// Faithful Swift port of the game logic in index.html. All tunable constants,
// state machine, AI, scoring, particles and persistence are kept identical;
// only the platform primitives are swapped (UserDefaults for localStorage,
// AVAudioEngine for WebAudio, CADisplayLink for requestAnimationFrame).

final class GameEngine: ObservableObject {

    // ---------- config ----------
    let playerMS: Double = 112
    let snakeBase: Double = 235
    let snakeMin: Double = 108
    let planSteps = 2
    let grow = 2
    let dashCD: Double = 2600

    let dirs: [Delta] = [
        Delta(x: 1, y: 0), Delta(x: -1, y: 0),
        Delta(x: 0, y: 1), Delta(x: 0, y: -1)
    ]
    let byName: [String: Delta] = [
        "up": Delta(x: 0, y: -1), "down": Delta(x: 0, y: 1),
        "left": Delta(x: -1, y: 0), "right": Delta(x: 1, y: 0)
    ]

    private let defaults = UserDefaults.standard
    private let bestKey = "reverse-snake-best"
    private let soundKey = "reverse-snake-sound"

    // ---------- published (SwiftUI shell) ----------
    @Published private(set) var hud = HUDData()
    @Published private(set) var phase: Phase = .ready
    @Published private(set) var overReasonKey = ""
    @Published private(set) var shakeToken = 0

    @Published var soundOn: Bool {
        didSet { defaults.set(soundOn, forKey: soundKey) }
    }

    // ---------- simulation state (read directly by the CG renderer) ----------
    private(set) var cols = 26
    private(set) var rows = 18
    private(set) var gridMode: GridMode = .wide

    var snake: [GridPoint] = []
    var player = GridPoint(x: 4, y: 12)
    var dot: GridPoint?
    var dir = Delta(x: 0, y: 0)
    var dirQueue: [Delta] = []
    var score = 0
    private(set) var best = 0
    /// True once this round beats the stored best (drives the NEW BEST tag).
    private(set) var isNewBest = false
    var pendingGrowth = 0
    var dashCd: Double = 0
    var countdown: Double = 3000
    var playerAcc: Double = 0
    var snakeAcc: Double = 0
    var hudAcc: Double = 0
    var stuckMs: Double = 0
    var graceMs: Double = 0
    var flash: CGFloat = 0
    var particles: [Particle] = []
    var snakePlan: (dir: Delta, left: Int)?
    var renderTime: Double = 0
    var cellSize: CGFloat = 24

    // ---------- init ----------
    init() {
        best = defaults.object(forKey: bestKey) as? Int ?? 0
        soundOn = (defaults.object(forKey: soundKey) as? Bool) ?? true
        reset()
    }

    // ---------- helpers ----------
    func inBounds(_ x: Int, _ y: Int) -> Bool { x >= 0 && y >= 0 && x < cols && y < rows }
    func dist(_ a: GridPoint, _ b: GridPoint) -> Int { abs(a.x - b.x) + abs(a.y - b.y) }
    var snakeMs: Double { max(snakeMin, snakeBase - Double(score) * 4.5) }

    func bodyBlocked(ignoreTail: Bool) -> Set<GridPoint> {
        var s = Set<GridPoint>()
        let limit = (ignoreTail && pendingGrowth == 0) ? snake.count - 1 : snake.count
        if limit > 0 {
            for i in 0..<limit { s.insert(snake[i]) }
        }
        return s
    }

    /// BFS flood fill, returns cells in visit order (same as JS Set iteration).
    func flood(start: GridPoint, blocked: Set<GridPoint>) -> [GridPoint] {
        var seen = Set<GridPoint>([start])
        var order: [GridPoint] = [start]
        var head = 0
        while head < order.count {
            let c = order[head]
            head += 1
            for d in dirs {
                let n = GridPoint(x: c.x + d.x, y: c.y + d.y)
                if !inBounds(n.x, n.y) || blocked.contains(n) || seen.contains(n) { continue }
                seen.insert(n)
                order.append(n)
            }
        }
        return order
    }

    // ---------- setup ----------
    func reset() {
        snake = []
        // Layout is proportionally identical to the web version's 18x26 / 26x18
        // start positions: snake head at (cols-4, 3|4), player at (4, rows-6).
        let snakeY = gridMode == .tall ? 3 : 4
        for i in 0..<5 { snake.append(GridPoint(x: cols - 4 - i, y: snakeY)) }
        player = GridPoint(x: 4, y: max(6, rows - 6))
        dir = Delta(x: 0, y: 0)
        dirQueue = []
        score = 0
        isNewBest = false
        pendingGrowth = 0
        dashCd = 0
        stuckMs = 0
        flash = 0
        particles = []
        snakePlan = nil
        playerAcc = 0
        snakeAcc = 0
        hudAcc = 0
        graceMs = 600
        spawnDot()
        updateHUD()
    }

    func spawnDot() {
        let blocked = bodyBlocked(ignoreTail: false)
        let reach = flood(start: player, blocked: blocked).filter { $0 != player }
        let safeD = dist(player, snake[0])
        let minAway = clamp(Int(floor(Double(safeD) * 0.5)), 8, 13)
        var cells = reach.filter { dist($0, snake[0]) >= minAway }
        if cells.isEmpty { cells = reach }
        if cells.isEmpty {
            for x in 0..<cols {
                for y in 0..<rows {
                    let p = GridPoint(x: x, y: y)
                    if !blocked.contains(p) && p != player { cells.append(p) }
                }
            }
        }
        let nice = cells.filter { dist($0, player) >= 3 && dist($0, player) <= 14 }
        let pool = nice.isEmpty ? cells : nice
        dot = pool.randomElement() ?? GridPoint(x: 1, y: 1)
    }

    // ---------- snake AI ----------
    func bfsFirstStep(from: GridPoint, to: GridPoint, blocked: Set<GridPoint>) -> GridPoint? {
        if from == to { return nil }
        // JS Array.sort is stable; reproduce that with an index tie-break.
        let order = dirs.enumerated().sorted { a, b in
            let da = dist(GridPoint(x: from.x + a.element.x, y: from.y + a.element.y), to)
            let db = dist(GridPoint(x: from.x + b.element.x, y: from.y + b.element.y), to)
            return da < db || (da == db && a.offset < b.offset)
        }.map { $0.element }

        var queue: [GridPoint] = [from]
        var first: [GridPoint: GridPoint] = [:]
        var seen = Set<GridPoint>([from])
        var head = 0
        while head < queue.count {
            let c = queue[head]
            head += 1
            for d in order {
                let n = GridPoint(x: c.x + d.x, y: c.y + d.y)
                if !inBounds(n.x, n.y) || blocked.contains(n) || seen.contains(n) { continue }
                seen.insert(n)
                first[n] = (c == from) ? Optional(n) : first[c]
                if n == to { return first[n] }
                queue.append(n)
            }
        }
        return nil
    }

    /// When the player cannot be reached, keep as much open space as possible.
    func surviveStep(blocked: Set<GridPoint>) -> GridPoint? {
        let head = snake[0]
        var cands: [(p: GridPoint, reach: Int, d: Int, order: Int)] = []
        for (idx, d) in dirs.enumerated() {
            let n = GridPoint(x: head.x + d.x, y: head.y + d.y)
            if !inBounds(n.x, n.y) { continue }
            if n == player { return n }
            if blocked.contains(n) { continue }
            let keep = pendingGrowth > 0 ? snake.count : snake.count - 1
            let sim: [GridPoint] = [n] + Array(snake.prefix(keep))
            var simBlocked = Set<GridPoint>()
            if sim.count > 1 {
                for i in 1..<sim.count { simBlocked.insert(sim[i]) }
            }
            cands.append((n, flood(start: n, blocked: simBlocked).count, dist(n, player), idx))
        }
        let sorted = cands.sorted { a, b in
            a.reach != b.reach ? a.reach > b.reach : (a.d != b.d ? a.d < b.d : a.order < b.order)
        }
        return sorted.first?.p
    }

    // ---------- turns ----------
    func playerBlocked() -> Set<GridPoint> { bodyBlocked(ignoreTail: false) }

    func collect() {
        guard let d = dot, player == d else { return }
        score += 1
        pendingGrowth += grow
        burst(d.x, d.y, UIColor(hex: 0x3DFFC0), 18)
        flash = 1
        beep(660, 0.07, .triangle, 0.05)
        Haptics.shared.collect()
        if score > best {
            best = score
            isNewBest = true
            defaults.set(best, forKey: bestKey)
        }
        spawnDot()
        updateHUD()
    }

    func tryMove(_ d: Delta) -> Bool {
        if d.x == 0 && d.y == 0 { return false }
        let nx = player.x + d.x, ny = player.y + d.y
        if !inBounds(nx, ny) { return false }            // wall: blocks, never kills
        if playerBlocked().contains(GridPoint(x: nx, y: ny)) {
            burst(nx, ny, UIColor(hex: 0xFF5C6E), 14)
            gameOver(L10n.K.overHitBody)
            return false
        }
        player = GridPoint(x: nx, y: ny)
        return true
    }

    func stepPlayer() {
        if !dirQueue.isEmpty { dir = dirQueue.removeFirst() }
        if tryMove(dir) { collect() }
    }

    func dash() {
        guard phase == .running, dashCd <= 0 else { return }
        if dir.x == 0 && dir.y == 0 && !dirQueue.isEmpty { dir = dirQueue.removeFirst() }
        dashCd = dashCD
        burst(player.x, player.y, UIColor(hex: 0xFF9A4D), 10)
        for _ in 0..<2 {
            if !tryMove(dir) { break }
            collect()
        }
        guard phase == .running else { return }
        beep(300, 0.09, .sawtooth, 0.035)
        Haptics.shared.dash()
        updateHUD()
    }

    func stepSnake() {
        let willGrow = pendingGrowth > 0
        var blocked = bodyBlocked(ignoreTail: !willGrow)
        let head = snake[0]
        blocked.remove(head)
        var next: GridPoint?

        // Steering inertia: keep walking PLAN_STEPS before recomputing.
        if let plan = snakePlan, plan.left > 0 {
            let c = GridPoint(x: head.x + plan.dir.x, y: head.y + plan.dir.y)
            if inBounds(c.x, c.y) && !blocked.contains(c) {
                next = c
                snakePlan = (plan.dir, plan.left - 1)
            }
        }
        if next == nil {
            next = bfsFirstStep(from: head, to: player, blocked: blocked)
                ?? surviveStep(blocked: blocked)
            if let n = next {
                snakePlan = (Delta(x: n.x - head.x, y: n.y - head.y), planSteps)
            }
        }
        guard let n = next else {
            // Self-locked: chop the tail so the game never deadlocks.
            stuckMs += snakeMs
            if stuckMs > 1500 {
                let cut = max(2, snake.count / 3)
                var i = 0
                while i < cut && snake.count > 3 {
                    let t = snake.removeLast()
                    burst(t.x, t.y, UIColor(hex: 0x42CBFF), 5)
                    i += 1
                }
                snakePlan = nil
                stuckMs = 0
                beep(230, 0.12, .triangle, 0.03)
                Haptics.shared.tailCut()
            }
            return
        }
        stuckMs = 0
        if n == player { gameOver(L10n.K.overCaught); return }
        snake.insert(n, at: 0)
        if willGrow { pendingGrowth -= 1 } else { snake.removeLast() }
    }

    // ---------- fx ----------
    func burst(_ gx: Int, _ gy: Int, _ color: UIColor, _ n: Int) {
        let cx = (CGFloat(gx) + 0.5) * cellSize
        let cy = (CGFloat(gy) + 0.5) * cellSize
        for _ in 0..<n {
            let a = CGFloat.random(in: 0...(2 * CGFloat.pi))
            let sp = CGFloat.random(in: 0.6...3.0)
            particles.append(Particle(x: cx, y: cy,
                                      vx: cos(a) * sp, vy: sin(a) * sp,
                                      life: 1, color: color))
        }
    }

    private func updateParticles(dt: Double) {
        let f = CGFloat(dt / 16)
        if f <= 0 { return }
        for i in particles.indices {
            particles[i].x += particles[i].vx * f
            particles[i].y += particles[i].vy * f
            particles[i].vx *= 0.96
            particles[i].vy *= 0.96
            particles[i].life -= 0.022 * f
        }
        particles.removeAll { $0.life <= 0 }
        flash = max(0, flash - 0.035 * f)
    }

    private func beep(_ freq: Double, _ dur: Double, _ wave: SoundEngine.Wave, _ vol: Float) {
        guard soundOn else { return }
        SoundEngine.shared.beep(freq: freq, duration: dur, wave: wave, volume: vol)
    }

    // ---------- HUD / flow ----------
    /// Localization key, resolved by SwiftUI at render time.
    private var stateKey: String {
        switch phase {
        case .ready: return L10n.K.stateReady
        case .countdown: return L10n.K.stateCountdown
        case .running: return L10n.K.stateRunning
        case .paused: return L10n.K.statePaused
        case .over: return L10n.K.stateOver
        }
    }

    func updateHUD() {
        let blocked = bodyBlocked(ignoreTail: false)
        let reach = flood(start: player, blocked: blocked).count
        let free = cols * rows - snake.count
        let pct = clamp(Int(round(Double(reach) / Double(max(1, free)) * 100)), 0, 100)
        let lvl = Int(round((snakeBase - snakeMs) / (snakeBase - snakeMin) * 100))
        hud = HUDData(
            score: score,
            best: best,
            length: snake.count + pendingGrowth,
            space: pct,
            threat: clamp(lvl, 0, 100),
            dashText: dashCd > 0 ? String(format: "%.1fs", dashCd / 1000) : L10n.s(L10n.K.dashReady),
            dashReady: dashCd <= 0,
            stateKey: stateKey
        )
    }

    func start() {
        reset()
        phase = .countdown
        countdown = 3000
        updateHUD()
        beep(520, 0.08, .sine, 0.04)
        Haptics.shared.tap()
    }

    func pause() {
        guard phase == .running || phase == .countdown else { return }
        phase = .paused
        updateHUD()
        Haptics.shared.tap()
    }

    func resume() {
        guard phase == .paused else { return }
        phase = .running
        updateHUD()
        Haptics.shared.tap()
    }

    func pauseForBackground() {
        if phase == .running || phase == .countdown { pause() }
    }

    func gameOver(_ reasonKey: String) {
        guard phase != .over else { return }
        phase = .over
        overReasonKey = reasonKey
        updateHUD()
        burst(player.x, player.y, UIColor(hex: 0xFF5C6E), 26)
        beep(150, 0.35, .sawtooth, 0.06)
        Haptics.shared.gameOver()
        shakeToken += 1
    }

    // ---------- input ----------
    func setDir(_ name: String) {
        guard let d = byName[name] else { return }
        if dirQueue.count < 2 { dirQueue.append(d) }
        if phase == .ready { start() }
    }

    /// The board grid is derived from the actual stage size so it fills the
    /// screen. Any shape change (rotation, Split View resize) restarts the
    /// round, matching the web relayout() behaviour.
    func applyGrid(cols newCols: Int, rows newRows: Int, mode: GridMode) {
        let unchanged = cols == newCols && rows == newRows && gridMode == mode
        cols = newCols
        rows = newRows
        gridMode = mode
        guard !unchanged else { return }
        if phase == .ready {
            reset()
        } else {
            start()
        }
    }

    // ---------- loop (driven by CADisplayLink) ----------
    func tick(dt: Double) {
        let dt = min(max(dt, 0), 90)
        renderTime += dt

        if phase == .countdown {
            let before = Int(ceil(countdown / 1000))
            countdown -= dt
            let after = Int(ceil(countdown / 1000))
            if after != before && after > 0 { Haptics.shared.countdownTick() }
            if countdown <= 0 {
                phase = .running
                playerAcc = 0
                snakeAcc = 0
                updateHUD()
                Haptics.shared.go()
            }
        }
        if phase == .running {
            playerAcc += dt
            hudAcc += dt
            if graceMs > 0 {
                graceMs -= dt
                snakeAcc = 0
            } else {
                snakeAcc += dt
            }
            if dashCd > 0 { dashCd = max(0, dashCd - dt) }

            while playerAcc >= playerMS && phase == .running {
                playerAcc -= playerMS
                stepPlayer()
            }
            let sms = snakeMs
            while snakeAcc >= sms && phase == .running {
                snakeAcc -= sms
                stepSnake()
            }
            if hudAcc >= 140 {
                hudAcc = 0
                updateHUD()
            }
        }
        updateParticles(dt: dt)
    }
}
