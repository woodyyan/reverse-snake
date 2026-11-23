import SwiftUI

/// Dark energy HUD: SCORE / BEST / LENGTH / SPACE / THREAT,
/// status lamp, state label, score pulse and the threat bar across the bottom.
struct HUDView: View {
    @ObservedObject var engine: GameEngine
    let m: LayoutMetrics

    @State private var pulse = false
    @State private var scoreScale: CGFloat = 1
    @State private var scoreBright: Double = 0

    private var stateColor: Color {
        switch engine.phase {
        case .running, .countdown: return Theme.green
        case .paused: return Theme.orange
        case .over: return Theme.danger
        case .ready: return Color(hex: 0x7189AC)
        }
    }

    private var isLive: Bool { engine.phase == .running || engine.phase == .countdown }

    var body: some View {
        let hud = engine.hud
        let weights = m.kpiWeights
        let total = weights.reduce(0, +)

        ZStack(alignment: .bottom) {
            LinearGradient(colors: [Theme.hudTop, Theme.hudBottom],
                           startPoint: .top, endPoint: .bottom)

            // Score-cell wash, like .score-cell background
            GeometryReader { g in
                LinearGradient(colors: [Theme.blue.opacity(0.20), Color.clear],
                               startPoint: .leading, endPoint: .trailing)
                    .frame(width: g.size.width * weights[0] / total * 0.85)
            }

            // Top scan highlight
            VStack(spacing: 0) {
                LinearGradient(stops: [
                    .init(color: .clear, location: 0),
                    .init(color: Theme.cyan, location: 0.18),
                    .init(color: Theme.blue, location: 0.65),
                    .init(color: .clear, location: 1)
                ], startPoint: .leading, endPoint: .trailing)
                .frame(height: 1)
                .opacity(0.75)
                Spacer(minLength: 0)
            }

            // Five KPI cells
            GeometryReader { g in
                HStack(alignment: .top, spacing: 0) {
                    kpi(code: "SCORE", zh: "得分", value: "\(hud.score)",
                        width: g.size.width * weights[0] / total,
                        isScore: true, showState: true, score: true)
                    kpi(code: "BEST", zh: "最高", value: "\(hud.best)",
                        width: g.size.width * weights[1] / total)
                    kpi(code: "LENGTH", zh: "蛇长", value: "\(hud.length)",
                        width: g.size.width * weights[2] / total)
                    kpi(code: "SPACE", zh: "空间", value: "\(hud.space)%",
                        width: g.size.width * weights[3] / total,
                        valueColor: hud.space < 30 ? Theme.danger : Theme.hudValue)
                    kpi(code: "THREAT", zh: "追击", value: "\(hud.threat)%",
                        width: g.size.width * weights[4] / total)
                }
            }

            // Through-line threat bar
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Theme.cyan.opacity(0.08)
                    LinearGradient(stops: [
                        .init(color: Theme.cyan, location: 0),
                        .init(color: Theme.blue, location: 0.55),
                        .init(color: Theme.orange, location: 1)
                    ], startPoint: .leading, endPoint: .trailing)
                    .frame(width: g.size.width * CGFloat(hud.threat) / 100)
                    .shadow(color: Theme.cyan.opacity(0.65), radius: 12)
                }
            }
            .frame(height: 3)

            // Glowing spine on the score cell
            LinearGradient(colors: [Theme.cyan, Theme.blue],
                           startPoint: .top, endPoint: .bottom)
                .frame(width: 2)
                .shadow(color: Theme.cyan.opacity(0.75), radius: 10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .frame(height: m.hudHeight)
        .clipShape(RoundedRectangle(cornerRadius: m.hudRadius))
        .overlay(RoundedRectangle(cornerRadius: m.hudRadius).stroke(Theme.hudBorder, lineWidth: 1))
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
        .onChange(of: engine.hud.score) { newValue in
            guard newValue > 0 && newValue > lastScore else { lastScore = newValue; return }
            lastScore = newValue
            scoreScale = 1.32
            scoreBright = 0.9
            withAnimation(.easeOut(duration: 0.38)) {
                scoreScale = 1
                scoreBright = 0
            }
        }
    }

    @State private var lastScore = 0

    @ViewBuilder
    private func kpi(code: String, zh: String, value: String, width: CGFloat,
                     isScore: Bool = false, showState: Bool = false,
                     score: Bool = false, valueColor: Color = Theme.hudValue) -> some View {
        let labSize = m.kpiLabel
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: m.compact ? 3 : 6) {
                Text(code)
                    .font(.system(size: labSize, weight: .heavy, design: .monospaced))
                    .tracking(m.compact ? 0.4 : 1.2)
                    .foregroundColor(Theme.cyan)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if !m.compact {
                    Text(zh)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(Color(hex: 0x8CA3C2))
                }
                if showState {
                    Spacer(minLength: 0)
                    if !(m.compact && !m.isShortLandscape) {
                        Text(engine.hud.stateText)
                            .font(.system(size: 8, weight: .heavy, design: .monospaced))
                            .tracking(1.2)
                            .foregroundColor(stateColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    Circle()
                        .fill(stateColor)
                        .frame(width: m.compact ? 4 : 6, height: m.compact ? 4 : 6)
                        .opacity(pulse && isLive ? 0.4 : 1)
                        .shadow(color: engine.phase == .over ? Theme.danger.opacity(0.8) : .clear,
                                radius: engine.phase == .over ? 8 : 0)
                }
            }
            .padding(.bottom, m.compact ? 2 : 3)

            Text(value)
                .font(.system(size: score ? m.kpiScore : m.kpiValue,
                              weight: .heavy, design: .monospaced))
                .foregroundColor(score ? Theme.cyan : valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .scaleEffect(score ? scoreScale : 1)
                .brightness(score ? scoreBright : 0)
                .shadow(color: score ? Theme.cyan.opacity(0.5) : Theme.cyan.opacity(0.2),
                        radius: score ? 9 : 8)
        }
        .padding(.top, m.compact ? 5 : 9)
        .padding(.leading, isScore ? (m.compact ? 9 : 18) : (m.compact ? 4 : 14))
        .padding(.trailing, 2)
        .frame(width: width, alignment: .leading)
        .overlay(alignment: .trailing) {
            if code != "THREAT" {
                Theme.cyan.opacity(0.10).frame(width: 1)
            }
        }
    }
}
