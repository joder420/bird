import AVFoundation
import Combine

/// Plays synthesized birdsong, ambient soundscapes, a distant background chorus and UI sounds.
///
/// Graph:
///   ambient ─────────────────────┐
///   song ────────────────────────┤
///   fx ──────────────────────────┼─▶ main mixer ─▶ output
///   chorus A/B ─▶ chorus mixer ─▶ reverb ─┘
///
/// If you drop real recordings named `<species-id>.m4a` (or .mp3/.wav/.caf) into the app bundle,
/// they are played instead of the synthesized song.
final class SoundEngine: ObservableObject {
    static let shared = SoundEngine()

    @Published private(set) var singingSpeciesID: String?
    @Published private(set) var chorusSpeciesID: String?

    private let engine = AVAudioEngine()
    private let ambientPlayer = AVAudioPlayerNode()
    private let songPlayer = AVAudioPlayerNode()
    private let fxPlayer = AVAudioPlayerNode()
    private let chorusPlayers = [AVAudioPlayerNode(), AVAudioPlayerNode()]
    private let chorusMixer = AVAudioMixerNode()
    private let reverb = AVAudioUnitReverb()
    private let format = AVAudioFormat(standardFormatWithSampleRate: BirdSynth.sampleRate, channels: 2)!

    private let synthQueue = DispatchQueue(label: "plumage.synth", qos: .userInitiated)
    // Caches are only touched on `synthQueue`.
    private var songCache: [String: [Float]] = [:]
    private var effectCache: [UISound: AVAudioPCMBuffer] = [:]
    private var ambientCache: [Soundscape: AVAudioPCMBuffer] = [:]

    private var settings = AppSettings()
    private var isConfigured = false
    private var currentScape: Soundscape?
    private var songToken = 0
    private var chorusTimer: Timer?
    private var chorusIndex = 0
    private var recordingPlayer: AVAudioPlayer?
    private var fadeTimer: Timer?
    private var fadeFrom: Float = 0
    private var fadeTarget: Float = 0
    private var fadeStep = 0
    private var fadeSteps = 1
    private var fadeCompletion: (() -> Void)?
    private var observers: [NSObjectProtocol] = []

    private init() {}

    // MARK: - Settings

    func apply(settings newSettings: AppSettings) {
        let previous = settings
        settings = newSettings
        configureIfNeeded()
        engine.mainMixerNode.outputVolume = newSettings.soundEnabled ? 1 : 0
        fxPlayer.volume = Float(newSettings.effectsVolume)
        chorusMixer.outputVolume = Float(newSettings.chorusVolume)

        if newSettings.soundEnabled && newSettings.ambientEnabled {
            if previous.soundscape != newSettings.soundscape || currentScape == nil || !ambientPlayer.isPlaying {
                startAmbient()
            } else {
                fade(to: Float(newSettings.ambientVolume), duration: 0.3)
            }
        } else {
            stopAmbient()
        }

        if newSettings.soundEnabled && newSettings.chorusEnabled {
            startChorus()
        } else {
            stopChorus()
        }
    }

    // MARK: - Engine

    private func configureIfNeeded() {
        guard !isConfigured else { return }
        isConfigured = true

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)

        reverb.loadFactoryPreset(.mediumHall)
        reverb.wetDryMix = 38

        for node in [ambientPlayer, songPlayer, fxPlayer] { engine.attach(node) }
        for node in chorusPlayers { engine.attach(node) }
        engine.attach(chorusMixer)
        engine.attach(reverb)

        engine.connect(ambientPlayer, to: engine.mainMixerNode, format: format)
        engine.connect(songPlayer, to: engine.mainMixerNode, format: format)
        engine.connect(fxPlayer, to: engine.mainMixerNode, format: format)
        for node in chorusPlayers {
            engine.connect(node, to: chorusMixer, fromBus: 0, toBus: chorusMixer.nextAvailableInputBus, format: format)
        }
        engine.connect(chorusMixer, to: reverb, format: format)
        engine.connect(reverb, to: engine.mainMixerNode, format: format)
        ambientPlayer.volume = 0

