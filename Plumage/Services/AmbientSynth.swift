import Foundation

/// Generates seamless, looping stereo nature beds (wind, water, crickets, rain, surf).
/// Everything is procedural, so the app needs no audio assets.
enum AmbientSynth {
    static let sampleRate = BirdSynth.sampleRate

    /// Renders `duration` seconds plus a crossfade tail, then folds the tail over the head
    /// so the buffer loops without a click.
    static func render(_ scape: Soundscape, duration: Double = 12) -> (left: [Float], right: [Float]) {
        let fade = 1.0
        let n = Int(duration * sampleRate)
        let total = Int((duration + fade) * sampleRate)
        var left = [Float](repeating: 0, count: total)
        var right = [Float](repeating: 0, count: total)
        var rng = SeededRandom(seed: StableHash.fnv1a(scape.rawValue))

        switch scape {
        case .forest:
            addWind(&left, &right, level: 0.32, gustCycles: 2, duration: duration, rng: &rng)
            addRustle(&left, &right, level: 0.06, rng: &rng)
        case .brook:
            addWater(&left, &right, level: 0.3, bubblesPerSecond: 55, rng: &rng)
            addWind(&left, &right, level: 0.1, gustCycles: 1, duration: duration, rng: &rng)
        case .meadow:
            addWind(&left, &right, level: 0.2, gustCycles: 3, duration: duration, rng: &rng)
            addInsects(&left, &right, level: 0.05, duration: duration, rng: &rng)
        case .night:
            addWind(&left, &right, level: 0.1, gustCycles: 1, duration: duration, rng: &rng)
            addCrickets(&left, &right, level: 0.07, duration: duration, rng: &rng)
        case .rain:
            addRain(&left, &right, level: 0.22, rng: &rng)
            addWind(&left, &right, level: 0.12, gustCycles: 2, duration: duration, rng: &rng)
        case .shore:
            addSurf(&left, &right, level: 0.38, wavesPerLoop: 2, duration: duration, rng: &rng)
            addWind(&left, &right, level: 0.12, gustCycles: 2, duration: duration, rng: &rng)
        }

        // Crossfade the extra tail into the head for a seamless loop.
        let f = total - n
        var outL = Array(left[0..<n])
        var outR = Array(right[0..<n])
        for i in 0..<f {
            let k = Float(i) / Float(f)
            outL[i] = left[i] * k + left[n + i] * (1 - k)
            outR[i] = right[i] * k + right[n + i] * (1 - k)
        }
        normalize(&outL, &outR, peak: 0.7)
        return (outL, outR)
    }

    // MARK: - Layers

    private static func white(_ rng: inout SeededRandom) -> Double { rng.unit() * 2 - 1 }

    private static func addWind(_ l: inout [Float], _ r: inout [Float], level: Double, gustCycles: Int, duration: Double, rng: inout SeededRandom) {
        var bl = 0.0, br = 0.0
        var lpL = 0.0, lpR = 0.0
        let phase = rng.range(0, 6.28)
        for i in 0..<l.count {
            let t = Double(i) / sampleRate
            // Brown noise for each channel, partly correlated.
            let shared = white(&rng)
            bl = (bl + 0.02 * (0.6 * shared + 0.4 * white(&rng))) / 1.02
            br = (br + 0.02 * (0.6 * shared + 0.4 * white(&rng))) / 1.02
            // Gusts are periodic over the loop length so the bed loops cleanly.
            let cycle = 2 * Double.pi * Double(gustCycles) * t / duration
            let gust = 0.55 + 0.3 * sin(cycle + phase) + 0.15 * sin(cycle * 2.0 + phase * 0.5)
            let a = 1 - exp(-2 * Double.pi * (300 + 500 * gust) / sampleRate)
            lpL += a * (bl - lpL)
            lpR += a * (br - lpR)
            l[i] += Float(lpL * 3.5 * gust * level)
            r[i] += Float(lpR * 3.5 * gust * level)
        }
    }

    private static func addRustle(_ l: inout [Float], _ r: inout [Float], level: Double, rng: inout SeededRandom) {
        var env = 0.0
        var target = 0.0
        var lp = 0.0
        for i in 0..<l.count {
            if i % 2205 == 0 { target = pow(rng.unit(), 3) }
            env += (target - env) * 0.0005
            let w = white(&rng)
            lp += 0.25 * (w - lp)
            let hiss = (w - lp) * env * level
            let pan = 0.5 + 0.4 * sin(Double(i) / sampleRate * 0.7)
            l[i] += Float(hiss * (1 - pan) * 2)
            r[i] += Float(hiss * pan * 2)
        }
    }

    private static func addWater(_ l: inout [Float], _ r: inout [Float], level: Double, bubblesPerSecond: Double, rng: inout SeededRandom) {
        // A rushing bed…
        var lp = 0.0, lp2 = 0.0
        for i in 0..<l.count {
            let w = white(&rng)
            lp += 0.08 * (w - lp)
            lp2 += 0.3 * (w - lp2)
            let bed = (lp2 - lp) * level * 0.9
            l[i] += Float(bed)
            r[i] += Float(bed * 0.9)
        }
        // …and hundreds of tiny resonant bubbles (rising, decaying sinusoids).
        let count = Int(bubblesPerSecond * Double(l.count) / sampleRate)
        for _ in 0..<count {
            let start = Int(rng.unit() * Double(l.count))
            let f0 = rng.range(450, 1500)
            let len = Int(rng.range(0.02, 0.06) * sampleRate)
            let amp = rng.range(0.15, 1) * level * 0.5
            let pan = rng.unit()
            var phase = 0.0
            for j in 0..<len {
                let idx = start + j
                if idx >= l.count { break }
                let u = Double(j) / Double(len)
                let f = f0 * (1 + 0.8 * u)
                phase += 2 * Double.pi * f / sampleRate
                let s = sin(phase) * exp(-5 * u) * amp
                l[idx] += Float(s * (1 - pan))
                r[idx] += Float(s * pan)
            }
        }
    }

