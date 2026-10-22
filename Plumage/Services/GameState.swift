import SwiftUI

/// The player's progress: discoveries, XP, feathers, collections, achievements and settings.
/// Every mutation persists immediately to UserDefaults as JSON.
final class GameState: ObservableObject {
    @Published private(set) var save: SaveData
    @Published private(set) var toasts: [Toast] = []
    @Published var levelUpCelebration: Int?

    let db = BirdDatabase.shared
    private let storeKey = "plumage.save.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: storeKey),
           let decoded = try? JSONDecoder().decode(SaveData.self, from: data) {
            save = decoded
        } else {
            save = SaveData()
        }
        registerVisit()
        SoundEngine.shared.apply(settings: save.settings)
        Haptics.shared.enabled = save.settings.hapticsEnabled
    }

    // MARK: - Derived values

    var level: Int { LevelSystem.level(for: save.xp) }
    var levelTitle: String { LevelSystem.title(for: level) }
    var levelProgress: (into: Int, needed: Int, fraction: Double) { LevelSystem.progress(for: save.xp) }
    var settings: AppSettings { save.settings }

    func isDiscovered(_ id: String) -> Bool { save.discovered.contains(id) }
    func isFavorite(_ id: String) -> Bool { save.favorites.contains(id) }

    /// The look shown in the Atlas — the player's custom look if they made one.
    func appearance(for species: BirdSpecies) -> BirdAppearance {
        save.customLooks[species.id] ?? species.appearance
    }

    func hasCustomLook(_ id: String) -> Bool { save.customLooks[id] != nil }

    var companion: Hatchling? {
        if let id = save.companionID, let h = save.aviary.first(where: { $0.id == id }) { return h }
        return save.aviary.last
    }

    var discoveryFraction: Double { Double(save.discovered.count) / Double(max(db.all.count, 1)) }

    var canClaimDaily: Bool {
        guard let last = save.lastDailyClaim else { return true }
        return !Calendar.current.isDateInToday(last)
    }

    // MARK: - Exploration

    func discover(_ species: BirdSpecies) {
        guard !save.discovered.contains(species.id) else { return }
        mutate { $0.discovered.insert(species.id) }
        award(xp: 20, feathers: 5, emoji: "🔍", title: "New species: \(species.name)", subtitle: "+20 XP · +5 🪶")
        SoundEngine.shared.play(.reward)
        Haptics.shared.success()
    }

    func toggleFavorite(_ species: BirdSpecies) {
        mutate {
            if $0.favorites.contains(species.id) { $0.favorites.remove(species.id) } else { $0.favorites.insert(species.id) }
        }
        Haptics.shared.tap()
        evaluateAchievements()
    }

    func recordSongPlayed(_ species: BirdSpecies) {
        let firstTime = !save.stats.songsHeard.contains(species.id)
        mutate {
            $0.stats.songsPlayed += 1
            $0.stats.songsHeard.insert(species.id)
        }
        if firstTime { award(xp: 5, feathers: 1, emoji: "🎵", title: "Song collected", subtitle: "\(species.name) · +5 XP") } else { evaluateAchievements() }
    }

    func recordEggInspected(_ species: BirdSpecies) {
        guard !save.stats.eggsInspected.contains(species.id) else { return }
        mutate { $0.stats.eggsInspected.insert(species.id) }
        award(xp: 4, feathers: 1, emoji: "🥚", title: "Egg catalogued", subtitle: "\(species.name) · +4 XP")
    }

    func recordComparison() {
        mutate { $0.stats.comparisons += 1 }
        award(xp: 3, feathers: 0, emoji: "⚖️", title: "Comparison noted", subtitle: "+3 XP", quiet: true)
    }

    func setNote(_ text: String, for id: String) {
        mutate { $0.notes[id] = text.isEmpty ? nil : text }
    }

    // MARK: - Games

    func recordAnswer(correct: Bool, streak: Int) {
        mutate {
            $0.stats.answersGiven += 1
            if correct { $0.stats.correctAnswers += 1 }
            $0.stats.bestStreak = max($0.stats.bestStreak, streak)
        }
        if correct {
            let bonus = min(streak, 5) * 2
            award(xp: 8 + bonus, feathers: 2, emoji: "✅", title: "Correct!", subtitle: "+\(8 + bonus) XP", quiet: true)
        } else {
            evaluateAchievements()
        }
    }

    func recordQuizFinished(correct: Int, total: Int) {
        let perfect = correct == total && total > 0
        mutate {
            $0.stats.quizzesPlayed += 1
            if perfect { $0.stats.perfectRounds += 1 }
        }
        let feathers = correct * 2 + (perfect ? 15 : 0)
        award(xp: perfect ? 40 : 10, feathers: feathers, emoji: perfect ? "🏆" : "📜",
              title: perfect ? "Perfect round!" : "Round complete",
              subtitle: "\(correct)/\(total) correct · +\(feathers) 🪶")
    }

    func recordMemoryWin(moves: Int) {
        mutate {
            $0.stats.memoryWins += 1
            if $0.stats.bestMemoryMoves == 0 || moves < $0.stats.bestMemoryMoves { $0.stats.bestMemoryMoves = moves }
        }
        let feathers = max(5, 30 - moves)
        award(xp: 30, feathers: feathers, emoji: "🃏", title: "Nest Match cleared!", subtitle: "\(moves) moves · +\(feathers) 🪶")
    }

    /// Hatches an egg of the given species, rolling a colour variant and unique look.
    @discardableResult
    func hatch(_ species: BirdSpecies, guessedRight: Bool) -> Hatchling {
        var rng = SystemRandomNumberGenerator()
        let variant = HatchVariant.roll(using: &rng)
        let base = species.appearance.jittered(using: &rng)
        let rarity = max(species.rarity, variant.rarity)
        let used = Set(save.aviary.map(\.nickname))
        let name = Hatchling.names.filter { !used.contains($0) }.randomElement() ?? Hatchling.names.randomElement()!
        let chick = Hatchling(id: UUID(), speciesID: species.id, nickname: name, variant: variant, rarity: rarity,
                              appearance: variant.apply(to: base), hatchedOn: Date())
        mutate {
            $0.aviary.append(chick)
            $0.stats.hatches += 1
            if variant != .wild { $0.stats.rareHatches += 1 }
            if guessedRight { $0.stats.eggGuessesRight += 1 }
            $0.discovered.insert(species.id)
        }
        let feathers = (guessedRight ? 15 : 3) + (variant == .wild ? 0 : 20)
        award(xp: 25, feathers: feathers, emoji: "🐣", title: "\(name) the \(species.name) hatched!",
              subtitle: variant == .wild ? "+25 XP · +\(feathers) 🪶" : "\(variant.title) variant! · +\(feathers) 🪶")
        return chick
    }

    func rename(_ hatchling: Hatchling, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        mutate { s in
            if let i = s.aviary.firstIndex(where: { $0.id == hatchling.id }) { s.aviary[i].nickname = String(trimmed.prefix(24)) }
        }
    }

    func release(_ hatchling: Hatchling) {
        mutate { s in
            s.aviary.removeAll { $0.id == hatchling.id }
            if s.companionID == hatchling.id { s.companionID = nil }
        }
        toast(Toast(kind: .info, emoji: "🕊️", title: "\(hatchling.nickname) flew free", subtitle: "Safe travels, little one."))
    }

    func setCompanion(_ hatchling: Hatchling) {
        mutate { $0.companionID = hatchling.id }
        toast(Toast(kind: .info, emoji: "🏡", title: "\(hatchling.nickname) is your companion", subtitle: "They'll greet you at the Nest."))
    }

    // MARK: - Studio

    func saveCustomLook(_ appearance: BirdAppearance, for speciesID: String) {
        mutate { $0.customLooks[speciesID] = appearance }
        toast(Toast(kind: .info, emoji: "🖌️", title: "Look applied to the Atlas", subtitle: "Reset it any time in the Studio."))
    }

    func resetLook(for speciesID: String) {
        mutate { $0.customLooks[speciesID] = nil }
    }

    func addCreation(name: String, baseSpeciesID: String, appearance: BirdAppearance) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let creation = Creation(id: UUID(), name: trimmed.isEmpty ? "Untitled bird" : String(trimmed.prefix(32)),
                                baseSpeciesID: baseSpeciesID, appearance: appearance, createdOn: Date())
        mutate {
            $0.creations.insert(creation, at: 0)
            $0.stats.studioSaves += 1
        }
        award(xp: 15, feathers: 3, emoji: "🎨", title: "\"\(creation.name)\" saved", subtitle: "Find it in your Journal · +15 XP")
    }

    func deleteCreation(_ creation: Creation) {
        mutate { $0.creations.removeAll { $0.id == creation.id } }
    }

    func isPaletteUnlocked(_ palette: PlumagePalette) -> Bool {
        palette.cost == 0 || save.unlockedPalettes.contains(palette.id)
    }

    /// Spends feathers to unlock a palette. Returns false if the player can't afford it.
    func unlock(_ palette: PlumagePalette) -> Bool {
        guard !isPaletteUnlocked(palette) else { return true }
        guard save.feathers >= palette.cost else {
            Haptics.shared.warning()
            SoundEngine.shared.play(.fail)
            return false
        }
        mutate {
            $0.feathers -= palette.cost
            $0.unlockedPalettes.insert(palette.id)
        }
        SoundEngine.shared.play(.unlock)
        Haptics.shared.success()
        toast(Toast(kind: .info, emoji: palette.emoji, title: "\(palette.name) palette unlocked", subtitle: "−\(palette.cost) 🪶"))
        return true
    }

    // MARK: - Daily

    func claimDaily() {
        guard canClaimDaily else { return }
        let streakBonus = min(save.stats.visitStreak, 7) * 2
        mutate {
            $0.lastDailyClaim = Date()
            $0.stats.dailyClaims += 1
            $0.discovered.insert(db.birdOfTheDay().id)
        }
        award(xp: 30, feathers: 15 + streakBonus, emoji: "🌅", title: "Daily gift claimed",
              subtitle: "+30 XP · +\(15 + streakBonus) 🪶 (streak bonus \(streakBonus))")
        SoundEngine.shared.play(.reward)
        Haptics.shared.success()
    }

    // MARK: - Settings

    func updateSettings(_ change: (inout AppSettings) -> Void) {
        var s = save.settings
        change(&s)
        guard s != save.settings else { return }
        mutate { $0.settings = s }
        SoundEngine.shared.apply(settings: s)
        Haptics.shared.enabled = s.hapticsEnabled
    }

    func completeOnboarding(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        mutate {
            $0.onboarded = true
            if !trimmed.isEmpty { $0.settings.birderName = String(trimmed.prefix(20)) }
        }
    }

    func resetProgress() {
        let keptSettings = save.settings
        save = SaveData()
        save.settings = keptSettings
        save.onboarded = true
        persist()
        registerVisit()
        toast(Toast(kind: .info, emoji: "🌱", title: "A fresh start", subtitle: "Your field journal is blank again."))
    }

    // MARK: - Toasts

    func toast(_ toast: Toast) {
        toasts.append(toast)
        if toasts.count > 3 { toasts.removeFirst(toasts.count - 3) }
        let id = toast.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) { [weak self] in
            self?.toasts.removeAll { $0.id == id }
        }
    }

    func dismissToast(_ toast: Toast) {
        toasts.removeAll { $0.id == toast.id }
    }

    // MARK: - Internals

    private func mutate(_ change: (inout SaveData) -> Void) {
        change(&save)
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(save) {
            defaults.set(data, forKey: storeKey)
        }
    }

    private func award(xp: Int, feathers: Int, emoji: String, title: String, subtitle: String, quiet: Bool = false) {
        let oldLevel = level
        mutate {
            $0.xp += xp
            $0.feathers += feathers
            $0.stats.feathersEarned += feathers
        }
        if !quiet { toast(Toast(kind: .reward, emoji: emoji, title: title, subtitle: subtitle)) }
        let newLevel = level
        if newLevel > oldLevel {
            levelUpCelebration = newLevel
            SoundEngine.shared.play(.levelUp)
            Haptics.shared.success()
            toast(Toast(kind: .level, emoji: "⭐️", title: "Level \(newLevel): \(LevelSystem.title(for: newLevel))", subtitle: "Your wings grow stronger."))
        }
        evaluateAchievements()
    }

    private func evaluateAchievements() {
        let newlyDone = Achievement.all.filter { save.achievements[$0.id] == nil && $0.isComplete(save, db) }
        guard !newlyDone.isEmpty else { return }
        for achievement in newlyDone {
            mutate { $0.achievements[achievement.id] = Date() }
            toast(Toast(kind: .achievement, emoji: achievement.emoji, title: "Achievement: \(achievement.title)",
                        subtitle: "+\(Achievement.rewardXP) XP · +\(Achievement.rewardFeathers) 🪶"))
        }
        SoundEngine.shared.play(.unlock)
        // Reward after recording so the recursive evaluation sees them as done.
        award(xp: Achievement.rewardXP * newlyDone.count, feathers: Achievement.rewardFeathers * newlyDone.count,
              emoji: "🏅", title: "", subtitle: "", quiet: true)
    }

    private func registerVisit() {
        let cal = Calendar.current
        let today = Date()
        if let last = save.stats.lastVisit {
            if cal.isDate(last, inSameDayAs: today) { return }
            let lastDay = cal.startOfDay(for: last)
            let days = cal.dateComponents([.day], from: lastDay, to: cal.startOfDay(for: today)).day ?? 0
            mutate {
                $0.stats.visitStreak = days == 1 ? $0.stats.visitStreak + 1 : 1
                $0.stats.daysVisited += 1
                $0.stats.lastVisit = today
            }
        } else {
            mutate {
                $0.stats.visitStreak = 1
                $0.stats.daysVisited = 1
                $0.stats.lastVisit = today
            }
        }
        evaluateAchievements()
    }
}
