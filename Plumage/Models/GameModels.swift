import Foundation

// MARK: - Collections

enum HatchVariant: String, Codable, CaseIterable {
    case wild, leucistic, melanistic, aurora, golden

    var title: String {
        switch self {
        case .wild: return "Wild type"
        case .leucistic: return "Leucistic"
        case .melanistic: return "Melanistic"
        case .aurora: return "Aurora"
        case .golden: return "Golden"
        }
    }

    var blurb: String {
        switch self {
        case .wild: return "Classic colours, as nature intended."
        case .leucistic: return "A rare loss of pigment leaves ghostly, pale plumage."
        case .melanistic: return "Extra dark pigment paints this bird in shadow."
        case .aurora: return "A shimmering, otherworldly palette — vanishingly rare."
        case .golden: return "Gilded from crown to tail. Legendary."
        }
    }

    var rarity: Rarity {
        switch self {
        case .wild: return .common
        case .leucistic, .melanistic: return .rare
        case .aurora, .golden: return .legendary
        }
    }

    func apply(to appearance: BirdAppearance) -> BirdAppearance {
        switch self {
        case .wild: return appearance
        case .leucistic: return appearance.leucistic
        case .melanistic: return appearance.melanistic
        case .aurora: return appearance.recolored { $0.hueShifted(150).saturated(1.4) }
        case .golden:
            var a = appearance.recolored { c in
                RGBA(0xE8B730).shaded(c.luminance > 0.6 ? 0.35 : (c.luminance < 0.25 ? -0.35 : 0)).mixed(with: c, 0.25)
            }
            a.beak = RGBA(0xF6E3A1)
            return a
        }
    }

    /// Rolls a variant: 2% golden, 3% aurora, 6% leucistic, 6% melanistic.
    static func roll<G: RandomNumberGenerator>(using rng: inout G) -> HatchVariant {
        let r = Double.random(in: 0..<1, using: &rng)
        if r < 0.02 { return .golden }
        if r < 0.05 { return .aurora }
        if r < 0.11 { return .leucistic }
        if r < 0.17 { return .melanistic }
        return .wild
    }
}

struct Hatchling: Codable, Identifiable, Hashable {
    var id: UUID
    var speciesID: String
    var nickname: String
    var variant: HatchVariant
    var rarity: Rarity
    var appearance: BirdAppearance
    var hatchedOn: Date

    static let names = [
        "Pip", "Sunny", "Maple", "Juniper", "Biscuit", "Clover", "Pebble", "Saffron", "Willow", "Echo",
        "Fig", "Indigo", "Kestrel", "Luna", "Mochi", "Nutmeg", "Olive", "Plum", "Quill", "Rumi",
        "Sorrel", "Tansy", "Umber", "Wren", "Yarrow", "Zephyr", "Basil", "Cinder", "Dewdrop", "Ember",
        "Fable", "Gale", "Hazel", "Iris", "Jasper", "Lark", "Moss", "Nimbus", "Orion", "Poppy",
        "Rowan", "Sable", "Thistle", "Velvet", "Whisper", "Acorn", "Bramble", "Chirp", "Drizzle", "Fennel"
    ]
}

struct Creation: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var baseSpeciesID: String
    var appearance: BirdAppearance
    var createdOn: Date
}

// MARK: - Settings

enum Soundscape: String, Codable, CaseIterable, Identifiable {
    case forest, brook, meadow, night, rain, shore

    var id: String { rawValue }

    var title: String {
        switch self {
        case .forest: return "Forest Breeze"
        case .brook: return "Babbling Brook"
        case .meadow: return "Summer Meadow"
        case .night: return "Moonlit Night"
        case .rain: return "Gentle Rain"
        case .shore: return "Ocean Shore"
        }
    }

    var emoji: String {
        switch self {
        case .forest: return "🌲"
        case .brook: return "🏞️"
        case .meadow: return "🌼"
        case .night: return "🌙"
        case .rain: return "🌧️"
        case .shore: return "🐚"
        }
    }

    /// Which habitats supply the background chorus for this soundscape.
    var habitats: [Habitat] {
        switch self {
        case .forest: return [.forest, .woodland, .rainforest]
        case .brook: return [.river, .wetland, .garden]
        case .meadow: return [.grassland, .garden, .savanna, .scrubland]
        case .night: return [.forest, .woodland]
        case .rain: return [.rainforest, .cloudForest, .woodland]
        case .shore: return [.coast, .ocean, .cliffs]
        }
    }
}

