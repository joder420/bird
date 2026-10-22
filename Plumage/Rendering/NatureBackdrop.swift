import SwiftUI

enum DayPhase: String, CaseIterable {
    case dawn, day, dusk, night

    static func current(_ mode: TimeOfDayMode, date: Date = Date()) -> DayPhase {
        switch mode {
        case .dawn: return .dawn
        case .day: return .day
        case .dusk: return .dusk
        case .night: return .night
        case .auto:
            let hour = Calendar.current.component(.hour, from: date)
            switch hour {
            case 5..<8: return .dawn
            case 8..<17: return .day
            case 17..<20: return .dusk
            default: return .night
            }
        }
    }

    var greeting: String {
        switch self {
        case .dawn: return "Good morning"
        case .day: return "Good day"
        case .dusk: return "Good evening"
        case .night: return "Good night"
        }
    }

    var sky: [Color] {
        switch self {
        case .dawn: return [Color(hex: 0x3E5C8A), Color(hex: 0xE9A88A), Color(hex: 0xF7D7A8)]
        case .day: return [Color(hex: 0x5FA8DD), Color(hex: 0xA9D6F0), Color(hex: 0xE8F4EC)]
        case .dusk: return [Color(hex: 0x2E2A5C), Color(hex: 0xB8576A), Color(hex: 0xF2A65A)]
        case .night: return [Color(hex: 0x0B1430), Color(hex: 0x1C2B55), Color(hex: 0x2E3F6E)]
        }
    }

    /// far mountains, mid hills, near hills, meadow
    var land: [Color] {
        switch self {
        case .dawn: return [Color(hex: 0x9A86A8), Color(hex: 0x6E7E86), Color(hex: 0x5E7F5A), Color(hex: 0x40654A)]
        case .day: return [Color(hex: 0x9DB4C8), Color(hex: 0x6F9A8A), Color(hex: 0x7FA65A), Color(hex: 0x4E7D3E)]
        case .dusk: return [Color(hex: 0x6B5A86), Color(hex: 0x4E4870), Color(hex: 0x3E4E4A), Color(hex: 0x2A3A33)]
        case .night: return [Color(hex: 0x24304F), Color(hex: 0x1C2742), Color(hex: 0x17283A), Color(hex: 0x0F1C26)]
        }
    }

    var isDark: Bool { self == .night || self == .dusk }
}

