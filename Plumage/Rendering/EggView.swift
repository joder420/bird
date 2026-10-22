import SwiftUI

/// Geometry for any egg: elongation (height ÷ width), asymmetry (pointed top vs blunt base)
/// and pointiness (how sharp the ends are).
struct EggGeometry: Hashable {
    var elongation: Double
    var asymmetry: Double
    var pointiness: Double

    init(elongation: Double, asymmetry: Double, pointiness: Double) {
        self.elongation = elongation
        self.asymmetry = asymmetry
        self.pointiness = pointiness
    }

    init(_ kind: EggShapeKind) {
        self.init(elongation: kind.elongation, asymmetry: kind.asymmetry, pointiness: kind.pointiness)
    }

    /// Outline of an egg of height `h`, centred on the origin, pointed end up.
    func path(height h: CGFloat) -> Path {
        let w = h / CGFloat(elongation)
        var p = Path()
        let steps = 120
        for i in 0...steps {
            let th = Double(i) / Double(steps) * 2 * .pi
            let s = sin(th), c = cos(th)
            let y = -Double(h) / 2 * c
            let sign: Double = s < 0 ? -1 : 1
            let x = Double(w) / 2 * sign * pow(abs(s), pointiness) * (1 - asymmetry * c)
            if i == 0 { p.move(to: CGPoint(x: x, y: y)) } else { p.addLine(to: CGPoint(x: x, y: y)) }
        }
        p.closeSubpath()
        return p
    }
}

/// An egg silhouette as a SwiftUI Shape, fitted to its frame.
struct EggShape: Shape {
    var geometry: EggGeometry

    func path(in rect: CGRect) -> Path {
        let h = min(rect.height, rect.width * CGFloat(geometry.elongation))
        return geometry.path(height: h).applying(CGAffineTransform(translationX: rect.midX, y: rect.midY))
    }
}

/// A fully painted egg: ground colour, seeded markings, glossy shading, optional cracks.
struct EggArt: View {
    var geometry: EggGeometry
    var base: RGBA
    var marking: RGBA
    var pattern: EggPattern
    var seed: UInt64 = 1
    /// 0 = intact, 1 = about to hatch.
    var cracks: Double = 0
    var glossy = false
    var showShadow = true

    init(egg: EggInfo, seed: UInt64, cracks: Double = 0, showShadow: Bool = true) {
        self.geometry = EggGeometry(egg.shape)
        self.base = egg.base
        self.marking = egg.marking
        self.pattern = egg.pattern
        self.seed = seed
        self.cracks = cracks
        self.glossy = egg.base.hsb.s > 0.4
        self.showShadow = showShadow
    }

    init(geometry: EggGeometry, base: RGBA, marking: RGBA, pattern: EggPattern, seed: UInt64 = 1, cracks: Double = 0, showShadow: Bool = true) {
        self.geometry = geometry
        self.base = base
        self.marking = marking
        self.pattern = pattern
        self.seed = seed
        self.cracks = cracks
        self.showShadow = showShadow
    }

