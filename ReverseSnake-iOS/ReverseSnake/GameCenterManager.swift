import Foundation
import GameKit
import SwiftUI
import UIKit

// MARK: - Game Center leaderboard
// Apple-hosted global ranking: no backend, no account system, no name entry
// (players appear under their Game Center nickname). Game Center is strictly
// optional — every failure degrades to the local best in UserDefaults and
// nothing here can block or interrupt a round.
//
// App Store Connect must define the two IDs below (see README):
//   snakefeast.best.alltime  classic leaderboard, high-score-first
//   snakefeast.best.weekly   recurring leaderboard, weekly reset

enum LeaderboardScope: String, CaseIterable, Identifiable {
    case global, friends, weekly
    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .global: return L10n.K.lbTabGlobal
        case .friends: return L10n.K.lbTabFriends
        case .weekly: return L10n.K.lbTabWeekly
        }
    }

    var leaderboardID: String {
        self == .weekly ? GameCenterManager.Config.weeklyID : GameCenterManager.Config.allTimeID
    }

    var playerScope: GKLeaderboard.PlayerScope { self == .friends ? .friendsOnly : .global }
}

struct LeaderboardRow: Identifiable, Equatable {
    let id: String
    let rank: Int
    let name: String
    let score: Int
    let isLocal: Bool
}

struct LeaderboardPage: Equatable {
    var rows: [LeaderboardRow]
    var me: LeaderboardRow?
    var total: Int
    var updatedAt: Date
}

/// State of the rank strip on the game-over panel.
enum RoundRank: Equatable {
    case hidden
    case signedOut
    case submitting
    case offline
    /// nil ranks = submitted but the rank could not be read back yet.
    case ranked(global: Int?, friends: Int?, climb: Int?)
}

@MainActor
final class GameCenterManager: NSObject, ObservableObject {
    static let shared = GameCenterManager()

    enum Config {
        static let allTimeID = "snakefeast.best.alltime"
        static let weeklyID = "snakefeast.best.weekly"
        static let pageSize = 50          // GameKit allows up to 100 per request
        static let cacheTTL: TimeInterval = 60
    }

    enum AuthState: Equatable { case unknown, needsLogin, authenticated, unavailable }

    @Published private(set) var auth: AuthState = .unknown
    @Published private(set) var pages: [LeaderboardScope: LeaderboardPage] = [:]
    @Published private(set) var loading: Set<LeaderboardScope> = []
    @Published private(set) var failed: Set<LeaderboardScope> = []
    @Published private(set) var roundRank: RoundRank = .hidden

    var isAuthenticated: Bool { auth == .authenticated }
    /// GameKit only hands out a sign-in sheet once per launch; after the player
    /// cancels it they must sign in from iOS Settings instead.
    var canPresentLogin: Bool { loginController != nil }

    private var loginController: UIViewController?
    private var autoLoginAllowed = true
    private var autoLoginShown = false
    private var started = false
    private var localBest = 0
    private var lastGlobalRank: Int?
    private var roundToken: UUID?
    private var boards: [String: GKLeaderboard] = [:]
    private let defaults = UserDefaults.standard
    private let pendingKey = "gc-pending-score"

    // MARK: Authentication

    /// Call once at launch. Authentication runs silently in the background.
    func start(localBest: Int) {
        self.localBest = max(self.localBest, localBest)
        guard !started else { return }
        started = true
        #if DEBUG
        if let mode = DebugMock.mode { applyMock(mode); return }
        #endif
        GKLocalPlayer.local.authenticateHandler = { [weak self] controller, _ in
            Task { @MainActor in self?.handleAuth(controller) }
        }
    }

    private func handleAuth(_ controller: UIViewController?) {
        if let controller {
            loginController = controller
            auth = .needsLogin
            if autoLoginAllowed && !autoLoginShown { presentLogin() }
            return
        }
        loginController = nil
        pages = [:]
        failed = []
        lastGlobalRank = nil
        if GKLocalPlayer.local.isAuthenticated {
            auth = .authenticated
            Task { await syncAfterSignIn() }
        } else {
            // Cancelled, restricted (parental controls / child account) or offline.
            auth = .unavailable
        }
    }

    /// Only the ready panel may auto-present the sign-in sheet — never mid-round.
    func setAutoLoginAllowed(_ allowed: Bool) {
        autoLoginAllowed = allowed
        if allowed && !autoLoginShown && loginController != nil { presentLogin() }
    }

