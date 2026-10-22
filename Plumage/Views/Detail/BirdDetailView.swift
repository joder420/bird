import SwiftUI

enum DetailTab: String, CaseIterable, Identifiable {
    case overview, anatomy, behavior, eggs, song, range, notes

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: return "Overview"
        case .anatomy: return "Anatomy"
        case .behavior: return "Behaviour"
        case .eggs: return "Eggs & Nest"
        case .song: return "Song"
        case .range: return "Range"
        case .notes: return "Field Notes"
        }
    }

    var emoji: String {
        switch self {
        case .overview: return "📜"
        case .anatomy: return "🪶"
        case .behavior: return "🧠"
        case .eggs: return "🥚"
        case .song: return "🎵"
        case .range: return "🗺️"
        case .notes: return "✍️"
        }
    }
}

struct BirdDetailView: View {
    let species: BirdSpecies

    @EnvironmentObject private var game: GameState
    @EnvironmentObject private var router: AppRouter
    @ObservedObject private var sound = SoundEngine.shared
    @Environment(\.dismiss) private var dismiss

    @State private var tab: DetailTab = .overview
    @State private var flapping = false
    @State private var heartBurst = 0
    @State private var showCompare = false

    private var isSinging: Bool { sound.singingSpeciesID == species.id }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                hero
                actionRow
                tabPicker
                Group {
                    switch tab {
                    case .overview: OverviewSection(species: species)
                    case .anatomy: AnatomySection(species: species)
                    case .behavior: BehaviorSection(species: species)
                    case .eggs: EggsSection(species: species)
                    case .song: SongSection(species: species)
                    case .range: RangeSection(species: species)
                    case .notes: NotesSection(species: species)
                    }
                }
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                .id(tab)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .background(alignment: .top) {
            LinearGradient(colors: [species.primaryHabitat.tint.opacity(0.55), .clear], startPoint: .top, endPoint: .center)
                .ignoresSafeArea()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(species.name)
                    .font(AppFont.script(24))
                    .foregroundStyle(.white)
                    .skyShadow()
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear {
            game.discover(species)
        }
        .onDisappear {
            if isSinging { sound.stopSong() }
        }
        .sheet(isPresented: $showCompare) {
            CompareView(initialLeft: species).environmentObject(game)
        }
    }

    // MARK: Hero

    private var hero: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(LinearGradient(colors: [species.primaryHabitat.tint.opacity(0.45), Palette.parchment.opacity(0.85)],
                                         startPoint: .top, endPoint: .bottom))
                    .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(Palette.parchmentEdge, lineWidth: 1.5))
                BirdView(appearance: game.appearance(for: species), singing: isSinging, flapping: flapping, padding: 18)
                    .padding(8)
                if heartBurst > 0 {
                    FeatherBurst(colors: [Palette.berry, .pink, Palette.sunrise]).id(heartBurst)
                }
                VStack {
                    HStack {
                        Text(species.group.emoji + " " + species.group.title)
                            .font(AppFont.caps(11))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Palette.parchment.opacity(0.9)))
                            .foregroundStyle(Palette.forest)
                        Spacer()
                        RarityStars(rarity: species.rarity, size: 12)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Palette.parchment.opacity(0.9)))
                    }
                    Spacer()
                    Text("Tap the bird to hear it sing")
                        .font(AppFont.handLight(12))
                        .foregroundStyle(Palette.inkSoft)
                }
                .padding(12)
            }
            .frame(height: 300)
            .contentShape(Rectangle())
            .onTapGesture { sing() }
            .accessibilityElement()
            .accessibilityLabel("Illustration of a \(species.name). Double tap to play its song.")
            .accessibilityAddTraits(.isButton)

            Text(species.name)
                .font(AppFont.display(44))
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
                .lineLimit(2)
                .padding(.top, 6)
            Text(species.scientific)
                .font(AppFont.italic(18))
                .foregroundStyle(Palette.inkSoft)
            HStack(spacing: 8) {
                StatusBadge(status: species.status)
                Text(species.familyCommon)
                    .font(AppFont.body(13))
                    .foregroundStyle(Palette.inkSoft)
                    .lineLimit(1)
            }
        }
        .padding(.top, 4)
    }

    private var actionRow: some View {
        HStack(spacing: 10) {
            Button {
                isSinging ? sound.stopSong() : sing()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isSinging ? "stop.fill" : "play.fill")
                    WaveformView(active: isSinging, color: Palette.parchment, bars: 12, seed: species.seed)
                        .frame(width: 54, height: 18)
                }
            }
            .buttonStyle(WoodButtonStyle(color: Palette.forest, compact: true))
            .accessibilityLabel(isSinging ? "Stop song" : "Play song")

            Button {
                game.toggleFavorite(species)
                if game.isFavorite(species.id) {
                    heartBurst += 1
                    SoundEngine.shared.play(.match)
                }
            } label: {
                Image(systemName: game.isFavorite(species.id) ? "heart.fill" : "heart")
                    .symbolEffect(.bounce, value: game.isFavorite(species.id))
            }
            .buttonStyle(WoodButtonStyle(color: Palette.berry, compact: true))
            .accessibilityLabel(game.isFavorite(species.id) ? "Remove from favourites" : "Add to favourites")

            Button {
                router.openStudio(for: species)
            } label: {
                Image(systemName: "paintbrush.pointed.fill")
            }
            .buttonStyle(WoodButtonStyle(color: Palette.dusk, compact: true))
            .accessibilityLabel("Customise in the Bird Studio")

            Button {
                showCompare = true
            } label: {
                Image(systemName: "scalemass.fill")
            }
            .buttonStyle(WoodButtonStyle(color: Palette.bark, compact: true))
            .accessibilityLabel("Compare with another bird")
        }
    }

    private var tabPicker: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(DetailTab.allCases) { t in
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { tab = t }
                            Haptics.shared.select()
                            SoundEngine.shared.play(.tap)
                            withAnimation { proxy.scrollTo(t.id, anchor: .center) }
                        } label: {
                            Chip(text: t.title, emoji: t.emoji, color: Palette.forest, selected: tab == t)
                        }
                        .buttonStyle(PressableStyle())
                        .id(t.id)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func sing() {
        let duration = sound.playSong(species)
        game.recordSongPlayed(species)
        Haptics.shared.pulse(0.5)
        flapping = true
        runAfter(min(max(duration * 0.4, 0.8), 2.5)) { flapping = false }
    }
}
