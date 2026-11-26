import SwiftUI

/// Death shake, triggered by engine.shakeToken.
struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 7
    var shakesPerUnit: CGFloat = 5
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        let x = amount * sin(animatableData * CGFloat.pi * shakesPerUnit)
        return ProjectionTransform(CGAffineTransform(translationX: x, y: 0))
    }
}

/// Board stage: grid shape follows the available area so the board fills
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
                RoundedRectangle(cornerRadius: m.stageRadius, style: .continuous)
                    .fill(Theme.board)
                    .overlay(RoundedRectangle(cornerRadius: m.stageRadius, style: .continuous)
                        .stroke(Theme.hairline, lineWidth: 1))

                GameBoardView(engine: engine, cols: dims.cols, rows: dims.rows, cell: cell)
                    .frame(width: w, height: h)
                    .clipShape(RoundedRectangle(cornerRadius: max(6, m.stageRadius - pad), style: .continuous))
            }
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
    @ObservedObject private var gc = GameCenterManager.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var shakeProgress: CGFloat = 1
    @State private var showBoard = ContentView.debugShowBoard

    var body: some View {
        GeometryReader { geo in
            let m = LayoutMetrics(size: geo.size)
            let phase = engine.phase

            ZStack {
                // 1. Game layer: always laid out so the grid is sized before play.
                VStack(spacing: m.rowGap) {
                    GameHUD(engine: engine, m: m)
                    BoardStage(engine: engine, m: m)
                        .modifier(ShakeEffect(animatableData: shakeProgress))
                        .overlay {
                            if phase == .paused {
                                BackdropBlur()
                                    .clipShape(RoundedRectangle(cornerRadius: m.stageRadius, style: .continuous))
                                    .transition(.opacity)
                            } else if phase == .over {
                                RoundedRectangle(cornerRadius: m.stageRadius, style: .continuous)
                                    .fill(Theme.scrim)
                                    .transition(.opacity)
                            }
                        }
                }
                .padding(.top, m.outerPadTop)
                .padding(.bottom, m.outerPadBottom)
                .padding(.horizontal, m.outerPadH)
                .frame(maxWidth: 1100)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .accessibilityHidden(phase == .ready || showBoard)
                .allowsHitTesting(phase != .ready && !showBoard)

                // 2. Results card over the dimmed board.
                if phase == .over && !showBoard {
                    ScrollView(.vertical, showsIndicators: false) {
                        GameOverCard(engine: engine, gc: gc, m: m) { openBoard() }
                            .frame(maxWidth: m.isShortLandscape ? 640 : 400)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .frame(maxWidth: .infinity, minHeight: geo.size.height)
                    }
                    .transition(.opacity)
                }

                // 3. Pause sheet from the bottom edge.
                if phase == .paused && !showBoard {
                    VStack {
                        Spacer(minLength: 0)
                        PauseSheet(engine: engine, m: m, bottomInset: geo.safeAreaInsets.bottom) {
                            openBoard()
                        }
                        .frame(maxWidth: m.isShortLandscape ? 720 : 560)
                    }
                    .ignoresSafeArea(edges: .bottom)
                    .transition(.move(edge: .bottom))
                }

                // 4. Home screen.
                if phase == .ready && !showBoard {
                    Theme.bg
                        .ignoresSafeArea()
                        .overlay(
                            HomeView(engine: engine, m: m) { openBoard() }
                                .padding(.horizontal, m.isWide ? 32 : 20)
                                .padding(.top, m.isShortLandscape ? 8 : 12)
                                .padding(.bottom, 8)
                        )
                        .transition(.opacity)
                }

                // 5. Leaderboard page.
                if showBoard {
                    Theme.bg
                        .ignoresSafeArea()
                        .overlay(
                            LeaderboardPanel(gc: gc, m: m, localBest: engine.best) { closeBoard() }
                                .frame(maxWidth: 560)
                                .padding(.horizontal, 20)
                                .padding(.top, m.isShortLandscape ? 6 : 10)
                                .padding(.bottom, 6)
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeOut(duration: 0.25), value: phase)
            .animation(.easeOut(duration: 0.25), value: showBoard)
            .background(Theme.bg.ignoresSafeArea())
            .onChange(of: engine.shakeToken) { _ in
                shakeProgress = 0
                withAnimation(.easeOut(duration: 0.32)) { shakeProgress = 1 }
            }
            .onChange(of: scenePhase) { p in
                if p != .active { engine.pauseForBackground() }
                if p == .active { gc.retryPending() }
            }
            .onAppear {
                AppearanceStore.shared.apply()
                startGameCenter()
            }
            .onChange(of: phase) { p in
                gc.setAutoLoginAllowed(p == .ready)
                switch p {
                case .over: gc.reportRound(score: engine.score, best: engine.best)
                case .countdown: gc.clearRound()
                default: break
                }
            }
        }
        .background(Theme.bg.ignoresSafeArea())
    }

    private func openBoard() { showBoard = true }

    private func closeBoard() {
        Haptics.shared.tap()
        showBoard = false
    }

    #if DEBUG
    private static var debugShowBoard: Bool { DebugMock.showBoard }
    #else
    private static var debugShowBoard: Bool { false }
    #endif

    /// Silent Game Center sign-in; never blocks or interrupts play.
    private func startGameCenter() {
        GameCenterManager.shared.start(localBest: engine.best)
        #if DEBUG
        if DebugMock.forceOver {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                engine.gameOver(L10n.K.overCaught)
            }
        }
        if let state = UserDefaults.standard.string(forKey: "SFDebugState") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                engine.debugStage(state)
            }
        }
        #endif
    }
}