    private static func addInsects(_ l: inout [Float], _ r: inout [Float], level: Double, duration: Double, rng: inout SeededRandom) {
        // Grasshopper stridulation: bursts of high, buzzy pulses.
        for _ in 0..<3 {
            let f = rng.range(5200, 7000)
            let pan = rng.unit()
            let period = duration / Double(Int(rng.range(5, 9)))
            var phase = 0.0
            for i in 0..<l.count {
                let t = Double(i) / sampleRate
                let local = t.truncatingRemainder(dividingBy: period)
                guard local < period * 0.45 else { continue }
                let pulse = sin(2 * Double.pi * 38 * t) > 0.2 ? 1.0 : 0.0
                phase += 2 * Double.pi * f / sampleRate
                let edge = min(local / 0.2, (period * 0.45 - local) / 0.2, 1)
                let s = sin(phase) * pulse * edge * level
                l[i] += Float(s * (1 - pan))
                r[i] += Float(s * pan)
            }
        }
    }

    private static func addCrickets(_ l: inout [Float], _ r: inout [Float], level: Double, duration: Double, rng: inout SeededRandom) {
        // Field crickets: chirps of 3–4 pulses near 4.5 kHz, each cricket on its own rhythm.
        for c in 0..<4 {
            let f = rng.range(4000, 5000)
            let pan = 0.15 + 0.7 * rng.unit()
            let chirpsPerLoop = 16 + c * 5
            let period = duration / Double(chirpsPerLoop)
            let pulses = 3 + c % 2
            let amp = level * rng.range(0.5, 1)
            var phase = 0.0
            for i in 0..<l.count {
                let t = Double(i) / sampleRate
                let local = t.truncatingRemainder(dividingBy: period)
                let pulseIndex = Int(local / 0.032)
                guard pulseIndex < pulses else { continue }
                let within = local - Double(pulseIndex) * 0.032
                guard within < 0.02 else { continue }
                phase += 2 * Double.pi * f / sampleRate
                let env = sin(Double.pi * within / 0.02)
                let s = sin(phase) * env * amp
                l[i] += Float(s * (1 - pan))
                r[i] += Float(s * pan)
            }
        }
    }

    private static func addRain(_ l: inout [Float], _ r: inout [Float], level: Double, rng: inout SeededRandom) {
        var lpL = 0.0, lpR = 0.0
        for i in 0..<l.count {
            lpL += 0.35 * (white(&rng) - lpL)
            lpR += 0.35 * (white(&rng) - lpR)
            l[i] += Float(lpL * level)
            r[i] += Float(lpR * level)
        }
        // Individual droplets.
        let drops = Int(Double(l.count) / sampleRate * 70)
        for _ in 0..<drops {
            let start = Int(rng.unit() * Double(l.count))
            let len = Int(0.012 * sampleRate)
            let amp = pow(rng.unit(), 2) * level * 2.2
            let pan = rng.unit()
            var hp = 0.0
            for j in 0..<len {
                let idx = start + j
                if idx >= l.count { break }
                let w = white(&rng)
                hp += 0.5 * (w - hp)
                let s = (w - hp) * exp(-Double(j) / Double(len) * 6) * amp
                l[idx] += Float(s * (1 - pan))
                r[idx] += Float(s * pan)
            }
        }
    }

    private static func addSurf(_ l: inout [Float], _ r: inout [Float], level: Double, wavesPerLoop: Int, duration: Double, rng: inout SeededRandom) {
        var lpL = 0.0, lpR = 0.0
        let period = duration / Double(wavesPerLoop)
        for i in 0..<l.count {
            let t = Double(i) / sampleRate
            let u = t.truncatingRemainder(dividingBy: period) / period
            // Swell builds, breaks, then a long hiss drains back down the sand.
            let env: Double
            if u < 0.35 { env = pow(u / 0.35, 2) * 0.6 }
            else if u < 0.45 { env = 0.6 + 0.4 * (u - 0.35) / 0.1 }
            else { env = exp(-(u - 0.45) * 4.2) }
            let cutoff = 200 + 2600 * env
            let a = 1 - exp(-2 * Double.pi * cutoff / sampleRate)
            lpL += a * (white(&rng) - lpL)
            lpR += a * (white(&rng) - lpR)
            l[i] += Float(lpL * env * level * 1.6)
            r[i] += Float(lpR * env * level * 1.6)
        }
    }

    private static func normalize(_ l: inout [Float], _ r: inout [Float], peak: Float) {
        var m: Float = 0
        for v in l { m = max(m, abs(v)) }
        for v in r { m = max(m, abs(v)) }
        guard m > 0 else { return }
        let k = peak / m
        for i in l.indices { l[i] *= k }
        for i in r.indices { r[i] *= k }
    }
}
