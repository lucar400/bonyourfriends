import SwiftUI
import UIKit

struct ResultView: View {
    @Environment(AppModel.self) private var model
    @State private var copied = false
    @State private var shown = false

    var body: some View {
        let t = model.totals
        VStack(spacing: 10) {
            Dots(states: model.dotStates)
                .padding(.horizontal, 16)
            HStack(spacing: 8) {
                Button(copied ? "Kopiert" : "Kopieren") {
                    UIPasteboard.general.string = model.summaryText
                    copied = true
                }
                .buttonStyle(InkButtonStyle(kind: .dark, height: 48, fontSize: 15))
                .layoutPriority(1.15)
                .sensoryFeedback(.success, trigger: copied)
                Button("Nochmal") { model.startSwiping() }
                    .buttonStyle(InkButtonStyle(kind: .light, height: 48, fontSize: 15))
                Button("Neuer Bon") { model.reset() }
                    .buttonStyle(InkButtonStyle(kind: .light, height: 48, fontSize: 15))
            }
            .padding(.horizontal, 16)

            ScrollView {
                VStack(spacing: 14) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 0) {
                            Lab(text: "Dein Anteil")
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(plainNumber(t.mine))
                                    .font(.display(58))
                                    .tracking(-2.6)
                                    .monospacedDigit()
                                    .contentTransition(.numericText())
                                Text("€")
                                    .font(.ui(26, 600))
                            }
                            .foregroundStyle(Palette.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        }
                        Spacer(minLength: 6)
                        Text("Das zahlst du!")
                            .font(.hand(25))
                            .foregroundStyle(Palette.hand)
                            .rotationEffect(.degrees(-5))
                            .fixedSize()
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .inked(Palette.card, radius: 26)

                    Bubbles(mine: t.mine, other: t.other, all: t.all, shown: shown)
                        .frame(height: 210)

                    VStack(spacing: 0) {
                        ForEach(Array(sorted.enumerated()), id: \.element.id) { i, it in
                            if i > 0 { DashedLine() }
                            ResultRow(item: it, decision: model.decisions[it.id] ?? Decision(state: .other, count: 0))
                                .opacity(shown ? 1 : 0)
                                .offset(y: shown ? 0 : 14)
                                .animation(.springHard.delay(Double(min(i, 8)) * 0.025), value: shown)
                        }
                    }
                    .padding(4)
                    .inked(Palette.card, radius: 26)

                    Text("Zeile antippen, um die Zuordnung zu ändern. Bei Mehrfachpackungen geht es mit dem Regler.")
                        .font(.ui(13, 500))
                        .foregroundStyle(Palette.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 6)

                    Text(model.summaryText)
                        .font(.ui(13, 500))
                        .lineSpacing(4)
                        .foregroundStyle(Palette.ink)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .inked(Palette.card, radius: 20, border: 2.5, shadow: 0)

                    ShareLink(item: model.summaryText) {
                        Label("Teilen", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(LinkStyle())
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 24)
                .animation(.springSoft, value: model.decisions)
            }
            .scrollIndicators(.hidden)
        }
        .padding(.top, 8)
        .onAppear { shown = true }
    }

    private var sorted: [Item] {
        model.items.sorted { $0.cents > $1.cents }
    }
}

struct Bubbles: View {
    var mine: Int
    var other: Int
    var all: Int
    var shown: Bool

