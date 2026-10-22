import Foundation

/// Loads the bundled encyclopedia (`birds.json`) once and offers lookups.
final class BirdDatabase {
    static let shared = BirdDatabase()

    let all: [BirdSpecies]
    private let byID: [String: BirdSpecies]

    private init() {
        guard let url = Bundle.main.url(forResource: "birds", withExtension: "json") else {
            fatalError("birds.json is missing from the app bundle")
        }
        do {
            let data = try Data(contentsOf: url)
            let species = try JSONDecoder().decode([BirdSpecies].self, from: data)
            all = species.sorted { $0.name < $1.name }
            byID = Dictionary(uniqueKeysWithValues: species.map { ($0.id, $0) })
        } catch {
            fatalError("Could not decode birds.json: \(error)")
        }
    }

    func species(_ id: String) -> BirdSpecies? { byID[id] }

    func inGroup(_ group: BirdGroup) -> [BirdSpecies] { all.filter { $0.group == group } }

    /// The featured "Bird of the Day" — the same for everyone on a given date.
    func birdOfTheDay(_ date: Date = Date()) -> BirdSpecies {
        let day = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        var rng = SeededRandom(seed: UInt64(day) &* 2654435761)
        return all[Int(rng.next() % UInt64(all.count))]
    }

    func random<G: RandomNumberGenerator>(excluding: Set<String> = [], using rng: inout G) -> BirdSpecies {
        let pool = all.filter { !excluding.contains($0.id) }
        return (pool.isEmpty ? all : pool).randomElement(using: &rng)!
    }

    /// Species that share a habitat with the given one — used for soundscape choruses.
    func neighbours(of habitat: Habitat) -> [BirdSpecies] {
        all.filter { $0.habitats.contains(habitat) }
    }

    var groupsInUse: [BirdGroup] {
        BirdGroup.allCases.filter { g in all.contains { $0.group == g } }
    }
}
