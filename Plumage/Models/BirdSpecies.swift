import SwiftUI

// MARK: - Taxonomy & ecology vocabularies

enum BirdGroup: String, Codable, CaseIterable, Identifiable {
    case songbird, raptor, owl, hummingbird, seabird, flightless, wader, waterfowl, parrot, tropical, gamebird, woodpecker, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .songbird: return "Songbirds"
        case .raptor: return "Raptors"
        case .owl: return "Owls"
        case .hummingbird: return "Hummingbirds"
        case .seabird: return "Seabirds"
        case .flightless: return "Flightless"
        case .wader: return "Waders"
        case .waterfowl: return "Waterfowl"
        case .parrot: return "Parrots"
        case .tropical: return "Tropical Jewels"
        case .gamebird: return "Ground Birds"
        case .woodpecker: return "Woodpeckers"
        case .other: return "Curiosities"
        }
    }

    var emoji: String {
        switch self {
        case .songbird: return "🎶"
        case .raptor: return "🦅"
        case .owl: return "🦉"
        case .hummingbird: return "🌺"
        case .seabird: return "🌊"
        case .flightless: return "🐾"
        case .wader: return "🦩"
        case .waterfowl: return "🦆"
        case .parrot: return "🦜"
        case .tropical: return "💎"
        case .gamebird: return "🌾"
        case .woodpecker: return "🪵"
        case .other: return "🔮"
        }
    }
}

enum Region: String, Codable, CaseIterable, Identifiable {
    case northAmerica, centralAmerica, southAmerica, europe, africa, asia, oceania, antarctica, oceans, arctic

    var id: String { rawValue }

    var title: String {
        switch self {
        case .northAmerica: return "North America"
        case .centralAmerica: return "Central America"
        case .southAmerica: return "South America"
        case .europe: return "Europe"
        case .africa: return "Africa"
        case .asia: return "Asia"
        case .oceania: return "Australia & Oceania"
        case .antarctica: return "Antarctica"
        case .oceans: return "Open Oceans"
        case .arctic: return "The Arctic"
        }
    }

    var emoji: String {
        switch self {
        case .northAmerica, .centralAmerica, .southAmerica: return "🌎"
        case .europe, .africa: return "🌍"
        case .asia, .oceania: return "🌏"
        case .antarctica: return "🧊"
        case .oceans: return "🌊"
        case .arctic: return "❄️"
        }
    }
}

enum Habitat: String, Codable, CaseIterable, Identifiable {
    case forest, rainforest, woodland, grassland, savanna, wetland, river, coast, ocean, mountains
    case tundra, polar, desert, urban, garden, scrubland, cliffs, cloudForest

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cloudForest: return "Cloud forest"
        default: return rawValue.prefix(1).uppercased() + rawValue.dropFirst()
        }
    }

    var emoji: String {
        switch self {
        case .forest: return "🌲"
        case .rainforest: return "🌴"
        case .woodland: return "🌳"
        case .grassland: return "🌾"
        case .savanna: return "🦒"
        case .wetland: return "🐸"
        case .river: return "🏞️"
        case .coast: return "🏖️"
        case .ocean: return "🌊"
        case .mountains: return "🏔️"
        case .tundra: return "❄️"
        case .polar: return "🧊"
        case .desert: return "🏜️"
        case .urban: return "🏙️"
        case .garden: return "🌻"
        case .scrubland: return "🌵"
        case .cliffs: return "🪨"
        case .cloudForest: return "🌫️"
        }
    }

    /// A sky/ground tint used by habitat-themed backdrops.
    var tint: Color {
        switch self {
        case .forest, .woodland, .garden: return Color(hex: 0x6B8F4E)
        case .rainforest, .cloudForest: return Color(hex: 0x2F6F4F)
        case .grassland, .savanna, .scrubland: return Color(hex: 0xC9A65A)
        case .wetland, .river: return Color(hex: 0x5E9C8F)
        case .coast, .ocean: return Color(hex: 0x3F86B5)
        case .mountains, .cliffs: return Color(hex: 0x7D8597)
        case .tundra, .polar: return Color(hex: 0xA9CBE0)
        case .desert: return Color(hex: 0xD9A066)
        case .urban: return Color(hex: 0x8A8D93)
        }
    }
}

enum Diet: String, Codable, CaseIterable, Identifiable {
    case seeds, insects, fruit, nectar, fish, smallMammals, reptiles, carrion, plants
    case invertebrates, crustaceans, nuts, squid, birds, amphibians, eggs

    var id: String { rawValue }

