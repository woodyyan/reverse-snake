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
    let title: String
    let fontSize: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
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
private struct PanelBadge: View {
    let code: String
    let color: Color

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
                .shadow(color: color.opacity(0.85), radius: 6)
            Text(code)
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
    let title: String
    let detail: String
    let compact: Bool

    var body: some View {
        HStack(spacing: compact ? 7 : 9) {
            Image(systemName: icon)
                .font(.system(size: compact ? 15 : 18, weight: .bold))
                .foregroundColor(Theme.cyan)
                .shadow(color: Theme.cyan.opacity(0.65), radius: 7)
                .frame(width: compact ? 22 : 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: compact ? 12 : 13, weight: .heavy))
                    .foregroundColor(Theme.hudValue)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(detail)
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

/// Ready / paused / game-over panels over a blurred dark stage.
/// All gameplay hints live here so the running board keeps the full screen.
struct GameOverlayView: View {
    @ObservedObject var engine: GameEngine
    let m: LayoutMetrics

    var body: some View {
        ZStack {
            BackdropBlur(style: .dark)
            Color(hex: 0x050A14).opacity(0.30)
            GeometryReader { g in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        panel
                            .frame(maxWidth: 470)
                    }
                    .frame(maxWidth: .infinity, minHeight: g.size.height, alignment: .center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, m.isShortLandscape ? 8 : 16)
                }
            }
        }
        .clipped()
    }

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

    private var cardBackground: some View {
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

    private var operationHints: some View {
        HStack(spacing: m.compact ? 8 : 12) {
            OperationChip(icon: "hand.draw.fill", title: "滑动转向",
                          detail: "SWIPE / TURN", compact: m.compact)
            OperationChip(icon: "bolt.fill", title: "点按冲刺",
                          detail: "TAP / DASH · 2.6s", compact: m.compact)
        }
    }

    private var readyPanel: some View {
        VStack(spacing: 0) {
            PanelBadge(code: "MISSION // BRIEFING", color: Theme.cyan)
                .padding(.bottom, m.isShortLandscape ? 10 : 16)

            Text("你是被追的那一个")
                .font(.system(size: titleFont, weight: .heavy))
                .tracking(-0.6)
                .foregroundColor(.white)
                .shadow(color: Theme.cyan.opacity(0.45), radius: 12)
                .padding(.bottom, 8)

            Text("控制橙点躲避追击，吃青绿晶体得分。\n每得 1 分，蛇变长 2 节、追得更快。\n撞到蛇身即结束；墙只挡路。")
                .font(.system(size: bodyFont))
                .foregroundColor(Theme.panelText)
                .lineSpacing(4)
                .multilineTextAlignment(.center)

            operationHints
                .padding(.top, m.isShortLandscape ? 12 : 18)

            PrimaryButton(title: "开始游戏", fontSize: m.compact ? 14 : 15) {
                engine.start()
            }
            .padding(.top, m.isShortLandscape ? 14 : 20)
        }
        .padding(.vertical, cardPadV)
        .padding(.horizontal, cardPadH)
        .background(cardBackground)
    }

    private var pausePanel: some View {
        VStack(spacing: 0) {
            PanelBadge(code: "SYSTEM // PAUSED", color: Theme.orange)
                .padding(.bottom, m.isShortLandscape ? 10 : 16)

            Text("已暂停")
                .font(.system(size: titleFont, weight: .heavy))
                .foregroundColor(.white)
                .shadow(color: Theme.orange.opacity(0.40), radius: 12)
                .padding(.bottom, 8)

            Text("蛇在原地等你。")
                .font(.system(size: bodyFont))
                .foregroundColor(Theme.panelText)

            PrimaryButton(title: "继续", fontSize: m.compact ? 14 : 15) {
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
            PanelBadge(code: "RUN // TERMINATED", color: Theme.danger)
                .padding(.bottom, m.isShortLandscape ? 8 : 14)

            Text("本局结束")
                .font(.system(size: titleFont, weight: .heavy))
                .foregroundColor(.white)
                .shadow(color: Theme.danger.opacity(0.40), radius: 12)

            Text(engine.overReason)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.danger)
                .padding(.top, 6)

            VStack(spacing: 0) {
                Text("SCORE")
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
                kpiCell("LENGTH", "蛇长", "\(engine.snake.count)")
                kpiCell("BEST", "最高", "\(engine.best)")
            }
            .padding(.top, m.isShortLandscape ? 8 : 14)

            PrimaryButton(title: "再来一局", fontSize: m.compact ? 14 : 15) {
                engine.start()
            }
            .padding(.top, m.isShortLandscape ? 14 : 20)
        }
        .padding(.vertical, cardPadV)
        .padding(.horizontal, cardPadH)
        .background(cardBackground)
    }

    private func kpiCell(_ code: String, _ zh: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            Text(code)
                .font(.system(size: 8, weight: .heavy, design: .monospaced))
                .tracking(1)
                .foregroundColor(Theme.cyan)
            Text(value)
                .font(.system(size: m.compact ? 16 : 20, weight: .heavy, design: .monospaced))
                .foregroundColor(Theme.hudValue)
            Text(zh)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(Theme.hudLabel)
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .trailing) {
            if code != "BEST" { Theme.cyan.opacity(0.12).frame(width: 1) }
        }
    }
}
