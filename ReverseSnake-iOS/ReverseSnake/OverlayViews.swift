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

struct PrimaryButton: View {
    let title: String
    let fontSize: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: fontSize, weight: .semibold))
                .foregroundColor(.white)
                .padding(.vertical, 11)
                .padding(.horizontal, 26)
                .background(Theme.blue)
                .clipShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
    }
}

/// Ready / paused / game-over panels, floating over a blurred dark stage.
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

    private var titleFont: CGFloat { m.isShortLandscape ? 19 : (m.compact ? 21 : 25) }
    private var bodyFont: CGFloat { m.isShortLandscape ? 12 : (m.compact ? 12.5 : 13.5) }
    private var keysFont: CGFloat { m.isShortLandscape ? 10 : (m.compact ? 11 : 12) }
    private var bigFont: CGFloat { m.compact ? 44 : 52 }

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
        RoundedRectangle(cornerRadius: 16)
            .fill(Theme.card)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.line, lineWidth: 1))
            .shadow(color: .black.opacity(0.34), radius: 60, y: 18)
    }

    private var readyPanel: some View {
        VStack(spacing: 0) {
            Text("你是被追的那一个")
                .font(.system(size: titleFont, weight: .bold))
                .tracking(-0.6)
                .foregroundColor(Theme.ink)
                .padding(.bottom, 8)

            Text("控制橙点躲避追击，吃青绿晶体得分。\n每得 1 分，蛇变长 2 节、追得更快。\n撞到蛇身即结束；墙只挡路。")
                .font(.system(size: bodyFont))
                .foregroundColor(Theme.ink2)
                .lineSpacing(4)
                .multilineTextAlignment(.center)

            PrimaryButton(title: "开始游戏", fontSize: m.compact ? 14 : 15) {
                engine.start()
            }
            .padding(.top, m.isShortLandscape ? 16 : 24)

            Text("棋盘上滑动转向 · 点按冲刺")
                .font(.system(size: keysFont))
                .foregroundColor(Color(hex: 0x98A2B3))
                .padding(.top, m.isShortLandscape ? 10 : 14)
        }
        .padding(.vertical, m.compact ? 24 : 30)
        .padding(.horizontal, m.compact ? 22 : 34)
        .background(cardBackground)
    }

    private var pausePanel: some View {
        VStack(spacing: 0) {
            Text("已暂停")
                .font(.system(size: titleFont, weight: .bold))
                .foregroundColor(Theme.ink)
                .padding(.bottom, 8)
            Text("蛇在原地等你。")
                .font(.system(size: bodyFont))
                .foregroundColor(Theme.ink2)
            PrimaryButton(title: "继续", fontSize: m.compact ? 14 : 15) {
                engine.resume()
            }
            .padding(.top, 18)
        }
        .padding(.vertical, m.compact ? 20 : 30)
        .padding(.horizontal, m.compact ? 24 : 34)
        .background(cardBackground)
    }

    private var overPanel: some View {
        VStack(spacing: 0) {
            Text("本局结束")
                .font(.system(size: titleFont, weight: .bold))
                .foregroundColor(Theme.ink)
            Text(engine.overReason)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.danger)
                .padding(.top, 6)
            Text("\(engine.score)")
                .font(.system(size: bigFont, weight: .heavy, design: .monospaced))
                .foregroundColor(Theme.blue)
                .tracking(-2)
                .padding(.top, m.compact ? 8 : 14)
            Text("吃掉了 \(engine.score) 个点 · 蛇长到了 \(engine.snake.count) 节 · 最高 \(engine.best)")
                .font(.system(size: bodyFont))
                .foregroundColor(Theme.ink2)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
            PrimaryButton(title: "再来一局", fontSize: m.compact ? 14 : 15) {
                engine.start()
            }
            .padding(.top, 20)
        }
        .padding(.vertical, m.compact ? 20 : 30)
        .padding(.horizontal, m.compact ? 18 : 34)
        .background(cardBackground)
    }

}
