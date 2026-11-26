import SwiftUI

// MARK: - Leaderboard UI (design v2)
// Full-screen page: segmented scope, top-3 podium, ranked list, and the
// local player's rank pinned at the bottom. Data comes from GameCenterManager.

/// Game-over rank strip: "🌐 Global #128 ↑34 · Friends #3  ›".
struct RankStrip: View {
    let rank: RoundRank
    let compact: Bool
    let action: () -> Void

    var body: some View {
        if rank != .hidden {
            Button(action: action) {
                HStack(spacing: 8) {
                    content
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Theme.text3)
                }
                .padding(.vertical, compact ? 10 : 12)
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.surface2))
                .contentShape(Rectangle())
            }
            .buttonStyle(SoftPressStyle(scale: 0.98))
        }
    }

    private var textFont: Font { .system(size: compact ? 13 : 14, weight: .semibold) }

    @ViewBuilder
    private var content: some View {
        switch rank {
        case .hidden:
            EmptyView()
        case .signedOut:
            icon("person.crop.circle.badge.plus", Theme.primary)
            L10n.t(L10n.K.rankLogin).font(textFont).foregroundColor(Theme.text).lineLimit(1).minimumScaleFactor(0.8)
        case .submitting:
            ProgressView().scaleEffect(0.75).frame(width: 18, height: 18)
            L10n.t(L10n.K.rankSubmitting).font(textFont).foregroundColor(Theme.text2).lineLimit(1)
        case .offline:
            icon("wifi.slash", Theme.text3)
            L10n.t(L10n.K.rankOffline).font(textFont).foregroundColor(Theme.text2).lineLimit(1).minimumScaleFactor(0.8)
        case let .ranked(global, friends, climb):
            icon("globe.asia.australia.fill", Theme.snakeHead)
            if global == nil && friends == nil {
                L10n.t(L10n.K.rankSynced).font(textFont).foregroundColor(Theme.text).lineLimit(1)
            } else {
                HStack(spacing: 6) {
                    if let global {
                        Text(verbatim: String(format: L10n.s(L10n.K.rankGlobal), global))
                            .font(.rounded(compact ? 14 : 15, .bold))
                            .foregroundColor(Theme.text)
                    }
                    if let climb {
                        Text(verbatim: "↑\(climb)")
                            .font(.rounded(compact ? 12 : 13, .bold))
                            .foregroundColor(Theme.player)
                    }
                    if let friends {
                        Text(verbatim: (global == nil ? "" : "· ") + String(format: L10n.s(L10n.K.rankFriends), friends))
                            .font(.rounded(compact ? 13 : 14, .semibold))
                            .foregroundColor(Theme.text2)
                    }
                }
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            }
        }
    }

    private func icon(_ name: String, _ color: Color) -> some View {
        Image(systemName: name)
            .font(.system(size: compact ? 14 : 15, weight: .semibold))
            .foregroundColor(color)
    }
}

// MARK: - Leaderboard page

struct LeaderboardPanel: View {
    @ObservedObject var gc: GameCenterManager
    let m: LayoutMetrics
    let localBest: Int
    let onClose: () -> Void

    @State private var scope: LeaderboardScope = .global

    private var compact: Bool { m.compact }

