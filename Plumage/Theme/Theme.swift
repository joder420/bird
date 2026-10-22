import SwiftUI

/// The naturalist's-field-journal palette.
enum Palette {
    static let forest = Color(hex: 0x2F4A36)
    static let moss = Color(hex: 0x6B8F4E)
    static let fern = Color(hex: 0x8DB36B)
    static let parchment = Color(hex: 0xF6EEDC)
    static let parchmentDeep = Color(hex: 0xE9DCC0)
    static let parchmentEdge = Color(hex: 0xD8C7A3)
    static let bark = Color(hex: 0x5B4332)
    static let ink = Color(hex: 0x2B2420)
    static let inkSoft = Color(hex: 0x5C5045)
    static let gold = Color(hex: 0xC9962B)
    static let sunrise = Color(hex: 0xE3A833)
    static let berry = Color(hex: 0xB0413E)
    static let sky = Color(hex: 0x8EC5E6)
    static let lake = Color(hex: 0x3F86B5)
    static let dusk = Color(hex: 0x6C5B9E)
}

/// Artistic typefaces that ship with iOS — no font files to bundle.
enum AppFont {
    /// Flowing copperplate script for big titles.
    static func display(_ size: CGFloat) -> Font { .custom("SnellRoundhand-Black", size: size) }
    static func script(_ size: CGFloat) -> Font { .custom("SnellRoundhand-Bold", size: size) }
    /// High-contrast Didone for headings.
    static func title(_ size: CGFloat) -> Font { .custom("Didot-Bold", size: size) }
    /// Engraved small caps for labels.
    static func caps(_ size: CGFloat) -> Font { .custom("Copperplate-Bold", size: size) }
    static func capsLight(_ size: CGFloat) -> Font { .custom("Copperplate", size: size) }
    /// Book face for reading.
    static func body(_ size: CGFloat = 16) -> Font { .custom("Baskerville", size: size, relativeTo: .body) }
    static func bodyBold(_ size: CGFloat = 16) -> Font { .custom("Baskerville-SemiBold", size: size, relativeTo: .body) }
    static func italic(_ size: CGFloat = 16) -> Font { .custom("Baskerville-Italic", size: size, relativeTo: .body) }
    /// Handwritten field notes.
    static func hand(_ size: CGFloat) -> Font { .custom("Noteworthy-Bold", size: size) }
    static func handLight(_ size: CGFloat) -> Font { .custom("Noteworthy-Light", size: size) }
    /// Typewritten data.
    static func data(_ size: CGFloat) -> Font { .custom("AmericanTypewriter-Semibold", size: size) }
    static func dataLight(_ size: CGFloat) -> Font { .custom("AmericanTypewriter", size: size) }
}

// MARK: - Parchment card

struct PaperGrain: View {
    var seed: Int = 0

    var body: some View {
        Canvas { context, size in
            var rng = SeededRandom(seed: UInt64(seed + 17))
            let count = Int(size.width * size.height / 900)
            for _ in 0..<min(count, 260) {
                let x = rng.unit() * Double(size.width), y = rng.unit() * Double(size.height)
                let r = 0.4 + rng.unit() * 1.1
                let dark = rng.unit() < 0.6
                context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                             with: .color((dark ? Palette.bark : Color.white).opacity(dark ? 0.08 : 0.25)))
            }
        }
        .allowsHitTesting(false)
    }
}

struct ParchmentCard: ViewModifier {
    var padding: CGFloat = 16
    var cornerRadius: CGFloat = 20
    var tint: Color? = nil

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                ZStack {
                    shape.fill(LinearGradient(colors: [Palette.parchment, Palette.parchmentDeep], startPoint: .topLeading, endPoint: .bottomTrailing))
                    if let tint {
                        shape.fill(tint.opacity(0.12))
                    }
                    PaperGrain().clipShape(shape)
                    shape.strokeBorder(Palette.parchmentEdge, lineWidth: 1.5)
                    shape.inset(by: 5).strokeBorder(Palette.gold.opacity(0.35), style: StrokeStyle(lineWidth: 0.8, dash: [4, 3]))
                }
                .shadow(color: Palette.bark.opacity(0.25), radius: 10, x: 0, y: 6)
            }
    }
}

extension View {
    func parchmentCard(padding: CGFloat = 16, cornerRadius: CGFloat = 20, tint: Color? = nil) -> some View {
        modifier(ParchmentCard(padding: padding, cornerRadius: cornerRadius, tint: tint))
    }

    /// White script text that stays legible over the sky.
    func skyShadow() -> some View {
        shadow(color: .black.opacity(0.35), radius: 3, x: 0, y: 2)
    }
}

// MARK: - Buttons

struct WoodButtonStyle: ButtonStyle {
    var color: Color = Palette.forest
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.caps(compact ? 13 : 15))
            .foregroundStyle(Palette.parchment)
            .padding(.horizontal, compact ? 14 : 20)
            .padding(.vertical, compact ? 8 : 12)
            .background {
                Capsule()
                    .fill(LinearGradient(colors: [color.opacity(0.95), color.blended(with: .black, by: 0.25)], startPoint: .top, endPoint: .bottom))
                    .overlay(Capsule().strokeBorder(Palette.gold.opacity(0.6), lineWidth: 1))
                    .shadow(color: color.opacity(0.4), radius: configuration.isPressed ? 2 : 6, y: configuration.isPressed ? 1 : 4)
            }
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .brightness(configuration.isPressed ? -0.03 : 0)
            .animation(.spring(response: 0.25, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

extension Color {
    /// Blends toward another colour (iOS 17-friendly alternative to `Color.mix`).
    func blended(with other: Color, by amount: Double) -> Color {
        RGBA(self).mixed(with: RGBA(other), amount).color
    }
}