    var title: String {
        switch self {
        case .smallMammals: return "Small mammals"
        default: return rawValue.prefix(1).uppercased() + rawValue.dropFirst()
        }
    }

    var emoji: String {
        switch self {
        case .seeds: return "🌾"
        case .insects: return "🐛"
        case .fruit: return "🍒"
        case .nectar: return "🌺"
        case .fish: return "🐟"
        case .smallMammals: return "🐭"
        case .reptiles: return "🦎"
        case .carrion: return "🦴"
        case .plants: return "🌿"
        case .invertebrates: return "🪱"
        case .crustaceans: return "🦐"
        case .nuts: return "🌰"
        case .squid: return "🦑"
        case .birds: return "🐦"
        case .amphibians: return "🐸"
        case .eggs: return "🥚"
        }
    }
}

enum ConservationStatus: String, Codable, CaseIterable, Identifiable {
    case LC, NT, VU, EN, CR, EW, EX

    var id: String { rawValue }

    var title: String {
        switch self {
        case .LC: return "Least Concern"
        case .NT: return "Near Threatened"
        case .VU: return "Vulnerable"
        case .EN: return "Endangered"
        case .CR: return "Critically Endangered"
        case .EW: return "Extinct in the Wild"
        case .EX: return "Extinct"
        }
    }

    var color: Color {
        switch self {
        case .LC: return Color(hex: 0x4E8F5A)
        case .NT: return Color(hex: 0x9CB53B)
        case .VU: return Color(hex: 0xE3A833)
        case .EN: return Color(hex: 0xE0702F)
        case .CR: return Color(hex: 0xC8372D)
        case .EW: return Color(hex: 0x6E3B6E)
        case .EX: return Color(hex: 0x2B2420)
        }
    }

    var index: Int { ConservationStatus.allCases.firstIndex(of: self) ?? 0 }

    var blurb: String {
        switch self {
        case .LC: return "Widespread and abundant — for now."
        case .NT: return "Close to qualifying as threatened; worth watching."
        case .VU: return "Facing a high risk of extinction in the wild."
        case .EN: return "Facing a very high risk of extinction in the wild."
        case .CR: return "Facing an extremely high risk of extinction in the wild."
        case .EW: return "Survives only in captivity."
        case .EX: return "No individuals remain."
        }
    }

    var isThreatened: Bool { index >= ConservationStatus.VU.index }
}

enum MigrationPattern: String, Codable, CaseIterable {
    case resident, partial, shortDistance, longDistance, nomadic, altitudinal, oceanic

    var title: String {
        switch self {
        case .resident: return "Resident"
        case .partial: return "Partial migrant"
        case .shortDistance: return "Short-distance migrant"
        case .longDistance: return "Long-distance migrant"
        case .nomadic: return "Nomad"
        case .altitudinal: return "Altitudinal migrant"
        case .oceanic: return "Ocean wanderer"
        }
    }

    var emoji: String {
        switch self {
        case .resident: return "🏡"
        case .partial: return "🧭"
        case .shortDistance: return "↔️"
        case .longDistance: return "🌐"
        case .nomadic: return "🎒"
        case .altitudinal: return "⛰️"
        case .oceanic: return "🌊"
        }
    }

    /// 0…1 — how far the bird typically travels, used for the migration meter.
    var distanceScore: Double {
        switch self {
        case .resident: return 0.05
        case .partial: return 0.4
        case .shortDistance: return 0.35
        case .longDistance: return 1.0
        case .nomadic: return 0.55
        case .altitudinal: return 0.2
        case .oceanic: return 0.85
        }
    }
}

enum NestType: String, Codable, CaseIterable {
    case cup, cavity, burrow, platform, scrape, ledge, ground, mound, mud, dome, feet, parasitic

    var title: String {
        switch self {
        case .cup: return "Woven cup"
        case .cavity: return "Tree cavity"
        case .burrow: return "Burrow"
        case .platform: return "Stick platform"
        case .scrape: return "Ground scrape"
        case .ledge: return "Bare ledge"
        case .ground: return "Ground nest"
        case .mound: return "Mound"
        case .mud: return "Mud cup"
        case .dome: return "Domed nest"
        case .feet: return "On the feet!"
        case .parasitic: return "Someone else's"
        }
    }

    var emoji: String {
        switch self {
        case .cup: return "🪺"
        case .cavity: return "🌳"
        case .burrow: return "🕳️"
        case .platform: return "🪵"
        case .scrape: return "🏜️"
        case .ledge: return "🧗"
        case .ground: return "🍂"
        case .mound: return "⛰️"
        case .mud: return "🧱"
        case .dome: return "🛖"
        case .feet: return "🦶"
        case .parasitic: return "🥷"
        }
    }
}

