import SwiftUI

/// A hand-drawn, stylised world map that highlights where a species lives.
struct WorldMapView: View {
    var highlighted: [Region]
    var accent: Color = Color(hex: 0xC8572D)
    var animated = true

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: !animated)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                WorldMapPainter.paint(in: context, size: size, highlighted: Set(highlighted), accent: accent, time: t)
            }
        }
        .aspectRatio(2, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel("Range map: " + highlighted.map(\.title).joined(separator: ", "))
    }
}

enum WorldMapPainter {
    typealias LonLat = (Double, Double)

    static let continents: [String: [LonLat]] = [
        "northAmerica": [(-168, 65), (-160, 71), (-140, 70), (-115, 73), (-95, 72), (-80, 73), (-65, 62), (-55, 52), (-66, 44),
                         (-76, 38), (-81, 30), (-80, 25), (-90, 29), (-97, 26), (-97, 21), (-88, 21), (-83, 10), (-78, 8),
                         (-92, 15), (-105, 20), (-112, 30), (-117, 33), (-124, 40), (-125, 48), (-135, 57), (-150, 60), (-165, 60)],
        "greenland": [(-55, 60), (-42, 60), (-20, 70), (-18, 80), (-40, 83), (-65, 80), (-72, 77), (-58, 70)],
        "southAmerica": [(-78, 8), (-72, 12), (-62, 10), (-50, 0), (-35, -6), (-38, -14), (-40, -22), (-48, -27), (-58, -38),
                         (-65, -42), (-68, -52), (-72, -54), (-75, -48), (-73, -38), (-71, -28), (-70, -18), (-76, -14), (-81, -6), (-80, 0)],
        "europe": [(-10, 36), (-9, 43), (-2, 44), (-5, 48), (2, 51), (5, 53), (8, 57), (5, 62), (12, 66), (20, 70), (30, 71),
                   (42, 68), (45, 62), (40, 55), (42, 47), (30, 45), (28, 41), (26, 38), (22, 37), (18, 40), (12, 44), (8, 44),
                   (3, 42), (0, 39), (-5, 36)],
        "britain": [(-6, 50), (1, 51), (2, 53), (-2, 56), (-5, 58), (-6, 55), (-4, 53), (-5, 50)],
        "africa": [(-17, 21), (-16, 15), (-17, 12), (-12, 6), (-7, 4), (5, 5), (9, 4), (10, -2), (13, -8), (12, -17), (16, -28),
                   (20, -35), (26, -34), (33, -26), (36, -18), (40, -15), (40, -5), (43, 0), (51, 11), (43, 12), (38, 18),
                   (33, 28), (25, 32), (11, 33), (10, 37), (0, 36), (-9, 33), (-14, 28)],
        "madagascar": [(44, -25), (47, -25), (50, -15), (49, -12), (44, -17)],
        "asia": [(42, 47), (40, 55), (45, 62), (42, 68), (60, 70), (80, 73), (105, 78), (130, 72), (150, 72), (170, 70),
                 (180, 66), (178, 62), (160, 60), (155, 55), (140, 53), (135, 45), (128, 40), (122, 32), (120, 25), (110, 20),
                 (106, 10), (100, 13), (103, 2), (98, 8), (97, 16), (92, 22), (88, 22), (80, 15), (77, 8), (73, 17), (67, 25),
                 (57, 25), (52, 15), (43, 12), (36, 32), (36, 36), (28, 41), (30, 45)],
        "japan": [(130, 31), (135, 34), (140, 36), (142, 40), (141, 45), (139, 40), (135, 35), (130, 33)],
        "borneo": [(109, 1), (117, 7), (119, 1), (116, -4), (110, -3)],
        "sumatra": [(95, 5), (104, -5), (106, -6), (100, -1)],
        "newGuinea": [(131, -1), (141, -3), (150, -7), (147, -10), (141, -9), (134, -4)],
        "australia": [(114, -22), (122, -18), (130, -12), (137, -12), (142, -11), (146, -19), (153, -25), (151, -34),
                      (146, -39), (140, -38), (135, -35), (128, -32), (118, -35), (115, -33)],
        "newZealand": [(172, -35), (178, -38), (175, -42), (171, -46), (167, -46), (172, -41)],
        "antarctica": [(-180, -70), (-120, -73), (-60, -64), (-30, -75), (30, -69), (90, -66), (150, -68), (180, -70), (180, -90), (-180, -90)],
    ]

    static func shapes(for region: Region) -> [String] {
        switch region {
        case .northAmerica: return ["northAmerica", "greenland"]
        case .centralAmerica: return []
        case .southAmerica: return ["southAmerica"]
        case .europe: return ["europe", "britain"]
        case .africa: return ["africa", "madagascar"]
        case .asia: return ["asia", "japan", "borneo", "sumatra"]
        case .oceania: return ["australia", "newZealand", "newGuinea"]
        case .antarctica: return ["antarctica"]
        case .oceans, .arctic: return []
        }
    }

