import SwiftUI

// MARK: - Overview

struct OverviewSection: View {
    let species: BirdSpecies

    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text("“\(species.tagline)”")
                    .font(AppFont.hand(18))
                    .foregroundStyle(Palette.moss)
                Text(species.summary)
                    .font(AppFont.body(17))
                    .foregroundStyle(Palette.ink)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .parchmentCard()

            VStack(spacing: 12) {
                SectionHeader(title: "Field measurements")
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    InfoTile(emoji: "📏", label: "Length", value: species.lengthText)
                    InfoTile(emoji: "🪽", label: "Wingspan", value: species.wingspanText)
                    InfoTile(emoji: "⚖️", label: "Weight", value: species.weightText)
                    InfoTile(emoji: "⏳", label: "Lifespan", value: species.lifespanText)
                    InfoTile(emoji: "💨", label: "Top speed", value: species.speedText)
                    InfoTile(emoji: "👥", label: "Population", value: species.population ?? "Not well known")
                }
            }
            .parchmentCard()

            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Family tree")
                TaxonomyLadder(species: species)
            }
            .parchmentCard()

            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Conservation")
                ConservationScale(status: species.status)
            }
            .parchmentCard()

            VStack(spacing: 10) {
                SectionHeader(title: "Field traits")
                ForEach(Array(species.traits.all.enumerated()), id: \.offset) { index, trait in
                    StatBar(label: trait.0, emoji: trait.1, value: trait.2,
                            color: [Palette.lake, Palette.dusk, Palette.gold, Palette.forest, Palette.berry][index % 5])
                }
            }
            .parchmentCard()

            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Curious facts")
                ForEach(Array(species.facts.enumerated()), id: \.offset) { index, fact in
                    HStack(alignment: .top, spacing: 10) {
                        Text(["❦", "✦", "❧", "✧"][index % 4])
                            .font(.system(size: 18))
                            .foregroundStyle(Palette.gold)
                        Text(fact)
                            .font(AppFont.body(16))
                            .foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .parchmentCard()
        }
    }
}

struct TaxonomyLadder: View {
    let species: BirdSpecies

