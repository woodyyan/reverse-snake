import SwiftUI

// MARK: - Shared UI components (design v2)
// Calm, Apple-style controls: solid primary, quiet surfaces, hairline borders.
// Every colour comes from Theme, so light / dark switch automatically.

/// Shared press feedback.
struct SoftPressStyle: ButtonStyle {
    var scale: CGFloat = 0.96

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Full-width primary action (start, resume, play again).
struct PrimaryButton: View {
    let titleKey: String
    var icon: String? = nil
    var compact = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: compact ? 14 : 16, weight: .bold))
                }
                L10n.t(titleKey)
                    .font(.system(size: compact ? 16 : 18, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundColor(Theme.onPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: compact ? 48 : 56)
            .background(RoundedRectangle(cornerRadius: compact ? 15 : 18, style: .continuous)
                .fill(Theme.primary))
            .contentShape(Rectangle())
        }
        .buttonStyle(SoftPressStyle())
    }
}

/// Quiet secondary action on a surface card.
struct SecondaryButton: View {
    let icon: String
    let titleKey: String
    var compact = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: compact ? 13 : 15, weight: .semibold))
                    .foregroundColor(Theme.text2)
                L10n.t(titleKey)
                    .font(.system(size: compact ? 13 : 14, weight: .semibold))
                    .foregroundColor(Theme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity)
            .frame(height: compact ? 42 : 46)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.hairline, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(SoftPressStyle())
    }
}

/// Circular icon button (pause, close).
struct RoundIconButton: View {
    let systemName: String
    let labelKey: String
    let size: CGFloat
    var tint: Color = Theme.text
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size * 0.36, weight: .bold))
                .foregroundColor(tint)
                .frame(width: size, height: size)
                .background(Circle().fill(Theme.surface2))
                .overlay(Circle().stroke(Theme.hairline, lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(SoftPressStyle(scale: 0.9))
        .accessibilityLabel(L10n.t(labelKey))
    }
}

/// Capsule badge: reason, new best, etc.
struct Pill: View {
    let text: Text
    var icon: String? = nil
    let foreground: Color
    let background: Color

    var body: some View {
        HStack(spacing: 5) {
            if let icon {
                Image(systemName: icon).font(.system(size: 11, weight: .bold))
            }
            text.font(.system(size: 13, weight: .bold)).lineLimit(1)
        }
        .foregroundColor(foreground)
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(Capsule().fill(background))
        .fixedSize()
    }
}

/// Initial-letter avatar used by the leaderboard.
struct Avatar: View {
    let name: String
    let size: CGFloat
    var ring: Color = Theme.hairline
    var ringWidth: CGFloat = 1

    var body: some View {
        Text(verbatim: String(name.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased())
            .font(.system(size: size * 0.38, weight: .bold))
            .foregroundColor(Theme.text)
            .frame(width: size, height: size)
            .background(Circle().fill(Theme.surface2))
            .overlay(Circle().stroke(ring, lineWidth: ringWidth))
    }
}

// MARK: - Element glyphs (home legend), drawn with the same colours as the board

struct PlayerGlyph: View {
    var size: CGFloat = 26
    var body: some View {
        ZStack {
            Circle().fill(Theme.player.opacity(0.18))
            Circle().stroke(Theme.player, lineWidth: size * 0.08).padding(size * 0.06)
            Circle().fill(Theme.player).frame(width: size * 0.56, height: size * 0.56)
            Circle().fill(Theme.playerHi).frame(width: size * 0.18, height: size * 0.18)
                .offset(x: -size * 0.08, y: -size * 0.08)
        }
        .frame(width: size, height: size)
    }
}

struct SeedGlyph: View {
    var size: CGFloat = 26
    var body: some View {
        ZStack {
            Circle().fill(Theme.food.opacity(0.18))
            RoundedRectangle(cornerRadius: size * 0.1, style: .continuous)
                .fill(Theme.food)
                .frame(width: size * 0.44, height: size * 0.44)
                .overlay(RoundedRectangle(cornerRadius: size * 0.04)
                    .fill(Theme.foodHi.opacity(0.9))
                    .frame(width: size * 0.12, height: size * 0.12)
                    .offset(x: -size * 0.07, y: -size * 0.07))
                .rotationEffect(.degrees(45))
        }
        .frame(width: size, height: size)
    }
}

struct SnakeGlyph: View {
    var size: CGFloat = 26
    var body: some View {
        ZStack(alignment: .trailing) {
            Capsule()
                .fill(LinearGradient(colors: [Theme.snakeTail, Theme.snakeHead],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(width: size * 0.9, height: size * 0.34)
            Circle().fill(Theme.snakeHead).frame(width: size * 0.56, height: size * 0.56)
        }
        .frame(width: size, height: size)
    }
}
