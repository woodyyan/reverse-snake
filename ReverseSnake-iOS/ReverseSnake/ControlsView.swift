import SwiftUI

// MARK: - Top bar: logo + brand + unified dark energy icon controls

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

            HStack(spacing: m.compact ? 6 : 8) {
                EnergyIconButton(
                    systemName: engine.phase == .paused ? "play.fill" : "pause.fill",
                    label: engine.phase == .paused ? "继续" : "暂停",
                    tint: engine.phase == .paused ? Theme.orange : Theme.cyan,
                    m: m
                ) {
                    if engine.phase == .paused { engine.resume() } else { engine.pause() }
                }

                EnergyIconButton(
                    systemName: engine.soundOn ? "speaker.wave.2.fill" : "speaker.slash.fill",
                    label: engine.soundOn ? "音效开" : "音效关",
                    tint: engine.soundOn ? Theme.cyan : Theme.hudLabel,
                    m: m
                ) {
                    engine.soundOn.toggle()
                    Haptics.shared.tap()
                }

                EnergyIconButton(
                    systemName: "arrow.counterclockwise",
                    label: "重开",
                    tint: Theme.cyan,
                    m: m
                ) {
                    engine.start()
                }
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.bottom, m.headerGap)
    }
}

/// One dark energy panel per control: HUD gradient + border + cyan glow,
/// so the three buttons read as a single control cluster instead of system buttons.
private struct EnergyIconButton: View {
    let systemName: String
    let label: String
    let tint: Color
    let m: LayoutMetrics
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: m.controlRadius)
                    .fill(LinearGradient(colors: [Theme.hudTop, Theme.hudBottom],
                                         startPoint: .top, endPoint: .bottom))
                RoundedRectangle(cornerRadius: m.controlRadius)
                    .fill(LinearGradient(colors: [Theme.cyan.opacity(0.10), Color.clear],
                                         startPoint: .top, endPoint: .bottom))
                Image(systemName: systemName)
                    .font(.system(size: m.controlIcon, weight: .bold))
                    .foregroundColor(tint)
                    .shadow(color: tint.opacity(0.55), radius: 5)
            }
            .frame(width: m.controlSize, height: m.controlSize)
            .overlay(
                RoundedRectangle(cornerRadius: m.controlRadius)
                    .stroke(Theme.hudBorder, lineWidth: 1)
            )
        }
        .buttonStyle(EnergyPressStyle())
        .accessibilityLabel(label)
    }
}

/// Shared press feedback for top-bar icon buttons and dialog primary buttons.
struct EnergyPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1)
            .brightness(configuration.isPressed ? 0.30 : 0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
