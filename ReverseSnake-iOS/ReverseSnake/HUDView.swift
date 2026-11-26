import SwiftUI

/// In-game HUD (design v2): pause | centred score | best, plus three mini
/// stats (length, space, threat). Sound / restart live in the pause sheet,
/// dash cooldown lives on the player's ring.
struct GameHUD: View {
    @ObservedObject var engine: GameEngine
    let m: LayoutMetrics

    @State private var scoreScale: CGFloat = 1
    @State private var scoreGlow: Double = 0
    @State private var lastScore = 0

    private var isPaused: Bool { engine.phase == .paused }
    private var canToggle: Bool { [.running, .countdown, .paused].contains(engine.phase) }

    var body: some View {
        Group {
            if m.isShortLandscape {
                HStack(spacing: 8) {
                    pauseButton
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        L10n.t(L10n.K.hudScore)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Theme.text2)
                        scoreText
                    }
                    .fixedSize()
                    stats
                    best(alignment: .trailing)
                }
                .frame(height: m.topBarHeight)
            } else {
                VStack(spacing: m.rowGap) {
                    ZStack {
                        HStack {
                            pauseButton
                            Spacer()
                            best(alignment: .trailing)
                        }
                        VStack(spacing: 0) {
                            L10n.t(L10n.K.hudScore)
                                .font(.system(size: 11, weight: .semibold))
                                .tracking(0.8)
                                .foregroundColor(Theme.text2)
                            scoreText
                        }
                    }
                    .frame(height: m.topBarHeight)
                    stats.frame(height: m.statsHeight)
                }
            }
        }
        .onChange(of: engine.hud.score) { newValue in
            defer { lastScore = newValue }
            guard newValue > 0 && newValue > lastScore else { return }
            scoreScale = 1.25
            scoreGlow = 1
            withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) { scoreScale = 1 }
            withAnimation(.easeOut(duration: 0.6)) { scoreGlow = 0 }
        }
    }

    private var pauseButton: some View {
        RoundIconButton(systemName: isPaused ? "play.fill" : "pause.fill",
                        labelKey: isPaused ? L10n.K.controlResume : L10n.K.controlPause,
                        size: m.roundButton) {
            if isPaused { engine.resume() } else { engine.pause() }
        }
        .opacity(canToggle ? 1 : 0.4)
        .disabled(!canToggle)
    }

    private var scoreText: some View {
        let value = Text(verbatim: "\(engine.hud.score)")
            .font(.rounded(m.scoreFont))
            .monospacedDigit()
        return value
            .foregroundColor(Theme.text)
            .overlay(value.foregroundColor(Theme.food).opacity(scoreGlow))
            .scaleEffect(scoreScale)
            .lineLimit(1)
    }

    private func best(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 1) {
            HStack(spacing: 3) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Theme.gold)
                L10n.t(L10n.K.hudBest)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.text2)
            }
            Text(verbatim: "\(engine.hud.best)")
                .font(.rounded(m.bestFont, .bold))
                .monospacedDigit()
                .foregroundColor(Theme.text)
        }
        .fixedSize()
    }

    private var stats: some View {
        let hud = engine.hud
        let lowSpace = hud.space < 30
        return HStack(spacing: 8) {
            StatChip(labelKey: L10n.K.hudLength, value: "\(hud.length)")
            StatChip(labelKey: L10n.K.hudSpace, value: "\(hud.space)%",
                     progress: CGFloat(hud.space) / 100,
                     barColor: lowSpace ? Theme.danger : Theme.snakeHead, alert: lowSpace)
            StatChip(labelKey: L10n.K.hudThreat, value: "\(hud.threat)%",
                     progress: CGFloat(hud.threat) / 100, barColor: Theme.player)
        }
    }
}

/// One mini stat: label, optional micro progress bar, value.
struct StatChip: View {
    let labelKey: String
    let value: String
    var progress: CGFloat? = nil
    var barColor: Color = Theme.snakeHead
    var alert = false

    var body: some View {
        ViewThatFits(in: .horizontal) {
            content(showBar: true)
            content(showBar: false)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Theme.hairline, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    private func content(showBar: Bool) -> some View {
        HStack(spacing: 5) {
            L10n.t(labelKey)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Theme.text2)
                .lineLimit(1)
                .fixedSize()
            if showBar, let progress {
                Capsule()
                    .fill(Theme.surface2)
                    .frame(width: 22, height: 4)
                    .overlay(alignment: .leading) {
                        Capsule().fill(barColor).frame(width: 22 * max(0.04, min(1, progress)), height: 4)
                    }
            }
            Spacer(minLength: 2)
            Text(verbatim: value)
                .font(.rounded(14, .bold))
                .monospacedDigit()
                .foregroundColor(alert ? Theme.danger : Theme.text)
                .lineLimit(1)
                .fixedSize()
        }
    }
}