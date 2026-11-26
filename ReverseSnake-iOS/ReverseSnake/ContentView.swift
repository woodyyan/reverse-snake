import SwiftUI

/// CSS @keyframes shake equivalent, triggered by engine.shakeToken.
struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 7
    var shakesPerUnit: CGFloat = 5
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        let x = amount * sin(animatableData * CGFloat.pi * shakesPerUnit)
        return ProjectionTransform(CGAffineTransform(translationX: x, y: 0))
    }
}

/// Deep-space stage: grid shape follows the available area so the board fills
/// nearly the whole screen on any iPhone / iPad size and orientation.
struct BoardStage: View {
    @ObservedObject var engine: GameEngine
    let m: LayoutMetrics

    var body: some View {
        GeometryReader { inner in
            let dims = m.gridDimensions(available: inner.size)
            let pad = m.stagePad
            let availW = max(0, inner.size.width - 2 * pad)
            let availH = max(120, inner.size.height - 2 * pad)
            let cell = max(9, floor(min(availW / CGFloat(dims.cols),
                                        availH / CGFloat(dims.rows))))
            let w = cell * CGFloat(dims.cols)
            let h = cell * CGFloat(dims.rows)
            let gridKey = "\(dims.cols)x\(dims.rows)-\(m.gridMode.rawValue)"

            ZStack {
                RoundedRectangle(cornerRadius: m.stageRadius)
                    .fill(Theme.stage)
                    .overlay(RoundedRectangle(cornerRadius: m.stageRadius)
                        .stroke(Theme.stageBorder, lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.20), radius: 44, y: 14)

                GameBoardView(engine: engine, cols: dims.cols, rows: dims.rows, cell: cell)
                    .frame(width: w, height: h)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                if engine.phase == .ready || engine.phase == .paused || engine.phase == .over {
                    GameOverlayView(engine: engine, m: m)
                        .clipShape(RoundedRectangle(cornerRadius: m.stageRadius))
                }
            }
            // Match the HUD / header width exactly. The grid keeps its square
            // cells and stays centred; only the deep-space stage expands into
            // the light gutters, so no board space or HUD space is lost.
            .frame(width: inner.size.width, height: h + 2 * pad)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .onAppear {
                engine.applyGrid(cols: dims.cols, rows: dims.rows, mode: m.gridMode)
            }
            .onChange(of: gridKey) { _ in
                engine.applyGrid(cols: dims.cols, rows: dims.rows, mode: m.gridMode)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ContentView: View {
    @StateObject private var engine = GameEngine()
    @Environment(\.scenePhase) private var scenePhase
    @State private var shakeProgress: CGFloat = 1

    var body: some View {
        GeometryReader { geo in
            let m = LayoutMetrics(size: geo.size)

            VStack(spacing: 0) {
                HeaderBar(engine: engine, m: m)
                HUDView(engine: engine, m: m)
                    .padding(.bottom, m.hudGap)

                BoardStage(engine: engine, m: m)
                    .modifier(ShakeEffect(animatableData: shakeProgress))
                    .onChange(of: engine.shakeToken) { _ in
                        shakeProgress = 0
                        withAnimation(.easeOut(duration: 0.32)) {
                            shakeProgress = 1
                        }
                    }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, m.outerPadTop)
            .padding(.bottom, m.outerPadBottom)
            .padding(.horizontal, m.outerPadH)
            .background(Theme.bg)
            .onChange(of: scenePhase) { phase in
                if phase != .active { engine.pauseForBackground() }
                if phase == .active { GameCenterManager.shared.retryPending() }
            }
            .onAppear { startGameCenter() }
            .onChange(of: engine.phase) { phase in
                let gc = GameCenterManager.shared
                gc.setAutoLoginAllowed(phase == .ready)
                switch phase {
                case .over: gc.reportRound(score: engine.score, best: engine.best)
                case .countdown: gc.clearRound()
                default: break
                }
            }
        }
        .background(Theme.bg.ignoresSafeArea())
    }

    /// Silent Game Center sign-in; never blocks or interrupts play.
    private func startGameCenter() {
        GameCenterManager.shared.start(localBest: engine.best)
        #if DEBUG
        if DebugMock.forceOver {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                engine.gameOver(L10n.K.overCaught)
            }
        }
        #endif
    }
}
