import SwiftUI
import UIKit

/// Native backdrop blur over the game board (adapts to light / dark).
struct BackdropBlur: UIViewRepresentable {
    var style: UIBlurEffect.Style = .systemUltraThinMaterial

    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

/// Number that rolls from its previous value to the new one.
private struct CountUp: ViewModifier, Animatable {
    var value: Double
    let font: Font

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    func body(content: Content) -> some View {
        Text(verbatim: "\(Int(value.rounded()))")
            .font(font)
            .monospacedDigit()
    }
}

/// Rectangle with only the top corners rounded (iOS 16 has no UnevenRoundedRectangle).
private struct TopRounded: Shape {
    var radius: CGFloat

    func path(in rect: CGRect) -> Path {
        Path(UIBezierPath(roundedRect: rect, byRoundingCorners: [.topLeft, .topRight],
                          cornerRadii: CGSize(width: radius, height: radius)).cgPath)
    }
}

// MARK: - Home

/// Standalone start screen: brand, live board preview, rules, legend, actions.
struct HomeView: View {
    @ObservedObject var engine: GameEngine
    @ObservedObject private var appearance = AppearanceStore.shared
    let m: LayoutMetrics
    let onLeaderboard: () -> Void

    var body: some View {
        Group {
            if m.isWide {
                HStack(alignment: .center, spacing: m.compact ? 20 : 32) {
                    VStack(alignment: .leading, spacing: 14) {
                        brand
                        preview
                    }
                    ScrollView(.vertical, showsIndicators: false) {
                        details.padding(.vertical, 8)
                    }
                    .frame(maxWidth: 420)
                }
                .frame(maxWidth: 980)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    brand
                    preview
                        .frame(minHeight: 140, maxHeight: min(m.width * 0.95, 560))
                        .padding(.top, m.compact ? 14 : 22)
                    details.padding(.top, m.compact ? 8 : 16)
                }
                .frame(maxWidth: 540)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var brand: some View {
        HStack(spacing: 12) {
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: m.compact ? 46 : 54, height: m.compact ? 46 : 54)
                .clipShape(RoundedRectangle(cornerRadius: (m.compact ? 46 : 54) * 0.2237, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: (m.compact ? 46 : 54) * 0.2237, style: .continuous)
                    .stroke(Theme.hairline, lineWidth: 1))
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: "Snake Feast")
                    .font(.system(size: m.compact ? 24 : 28, weight: .heavy))
                    .tracking(-0.4)
                    .foregroundColor(Theme.text)
                L10n.t(L10n.K.homeTagline)
                    .font(.system(size: 13))
                    .foregroundColor(Theme.text2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }

    private var preview: some View {
        BoardPreview()
            .background(Theme.board)
            .overlay {
                if !m.isWide {
                    LinearGradient(stops: [.init(color: Theme.bg.opacity(0), location: 0.55),
                                           .init(color: Theme.bg, location: 1)],
                                   startPoint: .top, endPoint: .bottom)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 0) {
            L10n.t(L10n.K.readyTitle)
                .font(.system(size: m.compact ? 26 : 30, weight: .heavy))
                .tracking(-0.4)
                .foregroundColor(Theme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            L10n.t(L10n.K.readyBody)
                .font(.system(size: m.compact ? 14 : 15))
                .foregroundColor(Theme.text2)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)

            HStack(spacing: 8) {
                legend(AnyView(PlayerGlyph()), L10n.K.legendYou, L10n.K.legendYouSub)
                legend(AnyView(SeedGlyph()), L10n.K.legendSeed, L10n.K.legendSeedSub)
                legend(AnyView(SnakeGlyph()), L10n.K.legendSnake, L10n.K.legendSnakeSub)
            }
            .padding(.top, m.compact ? 14 : 18)

            PrimaryButton(titleKey: L10n.K.start, icon: "play.fill", compact: m.isShortLandscape) {
                engine.start()
            }
            .padding(.top, m.compact ? 16 : 22)

            HStack(spacing: 8) {
                SecondaryButton(icon: "trophy", titleKey: L10n.K.homeLeaderboard, compact: m.compact) {
                    Haptics.shared.tap()
                    onLeaderboard()
                }
                SecondaryButton(icon: engine.soundOn ? "speaker.wave.2.fill" : "speaker.slash.fill",
                                titleKey: engine.soundOn ? L10n.K.controlSoundOn : L10n.K.controlSoundOff,
                                compact: m.compact) {
                    engine.soundOn.toggle()
                    Haptics.shared.tap()
                }
                SecondaryButton(icon: appearance.mode.icon, titleKey: appearance.mode.titleKey,
                                compact: m.compact) {
                    Haptics.shared.tap()
                    appearance.mode = appearance.mode.next
                }
            }
            .padding(.top, 10)

            Text(verbatim: String(format: L10n.s(L10n.K.homeBest), engine.best))
                .font(.system(size: 12, weight: .medium))
                .monospacedDigit()
                .foregroundColor(Theme.text3)
                .frame(maxWidth: .infinity)
                .padding(.top, 14)
        }
    }

    private func legend(_ glyph: AnyView, _ titleKey: String, _ subKey: String) -> some View {
        HStack(spacing: 8) {
            glyph
            VStack(alignment: .leading, spacing: 1) {
                L10n.t(titleKey)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Theme.text)
                L10n.t(subKey)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.text2)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.hairline, lineWidth: 1))
    }
}

// MARK: - Pause sheet

/// Bottom sheet: resume, restart, sound, appearance, leaderboard.
struct PauseSheet: View {
    @ObservedObject var engine: GameEngine
    @ObservedObject private var appearance = AppearanceStore.shared
    let m: LayoutMetrics
    let bottomInset: CGFloat
    let onLeaderboard: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Theme.surface2)
                .frame(width: 38, height: 5)
                .padding(.top, 10)
                .padding(.bottom, m.isShortLandscape ? 10 : 16)
            if m.isShortLandscape {
                HStack(alignment: .top, spacing: 18) {
                    VStack(alignment: .leading, spacing: 0) {
                        header
                        Spacer(minLength: 12)
                        resume
                    }
                    rows
                }
            } else {
                header
                resume.padding(.top, 18)
                rows.padding(.top, 10)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, bottomInset + (m.isShortLandscape ? 8 : 16))
        .background(
            TopRounded(radius: 30)
                .fill(Theme.surface)
                .shadow(color: Theme.shadow, radius: 30, y: -6)
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            L10n.t(L10n.K.pausedTitle)
                .font(.system(size: m.compact ? 24 : 26, weight: .heavy))
                .foregroundColor(Theme.text)
            L10n.t(L10n.K.pausedBody)
                .font(.system(size: 14))
                .foregroundColor(Theme.text2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var resume: some View {
        PrimaryButton(titleKey: L10n.K.resume, icon: "play.fill", compact: m.compact) {
            engine.resume()
        }
    }

    private var rows: some View {
        VStack(spacing: 8) {
            Button {
                engine.start()
            } label: {
                row(icon: "arrow.counterclockwise", titleKey: L10n.K.pauseRestart) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Theme.text3)
                }
            }
            .buttonStyle(SoftPressStyle(scale: 0.98))

            row(icon: engine.soundOn ? "speaker.wave.2.fill" : "speaker.slash.fill",
                titleKey: L10n.K.settingSound) {
                Toggle("", isOn: $engine.soundOn)
                    .labelsHidden()
                    .tint(Theme.primary)
            }

            ViewThatFits(in: .horizontal) {
                row(icon: appearance.mode.icon, titleKey: L10n.K.settingAppearance) { picker }
                row(icon: appearance.mode.icon, titleKey: nil) { picker }
            }

            Button {
                Haptics.shared.tap()
                onLeaderboard()
            } label: {
                row(icon: "trophy", titleKey: L10n.K.homeLeaderboard) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Theme.text3)
                }
            }
            .buttonStyle(SoftPressStyle(scale: 0.98))
        }
    }

    private var picker: some View {
        Picker("", selection: $appearance.mode) {
            ForEach(AppearanceMode.allCases) { mode in
                L10n.t(mode.titleKey).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
    }

    private func row<Trailing: View>(icon: String, titleKey: String?,
                                     @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Theme.text2)
                .frame(width: 22)
            if let titleKey {
                L10n.t(titleKey)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Theme.text)
                    .lineLimit(1)
                    .fixedSize()
            }
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.horizontal, 16)
        .frame(height: m.compact ? 48 : 52)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surface2))
        .contentShape(Rectangle())
    }
}