    var body: some View {
        let genus = species.scientific.split(separator: " ").first.map(String.init) ?? species.scientific
        let rungs: [(String, String, String)] = [
            ("Class", "Aves", "Birds"),
            ("Order", species.order, species.group.title),
            ("Family", species.family, species.familyCommon),
            ("Genus", genus, ""),
            ("Species", species.scientific, species.name)
        ]
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(rungs.enumerated()), id: \.offset) { index, rung in
                HStack(alignment: .top, spacing: 10) {
                    VStack(spacing: 0) {
                        Circle().fill(index == rungs.count - 1 ? Palette.berry : Palette.moss).frame(width: 10, height: 10)
                        if index < rungs.count - 1 {
                            Rectangle().fill(Palette.moss.opacity(0.4)).frame(width: 2, height: 30)
                        }
                    }
                    .padding(.top, 4)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(rung.0.uppercased()).font(AppFont.caps(10)).foregroundStyle(Palette.inkSoft)
                        HStack(spacing: 6) {
                            Text(rung.1).font(index >= 3 ? AppFont.italic(16) : AppFont.bodyBold(16)).foregroundStyle(Palette.ink)
                            if !rung.2.isEmpty {
                                Text("· \(rung.2)").font(AppFont.body(13)).foregroundStyle(Palette.inkSoft).lineLimit(1)
                            }
                        }
                    }
                    .padding(.leading, CGFloat(index) * 8)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Anatomy

struct AnatomySection: View {
    let species: BirdSpecies
    @EnvironmentObject private var game: GameState
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        let look = game.appearance(for: species)
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                SectionHeader(title: "Plumage palette")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 10)], spacing: 12) {
                    ForEach(Array(look.palette.enumerated()), id: \.offset) { _, swatch in
                        ColorSwatch(label: swatch.0, color: swatch.1)
                    }
                }
            }
            .parchmentCard()

            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "The bill")
                HStack(spacing: 14) {
                    BeakDiagram(appearance: look)
                        .frame(width: 120, height: 80)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(look.beakShape.title).font(AppFont.title(20)).foregroundStyle(Palette.ink)
                        Text(look.beakShape.purpose).font(AppFont.body(14)).foregroundStyle(Palette.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .parchmentCard()

            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Distinctive features")
                featureLine("👑", "Crest", look.crest == .none ? "No crest — a smooth crown." : "\(look.crest.title) crest")
                featureLine("🪶", "Tail", "\(look.tailStyle.title) tail" + (look.tailStyle == .train ? " — a train of elongated coverts" : ""))
                featureLine("🦋", "Wing pattern", look.wingPattern == .none ? "Plain wings" : "\(look.wingPattern.title) on the wing coverts")
                featureLine("🎭", "Face", look.markings.isEmpty ? "Unmarked face" : look.markings.map(\.kind.title).joined(separator: ", "))
                featureLine("👁️", "Eye", "\(look.eye.friendlyName) iris" + (look.eyeSize > 1.4 ? " — enormous, forward-facing eyes" : ""))
                featureLine("🦶", "Legs", look.legLength > 2 ? "Long wading legs" : (look.legLength < 0.3 ? "Short legs, often hidden by feathers" : "Perching legs"))
            }
            .parchmentCard()

            VStack(spacing: 12) {
                SectionHeader(title: "Size next to you")
                SizeComparisonView(species: species, appearance: look)
                    .frame(height: 220)
                Text("Silhouettes are to scale: a 170 cm person beside a \(species.lengthText) bird.")
                    .font(AppFont.italic(13))
                    .foregroundStyle(Palette.inkSoft)
                    .multilineTextAlignment(.center)
            }
            .parchmentCard()

            Button {
                router.openStudio(for: species)
            } label: {
                Label("Reshape this bird in the Studio", systemImage: "paintbrush.pointed.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(WoodButtonStyle(color: Palette.dusk))
        }
    }

    private func featureLine(_ emoji: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(emoji).frame(width: 24)
            Text(title.uppercased()).font(AppFont.caps(11)).foregroundStyle(Palette.inkSoft).frame(width: 92, alignment: .leading).padding(.top, 2)
            Text(detail).font(AppFont.body(15)).foregroundStyle(Palette.ink).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}

struct ColorSwatch: View {
    var label: String
    var color: RGBA

    var body: some View {
        VStack(spacing: 4) {
            Circle()
                .fill(color.color)
                .frame(width: 44, height: 44)
                .overlay(Circle().strokeBorder(Palette.bark.opacity(0.25), lineWidth: 1))
                .overlay(Circle().strokeBorder(.white.opacity(0.5), lineWidth: 2).padding(3))
                .shadow(color: color.color.opacity(0.4), radius: 4, y: 2)
            Text(label).font(AppFont.bodyBold(12)).foregroundStyle(Palette.ink).lineLimit(1)
            Text(color.friendlyName).font(AppFont.italic(11)).foregroundStyle(Palette.inkSoft).lineLimit(1).minimumScaleFactor(0.8)
            Text(color.hexString).font(AppFont.dataLight(9)).foregroundStyle(Palette.inkSoft.opacity(0.8))
        }
        .accessibilityElement(children: .combine)
    }
}

/// A close-up drawing of just the bill.
struct BeakDiagram: View {
    var appearance: BirdAppearance

    var body: some View {
        Canvas { context, size in
            let R: CGFloat = 34
            let shape = BirdRenderer.beakPath(appearance.beakShape, R: R, length: CGFloat(appearance.beakLength))
            let bounds = shape.path.boundingRect.insetBy(dx: -6, dy: -6)
            let scale = min(size.width / bounds.width, size.height / bounds.height)
            var g = context
            g.translateBy(x: size.width / 2, y: size.height / 2)
            g.scaleBy(x: scale, y: scale)
            g.translateBy(x: -bounds.midX, y: -bounds.midY)
            g.fill(Path(ellipseIn: CGRect(x: -R * 1.6, y: -R, width: R * 1.8, height: R * 2)), with: .color(appearance.head.color.opacity(0.35)))
            g.fill(shape.path, with: .linearGradient(Gradient(colors: [appearance.beak.shaded(0.2).color, appearance.beak.shaded(-0.15).color]),
                                                     startPoint: CGPoint(x: 0, y: -shape.height / 2), endPoint: CGPoint(x: 0, y: shape.height / 2)))
            g.stroke(shape.path, with: .color(appearance.beak.shaded(-0.45).color), lineWidth: 1.5)
        }
        .accessibilityHidden(true)
    }
}

/// A person and the bird drawn to the same scale.
struct SizeComparisonView: View {
    let species: BirdSpecies
    let appearance: BirdAppearance

    var body: some View {
        GeometryReader { geo in
            let personHeight = geo.size.height * 0.92
            let birdHeight = max(6, personHeight * CGFloat(species.lengthCm.mid / 170) * 0.85)
            let birdWidth = birdHeight * 1.3
            HStack(alignment: .bottom, spacing: 18) {
                PersonSilhouette()
                    .fill(Palette.bark.opacity(0.55))
                    .frame(width: personHeight * 0.32, height: personHeight)
                BirdSilhouette(appearance: appearance, color: species.primaryHabitat.tint, padding: 0)
                    .frame(width: birdWidth, height: birdHeight)
                    .overlay(alignment: .top) {
                        if birdHeight < 26 {
                            Text("🔍 tiny!")
                                .font(AppFont.hand(12))
                                .foregroundStyle(Palette.moss)
                                .fixedSize()
                                .offset(y: -22)
                        }
                    }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Palette.bark.opacity(0.3)).frame(height: 1)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("A \(species.name), \(species.lengthText) long, beside a 170 centimetre person.")
    }
}

/// A friendly, stylised human figure for scale.
struct PersonSilhouette: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        let headR = w * 0.22
        p.addEllipse(in: CGRect(x: rect.midX - headR, y: rect.minY, width: headR * 2, height: headR * 2))
        p.addRoundedRect(in: CGRect(x: rect.minX + w * 0.18, y: rect.minY + headR * 2.2, width: w * 0.64, height: h * 0.42),
                         cornerSize: CGSize(width: w * 0.2, height: w * 0.2))
        p.addRoundedRect(in: CGRect(x: rect.minX + w * 0.22, y: rect.minY + h * 0.55, width: w * 0.24, height: h * 0.45),
                         cornerSize: CGSize(width: w * 0.1, height: w * 0.1))
        p.addRoundedRect(in: CGRect(x: rect.minX + w * 0.54, y: rect.minY + h * 0.55, width: w * 0.24, height: h * 0.45),
                         cornerSize: CGSize(width: w * 0.1, height: w * 0.1))
        return p
    }
}

