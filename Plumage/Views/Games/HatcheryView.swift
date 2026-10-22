import SwiftUI
import Combine

/// Incubation mini-game: pick a mystery egg, keep it in the warm zone by tapping, guess the
/// species, and watch it hatch — sometimes into a rare colour variant.
struct HatcheryView: View {
    enum Stage: Equatable { case choose, incubate, hatching, revealed }

    @EnvironmentObject private var game: GameState

    @State private var stage: Stage = .choose
    @State private var nests: [BirdSpecies] = []
    @State private var chosen: BirdSpecies?
    @State private var guessOptions: [BirdSpecies] = []
    @State private var guess: BirdSpecies?
    @State private var temperature: Double = 0.35
    @State private var progress: Double = 0
    @State private var wobble: Double = 0
    @State private var hatchling: Hatchling?
    @State private var nameDraft = ""
    @State private var lastCrackLevel = 0
    @State private var burst = 0
    @State private var showAviary = false
    @State private var hatchingStarted: Date?

    private let idealZone = 0.5...0.8
    private let ticker = Timer.publish(every: 1.0 / 30, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ScreenTitle(title: "The Hatchery", subtitle: subtitle)
                switch stage {
                case .choose: chooseView
                case .incubate, .hatching: incubateView
                case .revealed: revealView
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 44)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .overlay {
            if burst > 0 { FeatherBurst(count: 50, duration: 3).id(burst).ignoresSafeArea() }
        }
        .onAppear { if nests.isEmpty { refillNests() } }
        .onReceive(ticker) { _ in tick() }
        .sheet(isPresented: $showAviary) {
            AviaryView().environmentObject(game)
        }
    }

    private var subtitle: String {
        switch stage {
        case .choose: return "Choose a mystery egg"
        case .incubate: return "Keep it cosy — tap to warm"
        case .hatching: return "Something is happening…"
        case .revealed: return "Welcome to the world!"
        }
    }

    // MARK: Choose

    private func refillNests() {
        var rng = SystemRandomNumberGenerator()
        var picked: [BirdSpecies] = []
        while picked.count < 3 {
            picked.append(BirdDatabase.shared.random(excluding: Set(picked.map(\.id)), using: &rng))
        }
        nests = picked
    }

