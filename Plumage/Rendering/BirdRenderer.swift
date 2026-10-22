import SwiftUI

// MARK: - Geometry helpers

fileprivate func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

fileprivate func rotated(_ p: CGPoint, _ angle: CGFloat) -> CGPoint {
    let c = cos(angle), s = sin(angle)
    return CGPoint(x: p.x * c - p.y * s, y: p.x * s + p.y * c)
}

fileprivate func offset(_ a: CGPoint, _ b: CGPoint) -> CGPoint { CGPoint(x: a.x + b.x, y: a.y + b.y) }

fileprivate func ellipse(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat, rotation: CGFloat = 0) -> Path {
    let base = Path(ellipseIn: CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2))
    let transform = CGAffineTransform(rotationAngle: rotation).concatenating(CGAffineTransform(translationX: cx, y: cy))
    return base.applying(transform)
}

fileprivate func circle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) -> Path { ellipse(cx, cy, r, r) }

/// Samples an arc as a polyline (angles in radians, y-down coordinates).
fileprivate func arcPoints(radius: CGFloat, from a0: CGFloat, to a1: CGFloat, steps: Int = 24) -> [CGPoint] {
    (0...steps).map { i in
        let a = a0 + (a1 - a0) * CGFloat(i) / CGFloat(steps)
        return CGPoint(x: cos(a) * radius, y: sin(a) * radius)
    }
}

fileprivate let deg: CGFloat = .pi / 180

// MARK: - Pose

/// Per-frame animation state for a bird.
struct BirdPose {
    var time: Double = 1
    var flap: Double = 0
    var beakOpen: Double = 0
    var blink: Double = 0
    var headBob: Double = 0
    var tailWag: Double = 0
    var breathe: Double = 1
    var showPerch = true

    static func make(time t: Double, singing: Bool, flapping: Bool, showPerch: Bool, animated: Bool) -> BirdPose {
        var p = BirdPose()
        p.time = t
        p.showPerch = showPerch
        guard animated else { return p }
        p.breathe = 1 + 0.015 * sin(t * 2)
        p.headBob = 4 * sin(t * 0.7)
        p.tailWag = 3 * sin(t * 1.3)
        let blinkPhase = t.truncatingRemainder(dividingBy: 3.7)
        if blinkPhase < 0.14 { p.blink = sin(blinkPhase / 0.14 * .pi) }
        if singing {
            p.beakOpen = 14 * abs(sin(t * 14))
            p.headBob += 6 * sin(t * 3)
        }
        if flapping {
            p.flap = 20 + 75 * abs(sin(t * 9))
        } else {
            let cycle = t.truncatingRemainder(dividingBy: 7.3)
            if cycle < 0.6 { p.flap = 55 * abs(sin(cycle * 16)) }
        }
        return p
    }
}

// MARK: - Renderer

/// Draws a fully procedural bird from a `BirdAppearance` into a SwiftUI `GraphicsContext`.
/// The model is drawn facing right with the body centred on the origin, then fitted to the canvas.
enum BirdRenderer {
    struct Layout {
        var L: CGFloat
        var T: CGFloat
        var tilt: CGFloat
        var breathe: CGFloat
        var R: CGFloat
        var neckBase: CGPoint
        var head: CGPoint
        var tailRoot: CGPoint
        var tailDir: CGFloat
        var shoulder: CGPoint
        var hips: [CGPoint]
        var groundY: CGFloat
        var waterY: CGFloat
    }

    static func layout(_ a: BirdAppearance, pose: BirdPose) -> Layout {
        let L: CGFloat = 75 * CGFloat(a.bodyLength)
        let T: CGFloat = 52 * CGFloat(a.plumpness)
        let tilt = CGFloat(a.bodyTilt) * deg
        let breathe = CGFloat(pose.breathe)
        func world(_ p: CGPoint) -> CGPoint { rotated(CGPoint(x: p.x, y: p.y * breathe), tilt) }
        let R: CGFloat = 34 * CGFloat(a.headSize)
        let neckBase = world(pt(L * 0.62, -T * 0.32))
        let neckDir = CGFloat(-80 + a.neckLean) * deg
        let neckLen = CGFloat(a.neckLength) * 60 + R * 0.35
        let head = offset(neckBase, pt(cos(neckDir) * neckLen, sin(neckDir) * neckLen))
        let tailRoot = world(pt(-L * 0.88, -T * 0.05))
        let tailDir = tilt + .pi + CGFloat(a.tailAngle + pose.tailWag) * deg
        let shoulder = world(pt(L * 0.3, -T * 0.3))
        let hips = [world(pt(L * 0.08, T * 0.8)), world(pt(-L * 0.1, T * 0.78))]
        let lowest = max(hips[0].y, hips[1].y)
        let groundY = lowest + CGFloat(a.legLength) * 45 + 6
        let waterY = hips[0].y - T * 0.55
        return Layout(L: L, T: T, tilt: tilt, breathe: breathe, R: R, neckBase: neckBase, head: head, tailRoot: tailRoot,
                      tailDir: tailDir, shoulder: shoulder, hips: hips, groundY: groundY, waterY: waterY)
    }

