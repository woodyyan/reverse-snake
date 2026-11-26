import SwiftUI
import UIKit

/// Native equivalent of CSS backdrop-filter: blur(3px) over the game canvas.
private struct BackdropBlur: UIViewRepresentable {
    let style: UIBlurEffect.Style

    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

// MARK: - Shared energy UI, same language as the HUD and top-bar controls

struct PrimaryButton: View {
    let titleKey: String
    let fontSize: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            L10n.t(titleKey)
                .font(.system(size: fontSize, weight: .heavy))
                .tracking(0.6)
                .foregroundColor(.white)
                .padding(.vertical, 12)
                .padding(.horizontal, 30)
                .background(
                    LinearGradient(colors: [Theme.blue, Theme.cyan],
                                   startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Theme.cyan.opacity(0.75), lineWidth: 1)
                )
                .shadow(color: Theme.cyan.opacity(0.45), radius: 14)
        }
        .buttonStyle(EnergyPressStyle())
    }
}

/// Monospaced status strip + status lamp, mirroring the HUD state label.
struct PanelBadge: View {
    let codeKey: String
    let color: Color

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
                .shadow(color: color.opacity(0.85), radius: 6)
            L10n.t(codeKey)
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .tracking(1.6)
                .foregroundColor(color)
                .fixedSize(horizontal: true, vertical: false)
            Rectangle()
                .fill(LinearGradient(colors: [color.opacity(0.5), Color.clear],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(width: 64, height: 1)
        }
    }
}

/// Highlighted control hint: glowing icon + Chinese action + monospaced detail.
private struct OperationChip: View {
    let icon: String
    let titleKey: String
    let detailKey: String
    let compact: Bool

    var body: some View {
        HStack(spacing: compact ? 7 : 9) {
            Image(systemName: icon)
                .font(.system(size: compact ? 15 : 18, weight: .bold))
                .foregroundColor(Theme.cyan)
                .shadow(color: Theme.cyan.opacity(0.65), radius: 7)
                .frame(width: compact ? 22 : 26)
            VStack(alignment: .leading, spacing: 1) {
                L10n.t(titleKey)
                    .font(.system(size: compact ? 12 : 13, weight: .heavy))
                    .foregroundColor(Theme.hudValue)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                L10n.t(detailKey)
                    .font(.system(size: compact ? 8.5 : 9.5, weight: .medium, design: .monospaced))
                    .tracking(0.6)
                    .foregroundColor(Theme.hudLabel)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, compact ? 8 : 10)
        .padding(.horizontal, compact ? 10 : 12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Theme.panelChip)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Theme.cyan.opacity(0.38), lineWidth: 1)
                )
        )
    }
}

private struct ScanLine: View {
    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: Theme.cyan, location: 0.18),
                .init(color: Theme.blue, location: 0.68),
                .init(color: .clear, location: 1)
            ], startPoint: .leading, endPoint: .trailing)
            .frame(height: 1)
            .opacity(0.85)
            Spacer(minLength: 0)
        }
    }
}

/// Four L-shaped reticles, echoing the board and AppIcon corner marks.
private struct CornerReticles: View {
    var body: some View {
        GeometryReader { g in
            Path { p in
                let L: CGFloat = 14
                let i: CGFloat = 10
                let w = g.size.width, h = g.size.height
                p.move(to: CGPoint(x: i, y: i + L))
                p.addLine(to: CGPoint(x: i, y: i)); p.addLine(to: CGPoint(x: i + L, y: i))
                p.move(to: CGPoint(x: w - i - L, y: i))
                p.addLine(to: CGPoint(x: w - i, y: i)); p.addLine(to: CGPoint(x: w - i, y: i + L))
                p.move(to: CGPoint(x: i, y: h - i - L))
                p.addLine(to: CGPoint(x: i, y: h - i)); p.addLine(to: CGPoint(x: i + L, y: h - i))
                p.move(to: CGPoint(x: w - i, y: h - i - L))
                p.addLine(to: CGPoint(x: w - i, y: h - i)); p.addLine(to: CGPoint(x: w - i - L, y: h - i))
            }
            .stroke(Theme.cyan.opacity(0.42), lineWidth: 2)
        }
    }
}