    var body: some View {
        GeometryReader { geo in
            let f = all > 0 ? max(0, min(1, Double(mine) / Double(all))) : 0
            let dm = 84 + 96 * sqrt(f)
            let dn = 84 + 96 * sqrt(1 - f)
            ZStack(alignment: .topLeading) {
                bubble("Deins", euro(mine), fill: Palette.olive, text: .white, size: dm, big: true)
                    .scaleEffect(shown ? 1 : 0.55)
                    .opacity(shown ? 1 : 0)
                    .animation(.springPop, value: shown)
                    .position(x: dm / 2, y: 8 + dm / 2)
                bubble("Nicht deins", euro(other), fill: Palette.salmon, text: Palette.ink, size: dn, big: true)
                    .scaleEffect(shown ? 1 : 0.55)
                    .opacity(shown ? 1 : 0)
                    .animation(.springPop.delay(0.05), value: shown)
                    .position(x: geo.size.width - dn / 2, y: geo.size.height - dn / 2)
                bubble("Bon", euro(all), fill: Palette.blue, text: Palette.ink, size: 88, big: false)
                    .scaleEffect(shown ? 1 : 0.55)
                    .opacity(shown ? 1 : 0)
                    .animation(.springPop.delay(0.1), value: shown)
                    .position(x: geo.size.width / 2, y: 44)
            }
            .animation(.springSoft, value: mine)
        }
    }

    private func bubble(_ label: String, _ value: String, fill: Color, text: Color, size: CGFloat, big: Bool) -> some View {
        VStack(spacing: 1) {
            Text(label)
                .font(.ui(13, 500))
                .opacity(0.75)
            Text(value)
                .font(.ui(big ? 20 : 15, 800))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .foregroundStyle(text)
        .padding(8)
        .frame(width: size, height: size)
        .background(Circle().fill(fill))
        .overlay(Circle().strokeBorder(Palette.ink, lineWidth: 3))
        .background(Circle().fill(Palette.ink).offset(x: 4, y: 4))
    }
}

struct ResultRow: View {
    @Environment(AppModel.self) private var model
    var item: Item
    var decision: Decision
    @State private var draft: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            Button {
                model.cycle(item)
            } label: {
                HStack(spacing: 12) {
                    Thumb(kind: item.kind, size: 48)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.name)
                            .font(.ui(16, 700))
                            .foregroundStyle(Palette.ink)
                            .multilineTextAlignment(.leading)
                        if !extras.isEmpty {
                            Text("inkl. " + extras)
                                .font(.ui(12, 500))
                                .foregroundStyle(Palette.muted)
                        }
                        HStack(spacing: 6) {
                            Circle().fill(chipColor).frame(width: 9, height: 9)
                            Text(decision.label(for: item))
                                .font(.ui(13, 700))
                                .foregroundStyle(chipColor)
                                .contentTransition(.opacity)
                        }
                    }
                    Spacer(minLength: 6)
                    Text(euro(item.cents))
                        .font(.ui(16, 600))
                        .monospacedDigit()
                        .foregroundStyle(Palette.ink)
                }
                .padding(.leading, 10)
                .padding(.trailing, 12)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(PressScaleStyle(scale: 0.97))
            .sensoryFeedback(.selection, trigger: decision)

            if item.qty > 2 {
                VStack(alignment: .leading, spacing: 2) {
                    (Text("Davon deine: ") + Text("\(draft)").font(.ui(12, 800)) + Text(" von \(item.qty)"))
                        .font(.ui(12, 500))
                        .foregroundStyle(Palette.muted)
                    Slider(
                        value: Binding(get: { Double(draft) }, set: { draft = Int($0.rounded()) }),
                        in: 0...Double(item.qty),
                        step: 1
                    ) { editing in
                        if !editing { model.setCount(item, draft) }
                    }
                    .tint(Palette.ink)
                }
                .padding(.leading, 70)
                .padding(.trailing, 14)
                .padding(.bottom, 12)
            }
        }
        .onAppear { draft = decision.count }
        .onChange(of: decision) { _, d in draft = d.count }
    }

    private var extras: String {
        var parts: [String] = []
        if item.discount != 0 { parts.append("Preisvorteil " + signed(item.discount)) }
        if item.deposit != 0 { parts.append("Pfand " + signed(item.deposit)) }
        return parts.joined(separator: " · ")
    }

    private var chipColor: Color {
        switch decision.state {
        case .mine, .part: Palette.mineText
        case .other: Palette.otherText
        case .split: Palette.splitText
        }
    }
}
