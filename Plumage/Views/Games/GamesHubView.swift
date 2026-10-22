import SwiftUI

enum GameDestination: String, CaseIterable, Identifiable {
    case quiz, hatchery, memory, eggLab

    var id: String { rawValue }

    var title: String {
        switch self {
        case .quiz: return "Birder's Quiz"
        case .hatchery: return "The Hatchery"
        case .memory: return "Nest Match"
        case .eggLab: return "Egg Lab"
        }
    }

    var subtitle: String {
        switch self {
        case .quiz: return "Eggs, songs, silhouettes & clues"
        case .hatchery: return "Incubate a mystery egg"
        case .memory: return "Pair each bird with its egg"
        case .eggLab: return "Sculpt eggs · tour the gallery"
        }
    }

    var emoji: String {
        switch self {
        case .quiz: return "🧠"
        case .hatchery: return "🐣"
        case .memory: return "🃏"
        case .eggLab: return "🔬"
        }
    }

    var color: Color {
        switch self {
        case .quiz: return Palette.lake
        case .hatchery: return Palette.sunrise
        case .memory: return Palette.dusk
        case .eggLab: return Palette.moss
        }
    }
}

struct GameTile: View {
    var destination: GameDestination

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(destination.emoji)
                .font(.system(size: 34))
                .frame(width: 54, height: 54)
                .background(Circle().fill(destination.color.opacity(0.2)))
            Text(destination.title)
                .font(AppFont.title(17))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(destination.subtitle)
                .font(AppFont.body(13))
                .foregroundStyle(Palette.inkSoft)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(minHeight: 34, alignment: .top)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .parchmentCard(padding: 12, cornerRadius: 18, tint: destination.color)
        .accessibilityElement(children: .combine)
    }
}

/// Hosts a game full-screen with a close button.
struct GameScreen: View {
    var destination: GameDestination
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topLeading) {
            NatureBackdrop()
            Group {
                switch destination {
                case .quiz: QuizView()
                case .hatchery: HatcheryView()
                case .memory: MemoryGameView()
                case .eggLab: EggLabView()
                }
            }
            Button {
                SoundEngine.shared.stopSong()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Palette.parchment.opacity(0.95)))
                    .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
            }
            .padding(.leading, 16)
            .padding(.top, 6)
            .accessibilityLabel("Close")
            ToastOverlay()
                .padding(.top, 44)
        }
    }
}

struct GamesHubView: View {
    @EnvironmentObject private var game: GameState
    @EnvironmentObject private var router: AppRouter
    @State private var active: GameDestination?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ScreenTitle(title: "Games", subtitle: "Learn by play — earn feathers & XP")
                XPBar(light: true).padding(.horizontal, 4)
                ForEach(GameDestination.allCases) { destination in
                    Button {
                        SoundEngine.shared.play(.select)
                        active = destination
                    } label: {
                        HStack(spacing: 14) {
                            Text(destination.emoji)
                                .font(.system(size: 40))
                                .frame(width: 70, height: 70)
                                .background(Circle().fill(destination.color.opacity(0.2)))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(destination.title).font(AppFont.title(21)).foregroundStyle(Palette.ink)
                                Text(destination.subtitle).font(AppFont.body(14)).foregroundStyle(Palette.inkSoft)
                                Text(statLine(destination)).font(AppFont.hand(12)).foregroundStyle(destination.color)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(Palette.bark.opacity(0.6))
                        }
                        .parchmentCard(tint: destination.color)
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .fullScreenCover(item: $active) { destination in
            GameScreen(destination: destination)
                .environmentObject(game)
                .environmentObject(router)
        }
    }

    private func statLine(_ destination: GameDestination) -> String {
        let s = game.save.stats
        switch destination {
        case .quiz:
            return s.answersGiven == 0 ? "Not played yet" : "\(s.correctAnswers)/\(s.answersGiven) correct · best streak \(s.bestStreak)"
        case .hatchery:
            return s.hatches == 0 ? "No eggs hatched yet" : "\(s.hatches) hatched · \(s.rareHatches) rare"
        case .memory:
            return s.memoryWins == 0 ? "Not won yet" : "\(s.memoryWins) wins · best \(s.bestMemoryMoves) moves"
        case .eggLab:
            return "\(s.eggsInspected.count) of \(BirdDatabase.shared.all.count) eggs catalogued"
        }
    }
}
