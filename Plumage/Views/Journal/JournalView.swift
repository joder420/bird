import SwiftUI

struct JournalView: View {
    @EnvironmentObject private var game: GameState
    @EnvironmentObject private var router: AppRouter
    @State private var showSettings = false
    @State private var showAviary = false
    @State private var selectedAchievement: Achievement?

    private let db = BirdDatabase.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ScreenTitle(title: "Field Journal", subtitle: "Signed, \(game.settings.birderName)")
                    profileCard
                    statsCard
                    collectionCard
                    achievementsCard
                    aviaryCard
                    creationsCard
                    favoritesCard
                    Button {
                        showSettings = true
                    } label: {
                        Label("Settings & sound", systemImage: "gearshape.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(WoodButtonStyle(color: Palette.bark))
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .navigationDestination(for: BirdSpecies.self) { BirdDetailView(species: $0) }
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $showSettings) { SettingsView().environmentObject(game) }
        .sheet(isPresented: $showAviary) { AviaryView().environmentObject(game) }
        .sheet(item: $selectedAchievement) { a in
            AchievementDetail(achievement: a)
                .environmentObject(game)
                .presentationDetents([.fraction(0.4)])
        }
    }

    // MARK: Profile

    private var profileCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Palette.sunrise, Palette.gold], startPoint: .top, endPoint: .bottom))
                    .frame(width: 84, height: 84)
                    .shadow(color: Palette.gold.opacity(0.5), radius: 8)
                VStack(spacing: -4) {
                    Text("LV").font(AppFont.caps(11))
                    Text("\(game.level)").font(AppFont.title(34))
                }
                .foregroundStyle(Palette.ink)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(game.levelTitle).font(AppFont.display(32)).foregroundStyle(Palette.ink).lineLimit(1).minimumScaleFactor(0.6)
                XPBar()
                HStack(spacing: 8) {
                    FeatherBadge(count: game.save.feathers, dark: true)
                    Text("🔥 \(game.save.stats.visitStreak) day\(game.save.stats.visitStreak == 1 ? "" : "s")")
                        .font(AppFont.data(13))
                        .foregroundStyle(Palette.berry)
                }
            }
        }
        .parchmentCard()
    }

    private var statsCard: some View {
        let s = game.save.stats
        return VStack(spacing: 10) {
            SectionHeader(title: "Ledger")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                InfoTile(emoji: "🔍", label: "Discovered", value: "\(game.save.discovered.count)")
                InfoTile(emoji: "🎵", label: "Songs heard", value: "\(s.songsHeard.count)")
                InfoTile(emoji: "🥚", label: "Eggs studied", value: "\(s.eggsInspected.count)")
                InfoTile(emoji: "✅", label: "Quiz right", value: "\(s.correctAnswers)")
                InfoTile(emoji: "🐣", label: "Hatched", value: "\(s.hatches)")
                InfoTile(emoji: "📅", label: "Days", value: "\(s.daysVisited)")
            }
        }
        .parchmentCard()
    }

    // MARK: Collection

    private var collectionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Collection")
            ForEach(db.groupsInUse) { group in
                let birds = db.inGroup(group)
                let found = birds.filter { game.isDiscovered($0.id) }.count
                HStack(spacing: 10) {
                    Text(group.emoji).frame(width: 24)
                    Text(group.title).font(AppFont.body(15)).foregroundStyle(Palette.ink).frame(width: 120, alignment: .leading)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Palette.bark.opacity(0.12))
                            Capsule().fill(found == birds.count ? Palette.gold : Palette.moss)
                                .frame(width: geo.size.width * CGFloat(found) / CGFloat(max(birds.count, 1)))
                        }
                    }
                    .frame(height: 8)
                    Text("\(found)/\(birds.count)").font(AppFont.data(12)).foregroundStyle(Palette.inkSoft).frame(width: 36, alignment: .trailing)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(group.title): \(found) of \(birds.count) discovered")
            }
        }
        .parchmentCard()
    }

    // MARK: Achievements

    private var achievementsCard: some View {
        VStack(spacing: 10) {
            SectionHeader(title: "Achievements · \(game.save.achievements.count)/\(Achievement.all.count)")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 74), spacing: 10)], spacing: 12) {
                ForEach(Achievement.all) { a in
                    let done = game.save.achievements[a.id] != nil
                    Button {
                        selectedAchievement = a
                    } label: {
                        VStack(spacing: 4) {
                            ZStack {
                                Circle()
                                    .fill(done ? AnyShapeStyle(LinearGradient(colors: [Palette.sunrise, Palette.gold], startPoint: .top, endPoint: .bottom))
                                               : AnyShapeStyle(Palette.bark.opacity(0.12)))
                                    .frame(width: 56, height: 56)
                                Text(a.emoji)
                                    .font(.system(size: 26))
                                    .grayscale(done ? 0 : 1)
                                    .opacity(done ? 1 : 0.4)
                                if !done {
                                    RingProgress(fraction: Double(a.current(game.save, db)) / Double(max(a.goal, 1)), lineWidth: 3, color: Palette.moss)
                                        .frame(width: 60, height: 60)
                                }
                            }
                            Text(a.title)
                                .font(AppFont.bodyBold(10))
                                .foregroundStyle(done ? Palette.ink : Palette.inkSoft)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .frame(height: 26, alignment: .top)
                        }
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel("\(a.title), \(done ? "unlocked" : "locked")")
                }
            }
        }
        .parchmentCard()
    }

    // MARK: Aviary

    private var aviaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionHeader(title: "Aviary")
                Button("See all") { showAviary = true }
                    .font(AppFont.caps(11))
                    .foregroundStyle(Palette.forest)
            }
            if game.save.aviary.isEmpty {
                Text("No hatchlings yet — visit the Hatchery in Games.")
                    .font(AppFont.italic(14))
                    .foregroundStyle(Palette.inkSoft)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(game.save.aviary.suffix(10).reversed()) { h in
                            VStack(spacing: 2) {
                                BirdView(appearance: h.appearance, animated: false, padding: 4)
                                    .frame(width: 80, height: 70)
                                Text(h.nickname).font(AppFont.script(18)).foregroundStyle(Palette.ink).lineLimit(1)
                                RarityStars(rarity: h.rarity, size: 7)
                            }
                            .frame(width: 92)
                        }
                    }
                }
            }
        }
        .parchmentCard()
    }

    // MARK: Creations

    @ViewBuilder
    private var creationsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Studio creations")
            if game.save.creations.isEmpty {
                Text("Design a bird in the Studio and frame it to see it here.")
                    .font(AppFont.italic(14))
                    .foregroundStyle(Palette.inkSoft)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                    ForEach(game.save.creations) { c in
                        VStack(spacing: 2) {
                            BirdView(appearance: c.appearance, animated: false, padding: 6)
                                .frame(height: 100)
                            Text(c.name).font(AppFont.script(20)).foregroundStyle(Palette.ink).lineLimit(1)
                            Text(c.createdOn.formatted(date: .abbreviated, time: .omitted)).font(AppFont.dataLight(10)).foregroundStyle(Palette.inkSoft)
                        }
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Palette.parchment.opacity(0.7)))
                        .contextMenu {
                            if let species = db.species(c.baseSpeciesID) {
                                Button {
                                    router.openStudio(for: species)
                                } label: {
                                    Label("Open base species in Studio", systemImage: "paintbrush")
                                }
                            }
                            Button(role: .destructive) {
                                game.deleteCreation(c)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .parchmentCard()
    }

    // MARK: Favourites

    private var favoritesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Favourites")
            let favorites = db.all.filter { game.isFavorite($0.id) }
            if favorites.isEmpty {
                Text("Tap the heart on any species to keep it close.")
                    .font(AppFont.italic(14))
                    .foregroundStyle(Palette.inkSoft)
            } else {
                ForEach(favorites) { bird in
                    NavigationLink(value: bird) {
                        HStack(spacing: 10) {
                            BirdView(appearance: game.appearance(for: bird), animated: false, showPerch: false, padding: 2)
                                .frame(width: 44, height: 40)
                            Text(bird.name).font(AppFont.bodyBold(16)).foregroundStyle(Palette.ink)
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(Palette.bark.opacity(0.6))
                        }
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
        .parchmentCard()
    }
}

extension Achievement: Hashable {
    static func == (lhs: Achievement, rhs: Achievement) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct AchievementDetail: View {
    let achievement: Achievement
    @EnvironmentObject private var game: GameState

    var body: some View {
        let db = BirdDatabase.shared
        let date = game.save.achievements[achievement.id]
        let current = achievement.current(game.save, db)
        VStack(spacing: 10) {
            Text(achievement.emoji).font(.system(size: 54)).grayscale(date == nil ? 1 : 0)
            Text(achievement.title).font(AppFont.display(34)).foregroundStyle(Palette.ink)
            Text(achievement.detail).font(AppFont.body(16)).foregroundStyle(Palette.inkSoft)
            if let date {
                Text("Unlocked \(date.formatted(date: .long, time: .omitted))").font(AppFont.hand(15)).foregroundStyle(Palette.forest)
            } else {
                ProgressView(value: Double(current), total: Double(max(achievement.goal, 1)))
                    .tint(Palette.moss)
                    .padding(.horizontal, 40)
                Text("\(current) / \(achievement.goal)").font(AppFont.data(14)).foregroundStyle(Palette.ink)
                Text("Reward: +\(Achievement.rewardXP) XP · +\(Achievement.rewardFeathers) 🪶").font(AppFont.dataLight(12)).foregroundStyle(Palette.inkSoft)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.parchment.ignoresSafeArea())
    }
}
