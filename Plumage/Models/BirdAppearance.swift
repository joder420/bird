import Foundation

// MARK: - Feature vocabularies

enum BeakShape: String, Codable, CaseIterable, Identifiable {
    case conical, needle, hooked, parrot, dagger, flat, decurved, pouch, shoe, toucan, deep, tiny, bent

    var id: String { rawValue }

    var title: String {
        switch self {
        case .conical: return "Seed-cracker"
        case .needle: return "Nectar needle"
        case .hooked: return "Raptor hook"
        case .parrot: return "Nutcracker"
        case .dagger: return "Dagger"
        case .flat: return "Dabbler"
        case .decurved: return "Probe"
        case .pouch: return "Pouch"
        case .shoe: return "Clog"
        case .toucan: return "Banana"
        case .deep: return "Sea parrot"
        case .tiny: return "Gape"
        case .bent: return "Filter"
        }
    }

    /// What a beak like this is built to do — shown in the Anatomy tab.
    var purpose: String {
        switch self {
        case .conical: return "A short, thick cone that cracks seeds with crushing force."
        case .needle: return "A long, slender tube that reaches deep into flowers for nectar."
        case .hooked: return "A sharp, down-curved hook for tearing meat."
        case .parrot: return "A massive curved bill that cracks nuts and doubles as a third foot for climbing."
        case .dagger: return "A straight spear for stabbing or seizing fish and prey."
        case .flat: return "A broad, flat bill that strains food from water and mud."
        case .decurved: return "A long, down-curved probe for pulling food from soil, crevices or flowers."
        case .pouch: return "A long bill with a stretchy pouch that scoops fish and water."
        case .shoe: return "An enormous, hook-tipped bill that engulfs large prey whole."
        case .toucan: return "A huge, lightweight bill for reaching fruit and shedding heat."
        case .deep: return "A tall, flattened bill that holds a row of fish crosswise."
        case .tiny: return "A small bill with a wide gape — ideal for swallowing prey whole or catching insects in flight."
        case .bent: return "A sharply bent bill lined with comb-like plates for filter-feeding upside-down."
        }
    }

    /// How far the beak extends beyond the head, in head radii (for framing).
    var reach: Double {
        switch self {
        case .conical: return 1.0
        case .needle: return 2.6
        case .hooked: return 1.0
        case .parrot: return 1.1
        case .dagger: return 2.1
        case .flat: return 1.5
        case .decurved: return 2.2
        case .pouch: return 2.9
        case .shoe: return 1.6
        case .toucan: return 2.9
        case .deep: return 1.0
        case .tiny: return 0.5
        case .bent: return 1.7
        }
    }
}

enum CrestStyle: String, Codable, CaseIterable, Identifiable {
    case none, pointed, tufts, fan, plumes, crown, curl
    var id: String { rawValue }
    var title: String {
        switch self {
        case .none: return "None"
        case .pointed: return "Pointed"
        case .tufts: return "Ear tufts"
        case .fan: return "Fan"
        case .plumes: return "Plumes"
        case .crown: return "Crown"
        case .curl: return "Topknot"
        }
    }
}

enum TailStyle: String, Codable, CaseIterable, Identifiable {
    case short, fan, forked, long, pointed, streamers, train, lyre
    var id: String { rawValue }
    var title: String {
        switch self {
        case .short: return "Short"
        case .fan: return "Fan"
        case .forked: return "Forked"
        case .long: return "Long"
        case .pointed: return "Wedge"
        case .streamers: return "Streamers"
        case .train: return "Train"
        case .lyre: return "Lyre"
        }
    }
    /// Base length in renderer units, before the tailLength multiplier.
    var baseLength: Double {
        switch self {
        case .short: return 34
        case .fan: return 55
        case .forked: return 70
        case .long: return 100
        case .pointed: return 62
        case .streamers: return 120
        case .train: return 150
        case .lyre: return 130
        }
    }
}

enum WingPattern: String, Codable, CaseIterable, Identifiable {
    case none, bars, spots, scallop, stripes
    var id: String { rawValue }
    var title: String { rawValue == "none" ? "Plain" : rawValue.capitalized }
}

