import SwiftUI
import Combine

/// "Nest Match": a memory game pairing each bird with its own egg.
struct MemoryGameView: View {
    struct Card: Identifiable, Equatable {
        enum Face: Equatable { case bird, egg }
        let id = UUID()
        let species: BirdSpecies
        let face: Face
        var revealed = false
        var matched = false
    }

    @EnvironmentObject private var game: GameState
    @State private var cards: [Card] = []
    @State private var selection: [Int] = []
    @State private var moves = 0
    @State private var startedAt = Date()
    @State private var elapsed: TimeInterval = 0
    @State private var won = false
    @State private var burst = 0
    @State private var pairs = 6
    @State private var gameID = UUID()

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                ScreenTitle(title: "Nest Match", subtitle: "Pair every bird with its egg")
                HStack(spacing: 10) {
                    InfoTile(emoji: "👣", label: "Moves", value: "\(moves)")
                    InfoTile(emoji: "⏱️", label: "Time", value: timeText)
                    InfoTile(emoji: "🪺", label: "Pairs", value: "\(cards.filter(\.matched).count / 2)/\(pairs)")
                }
                .parchmentCard(padding: 10)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                    ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                        MemoryCardView(card: card)
                            .aspectRatio(0.78, contentMode: .fit)
                            .onTapGesture { flip(index) }
                    }
                }

                if won {
                    VStack(spacing: 8) {
                        Text("All nests matched!").font(AppFont.script(32)).foregroundStyle(Palette.forest)
                        Text("\(moves) moves in \(timeText)").font(AppFont.data(15)).foregroundStyle(Palette.ink)
                        Button("Play again") { newGame() }
                            .buttonStyle(WoodButtonStyle())
                    }
                    .frame(maxWidth: .infinity)
                    .parchmentCard()
                    .transition(.scale.combined(with: .opacity))
                } else {
                    HStack {
                        Text("Difficulty").font(AppFont.caps(12)).foregroundStyle(.white).skyShadow()
                        Picker("Pairs", selection: $pairs) {
                            Text("4 pairs").tag(4)
                            Text("6 pairs").tag(6)
                            Text("8 pairs").tag(8)
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 44)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .overlay {
            if burst > 0 { FeatherBurst(count: 60).id(burst).ignoresSafeArea() }
        }
        .onAppear { if cards.isEmpty { newGame() } }
        .onChange(of: pairs) { _, _ in newGame() }
        .onReceive(ticker) { _ in
            if !won && moves > 0 { elapsed = Date().timeIntervalSince(startedAt) }
        }
    }

    private var timeText: String {
        let s = Int(elapsed)
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    private func newGame() {
        gameID = UUID()
        var rng = SystemRandomNumberGenerator()
        var chosen: [BirdSpecies] = []
        while chosen.count < pairs {
            chosen.append(BirdDatabase.shared.random(excluding: Set(chosen.map(\.id)), using: &rng))
        }
        var deck: [Card] = []
        for s in chosen {
            deck.append(Card(species: s, face: .bird))
            deck.append(Card(species: s, face: .egg))
        }
        withAnimation(.spring) {
            cards = deck.shuffled(using: &rng)
            selection = []
            moves = 0
            elapsed = 0
            won = false
        }
        startedAt = Date()
    }

    private func flip(_ index: Int) {
        guard !won, index < cards.count, !cards[index].revealed, !cards[index].matched, selection.count < 2 else { return }
        if moves == 0 && selection.isEmpty { startedAt = Date() }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) { cards[index].revealed = true }
        SoundEngine.shared.play(.flip)
        Haptics.shared.tap()
        selection.append(index)
        guard selection.count == 2 else { return }
        moves += 1
        let a = selection[0], b = selection[1]
        let token = gameID
        if cards[a].species == cards[b].species && cards[a].face != cards[b].face {
            runAfter(0.35) {
                guard token == gameID, a < cards.count, b < cards.count else { return }
                withAnimation(.spring) {
                    cards[a].matched = true
                    cards[b].matched = true
                }
                selection = []
                SoundEngine.shared.play(.match)
                Haptics.shared.success()
                game.discover(cards[a].species)
                if cards.allSatisfy(\.matched) { win() }
            }
        } else {
            runAfter(0.95) {
                guard token == gameID, a < cards.count, b < cards.count else { return }
                withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                    cards[a].revealed = false
                    cards[b].revealed = false
                }
                selection = []
            }
        }
    }

    private func win() {
        elapsed = Date().timeIntervalSince(startedAt)
        withAnimation(.spring) { won = true }
        burst += 1
        game.recordMemoryWin(moves: moves)
    }
}

struct MemoryCardView: View {
    var card: MemoryGameView.Card

    var body: some View {
        ZStack {
            back
                .opacity(card.revealed || card.matched ? 0 : 1)
            front
                .opacity(card.revealed || card.matched ? 1 : 0)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
        }
        .rotation3DEffect(.degrees(card.revealed || card.matched ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
        .scaleEffect(card.matched ? 0.94 : 1)
        .accessibilityElement()
        .accessibilityLabel(card.revealed || card.matched ? "\(card.species.name) \(card.face == .bird ? "bird" : "egg")" : "Face-down card")
        .accessibilityAddTraits(.isButton)
    }

    private var back: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(LinearGradient(colors: [Palette.forest, Color(hex: 0x1E3326)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(
                Text("❦")
                    .font(.system(size: 34))
                    .foregroundStyle(Palette.gold.opacity(0.75))
            )
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Palette.gold.opacity(0.5), lineWidth: 1).padding(6))
            .shadow(color: .black.opacity(0.25), radius: 4, y: 3)
    }

    private var front: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(card.matched ? Palette.moss.opacity(0.25) : Palette.parchment)
            .overlay {
                VStack(spacing: 2) {
                    if card.face == .bird {
                        BirdView(appearance: card.species.appearance, animated: false, showPerch: false, padding: 4)
                    } else {
                        EggArt(egg: card.species.egg, seed: card.species.seed, showShadow: false)
                            .padding(10)
                    }
                    Text(card.species.name)
                        .font(AppFont.bodyBold(10))
                        .foregroundStyle(Palette.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 4)
                        .padding(.bottom, 6)
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(card.matched ? Palette.forest : Palette.parchmentEdge, lineWidth: 1.5))
            .shadow(color: .black.opacity(0.18), radius: 4, y: 3)
    }
}