    /// Model-space bounding box of the whole bird, used to fit it to any canvas.
    static func bounds(_ a: BirdAppearance, _ lay: Layout, showPerch: Bool) -> CGRect {
        var pts: [CGPoint] = []
        let bodyR = max(lay.L, lay.T)
        pts.append(pt(-bodyR, -bodyR))
        pts.append(pt(bodyR, bodyR))
        let crestExtra: CGFloat = a.crest == .none ? 0 : 0.7 * CGFloat(a.crestSize)
        pts.append(pt(lay.head.x - lay.R * 1.4, lay.head.y - lay.R * (1.2 + crestExtra)))
        let reach = CGFloat(a.beakShape.reach * a.beakLength)
        pts.append(pt(lay.head.x + lay.R * (0.85 + reach), lay.head.y + lay.R))
        let tl = CGFloat(a.tailStyle.baseLength * a.tailLength)
        pts.append(offset(lay.tailRoot, pt(cos(lay.tailDir) * tl, sin(lay.tailDir) * tl)))
        if a.perch == .water {
            pts.append(pt(0, lay.waterY + 20))
        } else {
            pts.append(pt(0, lay.groundY + (showPerch && a.perch != .none ? 14 : 4)))
        }
        let xs = pts.map(\.x), ys = pts.map(\.y)
        let minX = xs.min() ?? 0, maxX = xs.max() ?? 0, minY = ys.min() ?? 0, maxY = ys.max() ?? 0
        return CGRect(x: minX, y: minY, width: max(maxX - minX, 1), height: max(maxY - minY, 1))
    }

    /// Draws the bird scaled to fit `size`.
    static func draw(_ a: BirdAppearance, pose: BirdPose, in context: GraphicsContext, size: CGSize, padding: CGFloat = 12) {
        let lay = layout(a, pose: pose)
        let box = bounds(a, lay, showPerch: pose.showPerch)
        let availableW = max(size.width - padding * 2, 1)
        let availableH = max(size.height - padding * 2, 1)
        let scale = min(availableW / box.width, availableH / box.height)

        var g = context
        g.translateBy(x: size.width / 2, y: size.height / 2)
        g.scaleBy(x: scale, y: scale)
        g.translateBy(x: -box.midX, y: -box.midY)

        let flap = CGFloat(pose.flap)
        if pose.showPerch { drawPerch(g, a, lay, front: false, time: pose.time) }
        if flap > 5 { drawWing(g, a, lay, flap: flap, far: true) }
        drawTail(g, a, lay, time: pose.time)
        drawLegs(g, a, lay)
        drawNeck(g, a, lay)
        drawBody(g, a, lay)
        drawWing(g, a, lay, flap: flap, far: false)
        drawHead(g, a, lay, pose: pose)
        if pose.showPerch { drawPerch(g, a, lay, front: true, time: pose.time) }
    }

    // MARK: Body

    static func bodyPath(_ L: CGFloat, _ T: CGFloat) -> Path {
        var p = Path()
        p.move(to: pt(L, 0))
        p.addCurve(to: pt(0, T), control1: pt(L, T * 0.75), control2: pt(L * 0.5, T))
        p.addCurve(to: pt(-L, -T * 0.05), control1: pt(-L * 0.55, T), control2: pt(-L * 0.88, T * 0.4))
        p.addCurve(to: pt(0, -T), control1: pt(-L * 0.85, -T * 0.5), control2: pt(-L * 0.5, -T))
        p.addCurve(to: pt(L, 0), control1: pt(L * 0.55, -T), control2: pt(L, -T * 0.7))
        p.closeSubpath()
        return p
    }

    private static func drawBody(_ ctx: GraphicsContext, _ a: BirdAppearance, _ lay: Layout) {
        var g = ctx
        g.rotate(by: .radians(Double(lay.tilt)))
        g.scaleBy(x: 1, y: lay.breathe)
        let L = lay.L, T = lay.T
        let body = bodyPath(L, T)
        g.fill(body, with: .linearGradient(Gradient(colors: [a.body.shaded(0.1).color, a.body.shaded(-0.15).color]),
                                           startPoint: pt(0, -T), endPoint: pt(0, T)))
        var inner = g
        inner.clip(to: body)
        let bellyCenter = pt(L * 0.18, T * 0.42)
        inner.fill(ellipse(bellyCenter.x, bellyCenter.y, L * 0.78, T * 0.62, rotation: -0.05),
                   with: .radialGradient(Gradient(colors: [a.belly.shaded(0.1).color, a.belly.color]),
                                         center: pt(L * 0.25, T * 0.45), startRadius: 4, endRadius: L * 0.8))
        if a.bellyPattern != .none {
            var rng = SeededRandom(seed: 11)
            let color = a.bellyPatternColor.color
            for _ in 0..<26 {
                let x = L * CGFloat(rng.range(-0.3, 0.8))
                let y = T * CGFloat(rng.range(0.05, 0.85))
                switch a.bellyPattern {
                case .spots:
                    inner.fill(circle(x, y, 2.6), with: .color(color))
                case .streaks:
                    inner.fill(ellipse(x, y, 1.6, 5, rotation: 0.2), with: .color(color))
                case .bars:
                    var bar = Path()
                    bar.move(to: pt(x - 5, y))
                    bar.addLine(to: pt(x + 5, y + 1))
                    inner.stroke(bar, with: .color(color), lineWidth: 1.6)
                case .none:
                    break
                }
            }
        }
        g.stroke(body, with: .color(a.body.shaded(-0.35).color), lineWidth: 1.5)
    }

    private static func drawNeck(_ ctx: GraphicsContext, _ a: BirdAppearance, _ lay: Layout) {
        guard a.neckLength > 0.12 else { return }
        var neck = Path()
        let mid = pt((lay.neckBase.x + lay.head.x) / 2 - 14 * CGFloat(a.neckCurve), (lay.neckBase.y + lay.head.y) / 2)
        neck.move(to: lay.neckBase)
        neck.addQuadCurve(to: lay.head, control: mid)
        ctx.stroke(neck, with: .color(a.neck.shaded(-0.25).color), style: StrokeStyle(lineWidth: lay.R * 1.05 + 2, lineCap: .round))
        ctx.stroke(neck, with: .color(a.neck.color), style: StrokeStyle(lineWidth: lay.R * 1.05, lineCap: .round))
    }

    // MARK: Wing