    var body: some View {
        Canvas { context, size in
            EggPainter.paint(in: context, size: size, geometry: geometry, base: base, marking: marking,
                             pattern: pattern, seed: seed, cracks: cracks, glossy: glossy, showShadow: showShadow)
        }
        .aspectRatio(1 / CGFloat(geometry.elongation) * 1.05, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

enum EggPainter {
    static func paint(in context: GraphicsContext, size: CGSize, geometry: EggGeometry, base: RGBA, marking: RGBA,
                      pattern: EggPattern, seed: UInt64, cracks: Double, glossy: Bool, showShadow: Bool) {
        let h = min(size.height * 0.94, size.width * CGFloat(geometry.elongation) * 0.94)
        let w = h / CGFloat(geometry.elongation)
        var g = context
        g.translateBy(x: size.width / 2, y: size.height / 2 - h * 0.02)
        let outline = geometry.path(height: h)

        if showShadow {
            let shadow = Path(ellipseIn: CGRect(x: -w * 0.42, y: h / 2 - h * 0.035, width: w * 0.84, height: h * 0.07))
            g.fill(shadow, with: .color(.black.opacity(0.16)))
        }

        g.fill(outline, with: .color(base.color))

        var inner = g
        inner.clip(to: outline)
        var rng = SeededRandom(seed: seed)
        let ink = marking.color
        let unit = h / 150

        switch pattern {
        case .plain:
            break
        case .speckled, .capped:
            let count = pattern == .capped ? 110 : 150
            for _ in 0..<count {
                var y = CGFloat(rng.range(-0.5, 0.5)) * h
                if pattern == .capped { y = h / 2 - CGFloat(pow(rng.unit(), 2)) * h * 0.45 }
                else if rng.unit() < 0.4 { y = min(h / 2, y + h * 0.2) }
                let x = CGFloat(rng.range(-0.5, 0.5)) * w
                let r = CGFloat(rng.range(0.6, 2.2)) * unit
                inner.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(ink.opacity(rng.range(0.6, 1))))
            }
        case .spotted:
            for _ in 0..<42 {
                var y = CGFloat(rng.range(-0.5, 0.5)) * h
                if rng.unit() < 0.4 { y = min(h / 2, y + h * 0.2) }
                let x = CGFloat(rng.range(-0.5, 0.5)) * w
                let rx = CGFloat(rng.range(2, 6)) * unit, ry = CGFloat(rng.range(1.5, 4.5)) * unit
                let spot = Path(ellipseIn: CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2))
                    .applying(CGAffineTransform(rotationAngle: CGFloat(rng.range(0, 3))).concatenating(CGAffineTransform(translationX: x, y: y)))
                inner.fill(spot, with: .color(ink.opacity(rng.range(0.7, 1))))
            }
        case .blotched:
            for _ in 0..<16 {
                var y = CGFloat(rng.range(-0.5, 0.5)) * h
                if rng.unit() < 0.5 { y = min(h / 2, y + h * 0.2) }
                let x = CGFloat(rng.range(-0.5, 0.5)) * w
                let rx = CGFloat(rng.range(5, 14)) * unit, ry = CGFloat(rng.range(3, 9)) * unit
                let blot = Path(ellipseIn: CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2))
                    .applying(CGAffineTransform(rotationAngle: CGFloat(rng.range(0, 3))).concatenating(CGAffineTransform(translationX: x, y: y)))
                inner.fill(blot, with: .color(ink.opacity(rng.range(0.55, 0.95))))
            }
        case .scrawled:
            for _ in 0..<12 {
                let x = CGFloat(rng.range(-0.5, 0.5)) * w
                let y = CGFloat(rng.range(-0.45, 0.5)) * h
                var scrawl = Path()
                scrawl.move(to: CGPoint(x: x, y: y))
                scrawl.addCurve(to: CGPoint(x: x + CGFloat(rng.range(-12, 12)) * unit, y: y + CGFloat(rng.range(-5, 5)) * unit),
                                control1: CGPoint(x: x + CGFloat(rng.range(-10, 10)) * unit, y: y + CGFloat(rng.range(-10, 10)) * unit),
                                control2: CGPoint(x: x + CGFloat(rng.range(-15, 15)) * unit, y: y + CGFloat(rng.range(-10, 10)) * unit))
                inner.stroke(scrawl, with: .color(ink), style: StrokeStyle(lineWidth: CGFloat(rng.range(1, 3)) * unit, lineCap: .round))
            }
            for _ in 0..<30 {
                let x = CGFloat(rng.range(-0.5, 0.5)) * w, y = CGFloat(rng.range(-0.3, 0.5)) * h
                let r = CGFloat(rng.range(0.8, 2.2)) * unit
                inner.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(ink))
            }
        case .streaked:
            for _ in 0..<26 {
                let x = CGFloat(rng.range(-0.5, 0.5)) * w
                let y = CGFloat(rng.range(-0.4, 0.5)) * h
                var streak = Path()
                streak.move(to: CGPoint(x: x, y: y))
                streak.addQuadCurve(to: CGPoint(x: x + CGFloat(rng.range(-4, 4)) * unit, y: y + CGFloat(rng.range(6, 14)) * unit),
                                    control: CGPoint(x: x + CGFloat(rng.range(-6, 6)) * unit, y: y + 5 * unit))
                inner.stroke(streak, with: .color(ink.opacity(0.85)), style: StrokeStyle(lineWidth: CGFloat(rng.range(1, 2.6)) * unit, lineCap: .round))
            }
        }

        // Soft 3D shading with a specular highlight.
        let highlight = glossy ? 0.75 : 0.5
        inner.fill(Path(CGRect(x: -w, y: -h, width: w * 2, height: h * 2)),
                   with: .radialGradient(Gradient(stops: [
                       .init(color: .white.opacity(highlight), location: 0),
                       .init(color: .white.opacity(0), location: 0.35),
                       .init(color: .black.opacity(0.28), location: 1)
                   ]), center: CGPoint(x: -w * 0.18, y: -h * 0.2), startRadius: 2, endRadius: h * 0.62))
        if glossy {
            inner.fill(Path(ellipseIn: CGRect(x: -w * 0.28, y: -h * 0.32, width: w * 0.16, height: h * 0.1)), with: .color(.white.opacity(0.6)))
        }

        if cracks > 0.05 {
            drawCracks(inner, w: w, h: h, amount: cracks, seed: seed)
        }

        g.stroke(outline, with: .color(.black.opacity(0.22)), lineWidth: max(1, h / 150))
    }

    private static func drawCracks(_ g: GraphicsContext, w: CGFloat, h: CGFloat, amount: Double, seed: UInt64) {
        var rng = SeededRandom(seed: seed &+ 99)
        let lines = Int(1 + amount * 5)
        var crack = Path()
        for i in 0..<lines {
            var x = CGFloat(rng.range(-0.3, 0.3)) * w
            var y = -h * 0.1 + CGFloat(i) * h * 0.04
            crack.move(to: CGPoint(x: x, y: y))
            let segments = Int(3 + amount * 6)
            for _ in 0..<segments {
                x += CGFloat(rng.range(4, 10)) * (rng.unit() < 0.5 ? -1 : 1) * h / 150
                y += CGFloat(rng.range(-6, 6)) * h / 150
                crack.addLine(to: CGPoint(x: x, y: y))
            }
        }
        g.stroke(crack, with: .color(.black.opacity(0.7)), style: StrokeStyle(lineWidth: max(1, h / 110), lineCap: .round, lineJoin: .miter))
        g.stroke(crack.applying(CGAffineTransform(translationX: 0.8, y: 0.8)), with: .color(.white.opacity(0.5)), lineWidth: max(0.6, h / 220))
    }
}

/// A row of small eggs representing a typical clutch.
struct ClutchView: View {
    var egg: EggInfo
    var count: Int
    var seed: UInt64

    var body: some View {
        HStack(spacing: -6) {
            ForEach(0..<max(1, min(count, 12)), id: \.self) { i in
                EggArt(egg: egg, seed: seed &+ UInt64(i), showShadow: false)
                    .frame(height: 34)
                    .rotationEffect(.degrees(Double(i % 3) * 8 - 8))
            }
        }
    }
}
