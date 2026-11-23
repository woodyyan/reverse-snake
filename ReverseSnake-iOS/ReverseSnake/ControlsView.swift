import SwiftUI

// MARK: - Top bar (pause / sound / restart only)

struct HeaderBar: View {
    @ObservedObject var engine: GameEngine
    let m: LayoutMetrics

    var body: some View {
        HStack(alignment: .center, spacing: m.compact ? 6 : 8) {
            // Game logo in the top-left corner (same artwork family as AppIcon).
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: m.logoSize, height: m.logoSize)
                .clipShape(RoundedRectangle(cornerRadius: m.logoSize * 0.22))
                .overlay(
                    RoundedRectangle(cornerRadius: m.logoSize * 0.22)
                        .stroke(Theme.line, lineWidth: 1)
                )

            (Text("REVERSE").foregroundColor(Theme.blue) + Text(" SNAKE").foregroundColor(Theme.ink))
                .font(.system(size: m.brandSize, weight: .bold))
                .tracking(-0.4)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer(minLength: 4)

            HStack(spacing: m.compact ? 5 : 8) {
                TopButton(title: engine.phase == .paused ? "继续" : "暂停", m: m) {
                    if engine.phase == .paused { engine.resume() } else { engine.pause() }
                }
                TopButton(title: engine.soundOn ? "音效开" : "音效关", m: m) {
                    engine.soundOn.toggle()
                }
                TopButton(title: "重开", m: m) {
                    engine.start()
                }
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.bottom, m.headerGap)
    }
}

private struct TopButton: View {
    let title: String
    let m: LayoutMetrics
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: m.buttonFont, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .foregroundColor(Theme.ink)
                .padding(.vertical, m.buttonPadV)
                .padding(.horizontal, m.buttonPadH)
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(Theme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