// MARK: - Behaviour

struct BehaviorSection: View {
    let species: BirdSpecies

    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Signature behaviours")
                ForEach(species.behaviors) { behavior in
                    HStack(alignment: .top, spacing: 12) {
                        Text(behavior.icon)
                            .font(.system(size: 26))
                            .frame(width: 46, height: 46)
                            .background(Circle().fill(Palette.moss.opacity(0.15)))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(behavior.title).font(AppFont.title(17)).foregroundStyle(Palette.ink)
                            Text(behavior.detail).font(AppFont.body(15)).foregroundStyle(Palette.inkSoft)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .parchmentCard()

            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "On the menu")
                Flow {
                    ForEach(species.diet) { d in Chip(text: d.title, emoji: d.emoji, color: Palette.gold) }
                }
                Text(species.dietNote).font(AppFont.body(15)).foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .parchmentCard()

            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Movements")
                HStack(spacing: 10) {
                    Text(species.migration.emoji).font(.system(size: 30))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(species.migration.title).font(AppFont.title(18)).foregroundStyle(Palette.ink)
                        Text(species.migrationNote).font(AppFont.body(14)).foregroundStyle(Palette.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                MigrationMeter(score: species.migration.distanceScore)
            }
            .parchmentCard()
        }
    }
}

struct MigrationMeter: View {
    var score: Double
    @State private var shown = false

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.bark.opacity(0.12))
                    Capsule()
                        .fill(LinearGradient(colors: [Palette.moss, Palette.lake], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * CGFloat(shown ? score : 0))
                    Text("🕊️")
                        .offset(x: max(0, geo.size.width * CGFloat(shown ? score : 0) - 14), y: -1)
                }
            }
            .frame(height: 14)
            HStack {
                Text("Stays home").font(AppFont.caps(9))
                Spacer()
                Text("Crosses the globe").font(AppFont.caps(9))
            }
            .foregroundStyle(Palette.inkSoft)
        }
        .onAppear { withAnimation(.easeOut(duration: 1.2)) { shown = true } }
        .accessibilityHidden(true)
    }
}

// MARK: - Eggs & nest

struct EggsSection: View {
    let species: BirdSpecies
    @EnvironmentObject private var game: GameState
    @State private var wobble = false

