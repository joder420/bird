import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var game: GameState
    @State private var page = 0
    @State private var name = ""
    @FocusState private var nameFocused: Bool

    private let showcase = ["scarlet-macaw", "atlantic-puffin", "barn-owl"]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                welcome.tag(0)
                features.tag(1)
                naming.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button(page < 2 ? "Next" : "Begin the Journey") {
                if page < 2 {
                    withAnimation { page += 1 }
                    SoundEngine.shared.play(.select)
                } else {
                    nameFocused = false
                    SoundEngine.shared.play(.success)
                    Haptics.shared.success()
                    game.completeOnboarding(name: name)
                }
            }
            .buttonStyle(WoodButtonStyle())
            .padding(.bottom, 24)
        }
    }

    private var welcome: some View {
        VStack(spacing: 18) {
            Spacer()
            Text("Welcome to")
                .font(AppFont.italic(20))
                .foregroundStyle(.white)
                .skyShadow()
            Text("Plumage")
                .font(AppFont.display(72))
                .foregroundStyle(.white)
                .skyShadow()
            HStack(spacing: -20) {
                ForEach(Array(showcase.enumerated()), id: \.offset) { index, id in
                    if let species = BirdDatabase.shared.species(id) {
                        BirdView(appearance: species.appearance, phase: Double(index) * 1.3, padding: 4)
                            .frame(width: 120, height: 120)
                    }
                }
            }
            Text("A living field journal of the world's birds — their songs, eggs, colours and curious lives.")
                .font(AppFont.body(17))
                .multilineTextAlignment(.center)
                .foregroundStyle(Palette.ink)
                .parchmentCard()
                .padding(.horizontal, 24)
            Spacer()
            Spacer()
        }
    }

    private var features: some View {
        VStack(spacing: 14) {
            Spacer()
            Text("Your field kit")
                .font(AppFont.display(48))
                .foregroundStyle(.white)
                .skyShadow()
            VStack(alignment: .leading, spacing: 14) {
                featureRow("📚", "The Atlas", "48 species with anatomy, behaviour, eggs, nests, songs and ranges.")
                featureRow("🎨", "Bird Studio", "Repaint any bird, reshape its beak, crest and tail, and save your creations.")
                featureRow("🪺", "Hatchery", "Incubate mystery eggs and raise rare colour variants.")
                featureRow("🎵", "Living sound", "Every song is synthesised live, over ambient forest, brook and shore.")
                featureRow("🏆", "Quests", "Quizzes, Nest Match, achievements, levels and feathers to earn.")
            }
            .parchmentCard()
            .padding(.horizontal, 20)
            Spacer()
            Spacer()
        }
    }

    private func featureRow(_ emoji: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(emoji).font(.system(size: 28))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(AppFont.title(18)).foregroundStyle(Palette.ink)
                Text(detail).font(AppFont.body(14)).foregroundStyle(Palette.inkSoft)
            }
        }
    }

    private var naming: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("Sign your journal")
                .font(AppFont.display(46))
                .foregroundStyle(.white)
                .skyShadow()
            VStack(spacing: 14) {
                Text("What should we call you, birder?")
                    .font(AppFont.italic(17))
                    .foregroundStyle(Palette.inkSoft)
                TextField("Your name", text: $name)
                    .font(AppFont.script(34))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Palette.ink)
                    .focused($nameFocused)
                    .submitLabel(.done)
                    .padding(.vertical, 6)
                    .overlay(alignment: .bottom) { Rectangle().fill(Palette.bark.opacity(0.4)).frame(height: 1) }
                SectionHeader(title: "Choose your soundscape")
                    .padding(.top, 6)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
                    ForEach(Soundscape.allCases) { scape in
                        Button {
                            game.updateSettings { $0.soundscape = scape }
                            Haptics.shared.select()
                        } label: {
                            VStack(spacing: 2) {
                                Text(scape.emoji).font(.system(size: 24))
                                Text(scape.title).font(AppFont.bodyBold(12)).foregroundStyle(Palette.ink).lineLimit(1).minimumScaleFactor(0.7)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 12).fill(game.settings.soundscape == scape ? Palette.moss.opacity(0.3) : Palette.parchment.opacity(0.6)))
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(game.settings.soundscape == scape ? Palette.forest : Palette.parchmentEdge, lineWidth: 1.5))
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
            }
            .parchmentCard()
            .padding(.horizontal, 20)
            Spacer()
            Spacer()
        }
    }
}
