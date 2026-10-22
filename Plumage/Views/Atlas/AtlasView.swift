import SwiftUI

enum AtlasSort: String, CaseIterable, Identifiable {
    case name, size, wingspan, weight, rarity, status, discovered

    var id: String { rawValue }

    var title: String {
        switch self {
        case .name: return "A → Z"
        case .size: return "Length"
        case .wingspan: return "Wingspan"
        case .weight: return "Weight"
        case .rarity: return "Rarity"
        case .status: return "Most threatened"
        case .discovered: return "Discovered first"
        }
    }
}

struct AtlasFilters: Equatable {
    var groups: Set<BirdGroup> = []
    var regions: Set<Region> = []
    var habitats: Set<Habitat> = []
    var diets: Set<Diet> = []
    var threatenedOnly = false
    var favoritesOnly = false
    var undiscoveredOnly = false

    var activeCount: Int {
        groups.count + regions.count + habitats.count + diets.count + (threatenedOnly ? 1 : 0) + (favoritesOnly ? 1 : 0) + (undiscoveredOnly ? 1 : 0)
    }
}

struct AtlasView: View {
    @EnvironmentObject private var game: GameState
    @State private var search = ""
    @State private var sort: AtlasSort = .name
    @State private var filters = AtlasFilters()
    @State private var showFilters = false
    @State private var showCompare = false
    @State private var gridMode = true

    private let db = BirdDatabase.shared

    private var results: [BirdSpecies] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var list = db.all.filter { bird in
            if !query.isEmpty && !bird.searchBlob.contains(query) { return false }
            if !filters.groups.isEmpty && !filters.groups.contains(bird.group) { return false }
            if !filters.regions.isEmpty && filters.regions.isDisjoint(with: bird.regions) { return false }
            if !filters.habitats.isEmpty && filters.habitats.isDisjoint(with: bird.habitats) { return false }
            if !filters.diets.isEmpty && filters.diets.isDisjoint(with: bird.diet) { return false }
            if filters.threatenedOnly && !bird.status.isThreatened { return false }
            if filters.favoritesOnly && !game.isFavorite(bird.id) { return false }
            if filters.undiscoveredOnly && game.isDiscovered(bird.id) { return false }
            return true
        }
        switch sort {
        case .name: list.sort { $0.name < $1.name }
        case .size: list.sort { $0.lengthCm.mid > $1.lengthCm.mid }
        case .wingspan: list.sort { ($0.wingspanCm?.mid ?? 0) > ($1.wingspanCm?.mid ?? 0) }
        case .weight: list.sort { $0.weightG.mid > $1.weightG.mid }
        case .rarity: list.sort { $0.rarity == $1.rarity ? $0.name < $1.name : $0.rarity > $1.rarity }
        case .status: list.sort { $0.status.index == $1.status.index ? $0.name < $1.name : $0.status.index > $1.status.index }
        case .discovered:
            list.sort {
                let a = game.isDiscovered($0.id), b = game.isDiscovered($1.id)
                return a == b ? $0.name < $1.name : a && !b
            }
        }
        return list
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    ScreenTitle(title: "The Atlas", subtitle: "\(game.save.discovered.count) of \(db.all.count) species discovered")
                    searchBar
                    groupStrip
                    controls
                    if results.isEmpty {
                        emptyState
                    } else if gridMode {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                            ForEach(results) { bird in
                                NavigationLink(value: bird) { SpeciesCard(species: bird) }
                                    .buttonStyle(PressableStyle())
                            }
                        }
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(results) { bird in
                                NavigationLink(value: bird) { SpeciesRow(species: bird) }
                                    .buttonStyle(PressableStyle())
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.immediately)
            .navigationDestination(for: BirdSpecies.self) { BirdDetailView(species: $0) }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showFilters) {
                FilterSheet(filters: $filters, sort: $sort)
                    .presentationDetents([.medium, .large])
                    .environmentObject(game)
            }
            .sheet(isPresented: $showCompare) {
                CompareView().environmentObject(game)
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(Palette.bark)
            TextField("Search names, habitats, regions…", text: $search)
                .font(AppFont.body(16))
                .foregroundStyle(Palette.ink)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !search.isEmpty {
                Button {
                    search = ""
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Palette.inkSoft)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Capsule().fill(Palette.parchment.opacity(0.95)))
        .overlay(Capsule().strokeBorder(Palette.parchmentEdge, lineWidth: 1.5))
        .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
    }

    private var groupStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button {
                    filters.groups.removeAll()
                    Haptics.shared.select()
                } label: {
                    Chip(text: "All", emoji: "🌍", color: Palette.forest, selected: filters.groups.isEmpty)
                }
                .buttonStyle(PressableStyle())
                ForEach(db.groupsInUse) { group in
                    Button {
                        if filters.groups.contains(group) { filters.groups.remove(group) } else { filters.groups.insert(group) }
                        Haptics.shared.select()
                    } label: {
                        Chip(text: group.title, emoji: group.emoji, color: Palette.forest, selected: filters.groups.contains(group))
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var controls: some View {
        HStack(spacing: 8) {
            Menu {
                Picker("Sort", selection: $sort) {
                    ForEach(AtlasSort.allCases) { Text($0.title).tag($0) }
                }
            } label: {
                Label(sort.title, systemImage: "arrow.up.arrow.down")
                    .font(AppFont.bodyBold(14))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Palette.parchment.opacity(0.9)))
                    .foregroundStyle(Palette.ink)
            }
            Button {
                showFilters = true
            } label: {
                Label(filters.activeCount > 0 ? "Filters (\(filters.activeCount))" : "Filters", systemImage: "line.3.horizontal.decrease.circle")
                    .font(AppFont.bodyBold(14))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(filters.activeCount > 0 ? Palette.moss.opacity(0.9) : Palette.parchment.opacity(0.9)))
                    .foregroundStyle(filters.activeCount > 0 ? Palette.parchment : Palette.ink)
            }
            Spacer()
            Button {
                showCompare = true
            } label: {
                Image(systemName: "scalemass.fill")
                    .padding(8)
                    .background(Circle().fill(Palette.parchment.opacity(0.9)))
                    .foregroundStyle(Palette.ink)
            }
            .accessibilityLabel("Compare two birds")
            Button {
                withAnimation(.spring) { gridMode.toggle() }
            } label: {
                Image(systemName: gridMode ? "list.bullet" : "square.grid.2x2.fill")
                    .padding(8)
                    .background(Circle().fill(Palette.parchment.opacity(0.9)))
                    .foregroundStyle(Palette.ink)
            }
            .accessibilityLabel(gridMode ? "Show as list" : "Show as grid")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Text("🪹").font(.system(size: 54))
            Text("No birds match")
                .font(AppFont.title(20))
                .foregroundStyle(Palette.ink)
            Text("Try a different search or clear some filters.")
                .font(AppFont.italic(15))
                .foregroundStyle(Palette.inkSoft)
            Button("Clear everything") {
                search = ""
                filters = AtlasFilters()
            }
            .buttonStyle(WoodButtonStyle(compact: true))
        }
        .frame(maxWidth: .infinity)
        .parchmentCard()
    }
}

