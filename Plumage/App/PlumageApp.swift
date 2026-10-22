import SwiftUI

@main
struct PlumageApp: App {
    @StateObject private var game = GameState()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(game)
                .preferredColorScheme(.light)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { SoundEngine.shared.resume() }
        }
    }
}
