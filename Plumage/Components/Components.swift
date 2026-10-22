import SwiftUI

// MARK: - Headings

/// An engraved small-caps heading framed by ornamental rules and a fleuron.
struct SectionHeader: View {
    var title: String
    var ornament = "❦"
    var color: Color = Palette.bark

    var body: some View {
        HStack(spacing: 10) {
            rule
            Text(ornament).font(.system(size: 14)).foregroundStyle(color.opacity(0.8))
            Text(title.uppercased())
                .font(AppFont.caps(14))
                .tracking(1.5)
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(ornament).font(.system(size: 14)).foregroundStyle(color.opacity(0.8)).scaleEffect(x: -1)
            rule
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isHeader)
    }

    private var rule: some View {
        Rectangle()
            .fill(LinearGradient(colors: [color.opacity(0), color.opacity(0.5)], startPoint: .leading, endPoint: .trailing))
            .frame(height: 1)
    }
}

/// Big script title shown at the top of each tab, over the sky.
struct ScreenTitle: View {
    var title: String
    var subtitle: String?

    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(AppFont.display(44))
                .foregroundStyle(.white)
                .skyShadow()
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            if let subtitle {
                Text(subtitle)
                    .font(AppFont.italic(15))
                    .foregroundStyle(.white.opacity(0.92))
                    .skyShadow()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Chips & badges

struct Chip: View {
    var text: String
    var emoji: String? = nil
    var color: Color = Palette.moss
    var selected = false

    var body: some View {
        HStack(spacing: 5) {
            if let emoji { Text(emoji).font(.system(size: 13)) }
            Text(text).font(AppFont.bodyBold(13))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .foregroundStyle(selected ? Palette.parchment : Palette.ink)
        .background(Capsule().fill(selected ? color : color.opacity(0.15)))
        .overlay(Capsule().strokeBorder(color.opacity(selected ? 0 : 0.45), lineWidth: 1))
    }
}

struct StatusBadge: View {
    var status: ConservationStatus
    var compact = false

    var body: some View {
        HStack(spacing: 4) {
            Text(status.rawValue).font(AppFont.data(compact ? 10 : 12))
            if !compact { Text(status.title).font(AppFont.bodyBold(12)) }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, compact ? 6 : 9)
        .padding(.vertical, compact ? 2 : 4)
        .background(Capsule().fill(status.color))
        .accessibilityLabel("Conservation status: \(status.title)")
    }
}

struct RarityStars: View {
    var rarity: Rarity
    var size: CGFloat = 10

    var body: some View {
        HStack(spacing: 1) {
            ForEach(0..<4, id: \.self) { i in
                Image(systemName: i < rarity.stars ? "star.fill" : "star")
                    .font(.system(size: size, weight: .bold))
                    .foregroundStyle(i < rarity.stars ? rarity.color : Palette.inkSoft.opacity(0.3))
            }
        }
        .accessibilityLabel("\(rarity.title) rarity")
    }
}

struct FeatherBadge: View {
    var count: Int
    var dark = false

    var body: some View {
        HStack(spacing: 4) {
            Text("🪶").font(.system(size: 14))
            Text("\(count)")
                .font(AppFont.data(15))
                .contentTransition(.numericText())
                .foregroundStyle(dark ? Palette.ink : .white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(dark ? Palette.gold.opacity(0.18) : Color.black.opacity(0.25)))
        .overlay(Capsule().strokeBorder(Palette.gold.opacity(0.6), lineWidth: 1))
        .animation(.spring, value: count)
        .accessibilityLabel("\(count) feathers")
    }
}

// MARK: - Bars & meters

struct StatBar: View {
    var label: String
    var emoji: String
    var value: Int
    var maxValue: Int = 10
    var color: Color = Palette.moss

    @State private var shown = false

    var body: some View {
        HStack(spacing: 10) {
            Text(emoji).frame(width: 22)
            Text(label.uppercased())
                .font(AppFont.caps(11))
                .foregroundStyle(Palette.inkSoft)
                .frame(width: 68, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.bark.opacity(0.12))
                    Capsule()
                        .fill(LinearGradient(colors: [color.opacity(0.7), color], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * (shown ? CGFloat(value) / CGFloat(maxValue) : 0))
                    HStack(spacing: 0) {
                        ForEach(1..<maxValue, id: \.self) { _ in
                            Spacer()
                            Rectangle().fill(Palette.parchment.opacity(0.6)).frame(width: 1)
                        }
                        Spacer()
                    }
                }
            }
            .frame(height: 10)
            Text("\(value)")
                .font(AppFont.data(13))
                .foregroundStyle(Palette.ink)
                .frame(width: 22, alignment: .trailing)
        }
        .onAppear { withAnimation(.spring(response: 0.9, dampingFraction: 0.8).delay(0.1)) { shown = true } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value) out of \(maxValue)")
    }
}

/// The IUCN scale from Least Concern to Extinct, with the species marked.
struct ConservationScale: View {
    var status: ConservationStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 3) {
                ForEach(ConservationStatus.allCases) { s in
                    VStack(spacing: 3) {
                        Text(s.rawValue)
                            .font(AppFont.data(s == status ? 13 : 10))
                            .foregroundStyle(s == status ? .white : s.color)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, s == status ? 7 : 4)
                            .background(RoundedRectangle(cornerRadius: 6).fill(s == status ? s.color : s.color.opacity(0.14)))
                        Image(systemName: "triangle.fill")
                            .font(.system(size: 8))
                            .rotationEffect(.degrees(180))
                            .foregroundStyle(s == status ? s.color : .clear)
                    }
                }
            }
            Text("\(status.title) — \(status.blurb)")
                .font(AppFont.italic(14))
                .foregroundStyle(Palette.inkSoft)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Conservation status \(status.title). \(status.blurb)")
    }
}