enum BellyPattern: String, Codable, CaseIterable, Identifiable {
    case none, streaks, spots, bars
    var id: String { rawValue }
    var title: String { rawValue == "none" ? "Plain" : rawValue.capitalized }
}

enum MarkingKind: String, Codable, CaseIterable, Identifiable {
    case mask, bib, cheek, cap, stripe, disc, eyeRing, collar
    var id: String { rawValue }
    var title: String {
        switch self {
        case .mask: return "Mask"
        case .bib: return "Throat bib"
        case .cheek: return "Cheek patch"
        case .cap: return "Cap"
        case .stripe: return "Brow stripe"
        case .disc: return "Facial disc"
        case .eyeRing: return "Eye ring"
        case .collar: return "Collar"
        }
    }
    /// Eye rings are painted on top of the eye; everything else sits under it.
    var isOverEye: Bool { self == .eyeRing }
}

struct Marking: Codable, Hashable, Identifiable {
    var kind: MarkingKind
    var color: RGBA
    var id: MarkingKind { kind }
}

enum PerchStyle: String, Codable, CaseIterable, Identifiable {
    case branch, ground, water, ice, rock, none
    var id: String { rawValue }
    var title: String {
        switch self {
        case .branch: return "Branch"
        case .ground: return "Meadow"
        case .water: return "Water"
        case .ice: return "Ice floe"
        case .rock: return "Rock"
        case .none: return "Floating"
        }
    }
    var emoji: String {
        switch self {
        case .branch: return "🌿"
        case .ground: return "🌾"
        case .water: return "🌊"
        case .ice: return "🧊"
        case .rock: return "🪨"
        case .none: return "✨"
        }
    }
}

// MARK: - Appearance

/// Every visual parameter the procedural renderer understands. Species ship with one;
/// the Bird Studio edits a copy; hatchlings get a mutated one.
struct BirdAppearance: Codable, Hashable {
    // Colours
    var body = RGBA(0x8B6B4A)
    var belly = RGBA(0xC9B49A)
    var head = RGBA(0x8B6B4A)
    var neck = RGBA(0x8B6B4A)
    var wing = RGBA(0x806244)
    var wingTip = RGBA(0x5A4530)
    var tail = RGBA(0x806244)
    var beak = RGBA(0x5A4A3A)
    var beakTip = RGBA(0x5A4A3A)
    var legs = RGBA(0x8D6E63)
    var eye = RGBA(0x2B1B17)
    var eyeDark = false
    var crestColor = RGBA(0x8B6B4A)
    var crestTip = RGBA(0x8B6B4A)
    var accent = RGBA(0x2A7A6F)
    var accent2 = RGBA(0xE9C46A)
    var wingPatternColor = RGBA(0xFFFFFF)
    var bellyPatternColor = RGBA(0x614A33)

    // Shape
    var beakShape: BeakShape = .conical
    var beakLength: Double = 1
    var beakAngle: Double = 0
    var crest: CrestStyle = .none
    var crestSize: Double = 1
    var tailStyle: TailStyle = .short
    var tailLength: Double = 1
    var tailAngle: Double = 8
    var plumpness: Double = 1
    var bodyLength: Double = 1
    var bodyTilt: Double = -25
    var neckLength: Double = 0
    var neckLean: Double = 0
    var neckCurve: Double = 0
    var legLength: Double = 0.5
    var headSize: Double = 1
    var eyeSize: Double = 1
    var headTilt: Double = 0
    var wingLength: Double = 1

    // Patterns & setting
    var wingPattern: WingPattern = .none
    var bellyPattern: BellyPattern = .none
    var markings: [Marking] = []
    var perch: PerchStyle = .branch

    static let standard = BirdAppearance()

    func marking(_ kind: MarkingKind) -> Marking? { markings.first { $0.kind == kind } }

