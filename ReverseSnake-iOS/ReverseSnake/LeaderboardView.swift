import SwiftUI

// MARK: - Leaderboard UI
// Custom panel drawn in the same dark-energy language as the ready / pause /
// game-over cards. Data comes from GameCenterManager; the system Game Center
// (Games app on iOS 26+) is one tap away via the footer link.

/// Secondary CTA under a PrimaryButton (leaderboard entry points).
struct SecondaryButton: View {
    let icon: String
    let titleKey: String
    let compact: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: compact ? 12 : 13, weight: .bold))
                L10n.t(titleKey)
                    .font(.system(size: compact ? 12.5 : 13.5, weight: .bold))
                    .lineLimit(1)
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .heavy))
                    .opacity(0.7)
            }
            .foregroundColor(Theme.cyan)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(Capsule().fill(Theme.panelChip))
            .overlay(Capsule().stroke(Theme.cyan.opacity(0.32), lineWidth: 1))
        }
        .buttonStyle(EnergyPressStyle())
    }
}

/// Game-over rank strip: "🌐 Global #128 ↑34 · Friends #3   NEW BEST  ›".
struct RankStrip: View {
    let rank: RoundRank
    let isNewBest: Bool
    let compact: Bool
    let action: () -> Void

    var body: some View {
        if rank != .hidden {
            Button(action: action) {
                HStack(spacing: 8) {
                    content
                    Spacer(minLength: 4)
                    if isNewBest, case .ranked = rank { newBestTag }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundColor(Theme.hudLabel)
                }
                .padding(.vertical, compact ? 8 : 10)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.panelChip))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(tint.opacity(0.40), lineWidth: 1))
            }
            .buttonStyle(StripPressStyle())
        }
    }

    private var tint: Color {
        switch rank {
        case .ranked: return Theme.cyan
        case .offline: return Theme.hudLabel
        default: return Theme.orange
        }
    }

    private var textFont: Font { .system(size: compact ? 12 : 13, weight: .semibold) }

    @ViewBuilder
    private var content: some View {
        switch rank {
        case .hidden:
            EmptyView()
        case .signedOut:
            icon("person.crop.circle.badge.plus", Theme.orange)
            L10n.t(L10n.K.rankLogin).font(textFont).foregroundColor(Theme.hudValue).lineLimit(1).minimumScaleFactor(0.8)
        case .submitting:
            ProgressView().tint(Theme.cyan).scaleEffect(0.75).frame(width: 18, height: 18)
            L10n.t(L10n.K.rankSubmitting).font(textFont).foregroundColor(Theme.panelText).lineLimit(1)
        case .offline:
            icon("wifi.slash", Theme.hudLabel)
            L10n.t(L10n.K.rankOffline).font(textFont).foregroundColor(Theme.panelText).lineLimit(1).minimumScaleFactor(0.8)
        case let .ranked(global, friends, climb):
            icon("globe.asia.australia.fill", Theme.cyan)
            if global == nil && friends == nil {
                L10n.t(L10n.K.rankSynced).font(textFont).foregroundColor(Theme.hudValue).lineLimit(1)
            } else {
                HStack(spacing: 6) {
                    if let global {
                        Text(verbatim: String(format: L10n.s(L10n.K.rankGlobal), global))
                            .font(.system(size: compact ? 13 : 14, weight: .heavy, design: .monospaced))
                            .foregroundColor(Theme.hudValue)
                    }
                    if let climb {
                        Text(verbatim: "↑\(climb)")
                            .font(.system(size: compact ? 11 : 12, weight: .heavy, design: .monospaced))
                            .foregroundColor(Theme.green)
                    }
                    if let friends {
                        Text(verbatim: (global == nil ? "" : "· ") + String(format: L10n.s(L10n.K.rankFriends), friends))
                            .font(.system(size: compact ? 12 : 13, weight: .bold, design: .monospaced))
                            .foregroundColor(Theme.panelText)
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            }
        }
    }

    private func icon(_ name: String, _ color: Color) -> some View {
        Image(systemName: name)
            .font(.system(size: compact ? 14 : 15, weight: .bold))
            .foregroundColor(color)
            .shadow(color: color.opacity(0.6), radius: 6)
    }

    private var newBestTag: some View {
        L10n.t(L10n.K.rankNewBest)
            .font(.system(size: 9, weight: .heavy, design: .monospaced))
            .tracking(0.8)
            .foregroundColor(Theme.orange)
            .padding(.vertical, 3)
            .padding(.horizontal, 7)
            .background(Capsule().fill(Theme.orange.opacity(0.14)))
            .overlay(Capsule().stroke(Theme.orange.opacity(0.55), lineWidth: 1))
            .fixedSize()
    }
}

/// Wide strips get a gentler press than the 0.88 icon-button scale.
private struct StripPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .brightness(configuration.isPressed ? 0.18 : 0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Leaderboard panel

struct LeaderboardPanel: View {
    @ObservedObject var gc: GameCenterManager
    let m: LayoutMetrics
    let localBest: Int
    let onClose: () -> Void

    @State private var scope: LeaderboardScope = .global

    private var compact: Bool { m.compact }
    // Clear the 10+14pt corner reticles so the close button / footer never sit on them.
    private var padH: CGFloat { m.isShortLandscape ? 18 : (compact ? 20 : 26) }
    private var padV: CGFloat { m.isShortLandscape ? 14 : (compact ? 24 : 28) }

    var body: some View {
        VStack(spacing: 0) {
            header
            tabs.padding(.top, m.isShortLandscape ? 8 : 12)
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 10)
            if gc.isAuthenticated {
                pinnedMe.padding(.top, 8)
            }
            footer.padding(.top, m.isShortLandscape ? 6 : 10)
        }
        .padding(.vertical, padV)
        .padding(.horizontal, padH)
        .background(EnergyCardBackground())
        .task(id: "\(scope.rawValue)-\(gc.isAuthenticated)") {
            await gc.load(scope)
        }
    }

    // MARK: Header + tabs

    private var header: some View {
        VStack(spacing: m.isShortLandscape ? 4 : 10) {
            HStack {
                PanelBadge(codeKey: L10n.K.lbBadge, color: Theme.cyan)
                Spacer(minLength: 8)
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundColor(Theme.hudLabel)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Theme.panelChip))
                        .overlay(Circle().stroke(Theme.hudBorder, lineWidth: 1))
                }
                .buttonStyle(EnergyPressStyle())
                .accessibilityLabel(L10n.t(L10n.K.lbClose))
            }
            if !m.isShortLandscape {
                L10n.t(L10n.K.lbTitle)
                    .font(.system(size: compact ? 20 : 24, weight: .heavy))
                    .foregroundColor(.white)
                    .shadow(color: Theme.cyan.opacity(0.45), radius: 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var tabs: some View {
        HStack(spacing: 4) {
            ForEach(LeaderboardScope.allCases) { s in
                let on = s == scope
                Button {
                    guard s != scope else { return }
                    Haptics.shared.tap()
                    scope = s
                } label: {
                    L10n.t(s.titleKey)
                        .font(.system(size: compact ? 12 : 13, weight: .heavy))
                        .foregroundColor(on ? .white : Theme.hudLabel)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, compact ? 7 : 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(on ? Theme.cyan.opacity(0.18) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(on ? Theme.cyan.opacity(0.70) : Color.clear, lineWidth: 1)
                        )
                        .shadow(color: on ? Theme.cyan.opacity(0.30) : .clear, radius: 8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.panelChip))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.hudBorder, lineWidth: 1))
    }

    // MARK: Content states

    @ViewBuilder
    private var content: some View {
        switch gc.auth {
        case .authenticated: boardContent
        case .unknown: skeleton
        case .needsLogin, .unavailable: signIn
        }
    }

    @ViewBuilder
    private var boardContent: some View {
        let page = gc.pages[scope]
        let isLoading = gc.loading.contains(scope)
        let isFailed = gc.failed.contains(scope)
        if let page, !page.rows.isEmpty {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 4) {
                    ForEach(page.rows) { row in
                        LeaderboardRowView(row: row, compact: compact)
                    }
                }
                .padding(.vertical, 2)
            }
            .refreshable { await gc.load(scope, force: true) }
        } else if isLoading || (page == nil && !isFailed) {
            skeleton
        } else if isFailed && page == nil {
            message(icon: "wifi.exclamationmark", titleKey: L10n.K.lbError) {
                SecondaryButton(icon: "arrow.clockwise", titleKey: L10n.K.lbRetry, compact: compact) {
                    Task { await gc.load(scope, force: true) }
                }
            }
        } else {
            message(icon: "trophy.fill",
                    titleKey: scope == .friends ? L10n.K.lbEmptyFriends : L10n.K.lbEmpty) { EmptyView() }
        }
    }

    private var skeleton: some View {
        VStack(spacing: 4) {
            ForEach(0..<8, id: \.self) { i in
                RoundedRectangle(cornerRadius: 9)
                    .fill(Theme.panelChip)
                    .frame(height: compact ? 34 : 38)
                    .opacity(1 - Double(i) * 0.1)
            }
            Spacer(minLength: 0)
        }
        .redacted(reason: .placeholder)
    }

    private var signIn: some View {
        VStack(spacing: 10) {
            Spacer(minLength: 0)
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: compact ? 28 : 34, weight: .bold))
                .foregroundColor(Theme.cyan)
                .shadow(color: Theme.cyan.opacity(0.6), radius: 12)
            L10n.t(L10n.K.lbLoginTitle)
                .font(.system(size: compact ? 14 : 15, weight: .heavy))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            L10n.t(L10n.K.lbLoginBody)
                .font(.system(size: compact ? 12 : 12.5))
                .foregroundColor(Theme.panelText)
                .multilineTextAlignment(.center)
            if gc.canPresentLogin {
                PrimaryButton(titleKey: L10n.K.lbLoginButton, fontSize: compact ? 13 : 14) {
                    gc.presentLogin()
                }
                .padding(.top, 4)
            }
            Text(verbatim: String(format: L10n.s(L10n.K.lbLocalBest), localBest))
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(Theme.orange)
                .padding(.vertical, 5)
                .padding(.horizontal, 10)
                .background(Capsule().fill(Theme.orange.opacity(0.12)))
                .overlay(Capsule().stroke(Theme.orange.opacity(0.45), lineWidth: 1))
                .padding(.top, 4)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    private func message<Action: View>(icon: String, titleKey: String,
                                       @ViewBuilder action: () -> Action) -> some View {
        VStack(spacing: 10) {
            Spacer(minLength: 0)
            Image(systemName: icon)
                .font(.system(size: compact ? 26 : 30, weight: .bold))
                .foregroundColor(Theme.hudLabel)
            L10n.t(titleKey)
                .font(.system(size: compact ? 13 : 14, weight: .semibold))
                .foregroundColor(Theme.panelText)
                .multilineTextAlignment(.center)
            action()
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Pinned "me" row + footer

    @ViewBuilder
    private var pinnedMe: some View {
        VStack(spacing: 8) {
            Rectangle()
                .fill(LinearGradient(colors: [.clear, Theme.orange.opacity(0.45), .clear],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(height: 1)
            if let me = gc.pages[scope]?.me {
                LeaderboardRowView(row: me, compact: compact)
            } else {
                HStack {
                    L10n.t(L10n.K.lbUnranked)
                        .font(.system(size: compact ? 12 : 13, weight: .semibold))
                        .foregroundColor(Theme.panelText)
                    Spacer()
                    Text(verbatim: String(format: L10n.s(L10n.K.lbLocalBest), localBest))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(Theme.orange)
                }
                .padding(.vertical, compact ? 8 : 10)
                .padding(.horizontal, 10)
                .background(RoundedRectangle(cornerRadius: 9).fill(Theme.orange.opacity(0.08)))
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            if gc.isAuthenticated, let page = gc.pages[scope] {
                Text(verbatim: String(format: L10n.s(L10n.K.lbUpdated),
                                      page.updatedAt.formatted(date: .omitted, time: .shortened)))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(gc.failed.contains(scope) ? Theme.orange : Theme.hudLabel)
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            Button {
                gc.openSystemLeaderboard(scope)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "gamecontroller")
                        .font(.system(size: 10, weight: .bold))
                    L10n.t(L10n.K.lbOpenSystem)
                        .font(.system(size: 11, weight: .bold))
                        .lineLimit(1)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8, weight: .heavy))
                }
                .foregroundColor(Theme.cyan.opacity(0.9))
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Row

struct LeaderboardRowView: View {
    let row: LeaderboardRow
    let compact: Bool

    private var medal: Color? {
        switch row.rank {
        case 1: return Theme.gold
        case 2: return Theme.silver
        case 3: return Theme.bronze
        default: return nil
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            rankBadge.frame(width: 36, alignment: .leading)
            Text(verbatim: row.name)
                .font(.system(size: compact ? 13 : 14, weight: row.isLocal ? .heavy : .semibold))
                .foregroundColor(row.isLocal ? Theme.orange : Theme.hudValue)
                .lineLimit(1)
                .truncationMode(.tail)
            if row.isLocal {
                L10n.t(L10n.K.lbMe)
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundColor(Theme.hudBottom)
                    .padding(.vertical, 2)
                    .padding(.horizontal, 6)
                    .background(Capsule().fill(Theme.orange))
                    .fixedSize()
            }
            Spacer(minLength: 8)
            Text(verbatim: "\(row.score)")
                .font(.system(size: compact ? 14 : 15, weight: .heavy, design: .monospaced))
                .foregroundColor(row.isLocal ? Theme.orange : (medal ?? Theme.cyan))
                .shadow(color: (row.isLocal ? Theme.orange : (medal ?? Theme.cyan)).opacity(0.45), radius: 6)
        }
        .padding(.vertical, compact ? 7 : 9)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(row.isLocal ? Theme.orange.opacity(0.12)
                      : (medal.map { $0.opacity(0.07) } ?? Theme.panelChip.opacity(0.55)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .stroke(row.isLocal ? Theme.orange.opacity(0.55)
                        : (medal.map { $0.opacity(0.35) } ?? Color.clear), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var rankBadge: some View {
        if let medal {
            Text(verbatim: "\(row.rank)")
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .foregroundColor(medal)
                .frame(width: 24, height: 24)
                .background(Circle().fill(medal.opacity(0.16)))
                .overlay(Circle().stroke(medal.opacity(0.85), lineWidth: 1))
                .shadow(color: medal.opacity(0.6), radius: 6)
        } else {
            Text(verbatim: row.rank < 10 ? "0\(row.rank)" : "\(row.rank)")
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .foregroundColor(row.isLocal ? Theme.orange : Theme.hudLabel)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}
