import SwiftUI

enum StudioSection: String, CaseIterable, Identifiable {
    case colors, shape, patterns, palettes, scene

    var id: String { rawValue }

    var title: String {
        switch self {
        case .colors: return "Colours"
        case .shape: return "Shape"
        case .patterns: return "Markings"
        case .palettes: return "Palettes"
        case .scene: return "Scene"
        }
    }

    var emoji: String {
        switch self {
        case .colors: return "🎨"
        case .shape: return "📐"
        case .patterns: return "🦓"
        case .palettes: return "🌈"
        case .scene: return "🏞️"
        }
    }
}

struct StudioView: View {
    @EnvironmentObject private var game: GameState
    @EnvironmentObject private var router: AppRouter
    @ObservedObject private var sound = SoundEngine.shared

    @State private var base: BirdSpecies = BirdDatabase.shared.species("northern-cardinal") ?? BirdDatabase.shared.all[0]
    @State private var look: BirdAppearance = .standard
    @State private var section: StudioSection = .colors
    @State private var flapping = false
    @State private var history: [BirdAppearance] = []
    @State private var lastHistoryPush = Date.distantPast
    @State private var isUndoing = false
    @State private var showFrame = false
    @State private var loaded = false
    @State private var sparkle = 0

    private let db = BirdDatabase.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                ScreenTitle(title: "Bird Studio", subtitle: "Reshape, repaint, reimagine")
                preview
                speciesStrip
                sectionPicker
                Group {
                    switch section {
                    case .colors: colorsPanel
                    case .shape: shapePanel
                    case .patterns: patternsPanel
                    case .palettes: palettesPanel
                    case .scene: scenePanel
                    }
                }
                .parchmentCard()
                actions
                creationsStrip
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .onAppear { loadFromRouter() }
        .onChange(of: router.studioSpeciesID) { _, _ in loadFromRouter() }
        .onChange(of: look) { old, _ in recordHistory(old) }
        .sheet(isPresented: $showFrame) {
            StudioFrameSheet(name: base.name, appearance: look, baseSpeciesID: base.id)
                .environmentObject(game)
                .presentationDetents([.large])
        }
    }

    // MARK: Loading & history

    private func loadFromRouter() {
        if let id = router.studioSpeciesID, let species = db.species(id) {
            select(species)
            router.studioSpeciesID = nil
        } else if !loaded {
            select(base)
        }
        loaded = true
    }

    private func select(_ species: BirdSpecies) {
        base = species
        isUndoing = true
        look = game.appearance(for: species)
        history.removeAll()
        runAfter(0) { isUndoing = false }
    }

    private func recordHistory(_ old: BirdAppearance) {
        guard !isUndoing else { return }
        if Date().timeIntervalSince(lastHistoryPush) > 0.6 {
            history.append(old)
            if history.count > 40 { history.removeFirst() }
            lastHistoryPush = Date()
        }
    }

    private func undo() {
        guard let previous = history.popLast() else { return }
        isUndoing = true
        withAnimation(.spring) { look = previous }
        Haptics.shared.tap()
        runAfter(0) { isUndoing = false }
    }

    // MARK: Preview

    private var preview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(LinearGradient(colors: [base.primaryHabitat.tint.opacity(0.4), Palette.parchment], startPoint: .top, endPoint: .bottom))
                .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(Palette.parchmentEdge, lineWidth: 1.5))
            BirdView(appearance: look, singing: sound.singingSpeciesID == base.id, flapping: flapping, padding: 16)
                .padding(10)
            if sparkle > 0 { FeatherBurst(count: 24, duration: 1.8).id(sparkle) }
            VStack {
                HStack {
                    circleButton("arrow.uturn.backward", "Undo", enabled: !history.isEmpty) { undo() }
                    Spacer()
                    circleButton("music.note", "Sing") {
                        sound.playSong(base)
                        game.recordSongPlayed(base)
                    }
                    circleButton(flapping ? "pause.fill" : "wind", flapping ? "Stop flapping" : "Flap wings") {
                        flapping.toggle()
                    }
                }
                Spacer()
                HStack {
                    circleButton("dice.fill", "Mutate") {
                        var rng = SystemRandomNumberGenerator()
                        withAnimation(.spring) { look = look.mutated(strength: 0.6, using: &rng) }
                        sparkle += 1
                        SoundEngine.shared.play(.whoosh)
                        Haptics.shared.bump()
                    }
                    Spacer()
                    if game.hasCustomLook(base.id) {
                        Text("Custom look in Atlas")
                            .font(AppFont.caps(9))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Palette.dusk.opacity(0.85)))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    circleButton("arrow.counterclockwise", "Reset to species") {
                        withAnimation(.spring) { look = base.appearance }
                        Haptics.shared.tap()
                    }
                }
            }
            .padding(12)
        }
        .frame(height: 300)
    }

    private func circleButton(_ icon: String, _ label: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Palette.parchment)
                .frame(width: 38, height: 38)
                .background(Circle().fill(Palette.forest.opacity(enabled ? 0.9 : 0.35)))
        }
        .disabled(!enabled)
        .accessibilityLabel(label)
    }

    private var speciesStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 8) {
                ForEach(db.all) { s in
                    Button {
                        withAnimation(.spring) { select(s) }
                        Haptics.shared.select()
                    } label: {
                        VStack(spacing: 2) {
                            BirdView(appearance: game.appearance(for: s), animated: false, showPerch: false, padding: 3)
                                .frame(width: 56, height: 50)
                            Text(s.name.split(separator: " ").last.map(String.init) ?? s.name)
                                .font(AppFont.bodyBold(10))
                                .foregroundStyle(Palette.ink)
                                .lineLimit(1)
                        }
                        .frame(width: 70)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 12).fill(s == base ? Palette.moss.opacity(0.35) : Palette.parchment.opacity(0.9)))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(s == base ? Palette.forest : Palette.parchmentEdge, lineWidth: 1.5))
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel(s.name)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var sectionPicker: some View {
        HStack(spacing: 6) {
            ForEach(StudioSection.allCases) { s in
                Button {
                    withAnimation(.spring(response: 0.35)) { section = s }
                    Haptics.shared.select()
                } label: {
                    VStack(spacing: 2) {
                        Text(s.emoji).font(.system(size: 18))
                        Text(s.title).font(AppFont.caps(9)).lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .foregroundStyle(section == s ? Palette.parchment : Palette.ink)
                    .background(RoundedRectangle(cornerRadius: 12).fill(section == s ? Palette.forest : Palette.parchment.opacity(0.92)))
                }
                .buttonStyle(PressableStyle())
            }
        }
    }

    // MARK: Colours

    private func colorBinding(_ keyPath: WritableKeyPath<BirdAppearance, RGBA>) -> Binding<Color> {
        Binding(get: { look[keyPath: keyPath].color }, set: { look[keyPath: keyPath] = RGBA($0) })
    }

    private var colorsPanel: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionHeader(title: "Plumage")
            colorRow("Crown & face", \.head)
            colorRow("Neck", \.neck)
            colorRow("Back & body", \.body)
            colorRow("Breast & belly", \.belly)
            colorRow("Wing coverts", \.wing)
            colorRow("Flight feathers", \.wingTip)
            colorRow("Tail", \.tail)
            if look.crest != .none {
                colorRow("Crest", \.crestColor)
                colorRow("Crest tips", \.crestTip)
            }
            SectionHeader(title: "Bare parts").padding(.top, 8)
            colorRow("Bill", \.beak)
            colorRow("Bill tip", \.beakTip)
            colorRow("Iris", \.eye)
            colorRow("Legs & feet", \.legs)
            if look.tailStyle == .train || look.tailStyle == .lyre {
                SectionHeader(title: "Ornaments").padding(.top, 8)
                colorRow("Eyespot ring", \.accent)
                colorRow("Eyespot centre", \.accent2)
            }
        }
    }

    private func colorRow(_ label: String, _ keyPath: WritableKeyPath<BirdAppearance, RGBA>) -> some View {
        HStack {
            Text(label).font(AppFont.body(16)).foregroundStyle(Palette.ink)
            Spacer()
            Text(look[keyPath: keyPath].friendlyName).font(AppFont.italic(12)).foregroundStyle(Palette.inkSoft)
            ColorPicker(label, selection: colorBinding(keyPath), supportsOpacity: false)
                .labelsHidden()
        }
        .padding(.vertical, 3)
    }

    // MARK: Shape

    private var shapePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Bill")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: 8)], spacing: 8) {
                ForEach(BeakShape.allCases) { shape in
                    Button {
                        withAnimation(.spring) { look.beakShape = shape }
                        Haptics.shared.select()
                    } label: {
                        VStack(spacing: 2) {
                            BeakDiagram(appearance: beakPreview(shape))
                            .frame(height: 34)
                            Text(shape.title).font(AppFont.bodyBold(10)).foregroundStyle(Palette.ink).lineLimit(1).minimumScaleFactor(0.7)
                        }
                        .padding(6)
                        .background(RoundedRectangle(cornerRadius: 10).fill(look.beakShape == shape ? Palette.moss.opacity(0.3) : Palette.parchment.opacity(0.6)))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(look.beakShape == shape ? Palette.forest : Palette.parchmentEdge, lineWidth: 1.2))
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            Text(look.beakShape.purpose).font(AppFont.italic(13)).foregroundStyle(Palette.inkSoft)
            slider("Bill length", $look.beakLength, 0.4...2.0)
            slider("Bill angle", $look.beakAngle, -20...35, format: "%.0f°")

            SectionHeader(title: "Crest").padding(.top, 6)
            chipRow(CrestStyle.allCases, selected: look.crest, title: { $0.title }) { look.crest = $0 }
            if look.crest != .none { slider("Crest size", $look.crestSize, 0.3...1.8) }

            SectionHeader(title: "Tail").padding(.top, 6)
            chipRow(TailStyle.allCases, selected: look.tailStyle, title: { $0.title }) { look.tailStyle = $0 }
            slider("Tail length", $look.tailLength, 0.05...2.0)
            slider("Tail angle", $look.tailAngle, -40...45, format: "%.0f°")

            SectionHeader(title: "Body").padding(.top, 6)
            slider("Plumpness", $look.plumpness, 0.7...1.5)
            slider("Body length", $look.bodyLength, 0.7...1.5)
            slider("Posture", $look.bodyTilt, -85...12, format: "%.0f°")
            slider("Head size", $look.headSize, 0.5...1.5)
            slider("Eye size", $look.eyeSize, 0.6...2.0)
            slider("Wing length", $look.wingLength, 0.2...1.8)
            slider("Neck length", $look.neckLength, 0...2.6)
            if look.neckLength > 0.3 { slider("Neck curve", $look.neckCurve, 0...2) }
            slider("Leg length", $look.legLength, 0.1...3.2)
        }
    }

    private func beakPreview(_ shape: BeakShape) -> BirdAppearance {
        var a = look
        a.beakShape = shape
        a.beakLength = 1
        return a
    }

    private func slider(_ label: String, _ value: Binding<Double>, _ range: ClosedRange<Double>, format: String = "%.2f") -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(label.uppercased()).font(AppFont.caps(11)).foregroundStyle(Palette.inkSoft)
                Spacer()
                Text(String(format: format, value.wrappedValue)).font(AppFont.dataLight(12)).foregroundStyle(Palette.ink)
            }
            Slider(value: value, in: range)
                .tint(Palette.forest)
        }
    }

    private func chipRow<T: Hashable>(_ options: [T], selected: T, title: @escaping (T) -> String, onPick: @escaping (T) -> Void) -> some View {
        Flow(spacing: 6) {
            ForEach(options, id: \.self) { option in
                Button {
                    withAnimation(.spring) { onPick(option) }
                    Haptics.shared.select()
                } label: {
                    Chip(text: title(option), color: Palette.forest, selected: option == selected)
                }
                .buttonStyle(PressableStyle())
            }
        }
    }

    // MARK: Patterns

    private var patternsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Wings")
            chipRow(WingPattern.allCases, selected: look.wingPattern, title: { $0.title }) { look.wingPattern = $0 }
            if look.wingPattern != .none { colorRow("Pattern colour", \.wingPatternColor) }

            SectionHeader(title: "Breast").padding(.top, 6)
            chipRow(BellyPattern.allCases, selected: look.bellyPattern, title: { $0.title }) { look.bellyPattern = $0 }
            if look.bellyPattern != .none { colorRow("Pattern colour", \.bellyPatternColor) }

            SectionHeader(title: "Face & neck").padding(.top, 6)
            ForEach(MarkingKind.allCases) { kind in
                markingRow(kind)
            }
            Toggle(isOn: $look.eyeDark) {
                Text("Dark, owl-like eyes").font(AppFont.body(16)).foregroundStyle(Palette.ink)
            }
            .tint(Palette.forest)
        }
    }

    private func markingRow(_ kind: MarkingKind) -> some View {
        let index = look.markings.firstIndex { $0.kind == kind }
        let isOn = Binding<Bool>(
            get: { index != nil },
            set: { on in
                if on {
                    if look.markings.firstIndex(where: { $0.kind == kind }) == nil {
                        look.markings.append(Marking(kind: kind, color: kind == .eyeRing ? RGBA(0xF2F2F2) : RGBA(0x1A1A1A)))
                    }
                } else {
                    look.markings.removeAll { $0.kind == kind }
                }
            })
        let color = Binding<Color>(
            get: { look.marking(kind)?.color.color ?? .black },
            set: { newValue in
                if let i = look.markings.firstIndex(where: { $0.kind == kind }) { look.markings[i].color = RGBA(newValue) }
            })
        return HStack {
            Toggle(isOn: isOn) {
                Text(kind.title).font(AppFont.body(16)).foregroundStyle(Palette.ink)
            }
            .tint(Palette.forest)
            if index != nil {
                ColorPicker(kind.title, selection: color, supportsOpacity: false).labelsHidden()
            }
        }
    }

    // MARK: Palettes

    private var palettesPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionHeader(title: "Magic palettes")
                FeatherBadge(count: game.save.feathers, dark: true)
            }
            Text("Transform the whole plumage at once. Unlock new palettes with feathers earned from quizzes, discoveries and hatching.")
                .font(AppFont.italic(13))
                .foregroundStyle(Palette.inkSoft)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(PlumagePalette.all) { palette in
                    let unlocked = game.isPaletteUnlocked(palette)
                    Button {
                        if unlocked || game.unlock(palette) {
                            withAnimation(.spring) { look = palette.transform(base.appearance) }
                            sparkle += 1
                            SoundEngine.shared.play(.reward)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            BirdView(appearance: palette.transform(base.appearance), animated: false, showPerch: false, padding: 2)
                                .frame(width: 46, height: 42)
                                .opacity(unlocked ? 1 : 0.45)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(palette.emoji) \(palette.name)").font(AppFont.bodyBold(14)).foregroundStyle(Palette.ink)
                                if unlocked {
                                    Text("Apply").font(AppFont.caps(10)).foregroundStyle(Palette.moss)
                                } else {
                                    Text("🔒 \(palette.cost) 🪶").font(AppFont.data(11)).foregroundStyle(game.save.feathers >= palette.cost ? Palette.forest : Palette.berry)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.parchment.opacity(0.7)))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(unlocked ? Palette.moss.opacity(0.6) : Palette.parchmentEdge, lineWidth: 1.2))
                    }
                    .buttonStyle(PressableStyle())
                }
            }
        }
    }

    // MARK: Scene

    private var scenePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Perch")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
                ForEach(PerchStyle.allCases) { perch in
                    Button {
                        withAnimation(.spring) { look.perch = perch }
                        Haptics.shared.select()
                    } label: {
                        VStack(spacing: 2) {
                            Text(perch.emoji).font(.system(size: 26))
                            Text(perch.title).font(AppFont.bodyBold(12)).foregroundStyle(Palette.ink)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 12).fill(look.perch == perch ? Palette.moss.opacity(0.3) : Palette.parchment.opacity(0.6)))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(look.perch == perch ? Palette.forest : Palette.parchmentEdge, lineWidth: 1.2))
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            slider("Head tilt", $look.headTilt, -25...25, format: "%.0f°")
            slider("Neck lean", $look.neckLean, -30...40, format: "%.0f°")
        }
    }

    // MARK: Actions

    private var actions: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    game.saveCustomLook(look, for: base.id)
                    SoundEngine.shared.play(.success)
                    Haptics.shared.success()
                } label: {
                    Label("Apply to Atlas", systemImage: "book.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(WoodButtonStyle(color: Palette.forest, compact: true))

                Button {
                    showFrame = true
                    SoundEngine.shared.play(.select)
                } label: {
                    Label("Frame & save", systemImage: "photo.artframe").frame(maxWidth: .infinity)
                }
                .buttonStyle(WoodButtonStyle(color: Palette.dusk, compact: true))
            }
            if game.hasCustomLook(base.id) {
                Button("Restore the Atlas to natural colours") {
                    game.resetLook(for: base.id)
                    Haptics.shared.tap()
                }
                .font(AppFont.italic(14))
                .foregroundStyle(.white)
                .skyShadow()
            }
        }
    }

    @ViewBuilder
    private var creationsStrip: some View {
        if !game.save.creations.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "Your creations", color: .white).skyShadow()
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(game.save.creations) { creation in
                            Button {
                                if let species = db.species(creation.baseSpeciesID) { base = species }
                                withAnimation(.spring) { look = creation.appearance }
                                Haptics.shared.select()
                            } label: {
                                VStack(spacing: 2) {
                                    BirdView(appearance: creation.appearance, animated: false, padding: 4)
                                        .frame(width: 90, height: 80)
                                    Text(creation.name).font(AppFont.script(16)).foregroundStyle(Palette.ink).lineLimit(1)
                                }
                                .frame(width: 110)
                                .parchmentCard(padding: 8, cornerRadius: 14)
                            }
                            .buttonStyle(PressableStyle())
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
    }
}