/// A compact list row for the Atlas.
struct SpeciesRow: View {
    var species: BirdSpecies
    @EnvironmentObject private var game: GameState

    var body: some View {
        let discovered = game.isDiscovered(species.id)
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(species.primaryHabitat.tint.opacity(0.3))
                if discovered {
                    BirdView(appearance: game.appearance(for: species), animated: false, showPerch: false, padding: 6)
                } else {
                    BirdSilhouette(appearance: species.appearance, color: Palette.bark.opacity(0.7), padding: 10)
                }
            }
            .frame(width: 64, height: 64)
            VStack(alignment: .leading, spacing: 3) {
                Text(species.name).font(AppFont.bodyBold(16)).foregroundStyle(Palette.ink)
                Text(species.scientific).font(AppFont.italic(13)).foregroundStyle(Palette.inkSoft)
                HStack(spacing: 6) {
                    Text(species.group.emoji)
                    Text(species.lengthText).font(AppFont.dataLight(11)).foregroundStyle(Palette.inkSoft)
                    RarityStars(rarity: species.rarity, size: 8)
                }
            }
            Spacer()
            StatusBadge(status: species.status, compact: true)
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Palette.bark.opacity(0.6))
        }
        .parchmentCard(padding: 10, cornerRadius: 16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(species.name)\(discovered ? "" : ", not yet discovered")")
        .accessibilityAddTraits(.isButton)
    }
}

struct FilterSheet: View {
    @Binding var filters: AtlasFilters
    @Binding var sort: AtlasSort
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    section("Sort by") {
                        Flow {
                            ForEach(AtlasSort.allCases) { option in
                                toggleChip(option.title, nil, selected: sort == option) { sort = option }
                            }
                        }
                    }
                    section("Collection") {
                        Flow {
                            toggleChip("Favourites", "💛", selected: filters.favoritesOnly) { filters.favoritesOnly.toggle() }
                            toggleChip("Undiscovered", "❔", selected: filters.undiscoveredOnly) { filters.undiscoveredOnly.toggle() }
                            toggleChip("Threatened", "🛡️", selected: filters.threatenedOnly) { filters.threatenedOnly.toggle() }
                        }
                    }
                    section("Region") {
                        Flow {
                            ForEach(Region.allCases) { r in
                                toggleChip(r.title, r.emoji, selected: filters.regions.contains(r)) { toggle(&filters.regions, r) }
                            }
                        }
                    }
                    section("Habitat") {
                        Flow {
                            ForEach(Habitat.allCases) { h in
                                toggleChip(h.title, h.emoji, selected: filters.habitats.contains(h)) { toggle(&filters.habitats, h) }
                            }
                        }
                    }
                    section("Diet") {
                        Flow {
                            ForEach(Diet.allCases) { d in
                                toggleChip(d.title, d.emoji, selected: filters.diets.contains(d)) { toggle(&filters.diets, d) }
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(Palette.parchment.ignoresSafeArea())
            .navigationTitle("Filter the Atlas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Reset") { filters = AtlasFilters() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.bold()
                }
            }
        }
    }

    private func toggle<T: Hashable>(_ set: inout Set<T>, _ value: T) {
        if set.contains(value) { set.remove(value) } else { set.insert(value) }
        Haptics.shared.select()
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased()).font(AppFont.caps(12)).tracking(1.2).foregroundStyle(Palette.bark)
            content()
        }
    }

    private func toggleChip(_ title: String, _ emoji: String?, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Chip(text: title, emoji: emoji, color: Palette.forest, selected: selected)
        }
        .buttonStyle(PressableStyle())
    }
}
