import SwiftUI

enum Mood {
    case neutral, happy, sad
}

struct SwipeView: View {
    @Environment(AppModel.self) private var model
    @State private var drag: CGSize = .zero
    @State private var flying: Choice?
    @State private var count = 1
    @State private var tick = 0
    @State private var hop = 0
    @State private var entered = false

    var body: some View {
        VStack(spacing: 8) {
            TopBar(onHome: { model.goHome() })
                .padding(.horizontal, 16)
            Dots(states: model.dotStates)
                .padding(.horizontal, 16)
                .animation(.springPop, value: model.index)

            GeometryReader { geo in
                let layers = min(6, max(0, model.items.count - 1))
                let step: CGFloat = 7
                let cardHeight = geo.size.height - CGFloat(layers) * step
                ZStack(alignment: .top) {
                    ForEach(Array(stack(layers).enumerated().reversed()), id: \.element.id) { pair in
                        let k = pair.offset
                        let item = pair.element
                        let top = k == 0
                        Group {
                            if k < 2 {
                                ItemCard(
                                    item: item,
                                    position: (model.items.firstIndex(of: item) ?? 0) + 1,
                                    total: model.items.count,
                                    count: top ? $count : .constant(item.qty),
                                    progress: top ? progress : .zero,
                                    mood: top ? mood : .neutral,
                                    hop: hop,
                                    coach: top && model.index == 0 && drag == .zero
                                )
                            } else {
                                PileCard(kind: item.kind)
                            }
                        }
                        .frame(width: geo.size.width, height: cardHeight)
                        .scaleEffect(1 - CGFloat(k) * 0.016, anchor: .bottom)
                        .rotationEffect(.degrees(top ? Double(drag.width / 18) : tilt(item.id)))
                        .offset(y: CGFloat(k) * step)
                        .offset(top ? visibleDrag : .zero)
                        .allowsHitTesting(top && flying == nil)
                        .zIndex(Double(10 - k))
                        .transition(.asymmetric(insertion: .opacity, removal: .identity))
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
                .gesture(dragGesture)
                .animation(.springSoft, value: model.index)
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 4)

            nav
                .padding(.bottom, 6)
        }
        .padding(.top, 8)
        .sensoryFeedback(.impact(weight: .medium), trigger: tick)
        .onAppear {
            syncCount()
            entered = true
        }
        .onChange(of: model.index) { _, _ in syncCount() }
    }

    private func stack(_ layers: Int) -> [Item] {
        Array(model.items.dropFirst(model.index).prefix(layers + 1))
    }

    private func tilt(_ id: Int) -> Double {
        let s = Double((id * 37) % 7) / 6
        return (id % 2 == 0 ? 1 : -1) * (0.5 + 1.1 * s)
    }

    private var visibleDrag: CGSize {
        CGSize(width: drag.width, height: drag.height > 0 ? rubber(drag.height, 120) : drag.height)
    }

    private func rubber(_ o: CGFloat, _ limit: CGFloat) -> CGFloat {
        (o * limit * 0.55) / (limit + 0.55 * abs(o))
    }

    private var progress: SwipeProgress {
        let m = min(1, max(0, drag.width / 90))
        let o = min(1, max(0, -drag.width / 90))
        let up = abs(drag.width) < 70 ? min(1, max(0, -drag.height / 100)) : 0
        switch flying {
        case .mine: return SwipeProgress(mine: 1, other: 0, split: 0)
        case .other: return SwipeProgress(mine: 0, other: 1, split: 0)
        case .split: return SwipeProgress(mine: 0, other: 0, split: 1)
        case nil: return SwipeProgress(mine: m, other: o, split: up)
        }
    }

    private var mood: Mood {
        let p = progress
        if p.other > 0.12 { return .happy }
        if p.mine > 0.12 { return .sad }
        return .neutral
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { v in
                guard flying == nil else { return }
                let before = mood
                drag = v.translation
                if mood == .happy && before != .happy { hop += 1 }
            }
            .onEnded { v in
                guard flying == nil else { return }
                let dx = v.translation.width
                let dy = v.translation.height
                let vx = abs(v.velocity.width) / 1000
                if dx > 100 || (dx > 45 && vx > 0.55) {
                    fling(.mine)
                } else if dx < -100 || (dx < -45 && vx > 0.55) {
                    fling(.other)
                } else if dy < -110 && abs(dx) < 80 {
                    fling(.split)
                } else {
                    withAnimation(.springSoft) { drag = .zero }
                }
            }
    }

    private var nav: some View {
        HStack(spacing: 6) {
            Button { fling(.other) } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.white)
                    .frame(width: 60, height: 52)
                    .background(Capsule().fill(Palette.red))
                    .overlay(Capsule().strokeBorder(Palette.ink, lineWidth: 2.5))
            }
            .buttonStyle(PressScaleStyle())
            .accessibilityLabel("Nicht meins")
            Button { fling(.split) } label: {
                Text("½")
                    .font(.ui(24, 800))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 60, height: 52)
                    .contentShape(Capsule())
            }
            .buttonStyle(PressScaleStyle())
            .accessibilityLabel("Geteilt, je zur Hälfte")
            Button { fling(.mine) } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.white)
                    .frame(width: 84, height: 52)
                    .background(Capsule().fill(Palette.ink))
            }
            .buttonStyle(PressScaleStyle())
            .accessibilityLabel("Meins")
        }
        .padding(6)
        .inked(Palette.card, radius: 999, border: 3, shadow: 4)
        .disabled(flying != nil)
    }

    private func fling(_ choice: Choice) {
        guard flying == nil, let item = model.current else { return }
        tick += 1
        if choice == .other { hop += 1 }
        withAnimation(.easeOut(duration: 0.1)) { flying = choice }
        let target: CGSize
        switch choice {
        case .mine: target = CGSize(width: 560, height: 40)
        case .other: target = CGSize(width: -560, height: 40)
        case .split: target = CGSize(width: 0, height: -900)
        }
        withAnimation(.timingCurve(0.2, 0.9, 0.3, 1, duration: 0.17)) { drag = target }
        let chosen = count
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(170))
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) {
                drag = .zero
                flying = nil
            }
            withAnimation(.springSoft) {
                model.decide(choice, count: choice == .mine && item.qty > 2 ? chosen : nil)
            }
        }
    }

    private func syncCount() {
        count = model.current?.qty ?? 1
    }
}

