import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case nest, atlas, studio, games, journal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nest: return "Nest"
        case .atlas: return "Atlas"
        case .studio: return "Studio"
        case .games: return "Games"
        case .journal: return "Journal"
        }
    }

    var icon: String {
        switch self {
        case .nest: return "house.fill"
        case .atlas: return "books.vertical.fill"
        case .studio: return "paintpalette.fill"
        case .games: return "gamecontroller.fill"
        case .journal: return "book.closed.fill"
        }
    }
}

/// Shared navigation state so any screen can jump to a tab or open the Studio for a species.
final class AppRouter: ObservableObject {
    @Published var tab: AppTab = .nest
    @Published var studioSpeciesID: String?

    func openStudio(for species: BirdSpecies) {
        studioSpeciesID = species.id
        tab = .studio
    }
}

struct RootView: View {
    @EnvironmentObject private var game: GameState
    @StateObject private var router = AppRouter()
    @State private var showSplash = true

    var body: some View {
        ZStack {
            NatureBackdrop()

            if !game.save.onboarded {
                OnboardingView()
                    .transition(.opacity)
            } else {
                tabContent
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        TabBar(selection: $router.tab)
                    }
                    .transition(.opacity)
            }

            ToastOverlay()

            if let level = game.levelUpCelebration {
                LevelUpOverlay(level: level) {
                    withAnimation { game.levelUpCelebration = nil }
                }
                .transition(.opacity)
                .zIndex(10)
            }

            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(20)
            }
        }
        .environmentObject(router)
        .animation(.easeInOut(duration: 0.35), value: game.save.onboarded)
        .onAppear {
            runAfter(1.8) {
                withAnimation(.easeOut(duration: 0.6)) { showSplash = false }
            }
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch router.tab {
        case .nest: HomeView()
        case .atlas: AtlasView()
        case .studio: StudioView()
        case .games: GamesHubView()
        case .journal: JournalView()
        }
    }
}

/// A floating, parchment tab bar with a leafy selection marker.
struct TabBar: View {
    @Binding var selection: AppTab
    @Namespace private var marker

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                Button {
                    guard selection != tab else { return }
                    Haptics.shared.select()
                    SoundEngine.shared.play(.tap)
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { selection = tab }
                } label: {
                    VStack(spacing: 3) {
                        ZStack {
                            if selection == tab {
                                Capsule()
                                    .fill(Palette.forest)
                                    .frame(width: 52, height: 32)
                                    .matchedGeometryEffect(id: "marker", in: marker)
                            }
                            Image(systemName: tab.icon)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(selection == tab ? Palette.parchment : Palette.bark.opacity(0.75))
                        }
                        .frame(height: 32)
                        Text(tab.title)
                            .font(AppFont.caps(10))
                            .foregroundStyle(selection == tab ? Palette.forest : Palette.inkSoft)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Palette.parchment.opacity(0.96))
                .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(Palette.parchmentEdge, lineWidth: 1.5))
                .shadow(color: .black.opacity(0.22), radius: 14, y: 6)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 4)
    }
}

/// Opening title card with the app name in flowing script.
struct SplashView: View {
    @State private var reveal = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Palette.forest, Color(hex: 0x1E3326)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 6) {
                BirdSnapshot(appearance: BirdDatabase.shared.species("northern-cardinal")?.appearance ?? .standard, showPerch: true)
                    .frame(width: 170, height: 150)
                    .scaleEffect(reveal ? 1 : 0.7)
                    .opacity(reveal ? 1 : 0)
                Text("Plumage")
                    .font(AppFont.display(64))
                    .foregroundStyle(Palette.parchment)
                    .opacity(reveal ? 1 : 0)
                    .offset(y: reveal ? 0 : 12)
                Text("A LIVING ATLAS OF BIRDS")
                    .font(AppFont.caps(13))
                    .tracking(3)
                    .foregroundStyle(Palette.gold)
                    .opacity(reveal ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.9, dampingFraction: 0.7)) { reveal = true }
        }
    }
}