    private static func drawWing(_ ctx: GraphicsContext, _ a: BirdAppearance, _ lay: Layout, flap: CGFloat, far: Bool) {
        var g = ctx
        g.translateBy(x: lay.shoulder.x, y: lay.shoulder.y)
        let angle = lay.tilt + .pi + 4 * deg + flap * (far ? 1.15 : 1) * deg
        g.rotate(by: .radians(Double(angle)))
        let len = lay.L * 1.35 * CGFloat(a.wingLength)
        let W = lay.T * 0.78
        let base = far ? a.wing.shaded(-0.35) : a.wing

        var wing = Path()
        wing.move(to: pt(-6, -W * 0.3))
        wing.addCurve(to: pt(len, W * 0.05), control1: pt(len * 0.3, -W * 0.55), control2: pt(len * 0.75, -W * 0.25))
        wing.addCurve(to: pt(0, W * 0.5), control1: pt(len * 0.7, W * 0.42), control2: pt(len * 0.3, W * 0.62))
        wing.addQuadCurve(to: pt(-6, -W * 0.3), control: pt(-W * 0.32, W * 0.1))
        wing.closeSubpath()

        g.fill(wing, with: .linearGradient(Gradient(colors: [base.shaded(0.12).color, base.shaded(-0.12).color]),
                                           startPoint: pt(0, -W * 0.5), endPoint: pt(0, W * 0.6)))
        var inner = g
        inner.clip(to: wing)
        let tip = far ? a.wingTip.shaded(-0.35) : a.wingTip
        inner.fill(Path(CGRect(x: len * 0.6, y: -W, width: len, height: W * 2)), with: .color(tip.color))
        var quills = Path()
        for i in 0..<4 {
            let x = len * (0.62 + CGFloat(i) * 0.09)
            quills.move(to: pt(x, -W * 0.25 + CGFloat(i) * 3))
            quills.addLine(to: pt(x + len * 0.12, W * 0.5))
        }
        inner.stroke(quills, with: .color(a.wingTip.shaded(-0.4).color), lineWidth: 1)

        if !far {
            let pc = a.wingPatternColor.color
            switch a.wingPattern {
            case .bars:
                for u: CGFloat in [0.22, 0.4] {
                    inner.fill(ellipse(len * u, W * 0.1, 4, W * 0.6, rotation: -0.25), with: .color(pc.opacity(0.9)))
                }
            case .spots:
                var rng = SeededRandom(seed: 3)
                for _ in 0..<16 {
                    inner.fill(circle(len * CGFloat(rng.range(0.05, 0.6)), W * CGFloat(rng.range(-0.25, 0.5)), 2.4), with: .color(pc))
                }
            case .scallop:
                var scallops = Path()
                for row in 0..<3 {
                    for i in 0..<5 {
                        let cx = len * (0.06 + CGFloat(i) * 0.11 + CGFloat(row) * 0.04)
                        let cy = W * (-0.15 + CGFloat(row) * 0.22)
                        let arc = arcPoints(radius: 6, from: 0.2, to: .pi - 0.2, steps: 8)
                        scallops.move(to: offset(arc[0], pt(cx, cy)))
                        for p in arc.dropFirst() { scallops.addLine(to: offset(p, pt(cx, cy))) }
                    }
                }
                inner.stroke(scallops, with: .color(pc.opacity(0.8)), lineWidth: 1.4)
            case .stripes:
                var stripes = Path()
                for i in 0..<6 {
                    stripes.move(to: pt(len * (0.08 + CGFloat(i) * 0.09), -W * 0.4))
                    stripes.addLine(to: pt(len * (0.02 + CGFloat(i) * 0.09), W * 0.6))
                }
                inner.stroke(stripes, with: .color(pc.opacity(0.85)), lineWidth: 2.2)
            case .none:
                break
            }
        }
        g.stroke(wing, with: .color(base.shaded(-0.35).color), lineWidth: 1.5)
    }

    // MARK: Tail