enum EggShapeKind: String, Codable, CaseIterable, Identifiable {
    case spherical, elliptical, longElliptical, oval, pyriform, conical, biconical

    var id: String { rawValue }

    var title: String {
        switch self {
        case .spherical: return "Spherical"
        case .elliptical: return "Elliptical"
        case .longElliptical: return "Long elliptical"
        case .oval: return "Oval"
        case .pyriform: return "Pyriform"
        case .conical: return "Conical"
        case .biconical: return "Biconical"
        }
    }

    /// Height ÷ width.
    var elongation: Double {
        switch self {
        case .spherical: return 1.08
        case .elliptical: return 1.3
        case .longElliptical: return 1.55
        case .oval: return 1.33
        case .pyriform: return 1.6
        case .conical: return 1.42
        case .biconical: return 1.5
        }
    }

    /// How much narrower the pointed end is than the blunt end.
    var asymmetry: Double {
        switch self {
        case .spherical: return 0.02
        case .elliptical: return 0.06
        case .longElliptical: return 0.05
        case .oval: return 0.13
        case .pyriform: return 0.3
        case .conical: return 0.24
        case .biconical: return 0.0
        }
    }

    /// >1 makes the ends sharper, <1 makes them blunter.
    var pointiness: Double {
        switch self {
        case .spherical: return 0.92
        case .elliptical: return 1.0
        case .longElliptical: return 1.05
        case .oval: return 1.0
        case .pyriform: return 1.2
        case .conical: return 1.25
        case .biconical: return 1.35
        }
    }

    var explanation: String {
        switch self {
        case .spherical: return "Nearly round. Common in cavity nesters like owls and kingfishers, where eggs can't roll away."
        case .elliptical: return "Evenly rounded at both ends, slightly longer than wide."
        case .longElliptical: return "Long and slim with similar ends — often laid by strong, streamlined fliers."
        case .oval: return "The classic egg: one end blunter than the other."
        case .pyriform: return "Pear-shaped, with one sharply pointed end. Stable on sloping cliff ledges."
        case .conical: return "Strongly tapered, so clutches pack neatly point-to-centre — typical of shorebirds."
        case .biconical: return "Pointed at both ends, like a spindle."
        }
    }

    /// Classifies a free-form egg geometry (used in the Egg Lab).
    static func classify(elongation: Double, asymmetry: Double) -> EggShapeKind {
        var best = EggShapeKind.oval
        var bestDistance = Double.infinity
        for kind in allCases {
            let de = (kind.elongation - elongation) / 0.25
            let da = (kind.asymmetry - asymmetry) / 0.1
            let distance = de * de + da * da
            if distance < bestDistance {
                bestDistance = distance
                best = kind
            }
        }
        return best
    }
}

enum EggPattern: String, Codable, CaseIterable, Identifiable {
    case plain, speckled, spotted, blotched, scrawled, capped, streaked

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum SongStyle: String, Codable, CaseIterable {
    case whistle, trill, chirp, warble, hoot, coo, caw, croak, quack, drum, screech, squawk
    case honk, buzz, boom, yodel, clatter, mimic, bugle, scream, hiss, cuckoo, peep

    var title: String { rawValue.capitalized }
}

// MARK: - Supporting value types

/// A numeric range stored as a two-element JSON array: `[min, max]`.
struct Span: Codable, Hashable {
    var min: Double
    var max: Double

    init(_ min: Double, _ max: Double) {
        self.min = min
        self.max = max
    }

    init(from decoder: Decoder) throws {
        var c = try decoder.unkeyedContainer()
        min = try c.decode(Double.self)
        max = try c.decode(Double.self)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.unkeyedContainer()
        try c.encode(min)
        try c.encode(max)
    }

    var mid: Double { (min + max) / 2 }

    /// Human-friendly "12–15" or "12" text.
    func formatted(_ unit: String = "", decimals: Int = 0) -> String {
        let fmt = "%.\(decimals)f"
        let lo = Span.trim(String(format: fmt, min))
        let hi = Span.trim(String(format: fmt, max))
        let core = lo == hi ? lo : "\(lo)–\(hi)"
        return unit.isEmpty ? core : "\(core) \(unit)"
    }

    private static func trim(_ s: String) -> String {
        guard s.contains(".") else { return s }
        var t = s
        while t.hasSuffix("0") { t.removeLast() }
        if t.hasSuffix(".") { t.removeLast() }
        return t
    }
}

struct Traits: Codable, Hashable {
    var flight: Int
    var song: Int
    var smarts: Int
    var stealth: Int
    var social: Int