/// Shared dark-energy card: HUD gradient, border, scan line, corner reticles.
struct EnergyCardBackground: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(LinearGradient(colors: [Theme.hudTop, Theme.hudBottom],
                                     startPoint: .top, endPoint: .bottom))
            RoundedRectangle(cornerRadius: 18)
                .fill(LinearGradient(colors: [Theme.cyan.opacity(0.07), Color.clear],
                                     startPoint: .top, endPoint: .bottom))
        }
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.hudBorder, lineWidth: 1))
        .overlay(ScanLine())
        .overlay(CornerReticles())
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.black.opacity(0.45), radius: 40, y: 16)
        .shadow(color: Theme.cyan.opacity(0.14), radius: 26)
    }
}

/// Ready / paused / game-over panels over a blurred dark stage.
/// All gameplay hints live here so the running board keeps the full screen.
struct GameOverlayView: View {
    @ObservedObject var engine: GameEngine
    let m: LayoutMetrics
    @ObservedObject private var gc = GameCenterManager.shared
    @State private var showBoard = GameOverlayView.debugShowBoard

    var body: some View {
        ZStack {
            BackdropBlur(style: .dark)
            Color(hex: 0x050A14).opacity(0.30)
            GeometryReader { g in
                let padV: CGFloat = m.isShortLandscape ? 8 : 16
                if showBoard {
                    LeaderboardPanel(gc: gc, m: m, localBest: engine.best) {
                        setBoard(false)
                    }
                    .frame(maxWidth: 470)
                    .frame(height: max(220, min(g.size.height - 2 * padV, 660)))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 16)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            panel
                                .frame(maxWidth: 470)
                        }
                        .frame(maxWidth: .infinity, minHeight: g.size.height, alignment: .center)
                        .padding(.horizontal, 16)
                        .padding(.vertical, padV)
                    }
                    .transition(.opacity)
                }
            }
        }
        .clipped()
    }

    private func setBoard(_ on: Bool) {
        Haptics.shared.tap()
        withAnimation(.easeOut(duration: 0.22)) { showBoard = on }
    }

    #if DEBUG
    private static var debugShowBoard: Bool { DebugMock.showBoard }
    #else
    private static var debugShowBoard: Bool { false }
    #endif

    private var titleFont: CGFloat { m.isShortLandscape ? 19 : (m.compact ? 22 : 26) }
    private var bodyFont: CGFloat { m.isShortLandscape ? 12 : (m.compact ? 12.5 : 13.5) }
    private var bigFont: CGFloat { m.compact ? 44 : 52 }
    private var cardPadV: CGFloat { m.isShortLandscape ? 14 : (m.compact ? 22 : 28) }
    private var cardPadH: CGFloat { m.isShortLandscape ? 18 : (m.compact ? 20 : 30) }

    @ViewBuilder
    private var panel: some View {
        switch engine.phase {
        case .ready: readyPanel
        case .paused: pausePanel
        case .over: overPanel
        default: EmptyView()
        }
    }

    private var cardBackground: some View { EnergyCardBackground() }

    private var operationHints: some View {
        HStack(spacing: m.compact ? 8 : 12) {
            OperationChip(icon: "hand.draw.fill",
                          titleKey: L10n.K.hintSwipeTitle,
                          detailKey: L10n.K.hintSwipeDetail, compact: m.compact)
            OperationChip(icon: "bolt.fill",
                          titleKey: L10n.K.hintDashTitle,
                          detailKey: L10n.K.hintDashDetail, compact: m.compact)
        }
    }

    private var readyPanel: some View {
        VStack(spacing: 0) {
            PanelBadge(codeKey: L10n.K.badgeReady, color: Theme.cyan)
                .padding(.bottom, m.isShortLandscape ? 10 : 16)

            L10n.t(L10n.K.readyTitle)
                .font(.system(size: titleFont, weight: .heavy))
                .tracking(-0.6)
                .foregroundColor(.white)
                .shadow(color: Theme.cyan.opacity(0.45), radius: 12)
                .padding(.bottom, 8)

            L10n.t(L10n.K.readyBody)
                .font(.system(size: bodyFont))
                .foregroundColor(Theme.panelText)
                .lineSpacing(4)
                .multilineTextAlignment(.center)

            operationHints
                .padding(.top, m.isShortLandscape ? 12 : 18)

            PrimaryButton(titleKey: L10n.K.start, fontSize: m.compact ? 14 : 15) {
                engine.start()
            }
            .padding(.top, m.isShortLandscape ? 14 : 20)

            SecondaryButton(icon: "trophy.fill", titleKey: L10n.K.lbOpen, compact: m.compact) {
                setBoard(true)
            }
            .padding(.top, m.isShortLandscape ? 8 : 12)
        }
        .padding(.vertical, cardPadV)
        .padding(.horizontal, cardPadH)
        .background(cardBackground)
    }

    private var pausePanel: some View {
        VStack(spacing: 0) {
            PanelBadge(codeKey: L10n.K.badgePaused, color: Theme.orange)
                .padding(.bottom, m.isShortLandscape ? 10 : 16)

            L10n.t(L10n.K.pausedTitle)
                .font(.system(size: titleFont, weight: .heavy))
                .foregroundColor(.white)
                .shadow(color: Theme.orange.opacity(0.40), radius: 12)
                .padding(.bottom, 8)

            L10n.t(L10n.K.pausedBody)
                .font(.system(size: bodyFont))
                .foregroundColor(Theme.panelText)

            PrimaryButton(titleKey: L10n.K.resume, fontSize: m.compact ? 14 : 15) {
                engine.resume()
            }
            .padding(.top, m.isShortLandscape ? 14 : 20)
        }
        .padding(.vertical, cardPadV)
        .padding(.horizontal, cardPadH)
        .background(cardBackground)
    }

    private var overPanel: some View {
        VStack(spacing: 0) {
            PanelBadge(codeKey: L10n.K.badgeOver, color: Theme.danger)
                .padding(.bottom, m.isShortLandscape ? 8 : 14)

            L10n.t(L10n.K.overTitle)
                .font(.system(size: titleFont, weight: .heavy))
                .foregroundColor(.white)
                .shadow(color: Theme.danger.opacity(0.40), radius: 12)

            L10n.t(engine.overReasonKey)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.danger)
                .padding(.top, 6)

            VStack(spacing: 0) {
                L10n.t(L10n.K.score)
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .tracking(1.8)
                    .foregroundColor(Theme.cyan.opacity(0.85))
                Text("\(engine.score)")
                    .font(.system(size: bigFont, weight: .heavy))
                    .foregroundColor(Theme.cyan)
                    .shadow(color: Theme.cyan.opacity(0.55), radius: 16)
            }
            .padding(.top, m.compact ? 6 : 10)

            HStack(spacing: 0) {
                kpiCell(labelKey: L10n.K.hudLength, subKey: L10n.K.hudSubLength,
                        value: "\(engine.snake.count)", showDivider: true)
                kpiCell(labelKey: L10n.K.hudBest, subKey: L10n.K.hudSubBest,
                        value: "\(engine.best)", showDivider: false)
            }
            .padding(.top, m.isShortLandscape ? 8 : 14)

            RankStrip(rank: gc.roundRank, isNewBest: engine.isNewBest, compact: m.compact) {
                setBoard(true)
            }
            .padding(.top, m.isShortLandscape ? 8 : 12)

            PrimaryButton(titleKey: L10n.K.replay, fontSize: m.compact ? 14 : 15) {
                engine.start()
            }
            .padding(.top, m.isShortLandscape ? 14 : 20)

            SecondaryButton(icon: "trophy.fill", titleKey: L10n.K.lbView, compact: m.compact) {
                setBoard(true)
            }
            .padding(.top, m.isShortLandscape ? 8 : 12)
        }
        .padding(.vertical, cardPadV)
        .padding(.horizontal, cardPadH)
        .background(cardBackground)
    }

    private func kpiCell(labelKey: String, subKey: String, value: String,
                         showDivider: Bool) -> some View {
        VStack(spacing: 3) {
            L10n.t(labelKey)
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .tracking(1)
                .foregroundColor(Theme.cyan)
            Text(value)
                .font(.system(size: m.compact ? 16 : 20, weight: .heavy, design: .monospaced))
                .foregroundColor(Theme.hudValue)
            L10n.t(subKey)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(Theme.hudLabel)
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .trailing) {
            if showDivider { Theme.cyan.opacity(0.12).frame(width: 1) }
        }
    }
}