    private var chooseView: some View {
        VStack(spacing: 14) {
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(Array(nests.enumerated()), id: \.offset) { i, species in
                    Button {
                        begin(with: species)
                    } label: {
                        VStack(spacing: 6) {
                            ZStack(alignment: .bottom) {
                                NestShape()
                                    .fill(LinearGradient(colors: [Color(hex: 0x8A6A44), Color(hex: 0x5B4332)], startPoint: .top, endPoint: .bottom))
                                    .frame(height: 40)
                                EggArt(egg: species.egg, seed: species.seed &+ UInt64(i))
                                    .frame(height: 80)
                                    .padding(.bottom, 18)
                            }
                            .frame(height: 110)
                            Text("Nest \(["I", "II", "III"][i])")
                                .font(AppFont.caps(11))
                                .foregroundStyle(Palette.inkSoft)
                            Text(sizeHint(species.egg))
                                .font(AppFont.hand(11))
                                .foregroundStyle(Palette.moss)
                        }
                        .frame(maxWidth: .infinity)
                        .parchmentCard(padding: 10, cornerRadius: 16)
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel("Mystery egg in nest \(i + 1), \(species.egg.base.friendlyName.lowercased()), \(species.egg.pattern.title.lowercased())")
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "How to incubate")
                instruction("👆", "Tap the egg to warm it. Warmth slowly fades.")
                instruction("🌡️", "Keep the thermometer in the green zone to make progress.")
                instruction("🔥", "Too hot and the embryo stops growing!")
                instruction("🔮", "Guess the species before it hatches for bonus feathers.")
                instruction("✨", "Rare variants — leucistic, melanistic, aurora, golden — can hatch.")
            }
            .parchmentCard()
            HStack(spacing: 10) {
                Button {
                    refillNests()
                    SoundEngine.shared.play(.whoosh)
                } label: {
                    Label("New nests", systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(WoodButtonStyle(color: Palette.bark, compact: true))
                Button {
                    showAviary = true
                } label: {
                    Label("My aviary (\(game.save.aviary.count))", systemImage: "bird.fill")
                }
                .buttonStyle(WoodButtonStyle(compact: true))
            }
        }
    }

    private func sizeHint(_ egg: EggInfo) -> String {
        switch egg.lengthMm {
        case ..<25: return "tiny"
        case ..<45: return "small"
        case ..<75: return "medium"
        case ..<110: return "large"
        default: return "enormous!"
        }
    }

    private func instruction(_ emoji: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(emoji)
            Text(text).font(AppFont.body(15)).foregroundStyle(Palette.ink).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func begin(with species: BirdSpecies) {
        chosen = species
        var rng = SystemRandomNumberGenerator()
        var options = [species]
        while options.count < 3 {
            options.append(BirdDatabase.shared.random(excluding: Set(options.map(\.id)), using: &rng))
        }
        guessOptions = options.shuffled()
        guess = nil
        temperature = 0.35
        progress = 0
        lastCrackLevel = 0
        hatchingStarted = nil
        withAnimation(.spring) { stage = .incubate }
        SoundEngine.shared.play(.select)
        Haptics.shared.bump()
    }

    // MARK: Incubate

    private var inZone: Bool { idealZone.contains(temperature) }

    private func tick() {
        let dt = 1.0 / 30
        switch stage {
        case .incubate:
            temperature = max(0, temperature - 0.11 * dt)
            if inZone {
                progress = min(1, progress + 0.075 * dt)
            } else if temperature > 0.92 {
                progress = max(0, progress - 0.02 * dt)
            }
            wobble = sin(Date().timeIntervalSinceReferenceDate * (4 + progress * 10)) * (2 + progress * 7)
            let crackLevel = Int(progress * 4)
            if crackLevel > lastCrackLevel {
                lastCrackLevel = crackLevel
                SoundEngine.shared.play(.crack)
                Haptics.shared.pulse(0.7)
            }
            if progress >= 1 {
                stage = .hatching
                hatchingStarted = Date()
                Haptics.shared.thump()
            }
        case .hatching:
            wobble = sin(Date().timeIntervalSinceReferenceDate * 40) * 12
            if let started = hatchingStarted, Date().timeIntervalSince(started) > 1.3 {
                finishHatch()
            }
        default:
            break
        }
    }

    private func warm() {
        guard stage == .incubate else { return }
        temperature = min(1, temperature + 0.085)
        Haptics.shared.pulse(0.35)
        if temperature > 0.92 { Haptics.shared.warning() }
    }

    private var incubateView: some View {
        VStack(spacing: 16) {
            HStack(alignment: .center, spacing: 16) {
                Thermometer(temperature: temperature, zone: idealZone)
                    .frame(width: 44, height: 240)
                ZStack {
                    RingProgress(fraction: progress, lineWidth: 10, color: Palette.sunrise)
                        .frame(width: 230, height: 230)
                    Circle()
                        .fill(RadialGradient(colors: [Palette.sunrise.opacity(0.35 * temperature + 0.05), .clear],
                                             center: .center, startRadius: 10, endRadius: 120))
                        .frame(width: 230, height: 230)
                    if let chosen {
                        EggArt(egg: chosen.egg, seed: chosen.seed, cracks: progress)
                            .frame(height: 160)
                            .rotationEffect(.degrees(wobble), anchor: .bottom)
                            .scaleEffect(stage == .hatching ? 1.08 : 1)
                    }
                }
                .contentShape(Circle())
                .onTapGesture { warm() }
                .accessibilityElement()
                .accessibilityLabel("Egg. Incubation \(Int(progress * 100)) percent.")
                .accessibilityHint("Double tap to warm the egg")
                .accessibilityAddTraits(.isButton)
            }
            Text(statusText)
                .font(AppFont.script(26))
                .foregroundStyle(.white)
                .skyShadow()
                .animation(.easeInOut, value: statusText)

            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Make a guess")
                Text(guess == nil ? "Which bird do you think laid this egg?" : "You guessed the \(guess!.name). We'll see…")
                    .font(AppFont.italic(14))
                    .foregroundStyle(Palette.inkSoft)
                ForEach(guessOptions) { option in
                    Button {
                        guard guess == nil else { return }
                        guess = option
                        Haptics.shared.select()
                        SoundEngine.shared.play(.select)
                    } label: {
                        HStack {
                            Text(option.name).font(AppFont.bodyBold(16)).foregroundStyle(guess == option ? .white : Palette.ink)
                            Spacer()
                            if guess == option { Image(systemName: "sparkles").foregroundStyle(.white) }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 12).fill(guess == option ? Palette.dusk : Palette.parchment.opacity(0.7)))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.parchmentEdge, lineWidth: 1))
                    }
                    .buttonStyle(PressableStyle())
                    .disabled(guess != nil && guess != option)
                }
            }
            .parchmentCard()
        }
    }

    private var statusText: String {
        if stage == .hatching { return "It's hatching!" }
        if temperature > 0.92 { return "Too hot! Let it cool…" }
        if temperature < idealZone.lowerBound { return progress > 0 ? "Getting chilly — tap!" : "Tap the egg to warm it" }
        return progress > 0.75 ? "Almost there…" : "Perfectly cosy"
    }

    private func finishHatch() {
        guard let chosen else { return }
        let right = guess == chosen
        hatchling = game.hatch(chosen, guessedRight: right)
        nameDraft = hatchling?.nickname ?? ""
        stage = .revealed
        burst += 1
        SoundEngine.shared.play(.hatch)
        runAfter(0.7) { SoundEngine.shared.playSong(chosen) }
        Haptics.shared.success()
    }

    // MARK: Reveal

    @ViewBuilder
    private var revealView: some View {
        if let hatchling, let species = BirdDatabase.shared.species(hatchling.speciesID) {
            VStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(RadialGradient(colors: [hatchling.rarity.color.opacity(0.45), Palette.parchment],
                                             center: .center, startRadius: 10, endRadius: 220))
                    BirdView(appearance: hatchling.appearance, singing: SoundEngine.shared.singingSpeciesID == species.id, padding: 20)
                }
                .frame(height: 280)
                .overlay(alignment: .topTrailing) {
                    RarityStars(rarity: hatchling.rarity, size: 14).padding(14)
                }
                VStack(spacing: 6) {
                    if hatchling.variant != .wild {
                        Text("✨ \(hatchling.variant.title.uppercased()) VARIANT ✨")
                            .font(AppFont.caps(13))
                            .tracking(1.5)
                            .foregroundStyle(hatchling.rarity.color)
                        Text(hatchling.variant.blurb).font(AppFont.italic(14)).foregroundStyle(Palette.inkSoft)
                    }
                    Text("A baby \(species.name)!")
                        .font(AppFont.title(22))
                        .foregroundStyle(Palette.ink)
                    if let guess {
                        Text(guess == species ? "🔮 Your guess was right! Bonus feathers earned." : "🔮 You guessed the \(guess.name) — so close!")
                            .font(AppFont.hand(14))
                            .foregroundStyle(guess == species ? Palette.forest : Palette.berry)
                    }
                    TextField("Name", text: $nameDraft)
                        .font(AppFont.script(34))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Palette.ink)
                        .padding(.vertical, 4)
                        .overlay(alignment: .bottom) { Rectangle().fill(Palette.bark.opacity(0.35)).frame(height: 1) }
                        .onSubmit { game.rename(hatchling, to: nameDraft) }
                        .padding(.horizontal, 30)
                }
                .parchmentCard()
                HStack(spacing: 10) {
                    Button {
                        game.rename(hatchling, to: nameDraft)
                        if let saved = game.save.aviary.first(where: { $0.id == hatchling.id }) { game.setCompanion(saved) }
                    } label: {
                        Label("Make companion", systemImage: "house.fill")
                    }
                    .buttonStyle(WoodButtonStyle(compact: true))
                    Button {
                        game.rename(hatchling, to: nameDraft)
                        self.hatchling = nil
                        refillNests()
                        withAnimation(.spring) { stage = .choose }
                    } label: {
                        Label("Hatch another", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(WoodButtonStyle(color: Palette.sunrise, compact: true))
                }
            }
        }
    }
}