    /// The palette swatches shown in the Anatomy tab.
    var palette: [(String, RGBA)] {
        var swatches: [(String, RGBA)] = [("Crown", head), ("Back", body), ("Breast", belly), ("Wing", wing),
                                           ("Primaries", wingTip), ("Tail", tail), ("Bill", beak), ("Legs", legs), ("Eye", eye)]
        if crest != .none { swatches.append(("Crest", crestColor)) }
        for m in markings { swatches.append((m.kind.title, m.color)) }
        return swatches
    }
}

extension BirdAppearance {
    enum CodingKeys: String, CodingKey {
        case body, belly, head, neck, wing, wingTip, tail, beak, beakTip, legs, eye, eyeDark
        case crestColor, crestTip, accent, accent2, wingPatternColor, bellyPatternColor
        case beakShape, beakLength, beakAngle, crest, crestSize, tailStyle, tailLength, tailAngle
        case plumpness, bodyLength, bodyTilt, neckLength, neckLean, neckCurve, legLength, headSize, eyeSize, headTilt, wingLength
        case wingPattern, bellyPattern, markings, perch
    }

    /// Lenient decoding: any missing key falls back to a sensible default, and several
    /// colours inherit from others (neck → head, tail → wing…) so species entries stay short.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = BirdAppearance.standard
        func color(_ key: CodingKeys, _ fallback: RGBA) throws -> RGBA {
            try c.decodeIfPresent(RGBA.self, forKey: key) ?? fallback
        }
        func number(_ key: CodingKeys, _ fallback: Double) throws -> Double {
            try c.decodeIfPresent(Double.self, forKey: key) ?? fallback
        }

        body = try color(.body, d.body)
        belly = try color(.belly, body.shaded(0.35))
        head = try color(.head, body)
        neck = try color(.neck, head)
        wing = try color(.wing, body.shaded(-0.08))
        wingTip = try color(.wingTip, wing.shaded(-0.3))
        tail = try color(.tail, wing)
        beak = try color(.beak, d.beak)
        beakTip = try color(.beakTip, beak)
        legs = try color(.legs, d.legs)
        eye = try color(.eye, d.eye)
        eyeDark = try c.decodeIfPresent(Bool.self, forKey: .eyeDark) ?? false
        crestColor = try color(.crestColor, head)
        crestTip = try color(.crestTip, crestColor)
        accent = try color(.accent, d.accent)
        accent2 = try color(.accent2, d.accent2)
        wingPatternColor = try color(.wingPatternColor, d.wingPatternColor)
        bellyPatternColor = try color(.bellyPatternColor, body.shaded(-0.3))

        beakShape = try c.decodeIfPresent(BeakShape.self, forKey: .beakShape) ?? d.beakShape
        beakLength = try number(.beakLength, d.beakLength)
        beakAngle = try number(.beakAngle, d.beakAngle)
        crest = try c.decodeIfPresent(CrestStyle.self, forKey: .crest) ?? d.crest
        crestSize = try number(.crestSize, d.crestSize)
        tailStyle = try c.decodeIfPresent(TailStyle.self, forKey: .tailStyle) ?? d.tailStyle
        tailLength = try number(.tailLength, d.tailLength)
        tailAngle = try number(.tailAngle, d.tailAngle)
        plumpness = try number(.plumpness, d.plumpness)
        bodyLength = try number(.bodyLength, d.bodyLength)
        bodyTilt = try number(.bodyTilt, d.bodyTilt)
        neckLength = try number(.neckLength, d.neckLength)
        neckLean = try number(.neckLean, d.neckLean)
        neckCurve = try number(.neckCurve, d.neckCurve)
        legLength = try number(.legLength, d.legLength)
        headSize = try number(.headSize, d.headSize)
        eyeSize = try number(.eyeSize, d.eyeSize)
        headTilt = try number(.headTilt, d.headTilt)
        wingLength = try number(.wingLength, d.wingLength)
        wingPattern = try c.decodeIfPresent(WingPattern.self, forKey: .wingPattern) ?? d.wingPattern
        bellyPattern = try c.decodeIfPresent(BellyPattern.self, forKey: .bellyPattern) ?? d.bellyPattern
        markings = try c.decodeIfPresent([Marking].self, forKey: .markings) ?? []
        perch = try c.decodeIfPresent(PerchStyle.self, forKey: .perch) ?? d.perch
    }
}