    private var egg: EggInfo { species.egg }

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                SectionHeader(title: "The egg")
                HStack(alignment: .bottom, spacing: 22) {
                    let maxLen = max(egg.lengthMm, 57)
                    VStack(spacing: 6) {
                        EggArt(egg: egg, seed: species.seed)
                            .frame(height: 170 * CGFloat(egg.lengthMm / maxLen))
                            .rotationEffect(.degrees(wobble ? 6 : -6), anchor: .bottom)
                            .animation(.easeInOut(duration: 0.18).repeatCount(5, autoreverses: true), value: wobble)
                            .onTapGesture {
                                wobble.toggle()
                                Haptics.shared.pulse(0.4)
                                SoundEngine.shared.play(.crack)
                            }
                        Text(species.name).font(AppFont.hand(12)).foregroundStyle(Palette.inkSoft)
                    }
                    VStack(spacing: 6) {
                        EggArt(geometry: EggGeometry(.oval), base: RGBA(0xF3E6D2), marking: RGBA(0xF3E6D2), pattern: .plain, seed: 2)
                            .frame(height: 170 * CGFloat(57 / maxLen))
                        Text("Chicken egg").font(AppFont.hand(12)).foregroundStyle(Palette.inkSoft)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 6)
                Text(egg.description)
                    .font(AppFont.body(16))
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .parchmentCard()

            VStack(spacing: 12) {
                SectionHeader(title: "Egg card")
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    InfoTile(emoji: "🥚", label: "Shape", value: egg.shape.title)
                    InfoTile(emoji: "🎨", label: "Markings", value: egg.pattern.title)
                    InfoTile(emoji: "📐", label: "Size", value: "\(Int(egg.lengthMm)) × \(Int(egg.widthMm)) mm")
                    InfoTile(emoji: "🐔", label: "Volume", value: chickenText)
                    InfoTile(emoji: "🔢", label: "Clutch", value: egg.clutch.formatted(egg.clutch.max == 1 ? "egg" : "eggs"))
                    InfoTile(emoji: "🌡️", label: "Incubation", value: egg.incubationDays.formatted("days"))
                }
                HStack(spacing: 16) {
                    ColorSwatch(label: "Ground", color: egg.base)
                    if egg.pattern != .plain { ColorSwatch(label: "Markings", color: egg.marking) }
                    Spacer(minLength: 0)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Shape class").font(AppFont.caps(10)).foregroundStyle(Palette.inkSoft)
                        Text(egg.shape.explanation).font(AppFont.italic(13)).foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .parchmentCard()

            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "A typical clutch")
                ClutchView(egg: egg, count: Int(egg.clutch.max.rounded()), seed: species.seed)
                    .frame(maxWidth: .infinity)
                IncubationTimeline(days: egg.incubationDays)
            }
            .parchmentCard()

            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "The nest")
                HStack(alignment: .top, spacing: 12) {
                    Text(species.nest.type.emoji)
                        .font(.system(size: 34))
                        .frame(width: 56, height: 56)
                        .background(Circle().fill(Palette.bark.opacity(0.12)))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(species.nest.type.title).font(AppFont.title(18)).foregroundStyle(Palette.ink)
                        Text(species.nest.description).font(AppFont.body(15)).foregroundStyle(Palette.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .parchmentCard()
        }
        .onAppear { game.recordEggInspected(species) }
    }

    private var chickenText: String {
        let v = egg.chickenEggs
        if v >= 1.5 { return String(format: "≈ %.0f× a hen's", v) }
        if v >= 0.9 { return "≈ a hen's egg" }
        return String(format: "≈ 1/%.0f of a hen's", 1 / max(v, 0.001))
    }
}

struct IncubationTimeline: View {
    var days: Span
    @State private var progress: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.bark.opacity(0.12))
                    Capsule()
                        .fill(LinearGradient(colors: [Palette.sunrise.opacity(0.6), Palette.berry], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * progress)
                    HStack {
                        Text("🥚")
                        Spacer()
                        Text("🐣")
                    }
                    .padding(.horizontal, 2)
                }
            }
            .frame(height: 24)
            Text("Hatches after \(days.formatted("days")) of incubation")
                .font(AppFont.italic(13))
                .foregroundStyle(Palette.inkSoft)
        }
        .onAppear { withAnimation(.easeInOut(duration: 1.8)) { progress = 1 } }
    }
}

// MARK: - Song

struct SongSection: View {
    let species: BirdSpecies
    @ObservedObject private var sound = SoundEngine.shared
    @EnvironmentObject private var game: GameState
    @State private var startedAt: Date?
    @State private var duration: Double = 1