    var body: some View {
        VStack(spacing: 0) {
            header
            tabs.padding(.top, m.isShortLandscape ? 8 : 14)
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 12)
            if gc.isAuthenticated {
                pinnedMe.padding(.top, 10)
            }
            footer.padding(.top, 10)
        }
        .task(id: "\(scope.rawValue)-\(gc.isAuthenticated)") {
            await gc.load(scope)
        }
    }

    // MARK: Header + tabs

    private var header: some View {
        HStack {
            L10n.t(L10n.K.lbTitle)
                .font(.system(size: m.isShortLandscape ? 22 : (compact ? 28 : 32), weight: .heavy))
                .foregroundColor(Theme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 8)
            RoundIconButton(systemName: "xmark", labelKey: L10n.K.lbClose, size: 34,
                            tint: Theme.text2, action: onClose)
        }
    }

    private var tabs: some View {
        HStack(spacing: 2) {
            ForEach(LeaderboardScope.allCases) { s in
                let on = s == scope
                Button {
                    guard s != scope else { return }
                    Haptics.shared.tap()
                    withAnimation(.easeOut(duration: 0.18)) { scope = s }
                } label: {
                    L10n.t(s.titleKey)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(on ? Theme.text : Theme.text2)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(on ? Theme.surface2 : Color.clear))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.hairline, lineWidth: 1))
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
            let top = Array(page.rows.prefix(3))
            let showPodium = !m.isShortLandscape && top.count == 3 && top.map(\.rank) == [1, 2, 3]
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 14) {
                    if showPodium { Podium(rows: top, compact: compact) }
                    let rest = showPodium ? Array(page.rows.dropFirst(3)) : page.rows
                    if !rest.isEmpty {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(rest.enumerated()), id: \.element.id) { i, row in
                                LeaderboardRowView(row: row, compact: compact)
                                    .overlay(alignment: .top) {
                                        if i > 0 { Theme.hairline.frame(height: 1).padding(.leading, 56) }
                                    }
                            }
                        }
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.surface))
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.hairline, lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
                .padding(.bottom, 4)
            }
            .refreshable { await gc.load(scope, force: true) }
        } else if isLoading || (page == nil && !isFailed) {
            skeleton
        } else if isFailed && page == nil {
            message(icon: "wifi.exclamationmark", titleKey: L10n.K.lbError) {
                SecondaryButton(icon: "arrow.clockwise", titleKey: L10n.K.lbRetry, compact: compact) {
                    Task { await gc.load(scope, force: true) }
                }
                .frame(maxWidth: 200)
            }
        } else {
            message(icon: "trophy",
                    titleKey: scope == .friends ? L10n.K.lbEmptyFriends : L10n.K.lbEmpty) { EmptyView() }
        }
    }

    private var skeleton: some View {
        VStack(spacing: 6) {
            ForEach(0..<8, id: \.self) { i in
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.surface)
                    .frame(height: compact ? 44 : 48)
                    .opacity(1 - Double(i) * 0.1)
            }
            Spacer(minLength: 0)
        }
    }

    private var signIn: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 0)
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: compact ? 30 : 36, weight: .semibold))
                .foregroundColor(Theme.snakeHead)
            L10n.t(L10n.K.lbLoginTitle)
                .font(.system(size: compact ? 16 : 17, weight: .bold))
                .foregroundColor(Theme.text)
                .multilineTextAlignment(.center)
            L10n.t(L10n.K.lbLoginBody)
                .font(.system(size: 14))
                .foregroundColor(Theme.text2)
                .multilineTextAlignment(.center)
            if gc.canPresentLogin {
                PrimaryButton(titleKey: L10n.K.lbLoginButton, compact: true) {
                    gc.presentLogin()
                }
                .frame(maxWidth: 300)
                .padding(.top, 6)
            }
            Pill(text: Text(verbatim: String(format: L10n.s(L10n.K.lbLocalBest), localBest)),
                 icon: "crown.fill", foreground: Theme.onGold, background: Theme.gold)
                .padding(.top, 6)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    private func message<Action: View>(icon: String, titleKey: String,
                                       @ViewBuilder action: () -> Action) -> some View {
        VStack(spacing: 12) {
            Spacer(minLength: 0)
            Image(systemName: icon)
                .font(.system(size: compact ? 28 : 32, weight: .semibold))
                .foregroundColor(Theme.text3)
            L10n.t(titleKey)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Theme.text2)
                .multilineTextAlignment(.center)
            action()
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Pinned "me" row + footer

    @ViewBuilder
    private var pinnedMe: some View {
        HStack(spacing: 12) {
            if let me = gc.pages[scope]?.me {
                Text(verbatim: "#\(me.rank)")
                    .font(.rounded(14, .bold))
                    .monospacedDigit()
                    .foregroundColor(Theme.player)
                    .lineLimit(1)
                    .fixedSize()
                Avatar(name: me.name, size: 34, ring: Theme.player, ringWidth: 1.5)
                VStack(alignment: .leading, spacing: 1) {
                    L10n.t(L10n.K.lbMe)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Theme.text)
                    Text(verbatim: me.name)
                        .font(.system(size: 11))
                        .foregroundColor(Theme.text2)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Text(verbatim: "\(me.score)")
                    .font(.rounded(22, .heavy))
                    .monospacedDigit()
                    .foregroundColor(Theme.player)
            } else {
                L10n.t(L10n.K.lbUnranked)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.text2)
                Spacer()
                Text(verbatim: String(format: L10n.s(L10n.K.lbLocalBest), localBest))
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
                    .foregroundColor(Theme.player)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: compact ? 56 : 62)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.player.opacity(0.12)))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.player.opacity(0.4), lineWidth: 1))
    }

    private var footer: some View {
        HStack(spacing: 8) {
            if gc.isAuthenticated, let page = gc.pages[scope] {
                Text(verbatim: String(format: L10n.s(L10n.K.lbUpdated),
                                      page.updatedAt.formatted(date: .omitted, time: .shortened)))
                    .font(.system(size: 11))
                    .foregroundColor(gc.failed.contains(scope) ? Theme.danger : Theme.text3)
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            Button {
                gc.openSystemLeaderboard(scope)
            } label: {
                HStack(spacing: 4) {
                    L10n.t(L10n.K.lbOpenSystem)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundColor(Theme.text2)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Podium (top 3)

private struct Podium: View {
    let rows: [LeaderboardRow]   // ranks 1, 2, 3
    let compact: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            column(rows[1], color: Theme.silver, height: compact ? 96 : 116, avatar: 48)
            column(rows[0], color: Theme.gold, height: compact ? 118 : 140, avatar: 58)
            column(rows[2], color: Theme.bronze, height: compact ? 84 : 102, avatar: 48)
        }
    }

    private func column(_ row: LeaderboardRow, color: Color, height: CGFloat, avatar: CGFloat) -> some View {
        VStack(spacing: 6) {
            Avatar(name: row.name, size: avatar, ring: color, ringWidth: 2)
            Text(verbatim: row.name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(row.isLocal ? Theme.player : Theme.text)
                .lineLimit(1)
                .truncationMode(.tail)
            VStack(spacing: 2) {
                Text(verbatim: "\(row.rank)")
                    .font(.rounded(compact ? 24 : 28, .heavy))
                    .foregroundColor(color)
                Text(verbatim: "\(row.score)")
                    .font(.rounded(compact ? 15 : 16, .bold))
                    .monospacedDigit()
                    .foregroundColor(Theme.text)
                Spacer(minLength: 0)
            }
            .padding(.top, 10)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LinearGradient(colors: [color.opacity(0.22), color.opacity(0.04)],
                                         startPoint: .top, endPoint: .bottom))
            )
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(color.opacity(0.4), lineWidth: 1))
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
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
        HStack(spacing: 12) {
            Text(verbatim: "\(row.rank)")
                .font(.rounded(15, .bold))
                .monospacedDigit()
                .foregroundColor(medal ?? (row.isLocal ? Theme.player : Theme.text3))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: 30, alignment: .leading)
            Avatar(name: row.name, size: 30, ring: row.isLocal ? Theme.player : (medal ?? Theme.hairline))
            Text(verbatim: row.name)
                .font(.system(size: 15, weight: row.isLocal ? .bold : .semibold))
                .foregroundColor(row.isLocal ? Theme.player : Theme.text)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 8)
            Text(verbatim: "\(row.score)")
                .font(.rounded(17, .bold))
                .monospacedDigit()
                .foregroundColor(row.isLocal ? Theme.player : Theme.text)
        }
        .padding(.horizontal, 14)
        .frame(height: compact ? 46 : 50)
        .background(row.isLocal ? Theme.player.opacity(0.10) : Color.clear)
        .accessibilityElement(children: .combine)
    }
}
