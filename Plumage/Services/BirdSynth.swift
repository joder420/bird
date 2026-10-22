import Foundation

/// An offline synthesizer that turns a species' `SongSignature` into audio samples.
///
/// Every song is built from short "notes": a carrier tone (with harmonics, sweeps, vibrato
/// and trill) blended with band-passed noise for harsh calls. The same seed always produces
/// the same song, so each species has a consistent voice.
enum BirdSynth {
    static let sampleRate: Double = 44_100

    struct Note {
        var start: Double
        var duration: Double
        var f0: Double
        var f1: Double
        var curve: Double = 1
        var vibratoRate: Double = 0
        var vibratoDepth: Double = 0
        var amRate: Double = 0
        var amDepth: Double = 0.8
        var harmonics: [Double] = [1]
        var noise: Double = 0
        var noiseQ: Double = 0.5
        var amp: Double = 1
        var attack: Double = 0.1
        var release: Double = 0.3
        var decay: Double = 0
    }

    // MARK: - Public

    /// Mono samples for a species' song, peak-normalised.
    static func song(_ signature: SongSignature, seed: UInt64) -> [Float] {
        render(notes(for: signature, seed: seed))
    }

    /// Duration in seconds without rendering any audio.
    static func duration(_ signature: SongSignature, seed: UInt64) -> Double {
        let n = notes(for: signature, seed: seed)
        return (n.map { $0.start + $0.duration }.max() ?? 0) + 0.15
    }

    // MARK: - Note generation

    static func notes(for sig: SongSignature, seed: UInt64) -> [Note] {
        var rng = SeededRandom(seed: seed)
        var all: [Note] = []
        var cursor = 0.0
        let phrases = max(1, min(sig.phrases, 4))
        for p in 0..<phrases {
            var phrase = phraseNotes(sig, rng: &rng, phraseIndex: p)
            let phraseEnd = phrase.map { $0.start + $0.duration }.max() ?? 0
            for i in phrase.indices { phrase[i].start += cursor }
            all += phrase
            cursor += phraseEnd + 0.45 + rng.range(0, 0.25)
            if cursor > 7 { break }
        }
        return all
    }

