import SwiftUI

enum Palette {
    static let ink = Color(hex: 0x111111)
    static let paper = Color(hex: 0xFBF6EC)
    static let card = Color.white
    static let muted = Color(hex: 0x6D6A64)
    static let peri = Color(hex: 0xCFC2FF)
    static let yellow = Color(hex: 0xFFE45C)
    static let mint = Color(hex: 0xD4E78F)
    static let blush = Color(hex: 0xFFD3BB)
    static let salmon = Color(hex: 0xF8A9C8)
    static let olive = Color(hex: 0x6FBF5A)
    static let blue = Color(hex: 0x8BBCFF)
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

struct Inked: ViewModifier {
    var fill: Color
    var radius: CGFloat
    var shadow: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Palette.ink, lineWidth: 2.5)
            )
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Palette.ink)
                    .offset(x: shadow, y: shadow)
            )
    }
}

extension View {
    func inked(_ fill: Color = Palette.card, radius: CGFloat = 22, shadow: CGFloat = 4) -> some View {
        modifier(Inked(fill: fill, radius: radius, shadow: shadow))
    }
}

struct ChunkyButtonStyle: ButtonStyle {
    var fill: Color = Palette.yellow

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded, weight: .bold))
            .foregroundStyle(Palette.ink)
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .inked(fill, radius: 999, shadow: configuration.isPressed ? 1 : 4)
            .offset(x: configuration.isPressed ? 3 : 0, y: configuration.isPressed ? 3 : 0)
            .animation(.spring(duration: 0.18, bounce: 0.4), value: configuration.isPressed)
    }
}

struct RoundIconButtonStyle: ButtonStyle {
    var fill: Color
    var size: CGFloat = 64

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size * 0.38, weight: .heavy, design: .rounded))
            .foregroundStyle(Palette.ink)
            .frame(width: size, height: size)
            .background(Circle().fill(fill))
            .overlay(Circle().stroke(Palette.ink, lineWidth: 2.5))
            .background(Circle().fill(Palette.ink).offset(x: configuration.isPressed ? 1 : 4, y: configuration.isPressed ? 1 : 4))
            .offset(x: configuration.isPressed ? 3 : 0, y: configuration.isPressed ? 3 : 0)
            .animation(.spring(duration: 0.18, bounce: 0.4), value: configuration.isPressed)
    }
}

extension Font {
    static func rounded(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}