enum TimeOfDayMode: String, Codable, CaseIterable, Identifiable {
    case auto, dawn, day, dusk, night
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var emoji: String {
        switch self {
        case .auto: return "🕰️"
        case .dawn: return "🌅"
        case .day: return "☀️"
        case .dusk: return "🌇"
        case .night: return "🌙"
        }
    }
}

struct AppSettings: Codable, Equatable {
    var soundEnabled = true
    var ambientEnabled = true
    var chorusEnabled = true
    var ambientVolume: Double = 0.55
    var chorusVolume: Double = 0.45
    var effectsVolume: Double = 0.8
    var soundscape: Soundscape = .forest
    var hapticsEnabled = true
    var timeOfDay: TimeOfDayMode = .auto
    var reduceMotion = false
    var birderName = "Wanderer"

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings()
        soundEnabled = try c.decodeIfPresent(Bool.self, forKey: .soundEnabled) ?? d.soundEnabled
        ambientEnabled = try c.decodeIfPresent(Bool.self, forKey: .ambientEnabled) ?? d.ambientEnabled
        chorusEnabled = try c.decodeIfPresent(Bool.self, forKey: .chorusEnabled) ?? d.chorusEnabled
        ambientVolume = try c.decodeIfPresent(Double.self, forKey: .ambientVolume) ?? d.ambientVolume
        chorusVolume = try c.decodeIfPresent(Double.self, forKey: .chorusVolume) ?? d.chorusVolume
        effectsVolume = try c.decodeIfPresent(Double.self, forKey: .effectsVolume) ?? d.effectsVolume
        soundscape = (try? c.decodeIfPresent(Soundscape.self, forKey: .soundscape)) ?? d.soundscape
        hapticsEnabled = try c.decodeIfPresent(Bool.self, forKey: .hapticsEnabled) ?? d.hapticsEnabled
        timeOfDay = (try? c.decodeIfPresent(TimeOfDayMode.self, forKey: .timeOfDay)) ?? d.timeOfDay
        reduceMotion = try c.decodeIfPresent(Bool.self, forKey: .reduceMotion) ?? d.reduceMotion
        birderName = try c.decodeIfPresent(String.self, forKey: .birderName) ?? d.birderName
    }

    enum CodingKeys: String, CodingKey {
        case soundEnabled, ambientEnabled, chorusEnabled, ambientVolume, chorusVolume, effectsVolume
        case soundscape, hapticsEnabled, timeOfDay, reduceMotion, birderName
    }
}

// MARK: - Stats & save file

struct Stats: Codable, Equatable {
    var songsPlayed = 0
    var songsHeard: Set<String> = []
    var eggsInspected: Set<String> = []
    var quizzesPlayed = 0
    var correctAnswers = 0
    var answersGiven = 0
    var bestStreak = 0
    var perfectRounds = 0
    var comparisons = 0
    var hatches = 0
    var rareHatches = 0
    var eggGuessesRight = 0
    var studioSaves = 0
    var memoryWins = 0
    var bestMemoryMoves = 0
    var daysVisited = 0
    var visitStreak = 0
    var lastVisit: Date?
    var dailyClaims = 0
    var feathersEarned = 0

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func int(_ k: CodingKeys) throws -> Int { try c.decodeIfPresent(Int.self, forKey: k) ?? 0 }
        func strings(_ k: CodingKeys) throws -> Set<String> { try c.decodeIfPresent(Set<String>.self, forKey: k) ?? [] }
        songsPlayed = try int(.songsPlayed)
        songsHeard = try strings(.songsHeard)
        eggsInspected = try strings(.eggsInspected)
        quizzesPlayed = try int(.quizzesPlayed)
        correctAnswers = try int(.correctAnswers)
        answersGiven = try int(.answersGiven)
        bestStreak = try int(.bestStreak)
        perfectRounds = try int(.perfectRounds)
        comparisons = try int(.comparisons)
        hatches = try int(.hatches)
        rareHatches = try int(.rareHatches)
        eggGuessesRight = try int(.eggGuessesRight)
        studioSaves = try int(.studioSaves)
        memoryWins = try int(.memoryWins)
        bestMemoryMoves = try int(.bestMemoryMoves)
        daysVisited = try int(.daysVisited)
        visitStreak = try int(.visitStreak)
        lastVisit = try c.decodeIfPresent(Date.self, forKey: .lastVisit)
        dailyClaims = try int(.dailyClaims)
        feathersEarned = try int(.feathersEarned)
    }

    enum CodingKeys: String, CodingKey {
        case songsPlayed, songsHeard, eggsInspected, quizzesPlayed, correctAnswers, answersGiven, bestStreak, perfectRounds
        case comparisons, hatches, rareHatches, eggGuessesRight, studioSaves, memoryWins, bestMemoryMoves
        case daysVisited, visitStreak, lastVisit, dailyClaims, feathersEarned
    }
}

