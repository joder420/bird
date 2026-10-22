import SwiftUI

/// Sculpt an egg with sliders, see which shape class it belongs to and which real bird lays the
/// closest match — then browse every egg in the Atlas at true relative size.
struct EggLabView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case lab, gallery
        var id: String { rawValue }
        var title: String { self == .lab ? "Egg Lab" : "Egg Gallery" }
    }

    @EnvironmentObject private var game: GameState
    @State private var mode: Mode = .lab
    @State private var elongation = 1.33
    @State private var asymmetry = 0.13
    @State private var pointiness = 1.0
    @State private var base = RGBA(0x9FD3DE)
    @State private var marking = RGBA(0x5A3E2B)
    @State private var pattern: EggPattern = .speckled
    @State private var seed: UInt64 = 3
    @State private var trueScale = true
    @State private var inspected: BirdSpecies?

    private let db = BirdDatabase.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                ScreenTitle(title: mode.title, subtitle: mode == .lab ? "Sculpt an egg, find its maker" : "Every egg in the Atlas")
                Picker("Mode", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 30)
                if mode == .lab { lab } else { gallery }
            }
            .padding(.horizontal, 16)
            .padding(.top, 44)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .sheet(item: $inspected) { s in
            EggPlate(species: s).environmentObject(game)
                .presentationDetents([.medium])
        }
    }

    // MARK: Lab

    private var geometry: EggGeometry { EggGeometry(elongation: elongation, asymmetry: asymmetry, pointiness: pointiness) }
    private var shapeClass: EggShapeKind { EggShapeKind.classify(elongation: elongation, asymmetry: asymmetry) }

    /// The real species whose egg is closest in shape and colour.
    private var closestSpecies: BirdSpecies {
        db.all.min { a, b in distance(to: a) < distance(to: b) } ?? db.all[0]
    }

    private func distance(to s: BirdSpecies) -> Double {
        let k = s.egg.shape
        let shape = pow((k.elongation - elongation) / 0.25, 2) + pow((k.asymmetry - asymmetry) / 0.1, 2)
        let c1 = s.egg.base, c2 = base
        let color = pow(c1.r - c2.r, 2) + pow(c1.g - c2.g, 2) + pow(c1.b - c2.b, 2)
        let patternPenalty: Double = s.egg.pattern == pattern ? 0 : 0.6
        return shape + color * 6 + patternPenalty
    }

    private var lab: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 24).fill(RadialGradient(colors: [Palette.parchment, Palette.parchmentDeep], center: .center, startRadius: 10, endRadius: 200))
                EggArt(geometry: geometry, base: base, marking: marking, pattern: pattern, seed: seed)
                    .frame(height: 210)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: geometry)
            }
            .frame(height: 250)
            .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(Palette.parchmentEdge, lineWidth: 1.5))

            VStack(alignment: .leading, spacing: 6) {
                Text("This is \(article(shapeClass.title)) \(shapeClass.title.lowercased()) egg")
                    .font(AppFont.title(20))
                    .foregroundStyle(Palette.ink)
                Text(shapeClass.explanation)
                    .font(AppFont.italic(14))
                    .foregroundStyle(Palette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .parchmentCard()

            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Sculpt")
                labSlider("Elongation", $elongation, 1.0...1.8)
                labSlider("Asymmetry", $asymmetry, 0...0.4)
                labSlider("Pointed ends", $pointiness, 0.8...1.5)
                SectionHeader(title: "Paint").padding(.top, 4)
                HStack {
                    ColorPicker("Ground colour", selection: Binding(get: { base.color }, set: { base = RGBA($0) }), supportsOpacity: false)
                        .font(AppFont.body(15))
                }
                HStack {
                    ColorPicker("Marking colour", selection: Binding(get: { marking.color }, set: { marking = RGBA($0) }), supportsOpacity: false)
                        .font(AppFont.body(15))
                }
                Flow(spacing: 6) {
                    ForEach(EggPattern.allCases) { p in
                        Button {
                            pattern = p
                            Haptics.shared.select()
                        } label: {
                            Chip(text: p.title, color: Palette.forest, selected: pattern == p)
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                HStack {
                    Button {
                        seed = UInt64.random(in: 1...9999)
                        Haptics.shared.tap()
                    } label: {
                        Label("Re-speckle", systemImage: "sparkles")
                    }
                    .buttonStyle(WoodButtonStyle(compact: true))
                    Button {
                        let k = EggShapeKind.allCases.randomElement() ?? .oval
                        withAnimation(.spring) {
                            elongation = k.elongation
                            asymmetry = k.asymmetry
                            pointiness = k.pointiness
                            base = RGBA(h: Double.random(in: 0...360), s: Double.random(in: 0.05...0.6), v: Double.random(in: 0.55...0.98))
                            marking = RGBA(h: Double.random(in: 0...60), s: 0.6, v: Double.random(in: 0.15...0.5))
                            pattern = EggPattern.allCases.randomElement() ?? .plain
                        }
                        Haptics.shared.bump()
                    } label: {
                        Label("Surprise me", systemImage: "dice.fill")
                    }
                    .buttonStyle(WoodButtonStyle(color: Palette.dusk, compact: true))
                }
            }
            .parchmentCard()

            let match = closestSpecies
            Button {
                inspected = match
            } label: {
                HStack(spacing: 12) {
                    EggArt(egg: match.egg, seed: match.seed)
                        .frame(height: 70)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("CLOSEST REAL EGG").font(AppFont.caps(11)).foregroundStyle(Palette.gold)
                        Text(match.name).font(AppFont.title(19)).foregroundStyle(Palette.ink)
                        Text("\(match.egg.shape.title) · \(match.egg.pattern.title) · \(Int(match.egg.lengthMm)) mm")
                            .font(AppFont.dataLight(12))
                            .foregroundStyle(Palette.inkSoft)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(Palette.bark)
                }
                .parchmentCard()
            }
            .buttonStyle(PressableStyle())
        }
    }

    private func article(_ word: String) -> String {
        guard let first = word.lowercased().first else { return "a" }
        return "aeiou".contains(first) ? "an" : "a"
    }

    private func labSlider(_ label: String, _ value: Binding<Double>, _ range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(label.uppercased()).font(AppFont.caps(11)).foregroundStyle(Palette.inkSoft)
                Spacer()
                Text(String(format: "%.2f", value.wrappedValue)).font(AppFont.dataLight(12)).foregroundStyle(Palette.ink)
            }
            Slider(value: value, in: range).tint(Palette.forest)
        }
    }

    // MARK: Gallery

    private var gallery: some View {
        let sorted = db.all.sorted { $0.egg.lengthMm > $1.egg.lengthMm }
        let largest = sorted.first?.egg.lengthMm ?? 150
        return VStack(spacing: 12) {
            Toggle(isOn: $trueScale) {
                Text("True relative size").font(AppFont.bodyBold(15)).foregroundStyle(.white)
            }
            .tint(Palette.sunrise)
            .padding(.horizontal, 6)
            .skyShadow()
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 10)], spacing: 14) {
                ForEach(sorted) { s in
                    Button {
                        inspected = s
                        game.recordEggInspected(s)
                    } label: {
                        VStack(spacing: 4) {
                            ZStack(alignment: .bottom) {
                                Color.clear
                                EggArt(egg: s.egg, seed: s.seed)
                                    .frame(height: trueScale ? max(14, 110 * CGFloat(s.egg.lengthMm / largest)) : 90)
                            }
                            .frame(height: 112)
                            Text(s.name).font(AppFont.bodyBold(11)).foregroundStyle(Palette.ink).lineLimit(2).multilineTextAlignment(.center)
                            Text("\(Int(s.egg.lengthMm)) mm").font(AppFont.dataLight(10)).foregroundStyle(Palette.inkSoft)
                        }
                        .frame(maxWidth: .infinity)
                        .parchmentCard(padding: 8, cornerRadius: 14)
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
    }
}

/// A museum label for a single egg.
struct EggPlate: View {
    let species: BirdSpecies
    @EnvironmentObject private var game: GameState

    var body: some View {
        VStack(spacing: 10) {
            EggArt(egg: species.egg, seed: species.seed)
                .frame(height: 150)
            Text(species.name).font(AppFont.display(32)).foregroundStyle(Palette.ink)
            Text(species.scientific).font(AppFont.italic(15)).foregroundStyle(Palette.inkSoft)
            Text(species.egg.description).font(AppFont.body(15)).foregroundStyle(Palette.ink).multilineTextAlignment(.center)
            HStack(spacing: 8) {
                Chip(text: species.egg.shape.title, emoji: "🥚", color: Palette.moss)
                Chip(text: "\(Int(species.egg.lengthMm))×\(Int(species.egg.widthMm)) mm", emoji: "📐", color: Palette.gold)
                Chip(text: species.egg.incubationDays.formatted("d"), emoji: "🌡️", color: Palette.berry)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Palette.parchment.ignoresSafeArea())
        .onAppear { game.recordEggInspected(species) }
    }
}
