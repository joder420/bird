import SwiftUI
import Combine

enum QuizMode: String, CaseIterable, Identifiable {
    case mixed, eggs, songs, silhouettes, clues

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mixed: return "Grand Tour"
        case .eggs: return "Whose Egg?"
        case .songs: return "Name That Song"
        case .silhouettes: return "Shadow Birds"
        case .clues: return "Field Clues"
        }
    }

    var detail: String {
        switch self {
        case .mixed: return "A bit of everything — the true birder's test."
        case .eggs: return "Match the egg to the bird that laid it."
        case .songs: return "Listen closely, then name the singer."
        case .silhouettes: return "Identify birds from their outline alone."
        case .clues: return "Deduce the bird from three field notes."
        }
    }

    var emoji: String {
        switch self {
        case .mixed: return "🧭"
        case .eggs: return "🥚"
        case .songs: return "🎵"
        case .silhouettes: return "🌑"
        case .clues: return "🔍"
        }
    }
}

enum QuestionKind: CaseIterable {
    case egg, song, silhouette, clue
}

struct QuizQuestion: Identifiable {
    let id = UUID()
    let kind: QuestionKind
    let answer: BirdSpecies
    let options: [BirdSpecies]
    let clues: [String]
}

enum QuizFactory {
    static func round(mode: QuizMode, count: Int = 8) -> [QuizQuestion] {
        var rng = SystemRandomNumberGenerator()
        let db = BirdDatabase.shared
        var used: Set<String> = []
        return (0..<count).map { i in
            let kind: QuestionKind
            switch mode {
            case .mixed: kind = QuestionKind.allCases[i % QuestionKind.allCases.count]
            case .eggs: kind = .egg
            case .songs: kind = .song
            case .silhouettes: kind = .silhouette
            case .clues: kind = .clue
            }
            let answer = db.random(excluding: used, using: &rng)
            used.insert(answer.id)
            var options = [answer]
            while options.count < 4 {
                let candidate = db.random(excluding: Set(options.map(\.id)), using: &rng)
                options.append(candidate)
            }
            options.shuffle(using: &rng)
            return QuizQuestion(kind: kind, answer: answer, options: options, clues: clues(for: answer, using: &rng))
        }
    }

    static func clues<G: RandomNumberGenerator>(for s: BirdSpecies, using rng: inout G) -> [String] {
        var pool: [String] = []
        pool.append("Lives in: " + s.habitats.prefix(3).map { $0.title.lowercased() }.joined(separator: ", ") + ".")
        pool.append("Found in " + s.regions.prefix(3).map(\.title).joined(separator: ", ") + ".")
        pool.append("Eats " + s.diet.prefix(3).map { $0.title.lowercased() }.joined(separator: ", ") + ".")
        pool.append("Nest: \(s.nest.type.title.lowercased()); clutch of \(s.egg.clutch.formatted()).")
        pool.append("Length \(s.lengthText); \(s.flightless ? "cannot fly" : "wingspan \(s.wingspanText)").")
        if let behavior = s.behaviors.randomElement(using: &rng) {
            pool.append(redact(behavior.title + ": " + behavior.detail, for: s))
        }
        pool.append("Voice: " + redact(s.call.mnemonic, for: s))
        pool.shuffle(using: &rng)
        return Array(pool.prefix(3))
    }

    /// Hides the species' own name inside a clue.
    static func redact(_ text: String, for s: BirdSpecies) -> String {
        var t = text
        let words = [s.name] + s.name.split(separator: " ").map(String.init).filter { $0.count > 3 }
        for w in words {
            t = t.replacingOccurrences(of: w, with: "this bird", options: .caseInsensitive)
        }
        return t
    }
}

struct QuizView: View {
    @EnvironmentObject private var game: GameState
    @ObservedObject private var sound = SoundEngine.shared

    @State private var mode: QuizMode?
    @State private var questions: [QuizQuestion] = []
    @State private var index = 0
    @State private var picked: BirdSpecies?
    @State private var timedOut = false
    @State private var correct = 0
    @State private var streak = 0
    @State private var bestStreak = 0
    @State private var score = 0
    @State private var remaining: Double = 20
    @State private var finished = false
    @State private var burst = 0