    private static func phraseNotes(_ sig: SongSignature, rng: inout SeededRandom, phraseIndex: Int) -> [Note] {
        let count = max(1, min(sig.notes, 24))
        let tempo = max(sig.tempo, 0.3)
        let interval = 1 / tempo
        let harsh = min(max(sig.harshness, 0), 1)
        var out: [Note] = []
        var t = 0.0

        func jitter(_ v: Double, _ amount: Double = 0.05) -> Double { v * (1 + rng.range(-amount, amount)) }

        switch sig.style {
        case .whistle:
            for i in 0..<count {
                let dur = interval * rng.range(0.6, 0.8)
                let lift = Double(i % 2) * sig.range * 0.08
                out.append(Note(start: t, duration: dur, f0: jitter(sig.pitch) + lift, f1: jitter(sig.pitch + sig.range),
                                curve: 0.7, vibratoRate: sig.trill, vibratoDepth: sig.trill > 0 ? 18 : 0,
                                harmonics: [1, 0.08, 0.02], noise: harsh * 0.6, amp: 1, attack: 0.12, release: 0.3))
                t += interval
            }

        case .trill:
            for i in 0..<count {
                let f = sig.pitch + (i % 2 == 0 ? 0 : sig.range * 0.3)
                out.append(Note(start: t, duration: interval * 0.6, f0: f, f1: f + sig.range * 0.1,
                                harmonics: [1, 0.1], noise: harsh * 0.5, amp: 0.9, attack: 0.15, release: 0.3))
                t += interval
            }

        case .chirp, .peep:
            for _ in 0..<count {
                let dur = sig.style == .peep ? 0.07 : rng.range(0.06, 0.11)
                let spread = abs(sig.range)
                let up = sig.range >= 0
                let hi = jitter(sig.pitch) + spread * 0.5, lo = jitter(sig.pitch) - spread * 0.3
                out.append(Note(start: t, duration: dur, f0: up ? lo : hi, f1: up ? hi : lo, curve: 0.5,
                                harmonics: [1, 0.12], noise: harsh * 0.5, amp: rng.range(0.75, 1), attack: 0.08, release: 0.4))
                t += interval * rng.range(0.8, 1.2)
            }

        case .warble, .mimic:
            if sig.style == .mimic {
                return mimicPhrase(sig, rng: &rng)
            }
            for _ in 0..<count {
                let dur = interval * rng.range(0.55, 0.95)
                let f0 = sig.pitch + sig.range * rng.range(-0.5, 0.5)
                let f1 = f0 + sig.range * rng.range(-0.35, 0.35)
                out.append(Note(start: t, duration: dur, f0: f0, f1: f1, curve: rng.range(0.5, 1.6),
                                vibratoRate: sig.trill > 0 ? sig.trill : rng.range(0, 40), vibratoDepth: rng.range(0, 60),
                                harmonics: [1, 0.15, 0.05], noise: harsh * 0.5, amp: rng.range(0.6, 1), attack: 0.1, release: 0.35))
                t += interval * rng.range(0.85, 1.25)
            }

        case .hoot:
            for i in 0..<count {
                let emphasis = (i == 1 && count > 3)
                let dur = interval * (emphasis ? 0.85 : rng.range(0.45, 0.7))
                out.append(Note(start: t, duration: dur, f0: sig.pitch * (emphasis ? 1.08 : 1), f1: sig.pitch + sig.range,
                                vibratoRate: 5, vibratoDepth: 3, harmonics: [1, 0.55, 0.3, 0.12, 0.05], noise: 0.06 + harsh * 0.3,
                                noiseQ: 0.9, amp: emphasis ? 1 : 0.8, attack: 0.25, release: 0.4))
                t += interval * (emphasis ? 1.2 : 1)
            }

        case .coo:
            for i in 0..<count {
                let dur = interval * 0.85
                let rise = i == count - 1 ? 1.0 : 0.92
                out.append(Note(start: t, duration: dur, f0: sig.pitch * 0.88, f1: (sig.pitch + sig.range) * rise, curve: 0.6,
                                vibratoRate: max(sig.trill, 4), vibratoDepth: 14, harmonics: [1, 0.5, 0.25, 0.1],
                                noise: 0.04, noiseQ: 0.9, amp: 0.9, attack: 0.3, release: 0.4))
                t += interval
            }

        case .caw, .croak, .squawk:
            let isCroak = sig.style == .croak
            let isSquawk = sig.style == .squawk
            for _ in 0..<count {
                let dur = isSquawk ? rng.range(0.2, 0.32) : (isCroak ? rng.range(0.22, 0.4) : rng.range(0.3, 0.42))
                out.append(Note(start: t, duration: dur, f0: jitter(sig.pitch * 1.06), f1: jitter(sig.pitch * 0.92 + sig.range),
                                curve: 0.8, amRate: isCroak ? rng.range(28, 55) : 0, amDepth: 0.6,
                                harmonics: [1, 0.9, 0.75, 0.6, 0.45, 0.35, 0.25, 0.15], noise: 0.15 + harsh * 0.55,
                                noiseQ: 0.35, amp: rng.range(0.8, 1), attack: 0.05, release: 0.25))
                t += interval * rng.range(0.9, 1.15)
            }

        case .quack:
            var amp = 1.0
            for _ in 0..<count {
                out.append(Note(start: t, duration: rng.range(0.18, 0.26), f0: jitter(sig.pitch), f1: sig.pitch + sig.range,
                                curve: 0.7, harmonics: [0.5, 1, 0.9, 0.7, 0.55, 0.4, 0.3], noise: 0.12 + harsh * 0.3,
                                noiseQ: 0.4, amp: amp, attack: 0.04, release: 0.3))
                amp *= 0.86
                t += interval
            }

        case .drum, .clatter:
            let isDrum = sig.style == .drum
            let hits = max(count, 8)
            var gap = interval
            for i in 0..<hits {
                let fade = isDrum ? 1 - Double(i) / Double(hits) * 0.5 : rng.range(0.7, 1)
                out.append(Note(start: t, duration: isDrum ? 0.018 : 0.022, f0: sig.pitch * (isDrum ? 2.2 : 3), f1: sig.pitch * 2,
                                harmonics: [0.3], noise: 0.95, noiseQ: 0.25, amp: fade, attack: 0.02, release: 0.8, decay: 60))
                t += gap
                if isDrum { gap *= 1.012 }
            }

        case .screech:
            for _ in 0..<count {
                let dur = min(interval * 0.85, 1.8)
                out.append(Note(start: t, duration: dur, f0: sig.pitch, f1: sig.pitch + sig.range, curve: 0.8,
                                vibratoRate: 9, vibratoDepth: 50, harmonics: [1, 0.5, 0.3, 0.15], noise: 0.2 + harsh * 0.7,
                                noiseQ: 0.3, amp: 1, attack: 0.08, release: 0.3))
                t += interval
            }

        case .honk, .bugle:
            let isBugle = sig.style == .bugle
            for _ in 0..<count {
                let dur = isBugle ? rng.range(0.38, 0.55) : rng.range(0.2, 0.3)
                out.append(Note(start: t, duration: dur, f0: jitter(sig.pitch * 0.95), f1: jitter(sig.pitch + sig.range), curve: 0.6,
                                vibratoRate: sig.trill, vibratoDepth: sig.trill > 0 ? 12 : 0,
                                amRate: isBugle ? 24 : 0, amDepth: 0.35,
                                harmonics: [1, 0.8, 0.6, 0.45, 0.3, 0.2], noise: 0.08 + harsh * 0.3, noiseQ: 0.45,
                                amp: 1, attack: 0.08, release: 0.3))
                t += interval
            }

        case .buzz:
            for _ in 0..<count {
                out.append(Note(start: t, duration: rng.range(0.15, 0.35), f0: jitter(sig.pitch), f1: sig.pitch + sig.range,
                                amRate: rng.range(55, 90), amDepth: 0.9, harmonics: [0.4, 0.2], noise: 0.5 + harsh * 0.4,
                                noiseQ: 0.3, amp: 0.8, attack: 0.1, release: 0.3))
                t += interval
            }

        case .boom:
            for _ in 0..<count {
                // Phone speakers can't reproduce ~80 Hz, so strong upper harmonics carry the "missing fundamental".
                out.append(Note(start: t, duration: interval * 0.7, f0: sig.pitch * 1.05, f1: sig.pitch, curve: 0.8,
                                harmonics: [1, 0.95, 0.85, 0.7, 0.5, 0.35, 0.2], noise: 0.05 + harsh * 0.2, noiseQ: 0.8,
                                amp: 1, attack: 0.3, release: 0.45))
                t += interval
            }

        case .yodel:
            var high = false
            for _ in 0..<count {
                let a = high ? sig.pitch + sig.range : sig.pitch
                let b = high ? sig.pitch : sig.pitch + sig.range
                out.append(Note(start: t, duration: interval * 0.95, f0: a, f1: b, curve: 2.5,
                                vibratoRate: 5, vibratoDepth: 10, harmonics: [1, 0.25, 0.06], noise: 0.02,
                                amp: 1, attack: 0.2, release: 0.25))
                high.toggle()
                t += interval * 0.92
            }

        case .scream:
            out.append(Note(start: 0, duration: 0.28, f0: sig.pitch * 0.75, f1: sig.pitch, curve: 0.6,
                            harmonics: [1, 0.7, 0.5, 0.3], noise: harsh * 0.4, noiseQ: 0.4, amp: 0.8, attack: 0.1, release: 0.25))
            out.append(Note(start: 0.32, duration: 0.7, f0: sig.pitch + sig.range, f1: (sig.pitch + sig.range) * 0.8, curve: 1.4,
                            vibratoRate: 7, vibratoDepth: 25, harmonics: [1, 0.75, 0.55, 0.35, 0.2], noise: harsh * 0.5,
                            noiseQ: 0.4, amp: 1, attack: 0.06, release: 0.35))

        case .hiss:
            for _ in 0..<count {
                out.append(Note(start: t, duration: rng.range(0.5, 0.9), f0: sig.pitch * 6, f1: sig.pitch * 5,
                                harmonics: [0], noise: 1, noiseQ: 0.15, amp: 0.8, attack: 0.25, release: 0.5))
                t += interval
            }

        case .cuckoo:
            out.append(Note(start: 0, duration: 0.26, f0: sig.pitch, f1: sig.pitch * 0.99,
                            harmonics: [1, 0.18, 0.05], noise: 0.02, amp: 1, attack: 0.15, release: 0.35))
            out.append(Note(start: 0.36, duration: 0.34, f0: sig.pitch * 0.82, f1: sig.pitch * 0.8,
                            harmonics: [1, 0.18, 0.05], noise: 0.02, amp: 0.9, attack: 0.15, release: 0.45))
        }
        return out
    }

