import SwiftUI

struct SVGPath: Shape {
    var d: String
    var viewBox: CGSize

    func path(in rect: CGRect) -> Path {
        let p = SVGPath.parse(d)
        let sx = rect.width / viewBox.width
        let sy = rect.height / viewBox.height
        return p.applying(CGAffineTransform(a: sx, b: 0, c: 0, d: sy, tx: rect.minX, ty: rect.minY))
    }

    static func parse(_ d: String) -> Path {
        var tokens: [String] = []
        var cur = ""
        func flush() {
            if !cur.isEmpty { tokens.append(cur); cur = "" }
        }
        for ch in d {
            if ch.isLetter && ch != "e" {
                flush()
                tokens.append(String(ch))
            } else if ch == "-" {
                if let last = cur.last, last == "e" { cur.append(ch) } else { flush(); cur.append(ch) }
            } else if ch == "," || ch == " " || ch == "\n" || ch == "\t" {
                flush()
            } else if ch == "." && cur.contains(".") {
                flush()
                cur.append(ch)
            } else {
                cur.append(ch)
            }
        }
        flush()

        var path = Path()
        var i = 0
        var cmd: Character = "M"
        var pt = CGPoint.zero
        var start = CGPoint.zero
        var lastCtrl: CGPoint?
        var lastQuad: CGPoint?

        func num() -> CGFloat {
            guard i < tokens.count, let v = Double(tokens[i]) else { i += 1; return 0 }
            i += 1
            return CGFloat(v)
        }
        func hasNum() -> Bool {
            i < tokens.count && Double(tokens[i]) != nil
        }

        while i < tokens.count {
            if let c = tokens[i].first, tokens[i].count == 1, c.isLetter {
                cmd = c
                i += 1
            }
            let rel = cmd.isLowercase
            let base = rel ? pt : .zero
            switch cmd.uppercased().first! {
            case "M":
                let p = CGPoint(x: base.x + num(), y: base.y + num())
                path.move(to: p)
                pt = p
                start = p
                cmd = rel ? "l" : "L"
                lastCtrl = nil
                lastQuad = nil
            case "L":
                let p = CGPoint(x: base.x + num(), y: base.y + num())
                path.addLine(to: p)
                pt = p
                lastCtrl = nil
                lastQuad = nil
            case "H":
                let x = (rel ? pt.x : 0) + num()
                pt = CGPoint(x: x, y: pt.y)
                path.addLine(to: pt)
                lastCtrl = nil
                lastQuad = nil
            case "V":
                let y = (rel ? pt.y : 0) + num()
                pt = CGPoint(x: pt.x, y: y)
                path.addLine(to: pt)
                lastCtrl = nil
                lastQuad = nil
            case "C":
                let c1 = CGPoint(x: base.x + num(), y: base.y + num())
                let c2 = CGPoint(x: base.x + num(), y: base.y + num())
                let p = CGPoint(x: base.x + num(), y: base.y + num())
                path.addCurve(to: p, control1: c1, control2: c2)
                pt = p
                lastCtrl = c2
                lastQuad = nil
            case "S":
                let c1 = lastCtrl.map { CGPoint(x: 2 * pt.x - $0.x, y: 2 * pt.y - $0.y) } ?? pt
                let c2 = CGPoint(x: base.x + num(), y: base.y + num())
                let p = CGPoint(x: base.x + num(), y: base.y + num())
                path.addCurve(to: p, control1: c1, control2: c2)
                pt = p
                lastCtrl = c2
                lastQuad = nil
            case "Q":
                let c = CGPoint(x: base.x + num(), y: base.y + num())
                let p = CGPoint(x: base.x + num(), y: base.y + num())
                path.addQuadCurve(to: p, control: c)
                pt = p
                lastQuad = c
                lastCtrl = nil
            case "T":
                let c = lastQuad.map { CGPoint(x: 2 * pt.x - $0.x, y: 2 * pt.y - $0.y) } ?? pt
                let p = CGPoint(x: base.x + num(), y: base.y + num())
                path.addQuadCurve(to: p, control: c)
                pt = p
                lastQuad = c
                lastCtrl = nil
            case "Z":
                path.closeSubpath()
                pt = start
                lastCtrl = nil
                lastQuad = nil
                while hasNum() { i += 1 }
                continue
            default:
                i += 1
            }
            if !hasNum(), i < tokens.count, Double(tokens[i]) == nil, tokens[i].count != 1 {
                i += 1
            }
        }
        return path
    }
}

struct Blob: Shape {
    var seed: Int

    func path(in rect: CGRect) -> Path {
        var t = (seed * 9301 + 49297) % 233280
        func rnd() -> Double {
            t = (t * 9301 + 49297) % 233280
            return Double(t) / 233280
        }
        let n = 8
        var pts: [CGPoint] = []
        for i in 0..<n {
            let ang = Double(i) / Double(n) * .pi * 2 + rnd() * 0.25
            let r = 66 + rnd() * 30
            pts.append(CGPoint(x: cos(ang) * r, y: sin(ang) * r))
        }
        var p = Path()
        for i in 0..<n {
            let p0 = pts[(i + n - 1) % n], p1 = pts[i], p2 = pts[(i + 1) % n], p3 = pts[(i + 2) % n]
            if i == 0 { p.move(to: p1) }
            p.addCurve(
                to: p2,
                control1: CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6),
                control2: CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
            )
        }
        p.closeSubpath()
        let s = min(rect.width, rect.height) / 200
        return p.applying(CGAffineTransform(a: s, b: 0, c: 0, d: s, tx: rect.midX, ty: rect.midY))
    }
}

