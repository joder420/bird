import SwiftUI

/// Side-by-side comparison of two species, drawn to scale.
struct CompareView: View {
    @EnvironmentObject private var game: GameState
    @Environment(\.dismiss) private var dismiss

    @State private var left: BirdSpecies
    @State private var right: BirdSpecies
    @State private var pickingLeft = false
    @State private var pickingRight = false

    private let db = BirdDatabase.shared

    init(initialLeft: BirdSpecies? = nil) {
        let all = BirdDatabase.shared.all
        let l = initialLeft ?? all.first { $0.id == "bald-eagle" } ?? all[0]
        let r = all.first { $0.id == (l.id == "ruby-throated-hummingbird" ? "common-ostrich" : "ruby-throated-hummingbird") } ?? all[1]
        _left = State(initialValue: l)
        _right = State(initialValue: r)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    stage
                    pickers
                    verdicts
                    stats
                    traits
                }
                .padding(16)
            }
            .background(Palette.parchment.ignoresSafeArea())
            .navigationTitle("Side by Side")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.bold()
                }
            }
            .sheet(isPresented: $pickingLeft) {
                SpeciesPicker(selection: $left).environmentObject(game)
            }
            .sheet(isPresented: $pickingRight) {
                SpeciesPicker(selection: $right).environmentObject(game)
            }
            .onChange(of: left) { _, _ in game.recordComparison() }
            .onChange(of: right) { _, _ in game.recordComparison() }
        }
    }

    // MARK: Stage

    private var stage: some View {
        GeometryReader { geo in
            let biggest = max(left.lengthCm.mid, right.lengthCm.mid)
            let maxH = geo.size.height - 30
            HStack(alignment: .bottom, spacing: 8) {
                scaled(left, height: maxH * CGFloat(left.lengthCm.mid / biggest), width: geo.size.width / 2 - 8)
                scaled(right, height: maxH * CGFloat(right.lengthCm.mid / biggest), width: geo.size.width / 2 - 8)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
        }
        .frame(height: 260)
        .parchmentCard(padding: 10)
    }

    private func scaled(_ s: BirdSpecies, height: CGFloat, width: CGFloat) -> some View {
        VStack(spacing: 4) {
            BirdView(appearance: game.appearance(for: s), showPerch: false, phase: Double(s.name.count), padding: 2)
                .frame(width: min(width, max(height * 1.3, 18)), height: max(height, 14))
            Text(s.lengthText).font(AppFont.dataLight(11)).foregroundStyle(Palette.inkSoft)
        }
        .frame(width: width)
    }

    private var pickers: some View {
        HStack(spacing: 10) {
            pickerButton(left) { pickingLeft = true }
            Text("vs").font(AppFont.script(26)).foregroundStyle(Palette.bark)
            pickerButton(right) { pickingRight = true }
        }
    }

    private func pickerButton(_ s: BirdSpecies, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(s.name).font(AppFont.bodyBold(15)).foregroundStyle(Palette.ink).lineLimit(2).multilineTextAlignment(.center)
                Text("Change ▾").font(AppFont.caps(10)).foregroundStyle(Palette.moss)
            }
            .frame(maxWidth: .infinity)
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 14).fill(Palette.parchmentDeep))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Palette.parchmentEdge, lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: Verdicts

    private var verdicts: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Verdicts")
            verdict("⚖️", ratioLine(left.weightG.mid, right.weightG.mid, "heavier"))
            if let lw = left.wingspanCm?.mid, let rw = right.wingspanCm?.mid {
                verdict("🪽", ratioLine(lw, rw, "wider-winged"))
            }
            verdict("🥚", ratioLine(left.egg.lengthMm * left.egg.widthMm * left.egg.widthMm,
                                    right.egg.lengthMm * right.egg.widthMm * right.egg.widthMm, "bigger-egged"))
            if let ls = left.lifespanYears?.max, let rs = right.lifespanYears?.max {
                verdict("⏳", ls == rs ? "Both can live about \(Int(ls)) years." :
                            "The \(ls > rs ? left.name : right.name) can outlive the other by \(Int(abs(ls - rs))) years.")
            }
        }
        .parchmentCard()
    }

    private func ratioLine(_ a: Double, _ b: Double, _ word: String) -> String {
        guard a > 0, b > 0 else { return "Too close to call." }
        let bigger = a >= b ? left.name : right.name
        let ratio = max(a, b) / min(a, b)
        if ratio < 1.1 { return "Practically equal — neither is notably \(word)." }
        let factor = ratio >= 10 ? String(format: "%.0f", ratio) : String(format: "%.1f", ratio)
        return "The \(bigger) is \(factor)× \(word)."
    }

    private func verdict(_ emoji: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(emoji)
            Text(text).font(AppFont.body(15)).foregroundStyle(Palette.ink).fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Stats

    private var stats: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "Measurements")
            duel("Length", "📏", left.lengthCm.mid, right.lengthCm.mid, left.lengthText, right.lengthText)
            duel("Wingspan", "🪽", left.wingspanCm?.mid ?? 0, right.wingspanCm?.mid ?? 0, left.wingspanText, right.wingspanText)
            duel("Weight", "⚖️", log10(max(left.weightG.mid, 1)), log10(max(right.weightG.mid, 1)), left.weightText, right.weightText)
            duel("Lifespan", "⏳", left.lifespanYears?.max ?? 0, right.lifespanYears?.max ?? 0, left.lifespanText, right.lifespanText)
            duel("Speed", "💨", left.speedKmh ?? 0, right.speedKmh ?? 0, left.speedText, right.speedText)
            duel("Clutch", "🔢", left.egg.clutch.max, right.egg.clutch.max, left.egg.clutch.formatted(), right.egg.clutch.formatted())
            duel("Incubation", "🌡️", left.egg.incubationDays.mid, right.egg.incubationDays.mid,
                 left.egg.incubationDays.formatted("d"), right.egg.incubationDays.formatted("d"))
        }
        .parchmentCard()
    }

    /// Two bars growing outward from the centre.
    private func duel(_ label: String, _ emoji: String, _ a: Double, _ b: Double, _ aText: String, _ bText: String) -> some View {
        let top = max(a, b, 0.0001)
        return VStack(spacing: 4) {
            HStack {
                Text(aText).font(AppFont.data(12)).foregroundStyle(a >= b ? Palette.forest : Palette.inkSoft)
                Spacer()
                Text("\(emoji) \(label.uppercased())").font(AppFont.caps(10)).foregroundStyle(Palette.inkSoft)
                Spacer()
                Text(bText).font(AppFont.data(12)).foregroundStyle(b >= a ? Palette.berry : Palette.inkSoft)
            }
            GeometryReader { geo in
                let half = geo.size.width / 2 - 2
                HStack(spacing: 4) {
                    HStack {
                        Spacer(minLength: 0)
                        Capsule().fill(Palette.forest.opacity(0.85)).frame(width: max(2, half * CGFloat(a / top)))
                    }
                    HStack {
                        Capsule().fill(Palette.berry.opacity(0.85)).frame(width: max(2, half * CGFloat(b / top)))
                        Spacer(minLength: 0)
                    }
                }
            }
            .frame(height: 8)
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: a)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: b)
    }

    private var traits: some View {
        VStack(spacing: 10) {
            SectionHeader(title: "Trait duel")
            ForEach(0..<5, id: \.self) { i in
                let l = left.traits.all[i], r = right.traits.all[i]
                duel(l.0, l.1, Double(l.2), Double(r.2), "\(l.2)", "\(r.2)")
            }
            let lt = left.traits.total, rt = right.traits.total
            Text(lt == rt ? "A perfectly balanced rivalry!" : "Overall champion: \(lt > rt ? left.name : right.name) 🏆")
                .font(AppFont.hand(16))
                .foregroundStyle(Palette.moss)
                .padding(.top, 4)
        }
        .parchmentCard()
    }
}

/// A searchable list of species to pick from.
struct SpeciesPicker: View {
    @Binding var selection: BirdSpecies
    @EnvironmentObject private var game: GameState
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        NavigationStack {
            List {
                ForEach(BirdDatabase.shared.all.filter { query.isEmpty || $0.searchBlob.contains(query.lowercased()) }) { s in
                    Button {
                        selection = s
                        Haptics.shared.select()
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            BirdView(appearance: game.appearance(for: s), animated: false, showPerch: false, padding: 2)
                                .frame(width: 44, height: 44)
                            VStack(alignment: .leading) {
                                Text(s.name).font(AppFont.bodyBold(16)).foregroundStyle(Palette.ink)
                                Text(s.scientific).font(AppFont.italic(13)).foregroundStyle(Palette.inkSoft)
                            }
                            Spacer()
                            if s == selection { Image(systemName: "checkmark").foregroundStyle(Palette.forest) }
                        }
                    }
                    .listRowBackground(Palette.parchment)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.parchmentDeep.ignoresSafeArea())
            .searchable(text: $query, prompt: "Search species")
            .navigationTitle("Choose a bird")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