    func presentLogin() {
        guard let controller = loginController,
              controller.presentingViewController == nil,
              let host = Self.topViewController() else { return }
        autoLoginShown = true
        host.present(controller, animated: true)
    }

    // MARK: Scores

    /// Game over: submit the round to both boards, then read back the rank.
    func reportRound(score: Int, best: Int) {
        localBest = max(localBest, best)
        let token = UUID()
        roundToken = token
        #if DEBUG
        if DebugMock.mode != nil { roundRank = auth == .authenticated ? .ranked(global: 128, friends: 3, climb: 34) : .signedOut; return }
        #endif
        switch auth {
        case .unknown: roundRank = .hidden; return
        case .needsLogin, .unavailable: roundRank = .signedOut; return
        case .authenticated: roundRank = .submitting
        }

        Task {
            if score > 0 {
                let ok = await submit(score, to: [Config.allTimeID, Config.weeklyID])
                if !ok {
                    defaults.set(max(score, defaults.integer(forKey: pendingKey)), forKey: pendingKey)
                    if roundToken == token { roundRank = .offline }
                    return
                }
                pages = [:]   // a new score invalidates every cached page
            }
            let ranks = await fetchMyRanks()
            guard roundToken == token else { return }
            let global = ranks?.global
            var climb: Int?
            if let global, let last = lastGlobalRank, global < last { climb = last - global }
            if let global { lastGlobalRank = global }
            roundRank = .ranked(global: global, friends: ranks?.friends, climb: climb)
        }
    }

    /// New round started: hide the previous round's rank strip.
    func clearRound() {
        roundToken = nil
        roundRank = .hidden
    }

    /// Foreground: resend a score that failed while offline.
    func retryPending() {
        guard auth == .authenticated else { return }
        let pending = defaults.integer(forKey: pendingKey)
        guard pending > 0 else { return }
        Task {
            if await submit(pending, to: [Config.allTimeID, Config.weeklyID]) {
                defaults.removeObject(forKey: pendingKey)
                pages = [:]
            }
        }
    }

    private func syncAfterSignIn() async {
        let pending = defaults.integer(forKey: pendingKey)
        if pending > 0, await submit(pending, to: [Config.allTimeID, Config.weeklyID]) {
            defaults.removeObject(forKey: pendingKey)
        }
        // Backfill the best set before Game Center was wired in (or while signed
        // out). The all-time board keeps only the player's highest score.
        if localBest > pending, localBest > 0 {
            _ = await submit(localBest, to: [Config.allTimeID])
        }
        lastGlobalRank = await fetchMyRanks()?.global
    }

    private func submit(_ score: Int, to ids: [String]) async -> Bool {
        do {
            try await GKLeaderboard.submitScore(score, context: 0,
                                                player: GKLocalPlayer.local,
                                                leaderboardIDs: ids)
            return true
        } catch {
            return false
        }
    }

    private func fetchMyRanks() async -> (global: Int?, friends: Int?)? {
        guard let board = await leaderboard(Config.allTimeID) else { return nil }
        do {
            let one = NSRange(location: 1, length: 1)
            let global = try await board.loadEntries(for: .global, timeScope: .allTime, range: one)
            let friends = try? await board.loadEntries(for: .friendsOnly, timeScope: .allTime, range: one)
            // A friends board with only the local player on it is not a ranking.
            var friendRank: Int?
            if let friends, friends.2 > 1 { friendRank = friends.0?.rank }
            return (global.0?.rank, friendRank)
        } catch {
            return nil
        }
    }

    // MARK: Leaderboard pages

    func load(_ scope: LeaderboardScope, force: Bool = false) async {
        guard auth == .authenticated else { return }
        #if DEBUG
        if DebugMock.mode != nil { return }
        #endif
        if !force, !failed.contains(scope), let page = pages[scope],
           Date().timeIntervalSince(page.updatedAt) < Config.cacheTTL { return }
        guard !loading.contains(scope) else { return }
        loading.insert(scope)
        defer { loading.remove(scope) }

        guard let board = await leaderboard(scope.leaderboardID) else {
            failed.insert(scope)
            return
        }
        do {
            // timeScope is ignored by recurring boards (they return the current week).
            let (me, entries, total) = try await board.loadEntries(
                for: scope.playerScope, timeScope: .allTime,
                range: NSRange(location: 1, length: Config.pageSize))
            let localID = GKLocalPlayer.local.gamePlayerID
            pages[scope] = LeaderboardPage(rows: entries.map { Self.row($0, localID: localID) },
                                           me: me.map { Self.row($0, localID: localID) },
                                           total: total,
                                           updatedAt: Date())
            failed.remove(scope)
        } catch {
            failed.insert(scope)
        }
    }

