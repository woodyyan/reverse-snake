import UIKit

/// Centralised haptic feedback for game events.
/// UIFeedbackGenerator is UIKit: all triggers are dispatched on the main
/// thread (CADisplayLink tick, touch handlers and SwiftUI actions already are).
final class Haptics {
    static let shared = Haptics()

    private let light = UIImpactFeedbackGenerator(style: .light)
    private let medium = UIImpactFeedbackGenerator(style: .medium)
    private let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private let soft = UIImpactFeedbackGenerator(style: .soft)
    private let selection = UISelectionFeedbackGenerator()
    private let notification = UINotificationFeedbackGenerator()

    private init() {
        // Wake the Taptic Engine while the start panel is on screen, so the
        // first in-game event has no warm-up latency.
        light.prepare(); medium.prepare(); rigid.prepare(); soft.prepare()
        selection.prepare(); notification.prepare()
    }

    private func onMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread { work() } else { DispatchQueue.main.async(execute: work) }
    }

    private func impact(_ g: UIImpactFeedbackGenerator) {
        onMain {
            g.impactOccurred()
            g.prepare()          // re-arm for the next event
        }
    }

    private func select() {
        onMain {
            self.selection.selectionChanged()
            self.selection.prepare()
        }
    }

    /// UI confirmation: start / restart / pause / resume / sound toggle.
    func tap() { select() }

    /// Countdown 2 / 1.
    func countdownTick() { impact(light) }

    /// Countdown finished, round is live.
    func go() { impact(medium) }

    /// Dash fired.
    func dash() { impact(rigid) }

    /// Crystal collected.
    func collect() { select() }

    /// Snake chopped its own tail to escape a deadlock.
    func tailCut() { impact(soft) }

    /// Collision / caught by the snake.
    func gameOver() {
        onMain {
            self.notification.notificationOccurred(.error)
            self.notification.prepare()
        }
    }
}
