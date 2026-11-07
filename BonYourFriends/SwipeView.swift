import SwiftUI

struct SwipeView: View {
    @Environment(AppModel.self) private var model
    @State private var drag: CGSize = .zero
    @State private var flying: Choice?
    @State private var count = 1
    @State private var tick = 0

    private let threshold: CGFloat = 110

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 20)
                .padding(.top, 8)

            progress
                .padding(.horizontal, 24)
                .padding(.top, 14)

            ZStack {
                ForEach(Array(upcoming.enumerated().reversed()), id: \.element.id) { pair in
                    let depth = pair.offset
                    let item = pair.element
                    let top = depth == 0
                    ItemCard(item: item, count: top ? $count : .constant(item.qty), lean: top ? lean : nil)
                        .scaleEffect(1 - CGFloat(depth) * 0.05)
                        .offset(y: CGFloat(depth) * 14)
                        .rotationEffect(.degrees(top ? Double(drag.width / 18) : Double(depth) * (depth % 2 == 0 ? 2 : -2)))
                        .offset(top ? drag : .zero)
                        .allowsHitTesting(top)
                        .gesture(dragGesture())
                        .zIndex(Double(10 - depth))
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 22)
            .frame(maxHeight: .infinity)

            controls
                .padding(.bottom, 18)
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: tick)
        .onAppear { syncCount() }
        .onChange(of: model.index) { _, _ in syncCount() }
    }

    private var upcoming: [Item] {
        Array(model.items.dropFirst(model.index).prefix(3))
    }

    private var lean: Choice? {
        if let flying { return flying }
        if drag.width > 40 { return .mine }
        if drag.width < -40 { return .other }
        if drag.height < -60 { return .split }
        return nil
    }

    private var header: some View {
        HStack {
            Button {
                model.reset()
            } label: {
                Image(systemName: "house")
            }
            .buttonStyle(RoundIconButtonStyle(fill: Palette.card, size: 44))
            Spacer()
            VStack(spacing: 0) {
                Text("Dein Anteil")
                    .font(.rounded(12, .semibold))
                    .foregroundStyle(Palette.muted)
                Text(euro(model.totals.mine))
                    .font(.rounded(22, .heavy))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(Palette.ink)
            }
            Spacer()
            Button {
                model.undo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .buttonStyle(RoundIconButtonStyle(fill: Palette.card, size: 44))
            .disabled(model.index == 0)
            .opacity(model.index == 0 ? 0.4 : 1)
        }
    }

    private var progress: some View {
        GeometryReader { geo in
            let total = max(1, model.items.count)
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.card)
                Capsule()
                    .fill(Palette.olive)
                    .frame(width: geo.size.width * CGFloat(model.index) / CGFloat(total))
                    .animation(.snappy, value: model.index)
            }
            .overlay(Capsule().stroke(Palette.ink, lineWidth: 2.5))
        }
        .frame(height: 14)
        .overlay(alignment: .trailing) {
            Text("\(min(model.index + 1, model.items.count)) / \(model.items.count)")
                .font(.rounded(12, .bold))
                .monospacedDigit()
                .foregroundStyle(Palette.ink)
                .offset(y: 18)
        }
    }

    private var controls: some View {
        HStack(spacing: 26) {
            VStack(spacing: 6) {
                Button { fling(.other) } label: { Image(systemName: "xmark") }
                    .buttonStyle(RoundIconButtonStyle(fill: Palette.salmon, size: 72))
                Text("Nicht deins").font(.rounded(12, .bold)).foregroundStyle(Palette.ink)
            }
            VStack(spacing: 6) {
                Button { fling(.split) } label: { Text("½") }
                    .buttonStyle(RoundIconButtonStyle(fill: Palette.blue, size: 58))
                Text("Teilen").font(.rounded(12, .bold)).foregroundStyle(Palette.ink)
            }
            VStack(spacing: 6) {
                Button { fling(.mine) } label: { Image(systemName: "checkmark") }
                    .buttonStyle(RoundIconButtonStyle(fill: Palette.mint, size: 72))
                Text("Deins").font(.rounded(12, .bold)).foregroundStyle(Palette.ink)
            }
        }
        .disabled(flying != nil)
    }

    private func dragGesture() -> some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { v in
                guard flying == nil else { return }
                drag = v.translation
            }
            .onEnded { v in
                guard flying == nil else { return }
                let w = v.translation.width + v.predictedEndTranslation.width * 0.25
                let h = v.translation.height + v.predictedEndTranslation.height * 0.25
                if w > threshold {
                    fling(.mine)
                } else if w < -threshold {
                    fling(.other)
                } else if h < -threshold * 1.3 && abs(w) < threshold {
                    fling(.split)
                } else {
                    withAnimation(.spring(duration: 0.35, bounce: 0.45)) { drag = .zero }
                }
            }
    }

    private func fling(_ choice: Choice) {
        guard flying == nil, let item = model.current else { return }
        flying = choice
        tick += 1
        let target: CGSize
        switch choice {
        case .mine: target = CGSize(width: 600, height: drag.height + 40)
        case .other: target = CGSize(width: -600, height: drag.height + 40)
        case .split: target = CGSize(width: drag.width, height: -900)
        }
        withAnimation(.easeIn(duration: 0.2)) { drag = target }
        let chosen = count
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(200))
            withAnimation(.snappy) {
                model.decide(choice, count: choice == .mine && item.qty > 1 ? chosen : nil)
            }
            drag = .zero
            flying = nil
        }
    }

    private func syncCount() {
        count = model.current?.qty ?? 1
    }
}