    /// The lyrebird's medley: snippets in borrowed styles stitched together.
    private static func mimicPhrase(_ sig: SongSignature, rng: inout SeededRandom) -> [Note] {
        let styles: [SongStyle] = [.whistle, .chirp, .trill, .warble, .squawk, .coo, .whistle]
        var out: [Note] = []
        var cursor = 0.0
        for i in 0..<4 {
            let style = styles[Int(rng.next() % UInt64(styles.count))]
            let snippet = SongSignature(style: style, pitch: sig.pitch * rng.range(0.5, 1.6), range: sig.range * rng.range(-0.6, 0.6),
                                        notes: 3 + i % 3, tempo: rng.range(4, 9), trill: rng.range(0, 30),
                                        harshness: style == .squawk ? 0.6 : 0.05, phrases: 1)
            var notes = phraseNotes(snippet, rng: &rng, phraseIndex: 0)
            let end = notes.map { $0.start + $0.duration }.max() ?? 0
            for j in notes.indices { notes[j].start += cursor }
            out += notes
            cursor += end + 0.18
        }
        return out
    }

    // MARK: - Rendering

    static func render(_ notes: [Note], tail: Double = 0.15, peak: Float = 0.85) -> [Float] {
        let end = (notes.map { $0.start + $0.duration }.max() ?? 0) + tail
        let total = Int(end * sampleRate)
        guard total > 0 else { return [] }
        var out = [Float](repeating: 0, count: total)
        var noiseState: UInt32 = 0x1234_5678

        for note in notes {
            let startIndex = Int(note.start * sampleRate)
            let length = Int(note.duration * sampleRate)
            guard length > 1 else { continue }
            var phase = 0.0
            var low = 0.0, band = 0.0
            let twoPi = 2 * Double.pi
            for i in 0..<length {
                let idx = startIndex + i
                if idx >= total { break }
                let tt = Double(i) / sampleRate
                let u = Double(i) / Double(length)

                // Frequency trajectory
                let shaped = note.curve == 1 ? u : pow(u, note.curve)
                var freq = note.f0 + (note.f1 - note.f0) * shaped
                if note.vibratoDepth > 0 { freq += note.vibratoDepth * sin(twoPi * note.vibratoRate * tt) }
                freq = min(max(freq, 30), 9_000)
                phase += twoPi * freq / sampleRate
                if phase > twoPi * 1000 { phase -= twoPi * 1000 }

                // Tonal part
                var tone = 0.0
                for (k, h) in note.harmonics.enumerated() where h != 0 {
                    let harmonicFreq = freq * Double(k + 1)
                    if harmonicFreq < 16_000 { tone += h * sin(phase * Double(k + 1)) }
                }

                // Noise, band-passed around the carrier (Chamberlin state-variable filter)
                var noisy = 0.0
                if note.noise > 0 {
                    noiseState = noiseState &* 1_664_525 &+ 1_013_904_223
                    let white = Double(noiseState >> 8) / Double(1 << 24) * 2 - 1
                    let fc = min(freq * 1.2, 7_000)
                    let f = 2 * sin(Double.pi * fc / sampleRate)
                    low += f * band
                    let high = white - low - note.noiseQ * band
                    band += f * high
                    noisy = band * 1.6
                }
                var s = tone * (1 - note.noise) + noisy * note.noise

                // Envelope
                var env = 1.0
                if u < note.attack { env = sin(.pi / 2 * u / max(note.attack, 0.0001)) }
                else if u > 1 - note.release { env = sin(.pi / 2 * (1 - u) / max(note.release, 0.0001)) }
                if note.decay > 0 { env *= exp(-note.decay * tt) }
                if note.amRate > 0 {
                    env *= (1 - note.amDepth) + note.amDepth * (0.5 + 0.5 * sin(twoPi * note.amRate * tt))
                }
                s *= env * note.amp
                out[idx] += Float(s)
            }
        }

        // Normalise to the requested peak.
        var maxValue: Float = 0
        for v in out { maxValue = max(maxValue, abs(v)) }
        if maxValue > 0 {
            let k = peak / maxValue
            for i in out.indices { out[i] *= k }
        }
        return out
    }

