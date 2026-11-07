import SwiftUI
import UIKit

struct ResultView: View {
    @Environment(AppModel.self) private var model
    @State private var copied = false

    var body: some View {
        let t = model.totals
        VStack(spacing: 0) {
            HStack {
                Button {
                    model.undo()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                }
                .buttonStyle(RoundIconButtonStyle(fill: Palette.card, size: 44))
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Dein Anteil")
                            .font(.rounded(16, .bold))
                            .foregroundStyle(Palette.ink.opacity(0.7))
                        Text(euro(t.mine))
                            .font(.rounded(56, .black))
                            .monospacedDigit()
                            .foregroundStyle(Palette.ink)
                            .minimumScaleFactor(0.6)
                        Text("von \(euro(t.all)) · die anderen \(euro(t.other))")
                            .font(.rounded(15, .semibold))
                            .foregroundStyle(Palette.ink.opacity(0.7))
                        if !model.metaLine.isEmpty {
                            Text(model.metaLine)
                                .font(.rounded(13, .semibold))
                                .foregroundStyle(Palette.ink.opacity(0.6))
                                .padding(.top, 2)
                        }
                    }
                    .padding(22)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .inked(Palette.yellow, radius: 28, shadow: 5)

                    VStack(spacing: 10) {
                        ForEach(model.items) { it in
                            if let d = model.decisions[it.id] {
                                ResultRow(item: it, decision: d)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }

            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    ShareLink(item: model.summaryText) {
                        Label("Teilen", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(ChunkyButtonStyle(fill: Palette.mint))
                    Button {
                        UIPasteboard.general.string = model.summaryText
                        copied = true
                    } label: {
                        Label(copied ? "Kopiert" : "Kopieren", systemImage: copied ? "checkmark" : "doc.on.doc")
                    }
                    .buttonStyle(ChunkyButtonStyle(fill: Palette.peri))
                    .sensoryFeedback(.success, trigger: copied)
                }
                HStack(spacing: 24) {
                    Button("Nochmal wischen") { model.startSwiping() }
                    Button("Neuer Bon") { model.reset() }
                }
                .font(.rounded(16, .semibold))
                .foregroundStyle(Palette.ink)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
    }
}

struct ResultRow: View {
    var item: Item
    var decision: Decision

    var body: some View {
        HStack(spacing: 12) {
            Text(item.kind.emoji)
                .font(.system(size: 20))
                .frame(width: 38, height: 38)
                .inked(item.kind.tile, radius: 999, shadow: 2)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .font(.rounded(15, .bold))
                    .lineLimit(1)
                Text(decision.label(for: item))
                    .font(.rounded(12, .semibold))
                    .foregroundStyle(Palette.muted)
            }
            Spacer(minLength: 8)
            Text(euro(decision.state == .other ? item.cents : decision.share(of: item)))
                .font(.rounded(15, .bold))
                .monospacedDigit()
                .strikethrough(decision.state == .other, color: Palette.muted)
                .foregroundStyle(decision.state == .other ? Palette.muted : Palette.ink)
        }
        .foregroundStyle(Palette.ink)
        .padding(10)
        .inked(decision.state == .other ? Palette.paper : Palette.card, radius: 18, shadow: decision.state == .other ? 0 : 3)
        .opacity(decision.state == .other ? 0.7 : 1)
    }
}
