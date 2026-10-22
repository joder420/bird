import Foundation

/// Runs `action` on the main actor after a delay. Safer than `DispatchQueue.main.asyncAfter`
/// for UI work because the closure is explicitly main-actor isolated.
func runAfter(_ seconds: Double, _ action: @escaping @MainActor () -> Void) {
    Task { @MainActor in
        if seconds > 0 {
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        }
        action()
    }
}
