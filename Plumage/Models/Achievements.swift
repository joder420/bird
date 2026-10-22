import Foundation

struct Achievement: Identifiable {
    let id: String
    let title: String
    let detail: String
    let emoji: String
    let goal: Int
    let progress: (SaveData, BirdDatabase) -> Int

    func current(_ save: SaveData, _ db: BirdDatabase) -> Int { min(progress(save, db), goal) }
    func isComplete(_ save: SaveData, _ db: BirdDatabase) -> Bool { progress(save, db) >= goal }

    static let rewardXP = 50
    static let rewardFeathers = 25

    static let all: [Achievement] = [
        Achievement(id: "first-flight", title: "First Flight", detail: "Discover your first species.", emoji: "🪶", goal: 1) { s, _ in s.discovered.count },
        Achievement(id: "field-notebook", title: "Field Notebook", detail: "Discover 10 species.", emoji: "📓", goal: 10) { s, _ in s.discovered.count },
        Achievement(id: "seasoned-birder", title: "Seasoned Birder", detail: "Discover 24 species.", emoji: "🔭", goal: 24) { s, _ in s.discovered.count },
        Achievement(id: "grand-aviarist", title: "Grand Aviarist", detail: "Discover every species in the Atlas.", emoji: "🏛️", goal: BirdDatabase.shared.all.count) { s, _ in s.discovered.count },
        Achievement(id: "night-watch", title: "Night Watch", detail: "Discover every owl.", emoji: "🦉", goal: BirdDatabase.shared.inGroup(.owl).count) { s, db in
            db.inGroup(.owl).filter { s.discovered.contains($0.id) }.count
        },
        Achievement(id: "raptor-ranger", title: "Raptor Ranger", detail: "Discover every raptor.", emoji: "🦅", goal: BirdDatabase.shared.inGroup(.raptor).count) { s, db in
            db.inGroup(.raptor).filter { s.discovered.contains($0.id) }.count
        },
        Achievement(id: "guardian", title: "Guardian", detail: "Discover every threatened species.", emoji: "🛡️", goal: BirdDatabase.shared.all.filter { $0.status.isThreatened }.count) { s, db in
            db.all.filter { $0.status.isThreatened && s.discovered.contains($0.id) }.count
        },
        Achievement(id: "globetrotter", title: "Globetrotter", detail: "Discover birds from 8 different regions.", emoji: "🧭", goal: 8) { s, db in
            Set(db.all.filter { s.discovered.contains($0.id) }.flatMap(\.regions)).count
        },
        Achievement(id: "oologist", title: "Oologist", detail: "Study the eggs of 15 species.", emoji: "🥚", goal: 15) { s, _ in s.stats.eggsInspected.count },
        Achievement(id: "song-collector", title: "Song Collector", detail: "Listen to 20 different birdsongs.", emoji: "🎼", goal: 20) { s, _ in s.stats.songsHeard.count },
        Achievement(id: "quiz-whiz", title: "Quiz Whiz", detail: "Answer 25 quiz questions correctly.", emoji: "🧠", goal: 25) { s, _ in s.stats.correctAnswers },
        Achievement(id: "flawless", title: "Flawless", detail: "Finish a quiz round without a mistake.", emoji: "💯", goal: 1) { s, _ in s.stats.perfectRounds },
        Achievement(id: "on-a-roll", title: "On a Roll", detail: "Reach a streak of 10 correct answers.", emoji: "🔥", goal: 10) { s, _ in s.stats.bestStreak },
        Achievement(id: "proud-parent", title: "Proud Parent", detail: "Hatch your first egg.", emoji: "🐣", goal: 1) { s, _ in s.stats.hatches },
        Achievement(id: "hatchery-hero", title: "Hatchery Hero", detail: "Hatch 10 eggs.", emoji: "🪺", goal: 10) { s, _ in s.stats.hatches },
        Achievement(id: "shiny", title: "Shiny!", detail: "Hatch a rare colour variant.", emoji: "✨", goal: 1) { s, _ in s.stats.rareHatches },
        Achievement(id: "egg-whisperer", title: "Egg Whisperer", detail: "Correctly guess 5 mystery eggs before they hatch.", emoji: "🔮", goal: 5) { s, _ in s.stats.eggGuessesRight },
        Achievement(id: "feather-artist", title: "Feather Artist", detail: "Save 3 creations in the Bird Studio.", emoji: "🎨", goal: 3) { s, _ in s.stats.studioSaves },
        Achievement(id: "total-recall", title: "Total Recall", detail: "Win 3 games of Nest Match.", emoji: "🃏", goal: 3) { s, _ in s.stats.memoryWins },
        Achievement(id: "side-by-side", title: "Side by Side", detail: "Compare 5 pairs of birds.", emoji: "⚖️", goal: 5) { s, _ in s.stats.comparisons },
        Achievement(id: "soft-spot", title: "Soft Spot", detail: "Favourite 5 birds.", emoji: "💛", goal: 5) { s, _ in s.favorites.count },
        Achievement(id: "daily-devotion", title: "Daily Devotion", detail: "Visit 7 days in a row.", emoji: "📅", goal: 7) { s, _ in s.stats.visitStreak },
        Achievement(id: "feather-hoard", title: "Feather Hoard", detail: "Earn 500 feathers in total.", emoji: "🪶", goal: 500) { s, _ in s.stats.feathersEarned },
    ]
}

/// Unlockable colour schemes for the Bird Studio.
struct PlumagePalette: Identifiable {
    let id: String
    let name: String
    let emoji: String
    let cost: Int
    let transform: (BirdAppearance) -> BirdAppearance

    static let all: [PlumagePalette] = [
        PlumagePalette(id: "leucistic", name: "Leucistic", emoji: "🤍", cost: 0) { $0.leucistic },
        PlumagePalette(id: "melanistic", name: "Melanistic", emoji: "🖤", cost: 0) { $0.melanistic },
        PlumagePalette(id: "sunset", name: "Sunset", emoji: "🌅", cost: 40) { a in
            a.recolored { $0.mixed(with: RGBA(0xF28A3C).hueShifted($0.luminance * 60 - 20), 0.6) }
        },
        PlumagePalette(id: "frost", name: "Frost", emoji: "❄️", cost: 60) { a in
            a.recolored { $0.mixed(with: RGBA(0xBFE3F5), 0.65) }
        },
        PlumagePalette(id: "ember", name: "Ember", emoji: "🔥", cost: 60) { a in
            a.recolored { c in RGBA(h: 10 + c.luminance * 40, s: 0.85, v: 0.35 + c.luminance * 0.6) }
        },
        PlumagePalette(id: "aurora", name: "Aurora", emoji: "🌌", cost: 80) { HatchVariant.aurora.apply(to: $0) },
        PlumagePalette(id: "midnight", name: "Midnight", emoji: "🌃", cost: 90) { a in
            a.recolored { c in RGBA(h: 230 + c.luminance * 50, s: 0.6, v: 0.18 + c.luminance * 0.55) }
        },
        PlumagePalette(id: "golden", name: "Golden", emoji: "👑", cost: 120) { HatchVariant.golden.apply(to: $0) },
    ]
}
