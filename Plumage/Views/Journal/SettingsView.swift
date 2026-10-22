import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var game: GameState
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var confirmReset = false

    private func binding<T>(_ keyPath: WritableKeyPath<AppSettings, T>) -> Binding<T> {
        Binding(get: { game.settings[keyPath: keyPath] }, set: { value in game.updateSettings { $0[keyPath: keyPath] = value } })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Birder name", text: $name)
                        .font(AppFont.script(26))
                        .onSubmit { saveName() }
                } header: {
                    header("Your name")
                }

                Section {
                    Toggle("All sound", isOn: binding(\.soundEnabled))
                    Toggle("Ambient soundscape", isOn: binding(\.ambientEnabled))
                        .disabled(!game.settings.soundEnabled)
                    volume("Ambience", binding(\.ambientVolume))
                    Toggle("Distant birdsong chorus", isOn: binding(\.chorusEnabled))
                        .disabled(!game.settings.soundEnabled)
                    volume("Chorus", binding(\.chorusVolume))
                    volume("Effects", binding(\.effectsVolume))
                    Picker("Soundscape", selection: binding(\.soundscape)) {
                        ForEach(Soundscape.allCases) { Text("\($0.emoji) \($0.title)").tag($0) }
                    }
                } header: {
                    header("Sound")
                } footer: {
                    Text("Every birdsong and soundscape is synthesised live on your device. Sound follows the ring/silent switch.")
                }

                Section {
                    Picker("Time of day", selection: binding(\.timeOfDay)) {
                        ForEach(TimeOfDayMode.allCases) { Text("\($0.emoji) \($0.title)").tag($0) }
                    }
                    Toggle("Reduce motion", isOn: binding(\.reduceMotion))
                    Toggle("Haptics", isOn: binding(\.hapticsEnabled))
                } header: {
                    header("Atmosphere")
                } footer: {
                    Text("“Auto” follows your clock: dawn, day, dusk and a starry, firefly-lit night.")
                }

                Section {
                    LabeledContent("Species", value: "\(BirdDatabase.shared.all.count)")
                    LabeledContent("Achievements", value: "\(game.save.achievements.count)/\(Achievement.all.count)")
                    LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
                    Text("Species facts are compiled from widely published ornithological references (IUCN Red List categories, field guides). Measurements are typical adult ranges and vary across populations. All bird illustrations and sounds are generated procedurally.")
                        .font(AppFont.italic(13))
                        .foregroundStyle(Palette.inkSoft)
                } header: {
                    header("About Plumage")
                }

                Section {
                    Button("Reset all progress", role: .destructive) { confirmReset = true }
                } footer: {
                    Text("Clears discoveries, XP, feathers, hatchlings, creations and notes. Settings are kept.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.parchment.ignoresSafeArea())
            .tint(Palette.forest)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        saveName()
                        dismiss()
                    }
                    .bold()
                }
            }
            .onAppear { name = game.settings.birderName }
            .confirmationDialog("Reset all progress?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Reset everything", role: .destructive) { game.resetProgress() }
            } message: {
                Text("This can't be undone.")
            }
        }
    }

    private func saveName() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        game.updateSettings { $0.birderName = String(trimmed.prefix(20)) }
    }

    private func header(_ text: String) -> some View {
        Text(text.uppercased()).font(AppFont.caps(12)).foregroundStyle(Palette.bark)
    }

    private func volume(_ label: String, _ value: Binding<Double>) -> some View {
        HStack {
            Text(label).frame(width: 84, alignment: .leading)
            Image(systemName: "speaker.fill").font(.caption).foregroundStyle(Palette.inkSoft)
            Slider(value: value, in: 0...1)
            Image(systemName: "speaker.wave.3.fill").font(.caption).foregroundStyle(Palette.inkSoft)
        }
        .disabled(!game.settings.soundEnabled)
    }
}
