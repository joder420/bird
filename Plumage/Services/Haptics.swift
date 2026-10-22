import UIKit

/// Thin wrapper over UIKit feedback generators that respects the player's haptics setting.
final class Haptics {
    static let shared = Haptics()

    var enabled = true

    private let light = UIImpactFeedbackGenerator(style: .light)
    private let medium = UIImpactFeedbackGenerator(style: .medium)
    private let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private let soft = UIImpactFeedbackGenerator(style: .soft)
    private let notifier = UINotificationFeedbackGenerator()
    private let selection = UISelectionFeedbackGenerator()

    private init() {}

    func tap() {
        guard enabled else { return }
        light.impactOccurred()
    }

    func select() {
        guard enabled else { return }
        selection.selectionChanged()
    }

    func thump() {
        guard enabled else { return }
        heavy.impactOccurred()
    }

    func pulse(_ intensity: Double = 0.6) {
        guard enabled else { return }
        soft.impactOccurred(intensity: CGFloat(min(max(intensity, 0), 1)))
    }

    func bump() {
        guard enabled else { return }
        medium.impactOccurred()
    }

    func success() {
        guard enabled else { return }
        notifier.notificationOccurred(.success)
    }

    func warning() {
        guard enabled else { return }
        notifier.notificationOccurred(.warning)
    }

    func error() {
        guard enabled else { return }
        notifier.notificationOccurred(.error)
    }
}