struct XPBar: View {
    @EnvironmentObject private var game: GameState
    var light = false

    var body: some View {
        let progress = game.levelProgress
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("LV \(game.level)")
                    .font(AppFont.data(13))
                    .foregroundStyle(light ? .white : Palette.forest)
                Text(game.levelTitle)
                    .font(AppFont.script(20))
                    .foregroundStyle(light ? .white : Palette.ink)
                Spacer()
                Text(progress.needed > 0 ? "\(progress.into)/\(progress.needed) XP" : "MAX")
                    .font(AppFont.dataLight(12))
                    .foregroundStyle(light ? .white.opacity(0.85) : Palette.inkSoft)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill((light ? Color.white : Palette.bark).opacity(0.18))
                    Capsule()
                        .fill(LinearGradient(colors: [Palette.sunrise, Palette.gold], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(8, geo.size.width * CGFloat(progress.fraction)))
                        .shadow(color: Palette.sunrise.opacity(0.6), radius: 4)
                }
            }
            .frame(height: 9)
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: game.save.xp)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Level \(game.level), \(game.levelTitle). \(progress.into) of \(progress.needed) experience to next level.")
    }
}

struct RingProgress: View {
    var fraction: Double
    var lineWidth: CGFloat = 8
    var color: Color = Palette.moss

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(min(max(fraction, 0), 1)))
                .stroke(AngularGradient(colors: [color.opacity(0.6), color], center: .center), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .animation(.spring(response: 0.8, dampingFraction: 0.8), value: fraction)
    }
}

/// A fact tile for the quick-facts grid.
struct InfoTile: View {
    var emoji: String
    var label: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(emoji)
                Text(label.uppercased()).font(AppFont.caps(10)).foregroundStyle(Palette.inkSoft).lineLimit(1)
            }
            Text(value)
                .font(AppFont.data(15))
                .foregroundStyle(Palette.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.parchment.opacity(0.7)))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.parchmentEdge, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Layout

/// Wraps children onto multiple lines like words in a paragraph.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, widest: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            widest = max(widest, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: proposal.width ?? widest, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

/// A view wrapper around `FlowLayout`.
struct Flow<Content: View>: View {
    var spacing: CGFloat = 8
    @ViewBuilder var content: () -> Content

    var body: some View {
        FlowLayout(spacing: spacing).callAsFunction(content)
    }
}

// MARK: - Sound visual

/// Animated bars that dance while a song plays.
struct WaveformView: View {
    var active: Bool
    var color: Color = Palette.forest
    var bars = 24
    var seed: UInt64 = 1

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24, paused: !active)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                var rng = SeededRandom(seed: seed)
                let w = size.width / CGFloat(bars)
                for i in 0..<bars {
                    let base = 0.2 + rng.unit() * 0.5
                    let wobble = active ? 0.5 + 0.5 * sin(t * (6 + rng.unit() * 8) + Double(i)) : 0.15
                    let h = max(3, size.height * CGFloat(base * wobble + (active ? 0.1 : 0)))
                    let rect = CGRect(x: CGFloat(i) * w + w * 0.2, y: (size.height - h) / 2, width: w * 0.6, height: h)
                    context.fill(Path(roundedRect: rect, cornerRadius: w * 0.3), with: .color(color.opacity(active ? 0.9 : 0.35)))
                }
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Celebrations

/// A one-shot burst of tumbling feathers. Change `.id(...)` to replay.
struct FeatherBurst: View {
    var colors: [Color] = [Palette.sunrise, Palette.berry, Palette.moss, Palette.sky, Palette.gold]
    var count = 34
    var duration = 2.6

    @State private var start = Date()

