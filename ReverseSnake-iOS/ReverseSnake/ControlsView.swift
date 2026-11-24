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

            // Brand name stays identical in every language (product name).
            (Text(verbatim: "SNAKE").foregroundColor(Theme.blue) + Text(verbatim: " FEAST").foregroundColor(Theme.ink))
                .font(.system(size: m.brandSize, weight: .bold))
                .tracking(-0.4)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer(minLength: 4)

            HStack(spacing: m.compact ? 6 : 8) {
                EnergyIconButton(
                    systemName: engine.phase == .paused ? "play.fill" : "pause.fill",
                    labelKey: engine.phase == .paused ? L10n.K.controlResume : L10n.K.controlPause,
                    tint: engine.phase == .paused ? Theme.orange : Theme.cyan,
                    m: m
                ) {
                    if engine.phase == .paused { engine.resume() } else { engine.pause() }
                }

                EnergyIconButton(
                    systemName: engine.soundOn ? "speaker.wave.2.fill" : "speaker.slash.fill",
                    labelKey: engine.soundOn ? L10n.K.controlSoundOn : L10n.K.controlSoundOff,
                    tint: engine.soundOn ? Theme.cyan : Theme.hudLabel,
                    m: m
                ) {
                    engine.soundOn.toggle()
                    Haptics.shared.tap()
                }

                EnergyIconButton(
                    systemName: "arrow.counterclockwise",
                    labelKey: L10n.K.controlRestart,
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
    let labelKey: String
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
        .accessibilityLabel(L10n.t(labelKey))
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
