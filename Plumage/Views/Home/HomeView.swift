import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var game: GameState
    @EnvironmentObject private var router: AppRouter
    @ObservedObject private var sound = SoundEngine.shared

    @State private var showSettings = false
    @State private var activeGame: GameDestination?
    @State private var companionSinging = false
    @State private var giftBurst = 0

    private let db = BirdDatabase.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    header
                    XPBar(light: true)
                        .padding(.horizontal, 4)
                    companionCard
                    dailyCard
                    quickPlay
                    factCard
                    soundscapeCard
                    progressCard
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .navigationDestination(for: BirdSpecies.self) { BirdDetailView(species: $0) }
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView().environmentObject(game)
        }
        .fullScreenCover(item: $activeGame) { destination in
            GameScreen(destination: destination)
                .environmentObject(game)
                .environmentObject(router)
        }
    }

    // MARK: Header

    private var header: some View {
        let phase = DayPhase.current(game.settings.timeOfDay)
        return HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 0) {
                Text(phase.greeting + ",")
                    .font(AppFont.italic(17))
                    .foregroundStyle(.white.opacity(0.95))
                Text(game.settings.birderName)
                    .font(AppFont.display(42))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .skyShadow()
            Spacer()
            VStack(alignment: .trailing, spacing: 8) {
                HStack(spacing: 8) {
                    FeatherBadge(count: game.save.feathers)
                    Button {
                        showSettings = true
                        Haptics.shared.tap()
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color.black.opacity(0.25)))
                    }
                    .accessibilityLabel("Settings")
                }
                if game.save.stats.visitStreak > 1 {
                    Text("🔥 \(game.save.stats.visitStreak)-day streak")
                        .font(AppFont.dataLight(12))
                        .foregroundStyle(.white)
                        .skyShadow()
                }
            }
        }
        .padding(.top, 8)
    }

    // MARK: Companion

    @ViewBuilder
    private var companionCard: some View {
        if let companion = game.companion, let species = db.species(companion.speciesID) {
            HStack(spacing: 12) {
                BirdView(appearance: companion.appearance, singing: companionSinging, phase: 2)
                    .frame(width: 130, height: 110)
                    .onTapGesture { sing(species) }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your companion")
                        .font(AppFont.caps(11))
                        .foregroundStyle(Palette.inkSoft)
                    Text(companion.nickname)
                        .font(AppFont.script(30))
                        .foregroundStyle(Palette.ink)
                    Text("\(companion.variant == .wild ? "" : companion.variant.title + " ")\(species.name)")
                        .font(AppFont.italic(14))
                        .foregroundStyle(Palette.inkSoft)
                    RarityStars(rarity: companion.rarity)
                    Text("Tap to hear them sing")
                        .font(AppFont.handLight(12))
                        .foregroundStyle(Palette.moss)
                }
                Spacer(minLength: 0)
            }
            .parchmentCard(padding: 12)
        } else {
            Button {
                activeGame = .hatchery
            } label: {
                HStack(spacing: 14) {
                    EggArt(egg: db.all[3].egg, seed: 4)
                        .frame(height: 70)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Your nest is empty")
                            .font(AppFont.title(19))
                            .foregroundStyle(Palette.ink)
                        Text("Visit the Hatchery to incubate a mystery egg — your first chick becomes your companion.")
                            .font(AppFont.body(14))
                            .foregroundStyle(Palette.inkSoft)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").foregroundStyle(Palette.bark)
                }
                .parchmentCard()
            }
            .buttonStyle(PressableStyle())
        }
    }

    private func sing(_ species: BirdSpecies) {
        let duration = sound.playSong(species)
        game.recordSongPlayed(species)
        companionSinging = true
        runAfter(max(duration, 1)) { companionSinging = false }
    }

    // MARK: Bird of the day

    private var dailyCard: some View {
        let bird = db.birdOfTheDay()
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("☀️ BIRD OF THE DAY")
                    .font(AppFont.caps(12))
                    .tracking(1.2)
                    .foregroundStyle(Palette.gold)
                Spacer()
                StatusBadge(status: bird.status, compact: true)
            }
            NavigationLink(value: bird) {
                HStack(spacing: 12) {
                    BirdView(appearance: game.appearance(for: bird), phase: 5)
                        .frame(width: 140, height: 120)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(bird.name)
                            .font(AppFont.title(22))
                            .foregroundStyle(Palette.ink)
                            .multilineTextAlignment(.leading)
                        Text(bird.scientific)
                            .font(AppFont.italic(14))
                            .foregroundStyle(Palette.inkSoft)
                        Text(bird.tagline)
                            .font(AppFont.hand(13))
                            .foregroundStyle(Palette.moss)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(PressableStyle())

            if game.canClaimDaily {
                Button {
                    game.claimDaily()
                    giftBurst += 1
                } label: {
                    Label("Claim today's gift", systemImage: "gift.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(WoodButtonStyle(color: Palette.berry))
            } else {
                Text("Gift claimed — come back tomorrow for another.")
                    .font(AppFont.italic(13))
                    .foregroundStyle(Palette.inkSoft)
            }
        }
        .parchmentCard()
        .overlay {
            if giftBurst > 0 {
                FeatherBurst().id(giftBurst)
            }
        }
    }

    // MARK: Quick play

    private var quickPlay: some View {
        VStack(spacing: 10) {
            SectionHeader(title: "Quick play", color: .white)
                .skyShadow()
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(GameDestination.allCases) { destination in
                    Button {
                        SoundEngine.shared.play(.select)
                        activeGame = destination
                    } label: {
                        GameTile(destination: destination)
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
    }

    // MARK: Did you know

    private var factCard: some View {
        TimelineView(.periodic(from: .now, by: 9)) { timeline in
            let index = Int(timeline.date.timeIntervalSinceReferenceDate / 9)
            let bird = db.all[index % db.all.count]
            let fact = bird.facts[(index / db.all.count) % max(bird.facts.count, 1)]
            HStack(alignment: .top, spacing: 12) {
                Text("💡").font(.system(size: 30))
                VStack(alignment: .leading, spacing: 4) {
                    Text("DID YOU KNOW?")
                        .font(AppFont.caps(11))
                        .tracking(1.2)
                        .foregroundStyle(Palette.gold)
                    Text(fact)
                        .font(AppFont.body(15))
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("— \(bird.name)")
                        .font(AppFont.hand(13))
                        .foregroundStyle(Palette.moss)
                }
                Spacer(minLength: 0)
            }
            .id(index)
            .transition(.opacity)
            .animation(.easeInOut, value: index)
        }
        .parchmentCard()
    }

    // MARK: Soundscape

    private var soundscapeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("🎧 SOUNDSCAPE")
                    .font(AppFont.caps(12))
                    .tracking(1.2)
                    .foregroundStyle(Palette.forest)
                Spacer()
                Button {
                    game.updateSettings { $0.soundEnabled.toggle() }
                    Haptics.shared.tap()
                } label: {
                    Image(systemName: game.settings.soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Palette.forest)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Palette.moss.opacity(0.15)))
                }
                .accessibilityLabel(game.settings.soundEnabled ? "Mute all sound" : "Unmute sound")
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Soundscape.allCases) { scape in
                        Button {
                            game.updateSettings {
                                $0.soundscape = scape
                                $0.ambientEnabled = true
                                $0.soundEnabled = true
                            }
                            Haptics.shared.select()
                        } label: {
                            Chip(text: scape.title, emoji: scape.emoji, color: Palette.forest,
                                 selected: game.settings.soundscape == scape && game.settings.ambientEnabled && game.settings.soundEnabled)
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
            }
            if let id = sound.chorusSpeciesID, let bird = db.species(id), game.settings.soundEnabled, game.settings.chorusEnabled {
                HStack(spacing: 6) {
                    WaveformView(active: true, color: Palette.moss, bars: 10, seed: bird.seed)
                        .frame(width: 50, height: 16)
                    Text("Somewhere nearby: \(game.isDiscovered(id) ? bird.name : "an unknown bird")…")
                        .font(AppFont.italic(13))
                        .foregroundStyle(Palette.inkSoft)
                        .lineLimit(1)
                }
            }
        }
        .parchmentCard()
    }

    // MARK: Progress

    private var progressCard: some View {
        HStack(spacing: 16) {
            ZStack {
                RingProgress(fraction: game.discoveryFraction, lineWidth: 10, color: Palette.forest)
                VStack(spacing: 0) {
                    Text("\(game.save.discovered.count)")
                        .font(AppFont.title(26))
                        .foregroundStyle(Palette.ink)
                    Text("of \(db.all.count)")
                        .font(AppFont.dataLight(11))
                        .foregroundStyle(Palette.inkSoft)
                }
            }
            .frame(width: 92, height: 92)
            VStack(alignment: .leading, spacing: 6) {
                Text("Species discovered")
                    .font(AppFont.title(19))
                    .foregroundStyle(Palette.ink)
                Text("\(game.save.achievements.count) of \(Achievement.all.count) achievements · \(game.save.aviary.count) hatched")
                    .font(AppFont.body(14))
                    .foregroundStyle(Palette.inkSoft)
                Button("Explore the Atlas") {
                    withAnimation { router.tab = .atlas }
                }
                .buttonStyle(WoodButtonStyle(compact: true))
            }
            Spacer(minLength: 0)
        }
        .parchmentCard()
    }
}