    // MARK: - Interface sounds

    static func effect(_ sound: UISound) -> [Float] {
        func bell(_ start: Double, _ f: Double, _ dur: Double = 0.35, amp: Double = 1) -> Note {
            Note(start: start, duration: dur, f0: f, f1: f, harmonics: [1, 0.35, 0.12, 0.05], amp: amp, attack: 0.01, release: 0.4, decay: 7)
        }
        var notes: [Note]
        var peak: Float = 0.6
        switch sound {
        case .tap:
            notes = [Note(start: 0, duration: 0.05, f0: 1500, f1: 1300, harmonics: [1, 0.2], amp: 1, attack: 0.05, release: 0.6, decay: 30)]
            peak = 0.25
        case .select:
            notes = [bell(0, 1318, 0.12), bell(0.06, 1760, 0.18)]
            peak = 0.3
        case .success:
            notes = [bell(0, 1046.5), bell(0.08, 1318.5), bell(0.16, 1568, 0.5)]
        case .fail:
            notes = [Note(start: 0, duration: 0.18, f0: 440, f1: 400, harmonics: [1, 0, 0.3, 0, 0.12], amp: 1, attack: 0.05, release: 0.4),
                     Note(start: 0.16, duration: 0.3, f0: 330, f1: 290, harmonics: [1, 0, 0.3, 0, 0.12], amp: 1, attack: 0.05, release: 0.5)]
            peak = 0.4
        case .reward:
            notes = [bell(0, 2093, 0.25), bell(0.06, 2637, 0.25), bell(0.12, 3136, 0.25), bell(0.18, 4186, 0.4, amp: 0.7)]
            peak = 0.45
        case .levelUp:
            notes = [bell(0, 784), bell(0.11, 1046.5), bell(0.22, 1318.5), bell(0.33, 1568, 0.7),
                     bell(0.33, 2093, 0.7, amp: 0.5), bell(0.33, 1046.5, 0.7, amp: 0.6)]
            peak = 0.6
        case .hatch:
            notes = [Note(start: 0, duration: 0.06, f0: 1800, f1: 1600, noise: 1, noiseQ: 0.3, amp: 1, attack: 0.02, release: 0.7, decay: 40),
                     Note(start: 0.12, duration: 0.05, f0: 2200, f1: 2000, noise: 1, noiseQ: 0.3, amp: 0.8, attack: 0.02, release: 0.7, decay: 40),
                     Note(start: 0.3, duration: 0.09, f0: 3500, f1: 5200, curve: 0.6, harmonics: [1, 0.1], amp: 1, attack: 0.1, release: 0.4),
                     Note(start: 0.45, duration: 0.09, f0: 3800, f1: 5600, curve: 0.6, harmonics: [1, 0.1], amp: 1, attack: 0.1, release: 0.4),
                     bell(0.6, 2093, 0.5, amp: 0.5)]
        case .crack:
            notes = [Note(start: 0, duration: 0.05, f0: 2400, f1: 1800, noise: 1, noiseQ: 0.25, amp: 1, attack: 0.02, release: 0.7, decay: 50)]
            peak = 0.45
        case .flip:
            notes = [Note(start: 0, duration: 0.09, f0: 900, f1: 3200, curve: 0.5, noise: 1, noiseQ: 0.2, amp: 1, attack: 0.3, release: 0.5)]
            peak = 0.3
        case .match:
            notes = [bell(0, 1568, 0.3), bell(0.09, 2093, 0.45)]
            peak = 0.45
        case .whoosh:
            notes = [Note(start: 0, duration: 0.35, f0: 500, f1: 3000, curve: 0.7, noise: 1, noiseQ: 0.2, amp: 1, attack: 0.4, release: 0.5)]
            peak = 0.3
        case .unlock:
            notes = [bell(0, 1318.5, 0.5), bell(0.1, 1975.5, 0.7)]
            peak = 0.5
        case .chirp:
            notes = [Note(start: 0, duration: 0.08, f0: 3600, f1: 5200, curve: 0.6, harmonics: [1, 0.1], amp: 1, attack: 0.1, release: 0.4),
                     Note(start: 0.11, duration: 0.07, f0: 4200, f1: 5600, curve: 0.6, harmonics: [1, 0.1], amp: 0.8, attack: 0.1, release: 0.4)]
            peak = 0.35
        }
        return render(notes, tail: 0.3, peak: peak)
    }
}

enum UISound: CaseIterable {
    case tap, select, success, fail, reward, levelUp, hatch, crack, flip, match, whoosh, unlock, chirp
}