    var all: [(String, String, Int)] {
        [("Flight", "🪽", flight), ("Song", "🎵", song), ("Smarts", "🧠", smarts), ("Stealth", "🌑", stealth), ("Social", "🤝", social)]
    }

    var total: Int { flight + song + smarts + stealth + social }
}

struct Behavior: Codable, Hashable, Identifiable {
    var icon: String
    var title: String
    var detail: String
    var id: String { title }
}

struct SongSignature: Codable, Hashable {
    var style: SongStyle
    var pitch: Double
    var range: Double
    var notes: Int
    var tempo: Double
    var trill: Double
    var harshness: Double
    var phrases: Int
}

struct CallInfo: Codable, Hashable {
    var description: String
    var mnemonic: String
    var song: SongSignature
}

struct NestInfo: Codable, Hashable {
    var type: NestType
    var description: String
}

struct EggInfo: Codable, Hashable {
    var shape: EggShapeKind
    var pattern: EggPattern
    var base: RGBA
    var marking: RGBA
    var lengthMm: Double
    var widthMm: Double
    var clutch: Span
    var incubationDays: Span
    var description: String

    /// Approximate egg volume relative to a 57 × 44 mm chicken egg.
    var chickenEggs: Double {
        (lengthMm * widthMm * widthMm) / (57 * 44 * 44)
    }
}

// MARK: - Species

struct BirdSpecies: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let scientific: String
    let family: String
    let familyCommon: String
    let order: String
    let group: BirdGroup
    let tagline: String
    let summary: String
    let status: ConservationStatus
    let population: String?
    let regions: [Region]
    let habitats: [Habitat]
    let diet: [Diet]
    let dietNote: String
    let migration: MigrationPattern
    let migrationNote: String
    let lengthCm: Span
    let wingspanCm: Span?
    let weightG: Span
    let lifespanYears: Span?
    let speedKmh: Double?
    let flightless: Bool
    let traits: Traits
    let behaviors: [Behavior]
    let call: CallInfo
    let nest: NestInfo
    let egg: EggInfo
    let facts: [String]
    let appearance: BirdAppearance

    static func == (lhs: BirdSpecies, rhs: BirdSpecies) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    /// A stable seed for this species (Swift's `hashValue` changes every launch).
    var seed: UInt64 { StableHash.fnv1a(id) }

    var primaryHabitat: Habitat { habitats.first ?? .forest }

    /// Game rarity derived from conservation status and how unusual the bird is.
    var rarity: Rarity {
        switch status {
        case .CR, .EW, .EX: return .legendary
        case .EN, .VU: return .rare
        case .NT: return .uncommon
        case .LC: return traits.total >= 34 ? .uncommon : .common
        }
    }

    var weightText: String {
        weightG.max >= 1000 ? Span(weightG.min / 1000, weightG.max / 1000).formatted("kg", decimals: 1) : weightG.formatted("g")
    }

    var lengthText: String { lengthCm.formatted("cm", decimals: 1) }
    var wingspanText: String { wingspanCm?.formatted("cm") ?? (flightless ? "Flightless" : "—") }
    var lifespanText: String { lifespanYears?.formatted("yrs") ?? "Unknown" }
    var speedText: String { speedKmh.map { "\(Int($0)) km/h" } ?? "—" }

    /// Text used for search matching.
    var searchBlob: String {
        ([name, scientific, family, familyCommon, order, group.title, tagline] + habitats.map(\.title) + regions.map(\.title) + diet.map(\.title))
            .joined(separator: " ")
            .lowercased()
    }
}

enum Rarity: String, Codable, CaseIterable, Comparable {
    case common, uncommon, rare, legendary

    var title: String { rawValue.capitalized }

    var color: Color {
        switch self {
        case .common: return Color(hex: 0x8A7F6E)
        case .uncommon: return Color(hex: 0x4E8F5A)
        case .rare: return Color(hex: 0x3E6FB0)
        case .legendary: return Color(hex: 0xC48A1A)
        }
    }

    var stars: Int {
        switch self {
        case .common: return 1
        case .uncommon: return 2
        case .rare: return 3
        case .legendary: return 4
        }
    }

    static func < (lhs: Rarity, rhs: Rarity) -> Bool { lhs.stars < rhs.stars }
}

enum StableHash {
    static func fnv1a(_ string: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return hash
    }
}

/// SplitMix64 — tiny, fast and deterministic, so the same seed always paints the same egg.
struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    /// Uniform Double in 0..<1.
    mutating func unit() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }

    mutating func range(_ lo: Double, _ hi: Double) -> Double {
        lo + (hi - lo) * unit()
    }
}