struct PileCard: View {
    var kind: Kind

    var body: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(kind.tile)
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Color.black.opacity(0.04)))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(Palette.ink, lineWidth: 2.5))
    }
}

struct SwipeProgress: Equatable {
    var mine: CGFloat
    var other: CGFloat
    var split: CGFloat
    static let zero = SwipeProgress(mine: 0, other: 0, split: 0)
}

struct TopBar: View {
    @Environment(AppModel.self) private var model
    var onHome: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 2) {
                Lab(text: model.metaLine.isEmpty ? "Dein Bon" : model.metaLine, size: 13)
                    .padding(.trailing, 56)
                HStack(spacing: 6) {
                    Headline(plain: "Was war", size: 32)
                    Highlight(text: "deins", size: 32)
                    Headline(plain: "?", size: 32)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onHome) {
                Image(systemName: "house")
            }
            .buttonStyle(CircleIconButtonStyle(size: 42))
            .accessibilityLabel("Zum Hauptmenü")
        }
    }
}

struct ItemCard: View {
    var item: Item
    var position: Int
    var total: Int
    @Binding var count: Int
    var progress: SwipeProgress
    var mood: Mood
    var hop: Int
    var coach: Bool
    @State private var qpop = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(String(format: "Pos. %02d / %02d", position, total))
                    .font(.ui(13, 600))
                    .opacity(0.65)
                Spacer()
                if item.qty > 1 {
                    Text("\(item.qty) Stück")
                        .font(.ui(12, 700))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Palette.ink))
                }
            }
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.display(28))
                    .tracking(-1)
                    .foregroundStyle(Palette.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                if !item.detail.isEmpty {
                    Text(item.detail)
                        .font(.ui(13, 600))
                        .foregroundStyle(Palette.ink.opacity(0.7))
                }
            }
            .padding(.horizontal, 6)

            art
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if item.qty > 2 {
                qtyBox
            }
            priceBox
        }
        .padding(.horizontal, 12)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .background(item.kind.tile)
        .overlay {
            ZStack {
                Palette.olive.opacity(progress.mine * 0.3)
                Palette.salmon.opacity(progress.other * 0.3)
                Palette.yellow.opacity(progress.split * 0.3)
            }
            .allowsHitTesting(false)
        }
        .overlay(alignment: .topLeading) {
            stamp(count < item.qty && item.qty > 2 ? "\(count) von \(item.qty)" : "Meins", color: Palette.mineText, angle: -8)
                .opacity(progress.mine)
                .padding(.leading, 18)
                .padding(.top, 56)
        }
        .overlay(alignment: .topTrailing) {
            stamp("Nicht meins", color: Palette.otherText, angle: 8)
                .opacity(progress.other)
                .padding(.trailing, 18)
                .padding(.top, 56)
        }
        .overlay(alignment: .top) {
            stamp("Geteilt", color: Palette.splitText, angle: 0)
                .opacity(progress.split)
                .padding(.top, 100)
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(Palette.ink, lineWidth: 3))
        .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Palette.ink).offset(x: 5, y: 5))
    }

    private var art: some View {
        ZStack {
            Blob(seed: item.id)
                .fill(Color.white.opacity(0.55))
                .frame(maxWidth: 270, maxHeight: 270)
                .padding(4)
            Image("art-\(item.kind.rawValue)-\(moodKey)")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 240, maxHeight: 240)
                .scaleEffect(mood == .sad ? 0.95 : 1)
                .offset(y: mood == .sad ? 6 : 0)
                .keyframeAnimator(initialValue: 0.0, trigger: hop) { v, y in
                    v.offset(y: y)
                } keyframes: { _ in
                    KeyframeTrack {
                        CubicKeyframe(-14, duration: 0.16)
                        CubicKeyframe(0, duration: 0.17)
                        CubicKeyframe(-5, duration: 0.09)
                        CubicKeyframe(0, duration: 0.1)
                    }
                }
                .animation(.springHard, value: mood)
            if item.qty > 2 {
                VStack(spacing: 0) {
                    Text("\(count)")
                        .font(.ui(30, 800))
                        .tracking(-1)
                        .contentTransition(.numericText())
                    Text("von \(item.qty)")
                        .font(.ui(11, 700))
                }
                .foregroundStyle(Palette.ink)
                .frame(width: 66, height: 66)
                .background(Circle().fill(count < item.qty ? Color.white : Palette.yellow))
                .overlay(Circle().strokeBorder(Palette.ink, lineWidth: 3))
                .background(Circle().fill(Palette.ink).offset(x: 3, y: 3))
                .rotationEffect(.degrees(8))
                .keyframeAnimator(initialValue: 1.0, trigger: count) { v, s in
                    v.scaleEffect(s)
                } keyframes: { _ in
                    KeyframeTrack {
                        CubicKeyframe(1.4, duration: 0.18)
                        CubicKeyframe(0.94, duration: 0.12)
                        CubicKeyframe(1, duration: 0.12)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, 8)
                .padding(.bottom, 4)
                .allowsHitTesting(false)
            }
            if coach {
                Text("Rechts = meins · Links = nicht meins · Hoch = geteilt")
                    .font(.ui(11, 700))
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.white))
                    .overlay(Capsule().strokeBorder(Palette.ink, lineWidth: 2.5))
                    .frame(maxHeight: .infinity, alignment: .top)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
    }

    private var moodKey: String {
        switch mood {
        case .neutral: "n"
        case .happy: "h"
        case .sad: "s"
        }
    }

    private var qtyBox: some View {
        VStack(spacing: 2) {
            Text("Wie viele waren deine?")
                .font(.ui(13, 700))
                .foregroundStyle(Palette.ink)
            InkSlider(value: $count, maximum: item.qty)
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .inked(Color.white, radius: 20, border: 2.5, shadow: 0)
    }

    private var priceBox: some View {
        VStack(spacing: 4) {
            if item.discount != 0 || item.deposit != 0 {
                VStack(spacing: 1) {
                    ledger("Preis", euro(item.cents - item.discount - item.deposit), good: false)
                    if item.discount != 0 { ledger("Preisvorteil", signed(item.discount), good: true) }
                    if item.deposit != 0 { ledger("Pfand", signed(item.deposit), good: false) }
                }
            }
            HStack(alignment: .firstTextBaseline) {
                Text(item.discount != 0 || item.deposit != 0 ? "Zu zahlen" : "Preis")
                    .font(.ui(13, 500))
                    .foregroundStyle(Palette.ledger)
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(plainNumber(item.cents))
                        .font(.display(42))
                        .tracking(-1.6)
                        .monospacedDigit()
                    Text("€")
                        .font(.ui(19, 600))
                }
                .foregroundStyle(item.cents < 0 ? Palette.mineText : Palette.ink)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .inked(Color.white, radius: 20, border: 2.5, shadow: 0)
    }

    private func ledger(_ label: String, _ value: String, good: Bool) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).monospacedDigit()
        }
        .font(.ui(12, good ? 700 : 500))
        .foregroundStyle(good ? Palette.mineText : Palette.ledger)
    }

    private func stamp(_ text: String, color: Color, angle: Double) -> some View {
        Text(text.uppercased())
            .font(.ui(19, 800))
            .tracking(0.4)
            .foregroundStyle(color)
            .padding(.horizontal, 18)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(color, lineWidth: 3))
            .background(RoundedRectangle(cornerRadius: 14).fill(color).offset(x: 3, y: 3))
            .rotationEffect(.degrees(angle))
            .allowsHitTesting(false)
    }
}

func plainNumber(_ cents: Int) -> String {
    let sign = cents < 0 ? "−" : ""
    let v = abs(cents)
    return sign + "\(v / 100)," + String(format: "%02d", v % 100)
}