struct SaveData: Codable {
    var xp = 0
    var feathers = 30
    var discovered: Set<String> = []
    var favorites: Set<String> = []
    var customLooks: [String: BirdAppearance] = [:]
    var creations: [Creation] = []
    var aviary: [Hatchling] = []
    var companionID: UUID?
    var achievements: [String: Date] = [:]
    var stats = Stats()
    var notes: [String: String] = [:]
    var settings = AppSettings()
    var lastDailyClaim: Date?
    var unlockedPalettes: Set<String> = []
    var onboarded = false

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        xp = try c.decodeIfPresent(Int.self, forKey: .xp) ?? 0
        feathers = try c.decodeIfPresent(Int.self, forKey: .feathers) ?? 30
        discovered = try c.decodeIfPresent(Set<String>.self, forKey: .discovered) ?? []
        favorites = try c.decodeIfPresent(Set<String>.self, forKey: .favorites) ?? []
        customLooks = (try? c.decodeIfPresent([String: BirdAppearance].self, forKey: .customLooks)) ?? [:]
        creations = (try? c.decodeIfPresent([Creation].self, forKey: .creations)) ?? []
        aviary = (try? c.decodeIfPresent([Hatchling].self, forKey: .aviary)) ?? []
        companionID = try c.decodeIfPresent(UUID.self, forKey: .companionID)
        achievements = try c.decodeIfPresent([String: Date].self, forKey: .achievements) ?? [:]
        stats = (try? c.decodeIfPresent(Stats.self, forKey: .stats)) ?? Stats()
        notes = try c.decodeIfPresent([String: String].self, forKey: .notes) ?? [:]
        settings = (try? c.decodeIfPresent(AppSettings.self, forKey: .settings)) ?? AppSettings()
        lastDailyClaim = try c.decodeIfPresent(Date.self, forKey: .lastDailyClaim)
        unlockedPalettes = try c.decodeIfPresent(Set<String>.self, forKey: .unlockedPalettes) ?? []
        onboarded = try c.decodeIfPresent(Bool.self, forKey: .onboarded) ?? false
    }

    enum CodingKeys: String, CodingKey {
        case xp, feathers, discovered, favorites, customLooks, creations, aviary, companionID, achievements
        case stats, notes, settings, lastDailyClaim, unlockedPalettes, onboarded
    }
}

// MARK: - Levels

enum LevelSystem {
    static let thresholds = [0, 60, 150, 280, 450, 680, 960, 1300, 1700, 2200, 2800, 3500, 4300, 5200, 6200]
    static let titles = [
        "Egg", "Hatchling", "Nestling", "Fledgling", "Juvenile", "Songbird", "Birdwatcher",
        "Field Naturalist", "Bird Bander", "Ornithologist", "Curator", "Aviary Keeper",
        "Sky Sage", "Feathered Legend", "Grand Aviarist"
    ]

    /// 1-based level for a given XP total.
    static func level(for xp: Int) -> Int {
        var lvl = 1
        for (i, t) in thresholds.enumerated() where xp >= t { lvl = i + 1 }
        return lvl
    }

    static func title(for level: Int) -> String {
        titles[min(max(level - 1, 0), titles.count - 1)]
    }

    static var maxLevel: Int { thresholds.count }

    /// XP earned within the current level, XP needed for the next, and a 0…1 fraction.
    static func progress(for xp: Int) -> (into: Int, needed: Int, fraction: Double) {
        let lvl = level(for: xp)
        guard lvl < maxLevel else { return (0, 0, 1) }
        let lo = thresholds[lvl - 1], hi = thresholds[lvl]
        let into = xp - lo, needed = hi - lo
        return (into, needed, Double(into) / Double(needed))
    }
}

// MARK: - Toasts

struct Toast: Identifiable, Equatable {
    enum Kind { case reward, achievement, level, info }
    let id = UUID()
    let kind: Kind
    let emoji: String
    let title: String
    let subtitle: String
}
