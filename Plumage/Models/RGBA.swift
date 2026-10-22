import SwiftUI
import UIKit

/// A Codable sRGB colour. Encodes as a "#RRGGBB" (or "#RRGGBBAA") hex string so the
/// species database and save files stay human-readable.
struct RGBA: Codable, Hashable {
    var r: Double
    var g: Double
    var b: Double
    var a: Double

    init(r: Double, g: Double, b: Double, a: Double = 1) {
        self.r = min(max(r, 0), 1)
        self.g = min(max(g, 0), 1)
        self.b = min(max(b, 0), 1)
        self.a = min(max(a, 0), 1)
    }

    init(_ hex: UInt32) {
        self.init(r: Double((hex >> 16) & 0xFF) / 255,
                  g: Double((hex >> 8) & 0xFF) / 255,
                  b: Double(hex & 0xFF) / 255)
    }

    init?(hex string: String) {
        var s = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6 || s.count == 8, let v = UInt64(s, radix: 16) else { return nil }
        if s.count == 6 {
            self.init(UInt32(v))
        } else {
            self.init(r: Double((v >> 24) & 0xFF) / 255,
                      g: Double((v >> 16) & 0xFF) / 255,
                      b: Double((v >> 8) & 0xFF) / 255,
                      a: Double(v & 0xFF) / 255)
        }
    }

    /// Converts a SwiftUI colour (e.g. from a ColorPicker) into stored components.
    init(_ color: Color) {
        let ui = UIColor(color)
        var rr: CGFloat = 0, gg: CGFloat = 0, bb: CGFloat = 0, aa: CGFloat = 0
        if ui.getRed(&rr, green: &gg, blue: &bb, alpha: &aa) {
            self.init(r: Double(rr), g: Double(gg), b: Double(bb), a: Double(aa))
        } else {
            var white: CGFloat = 0
            ui.getWhite(&white, alpha: &aa)
            self.init(r: Double(white), g: Double(white), b: Double(white), a: Double(aa))
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        guard let value = RGBA(hex: string) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid colour '\(string)'")
        }
        self = value
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(hexString)
    }

    var hexString: String {
        let ri = Int((r * 255).rounded())
        let gi = Int((g * 255).rounded())
        let bi = Int((b * 255).rounded())
        if a < 0.999 {
            let ai = Int((a * 255).rounded())
            return String(format: "#%02X%02X%02X%02X", ri, gi, bi, ai)
        }
        return String(format: "#%02X%02X%02X", ri, gi, bi)
    }

    var color: Color { Color(.sRGB, red: r, green: g, blue: b, opacity: a) }

    /// Perceived brightness, 0 (black) to 1 (white).
    var luminance: Double { 0.2126 * r + 0.7152 * g + 0.0722 * b }

    /// Negative `amount` darkens toward black, positive lightens toward white.
    func shaded(_ amount: Double) -> RGBA {
        if amount < 0 {
            let k = 1 + amount
            return RGBA(r: r * k, g: g * k, b: b * k, a: a)
        }
        return RGBA(r: r + (1 - r) * amount, g: g + (1 - g) * amount, b: b + (1 - b) * amount, a: a)
    }

    func mixed(with other: RGBA, _ t: Double) -> RGBA {
        RGBA(r: r + (other.r - r) * t, g: g + (other.g - g) * t, b: b + (other.b - b) * t, a: a + (other.a - a) * t)
    }

    func withAlpha(_ alpha: Double) -> RGBA { RGBA(r: r, g: g, b: b, a: alpha) }

    // MARK: HSB

    var hsb: (h: Double, s: Double, v: Double) {
        let maxC = max(r, g, b), minC = min(r, g, b)
        let delta = maxC - minC
        var h: Double = 0
        if delta > 0.00001 {
            if maxC == r {
                h = ((g - b) / delta).truncatingRemainder(dividingBy: 6)
            } else if maxC == g {
                h = (b - r) / delta + 2
            } else {
                h = (r - g) / delta + 4
            }
            h *= 60
            if h < 0 { h += 360 }
        }
        let s = maxC == 0 ? 0 : delta / maxC
        return (h, s, maxC)
    }

    init(h: Double, s: Double, v: Double, a: Double = 1) {
        let hh = (h.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) / 60
        let c = v * s
        let x = c * (1 - abs(hh.truncatingRemainder(dividingBy: 2) - 1))
        let m = v - c
        var rgb: (Double, Double, Double)
        switch Int(hh) {
        case 0: rgb = (c, x, 0)
        case 1: rgb = (x, c, 0)
        case 2: rgb = (0, c, x)
        case 3: rgb = (0, x, c)
        case 4: rgb = (x, 0, c)
        default: rgb = (c, 0, x)
        }
        self.init(r: rgb.0 + m, g: rgb.1 + m, b: rgb.2 + m, a: a)
    }

    func hueShifted(_ degrees: Double) -> RGBA {
        let c = hsb
        return RGBA(h: c.h + degrees, s: c.s, v: c.v, a: a)
    }

    func saturated(_ factor: Double) -> RGBA {
        let c = hsb
        return RGBA(h: c.h, s: min(1, c.s * factor), v: c.v, a: a)
    }

    /// A short, friendly colour name — used for egg and plumage descriptions.
    var friendlyName: String {
        let c = hsb
        if c.v < 0.18 { return "Ink black" }
        if c.s < 0.12 {
            if c.v > 0.9 { return "Snow white" }
            if c.v > 0.7 { return "Pearl grey" }
            if c.v > 0.45 { return "Slate grey" }
            return "Charcoal"
        }
        let names: [(Double, String)] = [
            (12, "Scarlet"), (28, "Ember orange"), (45, "Amber"), (62, "Golden yellow"),
            (85, "Lime"), (140, "Leaf green"), (170, "Jade"), (195, "Turquoise"),
            (215, "Sky blue"), (245, "Cobalt"), (275, "Violet"), (310, "Orchid"),
            (340, "Rose"), (361, "Crimson")
        ]
        var base = "Crimson"
        for (limit, name) in names where c.h < limit {
            base = name
            break
        }
        if c.s < 0.35 && c.v > 0.6 { return "Pale \(base.lowercased())" }
        if c.v < 0.45 { return "Deep \(base.lowercased())" }
        return base
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}