/// A woven stick nest.
struct NestShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.2))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.2), control: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.55))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.2), control: CGPoint(x: rect.midX, y: rect.maxY + rect.height * 0.5))
        p.closeSubpath()
        return p
    }
}

/// A vintage thermometer with the ideal incubation band.
struct Thermometer: View {
    var temperature: Double
    var zone: ClosedRange<Double>

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height - geo.size.width
            ZStack(alignment: .bottom) {
                Capsule().fill(Palette.parchment).overlay(Capsule().strokeBorder(Palette.bark.opacity(0.6), lineWidth: 2))
                Rectangle()
                    .fill(Palette.moss.opacity(0.35))
                    .frame(width: geo.size.width * 0.7, height: h * CGFloat(zone.upperBound - zone.lowerBound))
                    .offset(y: -geo.size.width * 0.6 - h * CGFloat(zone.lowerBound))
                Capsule()
                    .fill(LinearGradient(colors: [Palette.sunrise, Palette.berry], startPoint: .bottom, endPoint: .top))
                    .frame(width: geo.size.width * 0.32, height: geo.size.width * 0.6 + h * CGFloat(temperature))
                    .padding(.bottom, geo.size.width * 0.2)
                Circle()
                    .fill(Palette.berry)
                    .frame(width: geo.size.width * 0.8, height: geo.size.width * 0.8)
                    .padding(.bottom, geo.size.width * 0.1)
            }
            .animation(.linear(duration: 0.1), value: temperature)
        }
        .accessibilityElement()
        .accessibilityLabel("Temperature \(Int(temperature * 100)) percent")
    }
}