struct ItemCard: View {
    var item: Item
    @Binding var count: Int
    var lean: Choice?

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                item.kind.tile
                Text(item.kind.emoji)
                    .font(.system(size: 96))
                    .rotationEffect(.degrees(lean == .mine ? 8 : lean == .other ? -8 : 0))
                    .scaleEffect(lean == nil ? 1 : 1.08)
                    .animation(.spring(duration: 0.3, bounce: 0.5), value: lean)
                stamp
            }
            .frame(maxWidth: .infinity)
            .frame(height: 220)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Palette.ink).frame(height: 2.5)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(item.name)
                    .font(.rounded(26, .heavy))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                HStack(alignment: .firstTextBaseline) {
                    Text(details)
                        .font(.rounded(14, .medium))
                        .foregroundStyle(Palette.muted)
                        .lineLimit(2)
                    Spacer(minLength: 8)
                    Text(euro(item.cents))
                        .font(.rounded(24, .heavy))
                        .monospacedDigit()
                        .foregroundStyle(Palette.ink)
                }
                if item.qty > 1 {
                    slider
                        .padding(.top, 4)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.card)
        }
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).stroke(Palette.ink, lineWidth: 2.5))
        .background(RoundedRectangle(cornerRadius: 30, style: .continuous).fill(Palette.ink).offset(x: 5, y: 5))
    }

    private var details: String {
        var parts: [String] = []
        if !item.detail.isEmpty { parts.append(item.detail) }
        if item.discount != 0 { parts.append("inkl. Preisvorteil " + euro(item.discount)) }
        if item.deposit != 0 { parts.append("inkl. Pfand " + euro(item.deposit)) }
        return parts.joined(separator: " · ")
    }

    private var slider: some View {
        VStack(spacing: 4) {
            HStack {
                Text("Davon deins")
                    .font(.rounded(13, .bold))
                Spacer()
                Text("\(count) von \(item.qty) · \(euro(Int((Double(item.cents) * Double(count) / Double(item.qty)).rounded())))")
                    .font(.rounded(14, .heavy))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            .foregroundStyle(Palette.ink)
            Slider(
                value: Binding(get: { Double(count) }, set: { count = Int($0.rounded()) }),
                in: 0...Double(item.qty),
                step: 1
            )
            .tint(Palette.olive)
            .sensoryFeedback(.selection, trigger: count)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .inked(Palette.yellow.opacity(0.35), radius: 18, shadow: 0)
    }

    @ViewBuilder
    private var stamp: some View {
        if let lean {
            let text = lean == .mine ? "DEINS" : lean == .other ? "NICHT DEINS" : "GETEILT"
            let fill = lean == .mine ? Palette.mint : lean == .other ? Palette.salmon : Palette.blue
            Text(text)
                .font(.rounded(26, .black))
                .foregroundStyle(Palette.ink)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .inked(fill, radius: 14, shadow: 3)
                .rotationEffect(.degrees(lean == .other ? 10 : -10))
                .transition(.scale(scale: 0.6).combined(with: .opacity))
        }
    }
}