// MARK: - Game over card

struct GameOverCard: View {
    @ObservedObject var engine: GameEngine
    @ObservedObject var gc: GameCenterManager
    let m: LayoutMetrics
    let onLeaderboard: () -> Void

    @State private var shown: Double = 0
    @State private var appeared = false

    private var bigFont: CGFloat { m.isShortLandscape ? 64 : (m.compact ? 84 : 100) }

    var body: some View {
        Group {
            if m.isShortLandscape {
                HStack(alignment: .center, spacing: 22) {
                    summary.frame(minWidth: 170)
                    actions.frame(maxWidth: 320)
                }
            } else {
                VStack(spacing: 0) {
                    summary
                    actions.padding(.top, 18)
                }
            }
        }
        .padding(.horizontal, m.compact ? 20 : 26)
        .padding(.vertical, m.isShortLandscape ? 16 : 24)
        .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Theme.hairline, lineWidth: 1))
        .shadow(color: Theme.shadow, radius: 34, y: 18)
        .offset(y: appeared ? 0 : 24)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) { appeared = true }
            withAnimation(.easeOut(duration: 0.7).delay(0.1)) { shown = Double(engine.score) }
        }
    }

    private var summary: some View {
        VStack(spacing: 0) {
            Pill(text: L10n.t(engine.overReasonKey), foreground: Theme.danger,
                 background: Theme.danger.opacity(0.14))
            Color.clear
                .frame(height: bigFont * 1.05)
                .modifier(CountUp(value: shown, font: .rounded(bigFont)))
                .foregroundColor(Theme.text)
                .padding(.top, 8)
            if engine.isNewBest {
                Pill(text: L10n.t(L10n.K.rankNewBest), icon: "crown.fill",
                     foreground: Theme.onGold, background: Theme.gold)
            }
        }
    }

    private var actions: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                stat(L10n.K.hudLength, "\(engine.snake.count)", divider: true)
                stat(L10n.K.hudBest, "\(engine.best)", divider: true)
                stat(L10n.K.hudThreat, "\(engine.hud.threat)%", divider: false)
            }
            .padding(.vertical, m.isShortLandscape ? 8 : 12)
            .overlay(alignment: .top) { Theme.hairline.frame(height: 1) }
            .overlay(alignment: .bottom) { Theme.hairline.frame(height: 1) }

            RankStrip(rank: gc.roundRank, compact: m.compact, action: onLeaderboard)
                .padding(.top, 12)

            PrimaryButton(titleKey: L10n.K.replay, icon: "arrow.counterclockwise", compact: m.compact) {
                engine.start()
            }
            .padding(.top, 12)

            Button {
                engine.backToHome()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "house").font(.system(size: 12, weight: .semibold))
                    L10n.t(L10n.K.overHome).font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(Theme.text2)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .contentShape(Rectangle())
            }
            .buttonStyle(SoftPressStyle())
            .padding(.top, 4)
        }
    }

    private func stat(_ key: String, _ value: String, divider: Bool) -> some View {
        VStack(spacing: 2) {
            L10n.t(key)
                .font(.system(size: 12))
                .foregroundColor(Theme.text2)
            Text(verbatim: value)
                .font(.rounded(m.compact ? 20 : 22, .bold))
                .monospacedDigit()
                .foregroundColor(Theme.text)
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .trailing) {
            if divider { Theme.hairline.frame(width: 1) }
        }
    }
}