    var body: some View {
        TimelineView(.animation) { timeline in
            let elapsed = timeline.date.timeIntervalSince(start)
            Canvas { context, size in
                guard elapsed < duration else { return }
                let cx = size.width / 2, cy = size.height * 0.45
                for i in 0..<count {
                    let a = NaturePainter.hash01(i, 31) * 2 * .pi
                    let speed = 180 + NaturePainter.hash01(i, 32) * 260
                    let drag = 2.4
                    let travel = (1 - exp(-drag * elapsed)) / drag
                    let x = cx + CGFloat(cos(a) * speed * travel + 18 * sin(elapsed * 5 + Double(i)))
                    let y = cy + CGFloat(sin(a) * speed * travel - 160 * travel + 120 * elapsed * elapsed)
                    let alpha = max(0, 1 - elapsed / duration)
                    var f = context
                    f.translateBy(x: x, y: y)
                    f.rotate(by: .radians(elapsed * (2 + NaturePainter.hash01(i, 33) * 4) + Double(i)))
                    f.opacity = alpha
                    let color = colors[i % colors.count]
                    f.fill(Path(ellipseIn: CGRect(x: -9, y: -3, width: 18, height: 6)), with: .color(color))
                    var shaft = Path()
                    shaft.move(to: CGPoint(x: -11, y: 0))
                    shaft.addLine(to: CGPoint(x: 9, y: 0))
                    f.stroke(shaft, with: .color(.white.opacity(0.7)), lineWidth: 0.8)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Stacked reward / achievement banners.
struct ToastOverlay: View {
    @EnvironmentObject private var game: GameState

    var body: some View {
        VStack(spacing: 8) {
            ForEach(game.toasts) { toast in
                ToastBanner(toast: toast)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onTapGesture { withAnimation { game.dismissToast(toast) } }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: game.toasts)
    }
}

struct ToastBanner: View {
    var toast: Toast

    private var accent: Color {
        switch toast.kind {
        case .reward: return Palette.moss
        case .achievement: return Palette.gold
        case .level: return Palette.sunrise
        case .info: return Palette.lake
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(toast.emoji)
                .font(.system(size: 26))
                .frame(width: 44, height: 44)
                .background(Circle().fill(accent.opacity(0.18)))
            VStack(alignment: .leading, spacing: 2) {
                Text(toast.title).font(AppFont.bodyBold(15)).foregroundStyle(Palette.ink).lineLimit(2)
                if !toast.subtitle.isEmpty {
                    Text(toast.subtitle).font(AppFont.dataLight(12)).foregroundStyle(Palette.inkSoft).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Palette.parchment)
                .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
        )
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(accent.opacity(0.7), lineWidth: 1.5))
        .accessibilityElement(children: .combine)
    }
}

/// Full-screen celebration when the player levels up.
struct LevelUpOverlay: View {
    var level: Int
    var onDismiss: () -> Void

    @State private var appear = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
                .onTapGesture(perform: onDismiss)
            FeatherBurst(count: 60, duration: 3.2)
                .ignoresSafeArea()
            VStack(spacing: 10) {
                Text("Level Up!")
                    .font(AppFont.caps(18))
                    .tracking(3)
                    .foregroundStyle(Palette.gold)
                Text("\(level)")
                    .font(AppFont.title(72))
                    .foregroundStyle(Palette.ink)
                Text(LevelSystem.title(for: level))
                    .font(AppFont.display(40))
                    .foregroundStyle(Palette.forest)
                Text("New wings, new horizons.")
                    .font(AppFont.italic(15))
                    .foregroundStyle(Palette.inkSoft)
                Button("Onward", action: onDismiss)
                    .buttonStyle(WoodButtonStyle())
                    .padding(.top, 6)
            }
            .padding(28)
            .parchmentCard(padding: 8, cornerRadius: 28)
            .scaleEffect(appear ? 1 : 0.6)
            .opacity(appear ? 1 : 0)
        }
        .onAppear { withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) { appear = true } }
    }
}

// MARK: - Species card

/// A collectible card for the Atlas grid. Undiscovered birds appear as silhouettes.
struct SpeciesCard: View {
    var species: BirdSpecies
    @EnvironmentObject private var game: GameState

    var body: some View {
        let discovered = game.isDiscovered(species.id)
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(LinearGradient(colors: [species.primaryHabitat.tint.opacity(0.35), Palette.parchment.opacity(0.4)],
                                             startPoint: .top, endPoint: .bottom))
                    if discovered {
                        BirdView(appearance: game.appearance(for: species), animated: false, padding: 8)
                    } else {
                        BirdSilhouette(appearance: species.appearance, color: Palette.bark.opacity(0.75), padding: 14)
                        Text("?")
                            .font(AppFont.title(34))
                            .foregroundStyle(Palette.parchment)
                            .offset(y: -4)
                    }
                }
                .aspectRatio(1, contentMode: .fit)
                if game.isFavorite(species.id) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.berry)
                        .padding(6)
                }
            }
            Text(species.name)
                .font(AppFont.bodyBold(14))
                .foregroundStyle(Palette.ink)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)
                .frame(minHeight: 36)
            HStack {
                RarityStars(rarity: species.rarity, size: 8)
                Spacer()
                StatusBadge(status: species.status, compact: true)
            }
        }
        .parchmentCard(padding: 10, cornerRadius: 18)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(species.name)\(discovered ? "" : ", not yet discovered"). \(species.status.title).")
        .accessibilityAddTraits(.isButton)
    }
}