/// All the birds the player has hatched.
struct AviaryView: View {
    @EnvironmentObject private var game: GameState
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Hatchling?

    var body: some View {
        NavigationStack {
            ScrollView {
                if game.save.aviary.isEmpty {
                    VStack(spacing: 10) {
                        Text("🪹").font(.system(size: 60))
                        Text("Your aviary is empty").font(AppFont.title(20)).foregroundStyle(Palette.ink)
                        Text("Hatch an egg to welcome your first resident.").font(AppFont.italic(15)).foregroundStyle(Palette.inkSoft)
                    }
                    .padding(.top, 60)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                        ForEach(game.save.aviary.reversed()) { h in
                            Button { selected = h } label: { HatchlingCard(hatchling: h) }
                                .buttonStyle(PressableStyle())
                        }
                    }
                    .padding(16)
                }
            }
            .background(Palette.parchmentDeep.ignoresSafeArea())
            .navigationTitle("My Aviary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() }.bold() }
            }
            .sheet(item: $selected) { h in
                HatchlingDetail(hatchling: h).environmentObject(game)
                    .presentationDetents([.medium, .large])
            }
        }
    }
}

struct HatchlingCard: View {
    var hatchling: Hatchling
    @EnvironmentObject private var game: GameState

    var body: some View {
        VStack(spacing: 4) {
            BirdView(appearance: hatchling.appearance, animated: false, padding: 6)
                .frame(height: 110)
                .background(RoundedRectangle(cornerRadius: 12).fill(hatchling.rarity.color.opacity(0.15)))
            Text(hatchling.nickname).font(AppFont.script(24)).foregroundStyle(Palette.ink).lineLimit(1)
            Text(BirdDatabase.shared.species(hatchling.speciesID)?.name ?? "")
                .font(AppFont.italic(12)).foregroundStyle(Palette.inkSoft).lineLimit(1)
            HStack {
                RarityStars(rarity: hatchling.rarity, size: 9)
                Spacer()
                if hatchling.variant != .wild {
                    Text(hatchling.variant.title).font(AppFont.caps(9)).foregroundStyle(hatchling.rarity.color)
                }
                if game.companion?.id == hatchling.id { Text("🏡") }
            }
        }
        .parchmentCard(padding: 10, cornerRadius: 16)
    }
}

struct HatchlingDetail: View {
    var hatchling: Hatchling
    @EnvironmentObject private var game: GameState
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var confirmRelease = false

    var body: some View {
        let species = BirdDatabase.shared.species(hatchling.speciesID)
        VStack(spacing: 12) {
            BirdView(appearance: hatchling.appearance, singing: SoundEngine.shared.singingSpeciesID == hatchling.speciesID, padding: 10)
                .frame(height: 200)
                .onTapGesture {
                    if let species { SoundEngine.shared.playSong(species) }
                }
            TextField("Name", text: $name)
                .font(AppFont.script(34))
                .multilineTextAlignment(.center)
                .onSubmit { game.rename(hatchling, to: name) }
            Text("\(hatchling.variant.title) \(species?.name ?? "") · hatched \(hatchling.hatchedOn.formatted(date: .abbreviated, time: .omitted))")
                .font(AppFont.italic(14))
                .foregroundStyle(Palette.inkSoft)
            RarityStars(rarity: hatchling.rarity, size: 14)
            HStack(spacing: 10) {
                Button("Save name") {
                    game.rename(hatchling, to: name)
                    dismiss()
                }
                .buttonStyle(WoodButtonStyle(compact: true))
                Button("Companion") {
                    game.setCompanion(hatchling)
                    dismiss()
                }
                .buttonStyle(WoodButtonStyle(color: Palette.sunrise, compact: true))
                Button("Release") { confirmRelease = true }
                    .buttonStyle(WoodButtonStyle(color: Palette.berry, compact: true))
            }
        }
        .padding(20)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Palette.parchment.ignoresSafeArea())
        .onAppear { name = hatchling.nickname }
        .confirmationDialog("Release \(hatchling.nickname) into the wild?", isPresented: $confirmRelease, titleVisibility: .visible) {
            Button("Release", role: .destructive) {
                game.release(hatchling)
                dismiss()
            }
        }
    }
}