    private static func drawTail(_ ctx: GraphicsContext, _ a: BirdAppearance, _ lay: Layout, time: Double) {
        var g = ctx
        g.translateBy(x: lay.tailRoot.x, y: lay.tailRoot.y)
        g.rotate(by: .radians(Double(lay.tailDir)))
        let tl = CGFloat(a.tailLength)
        let w: CGFloat = 14 * CGFloat(a.plumpness)
        let fill = a.tail.color
        let edge = a.tail.shaded(-0.3).color
        var p = Path()

        switch a.tailStyle {
        case .short:
            let l = 34 * tl
            p.move(to: pt(-6, -w))
            p.addQuadCurve(to: pt(l, -w * 0.4), control: pt(l * 0.7, -w * 1.1))
            p.addQuadCurve(to: pt(l, w * 0.4), control: pt(l * 1.08, 0))
            p.addQuadCurve(to: pt(-6, w), control: pt(l * 0.7, w * 1.1))
        case .fan:
            let l = 55 * tl
            p.move(to: pt(-6, -w * 0.8))
            p.addLine(to: pt(l, -w * 1.9))
            p.addQuadCurve(to: pt(l, w * 1.9), control: pt(l * 1.15, 0))
            p.addLine(to: pt(-6, w * 0.8))
        case .forked:
            let l = 70 * tl
            p.move(to: pt(-6, -w * 0.7))
            p.addLine(to: pt(l, -w * 1.1))
            p.addLine(to: pt(l * 0.45, 0))
            p.addLine(to: pt(l, w * 1.1))
            p.addLine(to: pt(-6, w * 0.7))
        case .long:
            let l = 100 * tl
            p.move(to: pt(-6, -w * 0.8))
            p.addQuadCurve(to: pt(l, -w * 0.5), control: pt(l * 0.5, -w * 0.9))
            p.addQuadCurve(to: pt(l, w * 0.5), control: pt(l * 1.06, 0))
            p.addQuadCurve(to: pt(-6, w * 0.8), control: pt(l * 0.5, w * 0.9))
        case .pointed:
            let l = 62 * tl
            p.move(to: pt(-6, -w * 0.9))
            p.addQuadCurve(to: pt(l, 0), control: pt(l * 0.4, -w * 0.8))
            p.addQuadCurve(to: pt(-6, w * 0.9), control: pt(l * 0.4, w * 0.8))
        case .streamers:
            let l = 40 * tl
            p.move(to: pt(-6, -w * 0.8))
            p.addLine(to: pt(l, -w * 0.6))
            p.addLine(to: pt(l, w * 0.6))
            p.addLine(to: pt(-6, w * 0.8))
            p.closeSubpath()
            g.fill(p, with: .color(fill))
            g.stroke(p, with: .color(edge), lineWidth: 1.5)
            let s = CGFloat(3 * sin(time * 2))
            var streamers = Path()
            streamers.move(to: pt(l * 0.8, -2))
            streamers.addCurve(to: pt(l * 3.2, 4 + s), control1: pt(l * 1.6, -6), control2: pt(l * 2.4, 8 + s))
            streamers.move(to: pt(l * 0.8, 2))
            streamers.addCurve(to: pt(l * 3.0, 14 + s), control1: pt(l * 1.6, 4), control2: pt(l * 2.4, 16 + s))
            g.stroke(streamers, with: .color(fill), style: StrokeStyle(lineWidth: 4, lineCap: .round))
            return
        case .train:
            let l = 150 * tl
            p.move(to: pt(-6, -w))
            p.addCurve(to: pt(l, w * 0.8), control1: pt(l * 0.4, -w * 2.4), control2: pt(l * 0.85, -w * 1.4))
            p.addCurve(to: pt(-6, w), control1: pt(l * 0.9, w * 3.4), control2: pt(l * 0.4, w * 3.0))
            p.closeSubpath()
            g.fill(p, with: .linearGradient(Gradient(colors: [a.tail.shaded(0.1).color, a.tail.shaded(-0.2).color]),
                                            startPoint: .zero, endPoint: pt(l, 0)))
            var inner = g
            inner.clip(to: p)
            var shafts = Path()
            for i in 0..<14 {
                let v = -w * 1.2 + CGFloat(i) * w * 0.32
                shafts.move(to: pt(0, w * 0.2))
                shafts.addLine(to: pt(l, v + w * 0.8))
            }
            inner.stroke(shafts, with: .color(a.tail.shaded(-0.3).color.opacity(0.6)), lineWidth: 0.8)
            var rng = SeededRandom(seed: 7)
            for _ in 0..<38 {
                let u = CGFloat(rng.range(0.22, 0.98))
                let spread = w * (1.2 + 1.9 * u)
                let y = CGFloat(rng.range(-0.55, 0.85)) * spread + w * 0.5 * u
                let x = l * u
                let size = 3.5 + 3.5 * u
                inner.fill(ellipse(x, y, size * 1.25, size), with: .color(a.accent.color))
                inner.fill(ellipse(x, y, size * 0.75, size * 0.6), with: .color(a.accent2.color))
                inner.fill(ellipse(x + 0.6, y, size * 0.38, size * 0.32), with: .color(Color(hex: 0x10204A)))
            }
            g.stroke(p, with: .color(edge), lineWidth: 1.2)
            return
        case .lyre:
            let l = 110 * tl
            p.move(to: pt(-6, -w * 0.8))
            p.addQuadCurve(to: pt(l, -w * 1.2), control: pt(l * 0.5, -w * 1.4))
            p.addQuadCurve(to: pt(l, w * 1.2), control: pt(l * 0.5, 0))
            p.addQuadCurve(to: pt(-6, w * 0.8), control: pt(l * 0.5, w * 1.4))
            p.closeSubpath()
            g.fill(p, with: .color(fill.opacity(0.85)))
            var filaments = Path()
            for i in 0..<9 {
                let v = -w * 1.1 + CGFloat(i) * w * 0.27
                filaments.move(to: pt(0, 0))
                filaments.addQuadCurve(to: pt(l * 1.05, v), control: pt(l * 0.5, v * 0.3))
            }
            g.stroke(filaments, with: .color(a.tail.shaded(0.35).color.opacity(0.7)), lineWidth: 0.8)
            var lyre = Path()
            lyre.move(to: pt(0, -w * 0.6))
            lyre.addCurve(to: pt(l * 1.2, -w * 2.6), control1: pt(l * 0.5, -w * 3.5), control2: pt(l * 0.9, -w * 0.5))
            lyre.move(to: pt(0, w * 0.6))
            lyre.addCurve(to: pt(l * 1.2, w * 2.6), control1: pt(l * 0.5, w * 3.5), control2: pt(l * 0.9, w * 0.5))
            g.stroke(lyre, with: .color(a.accent.shaded(-0.3).color), style: StrokeStyle(lineWidth: 7, lineCap: .round))
            g.stroke(lyre, with: .color(a.accent.color), style: StrokeStyle(lineWidth: 5, lineCap: .round, dash: [6, 4]))
            return
        }
        p.closeSubpath()
        g.fill(p, with: .color(fill))
        var inner = g
        inner.clip(to: p)
        var feathers = Path()
        for i in -1...1 {
            feathers.move(to: pt(4, CGFloat(i) * w * 0.4))
            feathers.addLine(to: pt(120 * tl, CGFloat(i) * w * 1.2))
        }
        inner.stroke(feathers, with: .color(a.tail.shaded(-0.18).color), lineWidth: 1)
        g.stroke(p, with: .color(edge), lineWidth: 1.5)
    }

    // MARK: Legs & perch

