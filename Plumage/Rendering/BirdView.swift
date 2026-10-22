import SwiftUI

/// A living, procedurally drawn bird. Breathes, blinks, bobs its head, flutters its wings
/// now and then, and opens its beak while singing.
struct BirdView: View {
    var appearance: BirdAppearance
    var animated = true
    var singing = false
    var flapping = false
    var showPerch = true
    /// Offsets the animation clock so neighbouring birds don't move in lockstep.
    var phase: Double = 0
    var padding: CGFloat = 12

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @EnvironmentObject private var game: GameState

    private var shouldAnimate: Bool {
        animated && !systemReduceMotion && !game.settings.reduceMotion
    }

    var body: some View {
        Group {
            if shouldAnimate {
                TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
                    canvas(time: timeline.date.timeIntervalSinceReferenceDate + phase)
                }
            } else {
                canvas(time: 1.0)
            }
        }
        .accessibilityHidden(true)
    }

    private func canvas(time: Double) -> some View {
        let pose = BirdPose.make(time: time, singing: singing, flapping: flapping, showPerch: showPerch, animated: shouldAnimate)
        let look = appearance
        let pad = padding
        return Canvas { context, size in
            BirdRenderer.draw(look, pose: pose, in: context, size: size, padding: pad)
        }
    }
}

/// A flat-colour silhouette of a bird — for undiscovered species and the silhouette quiz.
struct BirdSilhouette: View {
    var appearance: BirdAppearance
    var color: Color = Color(hex: 0x2B2420)
    var padding: CGFloat = 12

    var body: some View {
        Rectangle()
            .fill(color)
            .mask {
                Canvas { context, size in
                    var pose = BirdPose()
                    pose.showPerch = false
                    BirdRenderer.draw(appearance, pose: pose, in: context, size: size, padding: padding)
                }
            }
            .accessibilityHidden(true)
    }
}

/// A static bird rendered without needing the GameState environment (for ImageRenderer snapshots).
struct BirdSnapshot: View {
    var appearance: BirdAppearance
    var showPerch = true
    var padding: CGFloat = 12

    var body: some View {
        Canvas { context, size in
            var pose = BirdPose()
            pose.showPerch = showPerch
            BirdRenderer.draw(appearance, pose: pose, in: context, size: size, padding: padding)
        }
    }
}