// MARK: - Variations

extension BirdAppearance {
    /// Applies a colour transform to every plumage colour (not eyes or legs).
    func recolored(_ transform: (RGBA) -> RGBA) -> BirdAppearance {
        var a = self
        a.body = transform(body); a.belly = transform(belly); a.head = transform(head); a.neck = transform(neck)
        a.wing = transform(wing); a.wingTip = transform(wingTip); a.tail = transform(tail)
        a.crestColor = transform(crestColor); a.crestTip = transform(crestTip)
        a.wingPatternColor = transform(wingPatternColor); a.bellyPatternColor = transform(bellyPatternColor)
        a.accent = transform(accent); a.accent2 = transform(accent2)
        a.markings = markings.map { Marking(kind: $0.kind, color: transform($0.color)) }
        return a
    }

    /// Small, natural individual variation — every hatchling is unique.
    func jittered<G: RandomNumberGenerator>(using rng: inout G) -> BirdAppearance {
        let hue = Double.random(in: -8...8, using: &rng)
        let light = Double.random(in: -0.06...0.06, using: &rng)
        var a = recolored { $0.hueShifted(hue).shaded(light) }
        a.plumpness *= Double.random(in: 0.94...1.08, using: &rng)
        a.tailLength *= Double.random(in: 0.92...1.1, using: &rng)
        a.crestSize *= Double.random(in: 0.9...1.15, using: &rng)
        a.headTilt = Double.random(in: -4...4, using: &rng)
        return a
    }

    /// Wild, playful randomisation for the Studio's "Mutate" button.
    func mutated<G: RandomNumberGenerator>(strength: Double, using rng: inout G) -> BirdAppearance {
        var a = self
        let hueShift = Double.random(in: -180...180, using: &rng) * strength
        a = a.recolored { $0.hueShifted(hueShift) }
        func nudge(_ v: Double, _ range: ClosedRange<Double>, _ spread: Double) -> Double {
            let n = v + Double.random(in: -spread...spread, using: &rng) * strength
            return min(max(n, range.lowerBound), range.upperBound)
        }
        a.beakLength = nudge(a.beakLength, 0.4...2.0, 0.6)
        a.tailLength = nudge(a.tailLength, 0.2...2.0, 0.6)
        a.plumpness = nudge(a.plumpness, 0.7...1.5, 0.3)
        a.headSize = nudge(a.headSize, 0.6...1.5, 0.3)
        a.crestSize = nudge(a.crestSize, 0.4...1.6, 0.5)
        if Double.random(in: 0...1, using: &rng) < 0.35 * strength {
            a.beakShape = BeakShape.allCases.randomElement(using: &rng) ?? a.beakShape
        }
        if Double.random(in: 0...1, using: &rng) < 0.35 * strength {
            a.crest = CrestStyle.allCases.randomElement(using: &rng) ?? a.crest
        }
        if Double.random(in: 0...1, using: &rng) < 0.35 * strength {
            a.tailStyle = TailStyle.allCases.randomElement(using: &rng) ?? a.tailStyle
        }
        if Double.random(in: 0...1, using: &rng) < 0.3 * strength {
            a.wingPattern = WingPattern.allCases.randomElement(using: &rng) ?? a.wingPattern
        }
        return a
    }

    /// Leucism: pigment loss that leaves plumage ghostly pale.
    var leucistic: BirdAppearance {
        var a = recolored { $0.mixed(with: RGBA(0xFBF8F2), 0.82) }
        a.beak = beak.mixed(with: RGBA(0xF2D7B0), 0.6)
        a.legs = legs.mixed(with: RGBA(0xF0C8B8), 0.6)
        return a
    }

    /// Melanism: excess dark pigment.
    var melanistic: BirdAppearance {
        recolored { $0.mixed(with: RGBA(0x16141C), 0.72) }
    }
}