    private static func drawLegs(_ ctx: GraphicsContext, _ a: BirdAppearance, _ lay: Layout) {
        guard a.perch != .water else { return }
        let color = a.legs.color
        let width = 3.2 + CGFloat(a.legLength) * 0.8 + CGFloat(a.plumpness - 1) * 2
        for (i, hip) in lay.hips.enumerated() {
            let footX = hip.x + (i == 0 ? 4 : -2)
            let knee = pt((hip.x + footX) / 2 - 10 * min(CGFloat(a.legLength), 1.5), (hip.y + lay.groundY) / 2)
            var leg = Path()
            leg.move(to: hip)
            leg.addLine(to: knee)
            leg.addLine(to: pt(footX, lay.groundY))
            ctx.stroke(leg, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
            var toes = Path()
            let y = lay.groundY
            toes.move(to: pt(footX, y)); toes.addLine(to: pt(footX + 14, y + 1))
            toes.move(to: pt(footX, y)); toes.addLine(to: pt(footX + 11, y + 4))
            toes.move(to: pt(footX, y)); toes.addLine(to: pt(footX - 9, y + 2))
            ctx.stroke(toes, with: .color(color), style: StrokeStyle(lineWidth: width * 0.7, lineCap: .round))
        }
    }

    private static func drawPerch(_ ctx: GraphicsContext, _ a: BirdAppearance, _ lay: Layout, front: Bool, time: Double) {
        let y = lay.groundY + 4
        switch a.perch {
        case .branch where !front:
            var branch = Path()
            branch.move(to: pt(-190, y - 4))
            branch.addQuadCurve(to: pt(190, y + 2), control: pt(0, y - 10))
            branch.addLine(to: pt(190, y + 14))
            branch.addQuadCurve(to: pt(-190, y + 10), control: pt(0, y + 6))
            branch.closeSubpath()
            ctx.fill(branch, with: .linearGradient(Gradient(colors: [Color(hex: 0x7D5A3E), Color(hex: 0x5A3F2B)]),
                                                   startPoint: pt(0, y - 8), endPoint: pt(0, y + 14)))
            ctx.stroke(branch, with: .color(Color(hex: 0x4A3222)), lineWidth: 2)
            var bark = Path()
            var x: CGFloat = -170
            while x < 180 {
                bark.move(to: pt(x, y))
                bark.addLine(to: pt(x + 18, y + 2))
                x += 37
            }
            ctx.stroke(bark, with: .color(Color(hex: 0x8A6A4A)), lineWidth: 1)
            for (lx, ang) in [(CGFloat(-140), CGFloat(-0.9)), (120, -2.1), (160, 0.4), (-100, 2.6)] {
                var leaf = ctx
                leaf.translateBy(x: lx, y: y)
                leaf.rotate(by: .radians(Double(ang + CGFloat(0.06 * sin(time * 1.4 + Double(lx))))))
                leaf.fill(ellipse(16, 0, 16, 6), with: .color(Color(hex: 0x5B8C3E)))
                var vein = Path()
                vein.move(to: .zero)
                vein.addLine(to: pt(30, 0))
                leaf.stroke(vein, with: .color(Color(hex: 0x3D6B2A)), lineWidth: 1)
            }
        case .ground where !front, .ice where !front, .rock where !front:
            let color: Color
            switch a.perch {
            case .ice: color = Color(hex: 0xDFF3FB)
            case .rock: color = Color(hex: 0x8D8D86)
            default: color = Color(hex: 0x7AA356)
            }
            ctx.fill(ellipse(0, y + 10, 160, 18), with: .color(color))
            if a.perch == .ice {
                ctx.fill(ellipse(-30, y + 6, 70, 6), with: .color(.white.opacity(0.7)))
            }
            if a.perch == .rock {
                ctx.fill(ellipse(-40, y + 4, 60, 8), with: .color(Color(hex: 0xA3A39B)))
            }
            ctx.fill(ellipse(0, y + 2, 60, 6), with: .color(.black.opacity(0.15)))
            if a.perch == .ground {
                var grass = Path()
                for gx: CGFloat in [-120, -90, 80, 110, 130] {
                    let sway = CGFloat(2 * sin(time * 1.5 + Double(gx)))
                    grass.move(to: pt(gx, y + 8)); grass.addLine(to: pt(gx - 5 + sway, y - 10))
                    grass.move(to: pt(gx, y + 8)); grass.addLine(to: pt(gx + 4 + sway, y - 12))
                }
                ctx.stroke(grass, with: .color(Color(hex: 0x4F7A35)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            }
        case .water where front:
            let wy = lay.waterY
            var water = Path()
            water.move(to: pt(-220, wy))
            var x: CGFloat = -220
            let drift = CGFloat((time * 12).truncatingRemainder(dividingBy: 20))
            while x <= 220 {
                water.addQuadCurve(to: pt(x + 10, wy), control: pt(x + 5, wy - 3))
                x += 10
            }
            water.addLine(to: pt(220, wy + 90))
            water.addLine(to: pt(-220, wy + 90))
            water.closeSubpath()
            ctx.fill(water, with: .linearGradient(Gradient(colors: [Color(hex: 0x5AA0C8, opacity: 0.55), Color(hex: 0x2E6E96, opacity: 0.75)]),
                                                  startPoint: pt(0, wy), endPoint: pt(0, wy + 90)))
            var glints = Path()
            glints.move(to: pt(-80 + drift, wy + 10)); glints.addLine(to: pt(-40 + drift, wy + 10))
            glints.move(to: pt(30 - drift, wy + 18)); glints.addLine(to: pt(80 - drift, wy + 18))
            glints.move(to: pt(-150 + drift, wy + 26)); glints.addLine(to: pt(-110 + drift, wy + 26))
            ctx.stroke(glints, with: .color(.white.opacity(0.6)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        default:
            break
        }
    }

    // MARK: Head

    private static func drawHead(_ ctx: GraphicsContext, _ a: BirdAppearance, _ lay: Layout, pose: BirdPose) {
        let R = lay.R
        var g = ctx
        g.translateBy(x: lay.head.x, y: lay.head.y)
        g.rotate(by: .degrees(pose.headBob + a.headTilt))
        drawCrest(g, a, R, time: pose.time)
        let headCircle = circle(0, 0, R)
        g.fill(headCircle, with: .radialGradient(Gradient(colors: [a.head.shaded(0.18).color, a.head.shaded(-0.12).color]),
                                                 center: pt(-R * 0.2, -R * 0.35), startRadius: R * 0.1, endRadius: R * 1.05))
        var face = g
        face.clip(to: headCircle)
        drawMarkings(face, a, R, overEye: false)
        drawBeak(g, a, R, open: CGFloat(pose.beakOpen))
        drawEye(g, a, R, blink: CGFloat(pose.blink))
    }

    private static func drawCrest(_ g: GraphicsContext, _ a: BirdAppearance, _ R: CGFloat, time: Double) {
        guard a.crest != .none else { return }
        let s = CGFloat(a.crestSize)
        let sway = CGFloat(2 * sin(time * 1.7))
        let fill = a.crestColor.color
        let edge = a.crestColor.shaded(-0.3).color
        switch a.crest {
        case .none:
            return
        case .pointed:
            var p = Path()
            p.move(to: pt(R * 0.35, -R * 0.82))
            p.addQuadCurve(to: pt(-R * (0.75 + 0.35 * s) + sway, -R * (1.25 + 0.55 * s)), control: pt(-R * 0.1, -R * (1.2 + 0.4 * s)))
            p.addQuadCurve(to: pt(-R * 0.78, -R * 0.45), control: pt(-R * 0.5, -R * 0.9))
            p.addLine(to: pt(R * 0.1, -R * 0.5))
            p.closeSubpath()
            g.fill(p, with: .color(fill))
            g.stroke(p, with: .color(edge), lineWidth: 1.2)
        case .tufts:
            for (x, dx) in [(-R * 0.35, CGFloat(-0.5)), (R * 0.15, CGFloat(-0.15))] {
                var p = Path()
                p.move(to: pt(x - R * 0.2, -R * 0.75))
                p.addLine(to: pt(x + dx * R * s + sway * 0.3, -R * (1.25 + 0.3 * s)))
                p.addLine(to: pt(x + R * 0.18, -R * 0.82))
                p.closeSubpath()
                g.fill(p, with: .color(fill))
                g.stroke(p, with: .color(edge), lineWidth: 1.2)
            }
        case .fan:
            for i in 0..<7 {
                var f = g
                f.translateBy(x: -R * 0.15, y: -R * 0.6)
                f.rotate(by: .radians(Double((-150 + CGFloat(i) * 17) * deg + sway * 0.01)))
                let feather = ellipse(R * 0.65 * s, 0, R * 0.7 * s, R * 0.13)
                f.fill(feather, with: .color(fill))
                f.stroke(feather, with: .color(edge), lineWidth: 1)
                if a.crestTip != a.crestColor {
                    f.fill(ellipse(R * 1.15 * s, 0, R * 0.2 * s, R * 0.11), with: .color(a.crestTip.color))
                }
            }
        case .plumes:
            for i in 0..<5 {
                let ang = (-118 + CGFloat(i) * 9) * deg
                let tip = pt(cos(ang) * R * s + sway * 0.4, sin(ang) * R * s - R * 0.75)
                var stalk = Path()
                stalk.move(to: pt(0, -R * 0.85))
                stalk.addLine(to: tip)
                g.stroke(stalk, with: .color(a.crestColor.shaded(-0.2).color), lineWidth: 1.5)
                g.fill(ellipse(tip.x, tip.y, R * 0.14, R * 0.1, rotation: ang), with: .color(fill))
            }
        case .crown:
            var bristles = Path()
            for i in 0..<22 {
                let ang = (-160 + CGFloat(i) * 6.5) * deg
                let len = R * (0.75 + 0.35 * sin(CGFloat(i) * 1.7)) * s
                bristles.move(to: pt(-R * 0.1, -R * 0.8))
                bristles.addLine(to: pt(-R * 0.1 + cos(ang) * len + sway * 0.3, -R * 0.8 + sin(ang) * len))
            }
            g.stroke(bristles, with: .color(fill), lineWidth: 1.6)
        case .curl:
            var curl = Path()
            curl.move(to: pt(R * 0.1, -R * 0.9))
            curl.addCurve(to: pt(R * 0.75 * s + sway * 0.3, -R * 1.25 * s), control1: pt(R * 0.2, -R * 1.6 * s), control2: pt(R * 0.9 * s, -R * 1.7 * s))
            g.stroke(curl, with: .color(fill), style: StrokeStyle(lineWidth: R * 0.16, lineCap: .round))
        }
    }

    private static func drawMarkings(_ g: GraphicsContext, _ a: BirdAppearance, _ R: CGFloat, overEye: Bool) {
        for m in a.markings where m.kind.isOverEye == overEye {
            let c = m.color.color
            switch m.kind {
            case .mask:
                var p = Path()
                p.move(to: pt(R * 0.95, -R * 0.25))
                p.addQuadCurve(to: pt(-R * 0.1, -R * 0.3), control: pt(R * 0.5, -R * 0.42))
                p.addQuadCurve(to: pt(-R * 0.15, R * 0.12), control: pt(-R * 0.35, -R * 0.05))
                p.addQuadCurve(to: pt(R * 0.98, R * 0.45), control: pt(R * 0.4, R * 0.28))
                p.closeSubpath()
                g.fill(p, with: .color(c))
            case .bib:
                var p = Path()
                p.move(to: pt(R * 0.9, R * 0.3))
                p.addQuadCurve(to: pt(-R * 0.1, R * 1.05), control: pt(R * 0.7, R * 1.15))
                p.addQuadCurve(to: pt(R * 0.5, R * 0.3), control: pt(R * 0.2, R * 0.6))
                p.closeSubpath()
                g.fill(p, with: .color(c))
            case .cheek:
                g.fill(ellipse(R * 0.15, R * 0.32, R * 0.32, R * 0.24, rotation: -0.2), with: .color(c))
            case .cap:
                var p = Path()
                let arc = arcPoints(radius: R * 1.005, from: .pi * 1.08, to: .pi * 1.85)
                p.move(to: arc[0])
                for q in arc.dropFirst() { p.addLine(to: q) }
                p.addQuadCurve(to: pt(-R * 0.93, -R * 0.25), control: pt(R * 0.2, -R * 0.45))
                p.closeSubpath()
                g.fill(p, with: .color(c))
            case .stripe:
                var p = Path()
                p.move(to: pt(R * 0.72, -R * 0.42))
                p.addQuadCurve(to: pt(-R * 0.55, -R * 0.25), control: pt(R * 0.2, -R * 0.52))
                g.stroke(p, with: .color(c), style: StrokeStyle(lineWidth: R * 0.11, lineCap: .round))
            case .disc:
                let disc = ellipse(R * 0.3, R * 0.02, R * 0.72, R * 0.86, rotation: 0.1)
                g.fill(disc, with: .color(c))
                g.stroke(disc, with: .color(m.color.shaded(-0.35).color), lineWidth: R * 0.08)
            case .eyeRing:
                let r = R * 0.17 * CGFloat(a.eyeSize) + R * 0.08
                g.fill(circle(R * 0.38, -R * 0.12, r), with: .color(c))
            case .collar:
                var p = Path()
                let arc = arcPoints(radius: R * 0.9, from: .pi * 0.35, to: .pi * 0.85, steps: 16)
                p.move(to: arc[0])
                for q in arc.dropFirst() { p.addLine(to: q) }
                g.stroke(p, with: .color(c), style: StrokeStyle(lineWidth: R * 0.16, lineCap: .round))
            }
        }
    }

    private static func drawEye(_ g: GraphicsContext, _ a: BirdAppearance, _ R: CGFloat, blink: CGFloat) {
        let ex = R * 0.38, ey = -R * 0.12, r = R * 0.17 * CGFloat(a.eyeSize)
        drawMarkings(g, a, R, overEye: true)
        g.fill(circle(ex, ey, r), with: .color(a.eye.color))
        g.fill(circle(ex + r * 0.12, ey, r * (a.eyeDark ? 0.95 : 0.55)), with: .color(Color(hex: 0x0D0D0D)))
        g.fill(circle(ex + r * 0.4, ey - r * 0.38, r * 0.28), with: .color(.white.opacity(0.95)))
        g.stroke(circle(ex, ey, r), with: .color(.black.opacity(0.5)), lineWidth: 1)
        if blink > 0.02 {
            var lid = g
            lid.clip(to: circle(ex, ey, r + 1))
            lid.fill(Path(CGRect(x: ex - r - 1, y: ey - r - 1, width: r * 2 + 2, height: (r * 2 + 2) * blink)), with: .color(a.head.color))
        }
    }

    // MARK: Beak

    static func beakPath(_ shape: BeakShape, R: CGFloat, length: CGFloat) -> (path: Path, height: CGFloat, length: CGFloat) {
        var p = Path()
        var bh: CGFloat = 0
        var l: CGFloat = 0
        switch shape {
        case .conical:
            bh = R * 0.62; l = R * 0.95 * length
            p.move(to: pt(0, -bh / 2))
            p.addQuadCurve(to: pt(l, bh * 0.05), control: pt(l * 0.5, -bh * 0.45))
            p.addQuadCurve(to: pt(0, bh / 2), control: pt(l * 0.5, bh * 0.5))
        case .needle:
            bh = R * 0.22; l = R * 2.6 * length
            p.move(to: pt(0, -bh / 2))
            p.addLine(to: pt(l, bh * 0.1))
            p.addLine(to: pt(l, bh * 0.3))
            p.addLine(to: pt(0, bh / 2))
        case .hooked:
            bh = R * 0.6; l = R * 0.95 * length
            p.move(to: pt(0, -bh / 2))
            p.addQuadCurve(to: pt(l, bh * 0.15), control: pt(l * 0.75, -bh * 0.65))
            p.addQuadCurve(to: pt(l * 0.78, bh * 0.85), control: pt(l * 0.98, bh * 0.75))
            p.addQuadCurve(to: pt(l * 0.55, bh * 0.4), control: pt(l * 0.82, bh * 0.35))
            p.addLine(to: pt(0, bh / 2))
        case .parrot:
            bh = R * 1.0; l = R * 1.05 * length
            p.move(to: pt(0, -bh * 0.55))
            p.addCurve(to: pt(l * 0.85, bh * 0.75), control1: pt(l * 0.7, -bh * 0.75), control2: pt(l * 1.15, -bh * 0.1))
            p.addQuadCurve(to: pt(l * 0.45, bh * 0.25), control: pt(l * 0.7, bh * 0.25))
            p.addQuadCurve(to: pt(0, bh * 0.5), control: pt(l * 0.4, bh * 0.6))
        case .dagger:
            bh = R * 0.42; l = R * 2.1 * length
            p.move(to: pt(0, -bh / 2))
            p.addQuadCurve(to: pt(l, bh * 0.05), control: pt(l * 0.6, -bh * 0.3))
            p.addQuadCurve(to: pt(0, bh / 2), control: pt(l * 0.6, bh * 0.4))
        case .flat:
            bh = R * 0.42; l = R * 1.45 * length
            p.move(to: pt(0, -bh * 0.6))
            p.addQuadCurve(to: pt(l * 0.85, -bh * 0.18), control: pt(l * 0.4, -bh * 0.2))
            p.addQuadCurve(to: pt(l, bh * 0.3), control: pt(l * 1.05, -bh * 0.1))
            p.addQuadCurve(to: pt(0, bh * 0.5), control: pt(l * 0.5, bh * 0.5))
        case .decurved:
            bh = R * 0.34; l = R * 2.2 * length
            p.move(to: pt(0, -bh / 2))
            p.addQuadCurve(to: pt(l, bh * 1.9), control: pt(l * 0.6, -bh * 0.7))
            p.addQuadCurve(to: pt(0, bh / 2), control: pt(l * 0.55, bh * 0.45))
        case .pouch:
            bh = R * 0.42; l = R * 2.9 * length
            p.move(to: pt(0, -bh / 2))
            p.addLine(to: pt(l * 0.95, -bh * 0.35))
            p.addQuadCurve(to: pt(l * 0.96, bh * 0.25), control: pt(l * 1.04, -bh * 0.2))
            p.addQuadCurve(to: pt(0, bh * 1.6), control: pt(l * 0.6, bh * 2.6))
        case .shoe:
            bh = R * 0.95; l = R * 1.55 * length
            p.move(to: pt(0, -bh * 0.5))
            p.addQuadCurve(to: pt(l * 0.92, -bh * 0.2), control: pt(l * 0.6, -bh * 0.55))
            p.addQuadCurve(to: pt(l * 0.9, bh * 0.35), control: pt(l * 1.06, bh * 0.1))
            p.addQuadCurve(to: pt(0, bh * 0.55), control: pt(l * 0.5, bh * 0.75))
        case .toucan:
            bh = R * 1.05; l = R * 2.9 * length
            p.move(to: pt(0, -bh * 0.55))
            p.addCurve(to: pt(l, bh * 0.15), control1: pt(l * 0.4, -bh * 0.8), control2: pt(l * 0.85, -bh * 0.45))
            p.addCurve(to: pt(0, bh * 0.5), control1: pt(l * 0.8, bh * 0.25), control2: pt(l * 0.4, bh * 0.6))
        case .deep:
            bh = R * 1.0; l = R * 1.0 * length
            p.move(to: pt(0, -bh * 0.55))
            p.addQuadCurve(to: pt(l, bh * 0.15), control: pt(l * 0.6, -bh * 0.5))
            p.addQuadCurve(to: pt(0, bh * 0.55), control: pt(l * 0.6, bh * 0.55))
        case .tiny:
            bh = R * 0.36; l = R * 0.45 * length
            p.move(to: pt(0, -bh / 2))
            p.addQuadCurve(to: pt(l * 0.85, bh * 0.6), control: pt(l * 0.9, -bh * 0.4))
            p.addQuadCurve(to: pt(0, bh / 2), control: pt(l * 0.4, bh * 0.3))
        case .bent:
            bh = R * 0.6; l = R * 1.7 * length
            p.move(to: pt(0, -bh / 2))
            p.addQuadCurve(to: pt(l * 0.55, -bh * 0.2), control: pt(l * 0.45, -bh * 0.55))
            p.addQuadCurve(to: pt(l * 0.9, bh * 1.6), control: pt(l * 0.8, bh * 0.5))
            p.addQuadCurve(to: pt(l * 0.5, bh * 0.55), control: pt(l * 0.7, bh * 1.2))
            p.addQuadCurve(to: pt(0, bh / 2), control: pt(l * 0.3, bh * 0.6))
        }
        p.closeSubpath()
        return (p, bh, l)
    }

    private static func drawBeak(_ ctx: GraphicsContext, _ a: BirdAppearance, _ R: CGFloat, open: CGFloat) {
        var g = ctx
        g.translateBy(x: R * 0.82, y: R * 0.12)
        g.rotate(by: .degrees(a.beakAngle))
        let shape = beakPath(a.beakShape, R: R, length: CGFloat(a.beakLength))

        if open > 0.5 {
            var mouth = Path()
            mouth.move(to: pt(-2, 0))
            mouth.addLine(to: pt(R * 0.7, -2))
            mouth.addLine(to: pt(R * 0.6, R * 0.5 * sin(open * deg) * 3))
            mouth.closeSubpath()
            g.fill(mouth, with: .color(Color(hex: 0x5A1E1E)))
        }

        func paintMandible(_ m: GraphicsContext) {
            let bh = shape.height, l = shape.length
            m.fill(shape.path, with: .linearGradient(Gradient(colors: [a.beak.shaded(0.2).color, a.beak.shaded(-0.15).color]),
                                                     startPoint: pt(0, -bh / 2), endPoint: pt(0, bh / 2)))
            if a.beakTip != a.beak {
                var tip = m
                tip.clip(to: shape.path)
                switch a.beakShape {
                case .deep:
                    tip.fill(Path(CGRect(x: l * 0.45, y: -bh, width: l, height: bh * 2)), with: .color(a.beakTip.color))
                    tip.fill(Path(CGRect(x: l * 0.38, y: -bh, width: l * 0.06, height: bh * 2)), with: .color(a.beak.shaded(0.5).color))
                case .toucan:
                    tip.fill(Path(CGRect(x: l * 0.82, y: -bh, width: l, height: bh * 2)), with: .color(a.beakTip.color))
                    tip.fill(Path(CGRect(x: -2, y: bh * 0.1, width: l, height: bh)), with: .color(a.beakTip.color.opacity(0.3)))
                default:
                    tip.fill(Path(CGRect(x: l * 0.62, y: -bh * 3, width: l * 2, height: bh * 6)), with: .color(a.beakTip.color))
                }
            }
            m.stroke(shape.path, with: .color(a.beak.shaded(-0.45).color), lineWidth: 1.2)
        }

        var upper = g
        upper.clip(to: Path(CGRect(x: -10, y: -R * 4, width: R * 8, height: R * 4 + 0.6)))
        paintMandible(upper)

        var lower = g
        lower.rotate(by: .degrees(Double(open)))
        lower.clip(to: Path(CGRect(x: -10, y: 0, width: R * 8, height: R * 6)))
        paintMandible(lower)

        var gape = Path()
        gape.move(to: .zero)
        gape.addLine(to: pt(shape.length * 0.75, 0))
        g.stroke(gape, with: .color(a.beak.shaded(-0.5).color), lineWidth: 1)
        g.fill(ellipse(R * 0.12, -R * 0.13, 2, 1.2), with: .color(a.beak.shaded(-0.5).color))
    }
}