        engine.prepare()
        startEngine()

        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            guard let self,
                  let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
            if type == .ended { self.restart() }
        })
        observers.append(center.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main) { [weak self] _ in
            self?.restart()
        })
    }

    private func startEngine() {
        guard !engine.isRunning else { return }
        do {
            try engine.start()
        } catch {
            print("Plumage audio: engine failed to start – \(error)")
        }
    }

    private func restart() {
        try? AVAudioSession.sharedInstance().setActive(true)
        startEngine()
        currentScape = nil
        apply(settings: settings)
    }

    /// Call when the app returns to the foreground.
    func resume() {
        guard isConfigured else { return }
        if engine.isRunning {
            apply(settings: settings)
        } else {
            restart()
        }
    }

    // MARK: - Ambient soundscape

    private func startAmbient() {
        let scape = settings.soundscape
        currentScape = scape
        synthQueue.async { [weak self] in
            guard let self else { return }
            let buffer: AVAudioPCMBuffer
            if let cached = self.ambientCache[scape] {
                buffer = cached
            } else {
                let rendered = AmbientSynth.render(scape)
                guard let made = self.makeBuffer(left: rendered.left, right: rendered.right) else { return }
                self.ambientCache[scape] = made
                buffer = made
            }
            DispatchQueue.main.async {
                guard self.currentScape == scape, self.settings.soundEnabled, self.settings.ambientEnabled else { return }
                self.startEngine()
                guard self.engine.isRunning else { return }
                self.ambientPlayer.stop()
                self.ambientPlayer.volume = 0
                self.ambientPlayer.scheduleBuffer(buffer, at: nil, options: [.loops], completionHandler: nil)
                self.ambientPlayer.play()
                self.fade(to: Float(self.settings.ambientVolume), duration: 2.0)
            }
        }
    }

    private func stopAmbient() {
        currentScape = nil
        fade(to: 0, duration: 0.6) { [weak self] in self?.ambientPlayer.stop() }
    }

    private func fade(to target: Float, duration: Double, completion: (() -> Void)? = nil) {
        fadeTimer?.invalidate()
        fadeFrom = ambientPlayer.volume
        fadeTarget = target
        fadeStep = 0
        fadeSteps = max(1, Int(duration * 30))
        fadeCompletion = completion
        fadeTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            self.fadeStep += 1
            let k = min(Float(self.fadeStep) / Float(self.fadeSteps), 1)
            self.ambientPlayer.volume = self.fadeFrom + (self.fadeTarget - self.fadeFrom) * k
            if self.fadeStep >= self.fadeSteps {
                timer.invalidate()
                let done = self.fadeCompletion
                self.fadeCompletion = nil
                done?()
            }
        }
    }

    // MARK: - Background chorus

    private func startChorus() {
        guard chorusTimer == nil else { return }
        scheduleNextChorusCall(after: 2.5)
    }

    private func stopChorus() {
        chorusTimer?.invalidate()
        chorusTimer = nil
        chorusPlayers.forEach { $0.stop() }
    }

    private func scheduleNextChorusCall(after delay: Double) {
        chorusTimer?.invalidate()
        chorusTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.playChorusCall()
            self.chorusTimer = nil
            if self.settings.soundEnabled && self.settings.chorusEnabled {
                self.scheduleNextChorusCall(after: Double.random(in: 4.5...11))
            }
        }
    }

    private func chorusPool() -> [BirdSpecies] {
        let db = BirdDatabase.shared
        let scape = settings.soundscape
        if scape == .night {
            let nightIDs: Set<String> = ["common-loon", "north-island-brown-kiwi", "kakapo", "european-robin", "great-tinamou"]
            return db.all.filter { $0.group == .owl || nightIDs.contains($0.id) }
        }
        let pool = db.all.filter { bird in bird.group != .owl && bird.habitats.contains { scape.habitats.contains($0) } }
        return pool.isEmpty ? db.all : pool
    }

    private func playChorusCall() {
        guard settings.soundEnabled, settings.chorusEnabled, singingSpeciesID == nil,
              let species = chorusPool().randomElement() else { return }
        let pan = Double.random(in: -0.85...0.85)
        let gain = Double.random(in: 0.35...0.7)
        let player = chorusPlayers[chorusIndex % chorusPlayers.count]
        chorusIndex += 1
        synthQueue.async { [weak self] in
            guard let self else { return }
            let samples = self.cachedSong(species)
            guard let buffer = self.makeBuffer(mono: samples, pan: pan, gain: gain) else { return }
            DispatchQueue.main.async {
                self.startEngine()
                guard self.engine.isRunning else { return }
                self.chorusSpeciesID = species.id
                player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
                if !player.isPlaying { player.play() }
            }
        }
    }

    // MARK: - Species song

    /// Plays a species' song and returns its approximate duration so views can animate the singer.
    @discardableResult
    func playSong(_ species: BirdSpecies) -> TimeInterval {
        guard settings.soundEnabled else { return 0 }
        configureIfNeeded()
        songToken += 1
        let token = songToken
        singingSpeciesID = species.id

        if let url = recordingURL(for: species.id), let player = try? AVAudioPlayer(contentsOf: url) {
            songPlayer.stop()
            recordingPlayer?.stop()
            recordingPlayer = player
            player.play()
            let duration = player.duration
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
                if self?.songToken == token { self?.singingSpeciesID = nil }
            }
            return duration
        }

        let duration = BirdSynth.duration(species.call.song, seed: species.seed)
        synthQueue.async { [weak self] in
            guard let self else { return }
            let samples = self.cachedSong(species)
            guard let buffer = self.makeBuffer(mono: samples, pan: 0, gain: 1) else { return }
            DispatchQueue.main.async {
                guard self.songToken == token else { return }
                self.startEngine()
                guard self.engine.isRunning else {
                    self.singingSpeciesID = nil
                    return
                }
                self.recordingPlayer?.stop()
                self.songPlayer.stop()
                self.songPlayer.volume = 1
                self.songPlayer.scheduleBuffer(buffer, at: nil, options: [], completionHandler: { [weak self] in
                    DispatchQueue.main.async {
                        if self?.songToken == token { self?.singingSpeciesID = nil }
                    }
                })
                self.songPlayer.play()
            }
        }
        return duration
    }

    func stopSong() {
        songToken += 1
        songPlayer.stop()
        recordingPlayer?.stop()
        singingSpeciesID = nil
    }

    /// Pre-renders songs off the main thread (e.g. for a quiz round).
    func warmUp(_ species: [BirdSpecies]) {
        synthQueue.async { [weak self] in
            species.forEach { _ = self?.cachedSong($0) }
        }
    }

    private func recordingURL(for id: String) -> URL? {
        for ext in ["m4a", "mp3", "wav", "caf"] {
            if let url = Bundle.main.url(forResource: id, withExtension: ext) { return url }
        }
        return nil
    }

    /// Must be called on `synthQueue`.
    private func cachedSong(_ species: BirdSpecies) -> [Float] {
        if let cached = songCache[species.id] { return cached }
        let samples = BirdSynth.song(species.call.song, seed: species.seed)
        songCache[species.id] = samples
        return samples
    }

    // MARK: - Interface sounds

    func play(_ sound: UISound) {
        guard settings.soundEnabled, settings.effectsVolume > 0.01 else { return }
        configureIfNeeded()
        synthQueue.async { [weak self] in
            guard let self else { return }
            let buffer: AVAudioPCMBuffer
            if let cached = self.effectCache[sound] {
                buffer = cached
            } else {
                guard let made = self.makeBuffer(mono: BirdSynth.effect(sound), pan: 0, gain: 1) else { return }
                self.effectCache[sound] = made
                buffer = made
            }
            DispatchQueue.main.async {
                self.startEngine()
                guard self.engine.isRunning else { return }
                self.fxPlayer.scheduleBuffer(buffer, at: nil, options: [.interrupts], completionHandler: nil)
                if !self.fxPlayer.isPlaying { self.fxPlayer.play() }
            }
        }
    }

    // MARK: - Buffers

    private func makeBuffer(mono samples: [Float], pan: Double, gain: Double) -> AVAudioPCMBuffer? {
        let angle = (pan + 1) * .pi / 4
        let lg = Float(cos(angle) * gain * 1.41), rg = Float(sin(angle) * gain * 1.41)
        let left = samples.map { $0 * lg }
        let right = samples.map { $0 * rg }
        return makeBuffer(left: left, right: right)
    }

    private func makeBuffer(left: [Float], right: [Float]) -> AVAudioPCMBuffer? {
        let frames = min(left.count, right.count)
        guard frames > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames)),
              let channels = buffer.floatChannelData else { return nil }
        buffer.frameLength = AVAudioFrameCount(frames)
        let l = channels[0], r = channels[1]
        for i in 0..<frames {
            l[i] = min(max(left[i], -1), 1)
            r[i] = min(max(right[i], -1), 1)
        }
        return buffer
    }
}