    private let questionTime: Double = 20
    private let ticker = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if mode == nil {
                    modePicker
                } else if finished {
                    summary
                } else if index < questions.count {
                    questionView(questions[index])
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 50)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .overlay {
            if burst > 0 { FeatherBurst().id(burst).ignoresSafeArea() }
        }
        .onReceive(ticker) { _ in tick() }
    }

    // MARK: Mode picker

    private var modePicker: some View {
        VStack(spacing: 14) {
            ScreenTitle(title: "Birder's Quiz", subtitle: "8 questions · 20 seconds each")
            ForEach(QuizMode.allCases) { m in
                Button {
                    start(m)
                } label: {
                    HStack(spacing: 14) {
                        Text(m.emoji)
                            .font(.system(size: 32))
                            .frame(width: 58, height: 58)
                            .background(Circle().fill(Palette.lake.opacity(0.18)))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(m.title).font(AppFont.title(19)).foregroundStyle(Palette.ink)
                            Text(m.detail).font(AppFont.body(14)).foregroundStyle(Palette.inkSoft).multilineTextAlignment(.leading)
                        }
                        Spacer()
                        Image(systemName: "play.circle.fill").font(.system(size: 26)).foregroundStyle(Palette.forest)
                    }
                    .parchmentCard()
                }
                .buttonStyle(PressableStyle())
            }
        }
    }

    private func start(_ m: QuizMode) {
        questions = QuizFactory.round(mode: m)
        sound.warmUp(questions.map(\.answer))
        mode = m
        index = 0
        correct = 0
        streak = 0
        bestStreak = 0
        score = 0
        finished = false
        beginQuestion()
        SoundEngine.shared.play(.select)
    }

    private func beginQuestion() {
        picked = nil
        timedOut = false
        remaining = questionTime
        if index < questions.count, questions[index].kind == .song {
            runAfter(0.4) { sound.playSong(questions[index].answer) }
        }
    }

    private func tick() {
        guard mode != nil, !finished, picked == nil, !timedOut, index < questions.count else { return }
        remaining = max(0, remaining - 0.1)
        if remaining <= 0 {
            timedOut = true
            streak = 0
            game.recordAnswer(correct: false, streak: 0)
            SoundEngine.shared.play(.fail)
            Haptics.shared.warning()
        }
    }

    // MARK: Question

    private func questionView(_ q: QuizQuestion) -> some View {
        VStack(spacing: 14) {
            header
            prompt(q)
                .frame(height: 230)
                .frame(maxWidth: .infinity)
                .parchmentCard(padding: 12)
            VStack(spacing: 10) {
                ForEach(q.options) { option in
                    optionButton(option, question: q)
                }
            }
            if picked != nil || timedOut {
                reveal(q)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: picked)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: timedOut)
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Question \(index + 1) of \(questions.count)")
                    .font(AppFont.caps(13))
                    .foregroundStyle(.white)
                Spacer()
                if streak > 1 {
                    Text("🔥 \(streak)")
                        .font(AppFont.data(15))
                        .foregroundStyle(.white)
                        .transition(.scale)
                }
                Text("\(score) pts")
                    .font(AppFont.data(15))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }
            .skyShadow()
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.3))
                    Capsule()
                        .fill(remaining > 6 ? Palette.fern : Palette.berry)
                        .frame(width: geo.size.width * CGFloat(remaining / questionTime))
                        .animation(.linear(duration: 0.1), value: remaining)
                }
            }
            .frame(height: 8)
        }
        .padding(.leading, 40)
    }

    @ViewBuilder
    private func prompt(_ q: QuizQuestion) -> some View {
        switch q.kind {
        case .egg:
            VStack(spacing: 8) {
                Text("Whose egg is this?").font(AppFont.title(20)).foregroundStyle(Palette.ink)
                EggArt(egg: q.answer.egg, seed: q.answer.seed)
                    .frame(height: 150)
                Text("\(Int(q.answer.egg.lengthMm)) × \(Int(q.answer.egg.widthMm)) mm · clutch \(q.answer.egg.clutch.formatted())")
                    .font(AppFont.dataLight(12)).foregroundStyle(Palette.inkSoft)
            }
        case .song:
            VStack(spacing: 12) {
                Text("Who is singing?").font(AppFont.title(20)).foregroundStyle(Palette.ink)
                WaveformView(active: sound.singingSpeciesID == q.answer.id, color: Palette.forest, bars: 28, seed: q.answer.seed)
                    .frame(height: 70)
                    .padding(.horizontal, 20)
                Button {
                    sound.playSong(q.answer)
                } label: {
                    Label("Play again", systemImage: "arrow.clockwise")
                }
                .buttonStyle(WoodButtonStyle(compact: true))
                Text("“\(QuizFactory.redact(q.answer.call.mnemonic, for: q.answer))”")
                    .font(AppFont.hand(14))
                    .foregroundStyle(Palette.moss)
                    .opacity(remaining < 10 || picked != nil || timedOut ? 1 : 0)
            }
        case .silhouette:
            VStack(spacing: 6) {
                Text("Name this shadow").font(AppFont.title(20)).foregroundStyle(Palette.ink)
                if picked != nil || timedOut {
                    BirdView(appearance: q.answer.appearance, showPerch: false, padding: 6)
                        .transition(.opacity)
                } else {
                    BirdSilhouette(appearance: q.answer.appearance, color: Palette.ink, padding: 6)
                }
            }
        case .clue:
            VStack(alignment: .leading, spacing: 10) {
                Text("Read the field notes").font(AppFont.title(20)).foregroundStyle(Palette.ink)
                ForEach(Array(q.clues.enumerated()), id: \.offset) { i, clue in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(i + 1).").font(AppFont.data(15)).foregroundStyle(Palette.gold)
                        Text(clue).font(AppFont.hand(15)).foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func optionButton(_ option: BirdSpecies, question q: QuizQuestion) -> some View {
        let answered = picked != nil || timedOut
        let isAnswer = option == q.answer
        let isPicked = option == picked
        let fill: Color = !answered ? Palette.parchment : (isAnswer ? Palette.moss : (isPicked ? Palette.berry : Palette.parchment.opacity(0.7)))
        return Button {
            answer(option, question: q)
        } label: {
            HStack {
                Text(option.name)
                    .font(AppFont.bodyBold(17))
                    .foregroundStyle(answered && (isAnswer || isPicked) ? .white : Palette.ink)
                Spacer()
                if answered && isAnswer { Image(systemName: "checkmark.circle.fill").foregroundStyle(.white) }
                if answered && isPicked && !isAnswer { Image(systemName: "xmark.circle.fill").foregroundStyle(.white) }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Palette.parchmentEdge, lineWidth: 1.2))
            .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
        }
        .buttonStyle(PressableStyle())
        .disabled(answered)
    }

    private func answer(_ option: BirdSpecies, question q: QuizQuestion) {
        guard picked == nil, !timedOut else { return }
        picked = option
        let right = option == q.answer
        if right {
            correct += 1
            streak += 1
            bestStreak = max(bestStreak, streak)
            score += 100 + Int(remaining * 5) + (streak - 1) * 20
            SoundEngine.shared.play(.success)
            Haptics.shared.success()
            if streak % 3 == 0 { burst += 1 }
        } else {
            streak = 0
            SoundEngine.shared.play(.fail)
            Haptics.shared.error()
        }
        game.recordAnswer(correct: right, streak: streak)
    }

    private func reveal(_ q: QuizQuestion) -> some View {
        let right = picked == q.answer
        return VStack(alignment: .leading, spacing: 8) {
            Text(timedOut ? "⏰ Time's up!" : (right ? "✨ Splendid!" : "Not quite…"))
                .font(AppFont.script(30))
                .foregroundStyle(right ? Palette.forest : Palette.berry)
            Text("It was the **\(q.answer.name)** (*\(q.answer.scientific)*).")
                .font(AppFont.body(16))
                .foregroundStyle(Palette.ink)
            if let fact = q.answer.facts.first {
                Text(fact).font(AppFont.italic(14)).foregroundStyle(Palette.inkSoft).fixedSize(horizontal: false, vertical: true)
            }
            Button(index + 1 < questions.count ? "Next question" : "See results") {
                next()
            }
            .buttonStyle(WoodButtonStyle())
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
        }
        .parchmentCard()
        .onAppear { game.discover(q.answer) }
    }

    private func next() {
        sound.stopSong()
        if index + 1 < questions.count {
            index += 1
            beginQuestion()
            SoundEngine.shared.play(.flip)
        } else {
            finished = true
            game.recordQuizFinished(correct: correct, total: questions.count)
            if correct == questions.count { burst += 1 }
        }
    }

    // MARK: Summary

    private var summary: some View {
        VStack(spacing: 14) {
            ScreenTitle(title: correct == questions.count ? "Flawless!" : "Round complete", subtitle: mode?.title)
            VStack(spacing: 12) {
                Text("\(correct) / \(questions.count)")
                    .font(AppFont.title(54))
                    .foregroundStyle(Palette.ink)
                Text(verdict)
                    .font(AppFont.script(28))
                    .foregroundStyle(Palette.forest)
                HStack(spacing: 10) {
                    InfoTile(emoji: "🏅", label: "Score", value: "\(score)")
                    InfoTile(emoji: "🔥", label: "Best streak", value: "\(bestStreak)")
                }
                HStack(spacing: 10) {
                    ForEach(questions) { q in
                        BirdView(appearance: q.answer.appearance, animated: false, showPerch: false, padding: 1)
                            .frame(width: 32, height: 30)
                    }
                }
            }
            .parchmentCard()
            HStack(spacing: 10) {
                Button("Play again") { if let mode { start(mode) } }
                    .buttonStyle(WoodButtonStyle())
                Button("Other modes") {
                    mode = nil
                    finished = false
                }
                    .buttonStyle(WoodButtonStyle(color: Palette.bark))
            }
        }
    }

    private var verdict: String {
        let ratio = Double(correct) / Double(max(questions.count, 1))
        switch ratio {
        case 1: return "A true ornithologist"
        case 0.75..<1: return "Sharp-eyed birder"
        case 0.5..<0.75: return "Promising fledgling"
        default: return "Keep exploring the Atlas"
        }
    }
}