/// Frames the creation like a museum plate, then saves or shares it.
struct StudioFrameSheet: View {
    let name: String
    let appearance: BirdAppearance
    let baseSpeciesID: String

    @EnvironmentObject private var game: GameState
    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""
    @State private var rendered: Image?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    PlateView(title: title.isEmpty ? "My \(name)" : title, subtitle: "after the \(name)", appearance: appearance)
                        .padding(.horizontal, 10)
                    TextField("Name your creation", text: $title)
                        .font(AppFont.script(28))
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 6)
                        .overlay(alignment: .bottom) { Rectangle().fill(Palette.bark.opacity(0.35)).frame(height: 1) }
                        .padding(.horizontal, 30)
                    HStack(spacing: 12) {
                        Button {
                            game.addCreation(name: title.isEmpty ? "My \(name)" : title, baseSpeciesID: baseSpeciesID, appearance: appearance)
                            SoundEngine.shared.play(.success)
                            Haptics.shared.success()
                            dismiss()
                        } label: {
                            Label("Save to Journal", systemImage: "tray.and.arrow.down.fill")
                        }
                        .buttonStyle(WoodButtonStyle())
                        if let rendered {
                            ShareLink(item: rendered, preview: SharePreview(title.isEmpty ? "My \(name)" : title, image: rendered)) {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                            .buttonStyle(WoodButtonStyle(color: Palette.lake))
                        }
                    }
                }
                .padding(.vertical, 20)
            }
            .background(Palette.parchmentDeep.ignoresSafeArea())
            .navigationTitle("Frame your bird")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Close") { dismiss() } }
            }
            .onAppear { render() }
            .onChange(of: title) { _, _ in render() }
        }
    }

    @MainActor
    private func render() {
        let plate = PlateView(title: title.isEmpty ? "My \(name)" : title, subtitle: "after the \(name)", appearance: appearance)
            .frame(width: 360)
        let renderer = ImageRenderer(content: plate)
        renderer.scale = 3
        if let ui = renderer.uiImage { rendered = Image(uiImage: ui) }
    }
}

/// A naturalist's illustration plate.
struct PlateView: View {
    var title: String
    var subtitle: String
    var appearance: BirdAppearance

    var body: some View {
        VStack(spacing: 6) {
            Text("PLATE No. \(Int(StableHash.fnv1a(title) % 300) + 1)")
                .font(AppFont.caps(11))
                .tracking(2)
                .foregroundStyle(Palette.bark)
            BirdSnapshot(appearance: appearance)
                .frame(height: 260)
            Text(title)
                .font(AppFont.display(36))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(subtitle)
                .font(AppFont.italic(14))
                .foregroundStyle(Palette.inkSoft)
            Text("— drawn in the Plumage Studio —")
                .font(AppFont.capsLight(10))
                .foregroundStyle(Palette.bark.opacity(0.7))
                .padding(.top, 4)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(LinearGradient(colors: [Color(hex: 0xFBF5E6), Palette.parchmentDeep], startPoint: .top, endPoint: .bottom))
        )
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Palette.bark.opacity(0.6), lineWidth: 2).padding(6))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Palette.gold.opacity(0.7), lineWidth: 1).padding(10))
        .background(RoundedRectangle(cornerRadius: 8).fill(Palette.bark).padding(-8))
        .padding(8)
    }
}