    private func leaderboard(_ id: String) async -> GKLeaderboard? {
        if let cached = boards[id] { return cached }
        guard let board = try? await GKLeaderboard.loadLeaderboards(IDs: [id]).first else { return nil }
        boards[id] = board
        return board
    }

    private static func row(_ entry: GKLeaderboard.Entry, localID: String) -> LeaderboardRow {
        let isLocal = entry.player.gamePlayerID == localID
        return LeaderboardRow(id: entry.player.gamePlayerID,
                              rank: entry.rank,
                              name: isLocal ? entry.player.alias : entry.player.displayName,
                              score: entry.score,
                              isLocal: isLocal)
    }

    // MARK: System UI

    /// "Open in Game Center": iOS 26 routes this to the Games app overlay.
    func openSystemLeaderboard(_ scope: LeaderboardScope) {
        if #available(iOS 18.0, *) {
            GKAccessPoint.shared.trigger(leaderboardID: scope.leaderboardID,
                                         playerScope: scope.playerScope,
                                         timeScope: .allTime) {}
        } else {
            guard let host = Self.topViewController() else { return }
            let vc = GKGameCenterViewController(leaderboardID: scope.leaderboardID,
                                                playerScope: scope.playerScope,
                                                timeScope: .allTime)
            vc.gameCenterDelegate = self
            host.present(vc, animated: true)
        }
    }

    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let windows = scenes.flatMap { $0.windows }
        var top = (windows.first { $0.isKeyWindow } ?? windows.first)?.rootViewController
        while let next = top?.presentedViewController { top = next }
        return top
    }
}

extension GameCenterManager: GKGameCenterControllerDelegate {
    nonisolated func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        DispatchQueue.main.async { gameCenterViewController.dismiss(animated: true) }
    }
}

// MARK: - Debug mock (DEBUG builds only)
// Simulator Game Center has no data, so UI can be checked with launch args:
//   -GCMock ranked      signed in, 50 fake rows, rank strip "#128 ↑34 · #3"
//   -GCMock signedout   signed-out states
//   -GCShowBoard YES    open the leaderboard panel at launch
//   -GCDebugOver YES    jump straight to the game-over panel

#if DEBUG
enum DebugMock {
    static var mode: String? { UserDefaults.standard.string(forKey: "GCMock") }
    static var showBoard: Bool { UserDefaults.standard.bool(forKey: "GCShowBoard") }
    static var forceOver: Bool { UserDefaults.standard.bool(forKey: "GCDebugOver") }
}

extension GameCenterManager {
    fileprivate func applyMock(_ mode: String) {
        guard mode == "ranked" else { auth = .unavailable; return }
        auth = .authenticated
        let names = ["Neo", "小白", "Ada", "Kai", "夜行者", "Luna", "Max", "阿杰", "Orion", "青柠",
                     "Zed", "Momo", "风之子", "Rex", "Iris", "老王", "Nova", "Sora", "鲸落", "Echo"]
        func rows(_ top: Int, _ step: Int) -> [LeaderboardRow] {
            (1...Config.pageSize).map { i in
                LeaderboardRow(id: "p\(i)", rank: i, name: names[(i - 1) % names.count] + (i > 20 ? " \(i)" : ""),
                               score: max(1, top - (i - 1) * step - (i % 3)), isLocal: false)
            }
        }
        let me = LeaderboardRow(id: "me", rank: 128, name: "Woody", score: max(localBest, 42), isLocal: true)
        var friends = Array(rows(156, 9).prefix(6))
        friends.insert(LeaderboardRow(id: "me", rank: 3, name: "Woody", score: 142, isLocal: true), at: 2)
        friends = friends.enumerated().map { i, r in
            LeaderboardRow(id: r.id, rank: i + 1, name: r.name, score: r.score, isLocal: r.isLocal)
        }
        let now = Date()
        pages = [
            .global: LeaderboardPage(rows: rows(312, 5), me: me, total: 18_240, updatedAt: now),
            .friends: LeaderboardPage(rows: friends, me: friends[2], total: friends.count, updatedAt: now),
            .weekly: LeaderboardPage(rows: [], me: nil, total: 0, updatedAt: now)
        ]
    }
}
#endif