/// The living landscape behind every screen: sky, sun or moon, drifting clouds, layered hills,
/// pines, passing flocks, falling leaves by day and fireflies by night.
struct NatureBackdrop: View {
    @EnvironmentObject private var game: GameState
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    var body: some View {
        let paused = systemReduceMotion || game.settings.reduceMotion
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: paused)) { timeline in
            let phase = DayPhase.current(game.settings.timeOfDay, date: timeline.date)
            let t = paused ? 0 : timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 10_000)
            Canvas { context, size in
                NaturePainter.paint(in: context, size: size, phase: phase, time: t)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

enum NaturePainter {
    /// Deterministic pseudo-random 0…1 from an index.
    static func hash01(_ i: Int, _ salt: Int = 0) -> Double {
        let v = sin(Double(i) * 12.9898 + Double(salt) * 78.233) * 43_758.5453
        return v - floor(v)
    }

    static func paint(in ctx: GraphicsContext, size: CGSize, phase: DayPhase, time t: Double) {
        let W = size.width, H = size.height
        let rect = CGRect(origin: .zero, size: size)

        // Sky
        ctx.fill(Path(rect), with: .linearGradient(Gradient(colors: phase.sky), startPoint: .zero, endPoint: CGPoint(x: 0, y: H * 0.75)))

        // Stars
        if phase.isDark {
            let count = phase == .night ? 90 : 30
            for i in 0..<count {
                let x = hash01(i, 1) * W, y = hash01(i, 2) * H * 0.55
                let twinkle = 0.45 + 0.55 * (0.5 + 0.5 * sin(t * (1 + hash01(i, 3) * 2) + Double(i)))
                let r = 0.6 + hash01(i, 4) * 1.3
                let alpha = (phase == .night ? 0.9 : 0.4) * twinkle
                ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(.white.opacity(alpha)))
            }
        }

        // Sun or moon
        let orb: CGPoint
        switch phase {
        case .dawn: orb = CGPoint(x: W * 0.22, y: H * 0.36)
        case .day: orb = CGPoint(x: W * 0.8, y: H * 0.13)
        case .dusk: orb = CGPoint(x: W * 0.78, y: H * 0.38)
        case .night: orb = CGPoint(x: W * 0.78, y: H * 0.14)
        }
        let orbR: CGFloat = phase == .night ? 26 : 34
        let glowColor: Color = phase == .night ? Color(hex: 0xC9D6F5) : (phase == .day ? Color(hex: 0xFFF6CF) : Color(hex: 0xFFC27A))
        ctx.fill(Path(ellipseIn: CGRect(x: orb.x - orbR * 4, y: orb.y - orbR * 4, width: orbR * 8, height: orbR * 8)),
                 with: .radialGradient(Gradient(colors: [glowColor.opacity(0.55), glowColor.opacity(0)]), center: orb, startRadius: orbR * 0.8, endRadius: orbR * 4))
        if phase == .night {
            ctx.drawLayer { layer in
                layer.fill(Path(ellipseIn: CGRect(x: orb.x - orbR, y: orb.y - orbR, width: orbR * 2, height: orbR * 2)), with: .color(Color(hex: 0xF4F1DA)))
                layer.blendMode = .destinationOut
                layer.fill(Path(ellipseIn: CGRect(x: orb.x - orbR * 0.55, y: orb.y - orbR * 1.15, width: orbR * 2, height: orbR * 2)), with: .color(.black))
            }
        } else {
            let sunColor: Color = phase == .day ? Color(hex: 0xFFF3C4) : Color(hex: 0xFFB36B)
            ctx.fill(Path(ellipseIn: CGRect(x: orb.x - orbR, y: orb.y - orbR, width: orbR * 2, height: orbR * 2)), with: .color(sunColor))
        }

        // Clouds
        let cloudAlpha: Double = phase == .night ? 0.18 : (phase == .day ? 0.85 : 0.6)
        let cloudTint: Color = phase == .dusk ? Color(hex: 0xF7C6B0) : (phase == .dawn ? Color(hex: 0xFCE3D2) : .white)
        for i in 0..<5 {
            let speed = 6 + hash01(i, 5) * 10
            let span = W + 320
            let x = (hash01(i, 6) * span + t * speed).truncatingRemainder(dividingBy: span) - 160
            let y = H * (0.06 + hash01(i, 7) * 0.3)
            let scale = 0.6 + hash01(i, 8) * 0.7
            drawCloud(ctx, at: CGPoint(x: x, y: y), scale: scale, color: cloudTint.opacity(cloudAlpha))
        }

        // Far mountains
        let lands = phase.land
        ctx.fill(ridge(width: W, baseY: H * 0.56, amplitude: H * 0.07, seed: 1, bottom: H), with: .color(lands[0]))
        // Mid hills with pines
        let midBase = H * 0.66
        ctx.fill(ridge(width: W, baseY: midBase, amplitude: H * 0.035, seed: 2, bottom: H), with: .color(lands[1]))
        let pineColor = lands[1].opacity(1)
        var pines = Path()
        for i in 0..<22 {
            let x = hash01(i, 9) * W
            let y = ridgeY(x: x, width: W, baseY: midBase, amplitude: H * 0.035, seed: 2) + 2
            let h = 18 + hash01(i, 10) * 26
            for tier in 0..<3 {
                let ty = y - h * CGFloat(tier) * 0.3
                let tw = h * (0.38 - CGFloat(tier) * 0.08)
                pines.move(to: CGPoint(x: x - tw, y: ty))
                pines.addLine(to: CGPoint(x: x, y: ty - h * 0.55))
                pines.addLine(to: CGPoint(x: x + tw, y: ty))
                pines.closeSubpath()
            }
        }
        var pineCtx = ctx
        pineCtx.opacity = 0.9
        pineCtx.fill(pines, with: .color(pineColor))
        pineCtx.fill(pines, with: .color(.black.opacity(0.12)))

        // A passing flock
        let flockPeriod = 26.0
        let flockT = t.truncatingRemainder(dividingBy: flockPeriod)
        if flockT < 16 {
            let fx = -120 + (W + 240) * flockT / 16
            let fy = H * 0.22 + 18 * sin(flockT * 0.6)
            var flock = Path()
            for b in 0..<6 {
                let row = Double(b / 2 + 1)
                let side: Double = b % 2 == 0 ? -1 : 1
                let bx = fx - row * 16, by = fy + side * row * 9
                let flap = 5 * sin(t * 9 + Double(b))
                flock.move(to: CGPoint(x: bx - 7, y: by - flap))
                flock.addQuadCurve(to: CGPoint(x: bx, y: by), control: CGPoint(x: bx - 3, y: by - 3 - flap))
                flock.addQuadCurve(to: CGPoint(x: bx + 7, y: by - flap), control: CGPoint(x: bx + 3, y: by - 3 - flap))
            }
            ctx.stroke(flock, with: .color((phase.isDark ? Color.white : Color(hex: 0x2B2420)).opacity(0.55)),
                       style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        }

        // Near hills and meadow
        ctx.fill(ridge(width: W, baseY: H * 0.78, amplitude: H * 0.025, seed: 3, bottom: H), with: .color(lands[2]))
        ctx.fill(ridge(width: W, baseY: H * 0.9, amplitude: H * 0.015, seed: 4, bottom: H), with: .color(lands[3]))

        // Grass blades and flowers
        var grass = Path()
        for i in 0..<60 {
            let x = hash01(i, 11) * W
            let y = ridgeY(x: x, width: W, baseY: H * 0.9, amplitude: H * 0.015, seed: 4) + 4
            let h = 10 + hash01(i, 12) * 16
            let sway = 4 * sin(t * 1.3 + x * 0.02)
            grass.move(to: CGPoint(x: x, y: y))
            grass.addQuadCurve(to: CGPoint(x: x + sway, y: y - h), control: CGPoint(x: x + sway * 0.3, y: y - h * 0.6))
        }
        ctx.stroke(grass, with: .color(lands[3].opacity(1)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        if !phase.isDark {
            let petals: [Color] = [Color(hex: 0xF2C14E), Color(hex: 0xE76F51), Color(hex: 0xF4F1EA), Color(hex: 0xB57EDC)]
            for i in 0..<18 {
                let x = hash01(i, 13) * W
                let y = ridgeY(x: x, width: W, baseY: H * 0.9, amplitude: H * 0.015, seed: 4) - 4 - hash01(i, 14) * 8
                let c = petals[i % petals.count]
                ctx.fill(Path(ellipseIn: CGRect(x: x - 3, y: y - 3, width: 6, height: 6)), with: .color(c))
                ctx.fill(Path(ellipseIn: CGRect(x: x - 1, y: y - 1, width: 2, height: 2)), with: .color(Color(hex: 0x6B4A2A)))
            }
        }

        // Particles: falling leaves by day, fireflies by night.
        if phase == .night {
            for i in 0..<20 {
                let bx = hash01(i, 15) * W, by = H * (0.55 + hash01(i, 16) * 0.4)
                let x = bx + 22 * sin(t * 0.4 + Double(i)) + 10 * sin(t * 1.1 + Double(i) * 2)
                let y = by + 14 * cos(t * 0.5 + Double(i) * 1.3)
                let blink = max(0, sin(t * (0.8 + hash01(i, 17)) + Double(i) * 3))
                let r: CGFloat = 9
                ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                         with: .radialGradient(Gradient(colors: [Color(hex: 0xEFFFA0).opacity(0.75 * blink), Color(hex: 0xEFFFA0).opacity(0)]),
                                               center: CGPoint(x: x, y: y), startRadius: 0, endRadius: r))
                ctx.fill(Path(ellipseIn: CGRect(x: x - 1.5, y: y - 1.5, width: 3, height: 3)), with: .color(Color(hex: 0xFAFFD0).opacity(blink)))
            }
        } else {
            let leafColors: [Color] = [Color(hex: 0xD9822B), Color(hex: 0xC0392B), Color(hex: 0xE3B23C), Color(hex: 0x7FA65A)]
            for i in 0..<14 {
                let speed = 18 + hash01(i, 18) * 22
                let span = H + 60
                let y = (hash01(i, 19) * span + t * speed).truncatingRemainder(dividingBy: span) - 30
                let x = hash01(i, 20) * W + 30 * sin(t * 0.9 + Double(i))
                var leaf = ctx
                leaf.translateBy(x: x, y: y)
                leaf.rotate(by: .radians(t * (0.6 + hash01(i, 21)) + Double(i)))
                leaf.scaleBy(x: 1, y: 0.4 + 0.6 * abs(sin(t * 1.6 + Double(i))))
                leaf.fill(Path(ellipseIn: CGRect(x: -6, y: -3, width: 12, height: 6)), with: .color(leafColors[i % leafColors.count].opacity(0.85)))
            }
        }
    }

    static func ridgeY(x: CGFloat, width: CGFloat, baseY: CGFloat, amplitude: CGFloat, seed: Int) -> CGFloat {
        let u = Double(x / max(width, 1))
        let s = Double(seed)
        let v = sin(u * 6.1 + s * 1.7) * 0.55 + sin(u * 13.7 + s * 3.1) * 0.3 + sin(u * 29.3 + s * 5.3) * 0.15
        return baseY - amplitude * CGFloat(v)
    }

    static func ridge(width: CGFloat, baseY: CGFloat, amplitude: CGFloat, seed: Int, bottom: CGFloat) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: bottom))
        let steps = 64
        for i in 0...steps {
            let x = width * CGFloat(i) / CGFloat(steps)
            p.addLine(to: CGPoint(x: x, y: ridgeY(x: x, width: width, baseY: baseY, amplitude: amplitude, seed: seed)))
        }
        p.addLine(to: CGPoint(x: width, y: bottom))
        p.closeSubpath()
        return p
    }

    static func drawCloud(_ ctx: GraphicsContext, at c: CGPoint, scale: CGFloat, color: Color) {
        var cloud = Path()
        let puffs: [(CGFloat, CGFloat, CGFloat)] = [(-40, 6, 22), (-15, -8, 28), (15, -4, 24), (40, 8, 18), (0, 10, 22)]
        for (dx, dy, r) in puffs {
            cloud.addEllipse(in: CGRect(x: c.x + (dx - r) * scale, y: c.y + (dy - r) * scale, width: r * 2 * scale, height: r * 2 * scale))
        }
        ctx.fill(cloud, with: .color(color))
    }
}