struct Thumb: View {
    var kind: Kind
    var size: CGFloat = 46

    var body: some View {
        Image("thumb-" + kind.rawValue)
            .resizable()
            .scaledToFit()
            .frame(width: size * 1.18, height: size * 1.18)
            .frame(width: size, height: size)
            .background(kind.tile)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(Palette.ink, lineWidth: 2.5))
    }
}

enum DotState {
    case off, now, mine, other, split, part
}

struct Dots: View {
    var states: [DotState]

    var body: some View {
        GeometryReader { geo in
            let n = max(1, states.count)
            let gap: CGFloat = 3
            let size = max(6, min(18, (geo.size.width - gap * CGFloat(n - 1) - 8) / CGFloat(n)))
            HStack(spacing: gap) {
                ForEach(Array(states.enumerated()), id: \.offset) { _, s in
                    dot(s, size: size)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: 24)
    }

    @ViewBuilder
    private func dot(_ s: DotState, size: CGFloat) -> some View {
        let fill: AnyShapeStyle = switch s {
        case .off: AnyShapeStyle(Palette.dotOff)
        case .now: AnyShapeStyle(Palette.yellow)
        case .mine: AnyShapeStyle(Palette.olive)
        case .other: AnyShapeStyle(Palette.salmon)
        case .split: AnyShapeStyle(Palette.yellow)
        case .part: AnyShapeStyle(LinearGradient(stops: [.init(color: Palette.olive, location: 0.5), .init(color: Palette.salmon, location: 0.5)], startPoint: .leading, endPoint: .trailing))
        }
        Circle()
            .fill(fill)
            .overlay(Circle().strokeBorder(Palette.ink, lineWidth: 1.5))
            .frame(width: size, height: size)
            .background {
                if s == .now {
                    Circle().fill(Color.white).padding(-1.5)
                        .background(Circle().fill(Palette.ink).padding(-3))
                }
            }
            .scaleEffect(s == .now ? 1.06 : 1)
            .animation(.springPop, value: s == .now)
    }
}

struct InkSlider: View {
    @Binding var value: Int
    var maximum: Int
    var showTicks = true
    @State private var active = false

    var body: some View {
        VStack(spacing: 2) {
            GeometryReader { geo in
                let w = geo.size.width
                let thumb: CGFloat = 32
                let usable = max(1, w - thumb)
                let p = maximum > 0 ? CGFloat(value) / CGFloat(maximum) : 1
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white)
                        .overlay(alignment: .leading) {
                            Capsule().fill(Palette.salmon).frame(width: thumb / 2 + usable * p)
                        }
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(Palette.ink, lineWidth: 2.5))
                        .frame(height: 16)
                        .scaleEffect(x: 1, y: active ? 1.18 : 1)
                    Circle()
                        .fill(Palette.yellow)
                        .overlay(Circle().strokeBorder(Palette.ink, lineWidth: 3))
                        .background(Circle().fill(Palette.ink).offset(x: 2, y: 2))
                        .frame(width: thumb, height: thumb)
                        .scaleEffect(x: active ? 1.45 : 1, y: active ? 1.1 : 1)
                        .offset(x: usable * p)
                }
                .frame(height: 34)
                .contentShape(Rectangle())
                .highPriorityGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { g in
                            if !active { active = true }
                            let x = min(max(0, g.location.x - thumb / 2), usable)
                            let nv = Int((x / usable * CGFloat(maximum)).rounded())
                            if nv != value { value = nv }
                        }
                        .onEnded { _ in active = false }
                )
                .animation(.springHard, value: active)
                .animation(.spring(response: 0.22, dampingFraction: 0.8), value: value)
            }
            .frame(height: 34)
            .sensoryFeedback(.selection, trigger: value)

            if showTicks {
                HStack {
                    ForEach(0...maximum, id: \.self) { t in
                        Text("\(t)")
                            .font(.ui(11, 700))
                            .foregroundStyle(Palette.ink.opacity(0.6))
                        if t < maximum { Spacer(minLength: 0) }
                    }
                }
                .padding(.horizontal, 10)
            }
        }
    }
}

struct HandArrow: Shape {
    func path(in rect: CGRect) -> Path {
        var p = SVGPath(d: "M6 8C8 40 30 58 70 56", viewBox: CGSize(width: 90, height: 70)).path(in: rect)
        p.addPath(SVGPath(d: "M58 42 74 56 56 66", viewBox: CGSize(width: 90, height: 70)).path(in: rect))
        return p
    }
}

struct Spinner: View {
    @State private var spin = false

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.75)
            .stroke(Palette.ink, style: StrokeStyle(lineWidth: 3, lineCap: .round))
            .background(Circle().stroke(Palette.line, lineWidth: 3))
            .frame(width: 22, height: 22)
            .rotationEffect(.degrees(spin ? 360 : 0))
            .animation(.linear(duration: 0.9).repeatForever(autoreverses: false), value: spin)
            .onAppear { spin = true }
    }
}