    private var isSinging: Bool { sound.singingSpeciesID == species.id }

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 14) {
                SectionHeader(title: "Voice")
                Button {
                    if isSinging {
                        sound.stopSong()
                    } else {
                        duration = sound.playSong(species)
                        game.recordSongPlayed(species)
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(RadialGradient(colors: [Palette.moss, Palette.forest], center: .center, startRadius: 4, endRadius: 60))
                            .frame(width: 104, height: 104)
                            .shadow(color: Palette.forest.opacity(0.4), radius: 10, y: 6)
                        Image(systemName: isSinging ? "stop.fill" : "play.fill")
                            .font(.system(size: 38, weight: .bold))
                            .foregroundStyle(Palette.parchment)
                            .offset(x: isSinging ? 0 : 3)
                    }
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(isSinging ? "Stop song" : "Play song")

                Text(species.call.mnemonic)
                    .font(AppFont.hand(20))
                    .foregroundStyle(Palette.moss)
                    .multilineTextAlignment(.center)
                Text(species.call.description)
                    .font(AppFont.body(16))
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .parchmentCard()

            VStack(spacing: 10) {
                SectionHeader(title: "Sonogram")
                Sonogram(signature: species.call.song, seed: species.seed, startedAt: isSinging ? startedAt : nil, duration: duration)
                    .frame(height: 150)
                Text("Pitch over time — each stroke is one note of the song you hear.")
                    .font(AppFont.italic(12))
                    .foregroundStyle(Palette.inkSoft)
            }
            .parchmentCard()

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                InfoTile(emoji: "🎼", label: "Style", value: species.call.song.style.title)
                InfoTile(emoji: "📶", label: "Pitch", value: pitchText)
                InfoTile(emoji: "⏱️", label: "Tempo", value: String(format: "%.1f /s", species.call.song.tempo))
            }
            .parchmentCard(padding: 10)
        }
        .onChange(of: isSinging) { _, singing in
            startedAt = singing ? Date() : nil
            if singing { duration = BirdSynth.duration(species.call.song, seed: species.seed) }
        }
    }

    private var pitchText: String {
        let p = species.call.song.pitch
        return p >= 1000 ? String(format: "%.1f kHz", p / 1000) : "\(Int(p)) Hz"
    }
}

/// A stylised spectrogram drawn from the very notes the synthesizer plays, with a moving playhead.
struct Sonogram: View {
    let signature: SongSignature
    let seed: UInt64
    var startedAt: Date?
    var duration: Double

    var body: some View {
        let notes = BirdSynth.notes(for: signature, seed: seed)
        let total = max((notes.map { $0.start + $0.duration }.max() ?? 1), 0.5)
        let frequencies = notes.flatMap { [$0.f0, $0.f1] }
        let lo = max(20, (frequencies.min() ?? 100) * 0.7)
        let hi = max(lo * 2, (frequencies.max() ?? 1000) * 1.3)
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: startedAt == nil)) { timeline in
            let elapsed = startedAt.map { timeline.date.timeIntervalSince($0) } ?? -1
            Canvas { context, size in
                let rect = CGRect(origin: .zero, size: size)
                context.fill(Path(roundedRect: rect, cornerRadius: 12), with: .color(Color(hex: 0x1F2A24)))
                var grid = Path()
                for i in 1..<4 {
                    let y = size.height * CGFloat(i) / 4
                    grid.move(to: CGPoint(x: 0, y: y))
                    grid.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(grid, with: .color(.white.opacity(0.08)), lineWidth: 1)

                func yFor(_ f: Double) -> CGFloat {
                    let u = log(max(f, lo) / lo) / log(hi / lo)
                    return size.height * (1 - CGFloat(u) * 0.9) - size.height * 0.05
                }
                for note in notes {
                    var stroke = Path()
                    let steps = 12
                    for s in 0...steps {
                        let u = Double(s) / Double(steps)
                        let t = note.start + note.duration * u
                        let shaped = note.curve == 1 ? u : pow(u, note.curve)
                        let f = note.f0 + (note.f1 - note.f0) * shaped
                        let point = CGPoint(x: size.width * CGFloat(t / total), y: yFor(f))
                        if s == 0 { stroke.move(to: point) } else { stroke.addLine(to: point) }
                    }
                    let played = elapsed >= note.start
                    let width = 2 + CGFloat(note.amp) * 4 + CGFloat(note.noise) * 6
                    let color = note.noise > 0.5 ? Color(hex: 0xE3A833) : Color(hex: 0x9EE0A8)
                    context.stroke(stroke, with: .color(color.opacity(played ? 1 : 0.55)),
                                   style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
                    if note.harmonics.count > 1, note.harmonics[1] > 0.3 {
                        context.stroke(stroke.applying(CGAffineTransform(translationX: 0, y: -size.height * 0.12)),
                                       with: .color(color.opacity(played ? 0.45 : 0.2)), style: StrokeStyle(lineWidth: width * 0.6, lineCap: .round))
                    }
                }
                if elapsed >= 0 && elapsed <= total {
                    let x = size.width * CGFloat(elapsed / total)
                    var head = Path()
                    head.move(to: CGPoint(x: x, y: 4))
                    head.addLine(to: CGPoint(x: x, y: size.height - 4))
                    context.stroke(head, with: .color(.white.opacity(0.85)), lineWidth: 1.5)
                }
                context.draw(Text("\(Int(hi)) Hz").font(.system(size: 9, design: .monospaced)).foregroundColor(.white.opacity(0.5)),
                             at: CGPoint(x: 8, y: 8), anchor: .topLeading)
                context.draw(Text(String(format: "%.1f s", total)).font(.system(size: 9, design: .monospaced)).foregroundColor(.white.opacity(0.5)),
                             at: CGPoint(x: size.width - 8, y: size.height - 8), anchor: .bottomTrailing)
            }
        }
        .accessibilityLabel("Sonogram of the song")
    }
}