    /// Glowing range blobs for regions that aren't a whole landmass (lon, lat, radiusLon, radiusLat).
    static func glows(for region: Region) -> [(Double, Double, Double, Double)] {
        switch region {
        case .centralAmerica: return [(-87, 14, 11, 8)]
        case .oceans: return [(-150, -20, 25, 22), (-30, 0, 18, 30), (75, -30, 25, 15), (0, -55, 60, 6)]
        case .arctic: return [(0, 78, 180, 8)]
        default: return []
        }
    }

    static func pin(for region: Region) -> (Double, Double) {
        switch region {
        case .northAmerica: return (-100, 45)
        case .centralAmerica: return (-87, 14)
        case .southAmerica: return (-60, -15)
        case .europe: return (15, 50)
        case .africa: return (20, 5)
        case .asia: return (95, 45)
        case .oceania: return (134, -25)
        case .antarctica: return (0, -78)
        case .oceans: return (-150, -20)
        case .arctic: return (-40, 76)
        }
    }

    static func paint(in context: GraphicsContext, size: CGSize, highlighted: Set<Region>, accent: Color, time: Double) {
        func project(_ lonLat: LonLat) -> CGPoint {
            CGPoint(x: (lonLat.0 + 180) / 360 * size.width, y: (90 - lonLat.1) / 180 * size.height)
        }

        // Ocean with a faint graticule.
        let frame = Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 14)
        context.fill(frame, with: .linearGradient(Gradient(colors: [Color(hex: 0xBFD9DF), Color(hex: 0xA5C6CF)]),
                                                  startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
        var grid = Path()
        for lon in stride(from: -150.0, through: 150.0, by: 30.0) {
            grid.move(to: project((lon, 90)))
            grid.addLine(to: project((lon, -90)))
        }
        for lat in stride(from: -60.0, through: 60.0, by: 30.0) {
            grid.move(to: project((-180, lat)))
            grid.addLine(to: project((180, lat)))
        }
        var clipped = context
        clipped.clip(to: frame)
        clipped.stroke(grid, with: .color(.white.opacity(0.35)), style: StrokeStyle(lineWidth: 0.6, dash: [3, 3]))

        let litShapes = Set(highlighted.flatMap { shapes(for: $0) })
        let pulse = 0.5 + 0.5 * sin(time * 2.4)

        for (name, points) in continents {
            var land = Path()
            land.move(to: project(points[0]))
            for p in points.dropFirst() { land.addLine(to: project(p)) }
            land.closeSubpath()
            let lit = litShapes.contains(name)
            clipped.fill(land, with: .color(lit ? accent.opacity(0.75 + 0.2 * pulse) : Color(hex: 0xE9DCC0)))
            clipped.stroke(land, with: .color(lit ? accent : Color(hex: 0x9C8A6A)), style: StrokeStyle(lineWidth: lit ? 1.4 : 0.8, lineJoin: .round))
        }

        for region in highlighted {
            for (lon, lat, rLon, rLat) in glows(for: region) {
                let c = project((lon, lat))
                let rx = rLon / 360 * size.width, ry = rLat / 180 * size.height
                let blob = Path(ellipseIn: CGRect(x: c.x - rx, y: c.y - ry, width: rx * 2, height: ry * 2))
                clipped.fill(blob, with: .radialGradient(Gradient(colors: [accent.opacity(0.55 + 0.25 * pulse), accent.opacity(0)]),
                                                         center: c, startRadius: 0, endRadius: max(rx, ry)))
            }
        }

        // Pins with a ripple.
        for region in highlighted {
            let c = project(pin(for: region))
            let ripple = CGFloat((time * 0.8 + Double(region.title.count)).truncatingRemainder(dividingBy: 1))
            let rr = 4 + ripple * 14
            clipped.stroke(Path(ellipseIn: CGRect(x: c.x - rr, y: c.y - rr, width: rr * 2, height: rr * 2)),
                           with: .color(accent.opacity(Double(1 - ripple))), lineWidth: 1.5)
            clipped.fill(Path(ellipseIn: CGRect(x: c.x - 4, y: c.y - 4, width: 8, height: 8)), with: .color(.white))
            clipped.fill(Path(ellipseIn: CGRect(x: c.x - 2.6, y: c.y - 2.6, width: 5.2, height: 5.2)), with: .color(accent))
        }

        context.stroke(frame, with: .color(Color(hex: 0x6B5A44).opacity(0.6)), lineWidth: 1.5)
    }
}
