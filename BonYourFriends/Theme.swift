import SwiftUI

enum Palette {
    static let page = Color(hex: 0xE7E5E1)
    static let screen = Color(hex: 0xF5F2E9)
    static let paper = screen
    static let hero = Color(hex: 0xFFFDF7)
    static let card = Color.white
    static let ink = Color(hex: 0x111111)
    static let muted = Color(hex: 0x6D6A64)
    static let line = Color(hex: 0xD9D5CB)
    static let dotOff = Color(hex: 0xE4E0D6)
    static let mineText = Color(hex: 0x14803F)
    static let otherText = Color(hex: 0xE0301E)
    static let splitText = Color(hex: 0xA36A00)
    static let red = Color(hex: 0xFF3B30)
    static let hand = Color(hex: 0x1FB15A)
    static let ledger = Color(hex: 0x77727F)
    static let peri = Color(hex: 0xCFC2FF)
    static let yellow = Color(hex: 0xFFE45C)
    static let mint = Color(hex: 0xD4E78F)
    static let blush = Color(hex: 0xFFD3BB)
    static let salmon = Color(hex: 0xF8A9C8)
    static let olive = Color(hex: 0x6FBF5A)
    static let blue = Color(hex: 0x8BBCFF)
    static let shoe = Color(hex: 0x8F7BFF)
    static let paperLine = Color(hex: 0xC9C4B8)
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

extension Font {
    static func ui(_ size: CGFloat, _ weight: Int = 600) -> Font {
        let w = [500, 600, 700, 800].min { abs($0 - weight) < abs($1 - weight) } ?? 600
        return .custom("BYFText-\(w)", size: size)
    }

    static func display(_ size: CGFloat) -> Font {
        .custom("BYFDisplay-800", size: size)
    }

    static func hand(_ size: CGFloat) -> Font {
        .custom("BYFHand-700", size: size)
    }

    static func rounded(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        switch weight {
        case .black, .heavy: .ui(size, 800)
        case .bold: .ui(size, 700)
        case .semibold: .ui(size, 600)
        default: .ui(size, 500)
        }
    }
}

struct Inked: ViewModifier {
    var fill: Color
    var radius: CGFloat
    var border: CGFloat
    var shadow: CGFloat
    var shadowColor: Color

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .background(shape.fill(fill))
            .overlay(shape.strokeBorder(Palette.ink, lineWidth: border))
            .background(shape.fill(shadowColor).offset(x: shadow, y: shadow))
    }
}

extension View {
    func inked(_ fill: Color = Palette.card, radius: CGFloat = 26, border: CGFloat = 3, shadow: CGFloat = 5, shadowColor: Color = Palette.ink) -> some View {
        modifier(Inked(fill: fill, radius: radius, border: border, shadow: shadow, shadowColor: shadowColor))
    }
}

extension Animation {
    static let springHard = Animation.spring(response: 0.42, dampingFraction: 0.45)
    static let springSoft = Animation.spring(response: 0.5, dampingFraction: 0.72)
    static let springPop = Animation.spring(response: 0.36, dampingFraction: 0.55)
}

struct InkButtonStyle: ButtonStyle {
    enum Kind { case dark, light }
    var kind: Kind = .light
    var height: CGFloat = 54
    var fontSize: CGFloat = 16

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let fill = kind == .dark ? Palette.ink : Palette.card
        let shadowColor = kind == .dark ? Palette.salmon : Palette.ink
        return configuration.label
            .font(.ui(fontSize, 700))
            .foregroundStyle(kind == .dark ? Color.white : Palette.ink)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: height)
            .inked(fill, radius: 999, border: 3, shadow: pressed ? 1 : 4, shadowColor: shadowColor)
            .scaleEffect(pressed ? 0.93 : 1)
            .offset(x: pressed ? 3 : 0, y: pressed ? 3 : 0)
            .animation(pressed ? .easeOut(duration: 0.06) : .springHard, value: pressed)
    }
}

struct CircleIconButtonStyle: ButtonStyle {
    var size: CGFloat = 42

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .font(.system(size: size * 0.42, weight: .bold))
            .foregroundStyle(Palette.ink)
            .frame(width: size, height: size)
            .background(Circle().fill(Palette.card))
            .overlay(Circle().strokeBorder(Palette.ink, lineWidth: 2.5))
            .background(Circle().fill(Palette.ink).offset(x: pressed ? 1 : 3, y: pressed ? 1 : 3))
            .scaleEffect(pressed ? 0.86 : 1)
            .offset(x: pressed ? 2 : 0, y: pressed ? 2 : 0)
            .animation(pressed ? .easeOut(duration: 0.06) : .springHard, value: pressed)
    }
}

struct PressScaleStyle: ButtonStyle {
    var scale: CGFloat = 0.84

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(configuration.isPressed ? .easeOut(duration: 0.06) : .springHard, value: configuration.isPressed)
    }
}

struct Highlight: View {
    var text: String
    var size: CGFloat

    var body: some View {
        Text(text)
            .font(.display(size))
            .tracking(-size * 0.035)
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, size * 0.18)
            .padding(.bottom, size * 0.04)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Palette.salmon)
                    .background(
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .fill(Color.white)
                            .padding(-3)
                    )
            )
            .rotationEffect(.degrees(-3))
            .padding(.horizontal, size * 0.04)
    }
}

struct Headline: View {
    var plain: String
    var size: CGFloat = 34

    var body: some View {
        Text(plain)
            .font(.display(size))
            .tracking(-size * 0.035)
            .foregroundStyle(Palette.ink)
    }
}

struct Lab: View {
    var text: String
    var size: CGFloat = 14

    var body: some View {
        Text(text)
            .font(.ui(size, 600))
            .foregroundStyle(Palette.muted)
            .lineLimit(1)
            .truncationMode(.tail)
    }
}