// MARK: - Range

struct RangeSection: View {
    let species: BirdSpecies

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                SectionHeader(title: "Where in the world")
                WorldMapView(highlighted: species.regions, accent: Palette.berry)
                Flow {
                    ForEach(species.regions) { r in Chip(text: r.title, emoji: r.emoji, color: Palette.berry) }
                }
            }
            .parchmentCard()

            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Habitats")
                ForEach(species.habitats) { h in
                    HStack(spacing: 12) {
                        Text(h.emoji)
                            .font(.system(size: 24))
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(h.tint.opacity(0.25)))
                        Text(h.title).font(AppFont.title(17)).foregroundStyle(Palette.ink)
                        Spacer()
                        if h == species.primaryHabitat {
                            Text("PRIMARY").font(AppFont.caps(10)).foregroundStyle(Palette.forest)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Capsule().fill(Palette.moss.opacity(0.2)))
                        }
                    }
                }
            }
            .parchmentCard()
        }
    }
}

// MARK: - Notes

struct NotesSection: View {
    let species: BirdSpecies
    @EnvironmentObject private var game: GameState
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "My field notes")
            Text("Where did you see it? What was it doing? Sketch it in words.")
                .font(AppFont.italic(14))
                .foregroundStyle(Palette.inkSoft)
            ZStack(alignment: .topLeading) {
                LinedPaper()
                TextEditor(text: $text)
                    .font(AppFont.hand(17))
                    .foregroundStyle(Color(hex: 0x23395B))
                    .scrollContentBackground(.hidden)
                    .focused($focused)
                    .padding(.horizontal, 6)
                if text.isEmpty {
                    Text("e.g. “Spotted two at the lake at dawn, bobbing their heads…”")
                        .font(AppFont.handLight(16))
                        .foregroundStyle(Palette.inkSoft.opacity(0.6))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }
            }
            .frame(minHeight: 240)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            HStack {
                Text("\(text.count) characters").font(AppFont.dataLight(11)).foregroundStyle(Palette.inkSoft)
                Spacer()
                if focused {
                    Button("Done") { focused = false }
                        .buttonStyle(WoodButtonStyle(compact: true))
                }
            }
        }
        .parchmentCard()
        .onAppear { text = game.save.notes[species.id] ?? "" }
        .onChange(of: text) { _, newValue in game.setNote(newValue, for: species.id) }
    }
}

struct LinedPaper: View {
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: 0xFFFDF5)))
            var lines = Path()
            var y: CGFloat = 32
            while y < size.height {
                lines.move(to: CGPoint(x: 0, y: y))
                lines.addLine(to: CGPoint(x: size.width, y: y))
                y += 26
            }
            context.stroke(lines, with: .color(Color(hex: 0x9FC3E0).opacity(0.6)), lineWidth: 0.8)
            var margin = Path()
            margin.move(to: CGPoint(x: 4, y: 0))
            margin.addLine(to: CGPoint(x: 4, y: size.height))
            context.stroke(margin, with: .color(Palette.berry.opacity(0.4)), lineWidth: 1)
        }
    }
}
