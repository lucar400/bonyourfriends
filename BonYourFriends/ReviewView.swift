import SwiftUI

struct ReviewView: View {
    @Environment(AppModel.self) private var model
    @State private var editing: Item?
    @State private var newName = ""
    @State private var showRaw = false
    @State private var shown = false

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                hero
                VStack(spacing: 10) {
                    Button { model.startSwiping() } label: { Label("Let’s split!", systemImage: "rectangle.stack") }
                        .buttonStyle(InkButtonStyle(kind: .dark, height: 54))
                        .disabled(model.items.isEmpty)
                        .opacity(model.items.isEmpty ? 0.4 : 1)
                    HStack(spacing: 10) {
                        Button("Weiteren Bon hinzufügen") { model.addAnother() }
                            .buttonStyle(InkButtonStyle(kind: .light, height: 54))
                        Button("Neu einlesen") { model.reset() }
                            .buttonStyle(InkButtonStyle(kind: .light, height: 54))
                    }
                }
                if showRaw {
                    Text(model.rawText.joined(separator: "\n"))
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .inked(Palette.card, radius: 20, border: 2.5, shadow: 3)
                } else {
                    list
                }
                Text("Preisvorteil und Pfand sind schon beim Artikel darüber eingerechnet. Tippen zum Umbenennen, mit dem Kreuz entfernst du Zeilen, die nicht zum Einkauf gehören.")
                    .font(.ui(13, 500))
                    .foregroundStyle(Palette.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 6)
                if !model.rawText.isEmpty && !model.meta.sample {
                    Button(showRaw ? "Artikelliste zeigen" : "Erkannten Rohtext zeigen") {
                        withAnimation(.springSoft) { showRaw.toggle() }
                    }
                    .buttonStyle(LinkStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .onAppear { shown = true }
        .alert("Name ändern", isPresented: Binding(get: { editing != nil }, set: { if !$0 { editing = nil } })) {
            TextField("Produktname", text: $newName)
            Button("Speichern") {
                if let e = editing { model.rename(e, to: newName) }
                editing = nil
            }
            Button("Abbrechen", role: .cancel) { editing = nil }
        } message: {
            if let e = editing, e.raw.lowercased() != e.name.lowercased() {
                Text("Auf dem Bon: \(e.raw)")
            }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 8) {
            Lab(text: subtitle)
            HStack(spacing: 10) {
                Highlight(text: "\(model.items.count) Artikel", size: 34)
                Headline(plain: "erkannt", size: 34)
            }
            .padding(.vertical, 4)
            check
                .padding(.top, 4)
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .inked(Palette.hero, radius: 28)
    }

    private var subtitle: String {
        var parts = model.metaParts
        if model.namedByAI { parts.append("Namen von der KI") }
        return parts.isEmpty ? "Dein Bon" : parts.joined(separator: " · ")
    }

    private var check: some View {
        let sum = model.sum
        let total = model.meta.total
        let ok = total == sum
        let msg: String
        if let total {
            msg = ok ? "Summe stimmt mit dem Bon überein: \(euro(sum))" : "Artikel \(euro(sum)), Bon \(euro(total)). Differenz \(euro(sum - total)). Prüfe die Liste."
        } else {
            msg = "Summe \(euro(sum)). Bon-Betrag nicht erkannt."
        }
        return HStack(spacing: 12) {
            Text(msg)
                .font(.ui(15, 600))
                .foregroundStyle(Palette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: ok ? "checkmark" : "exclamationmark")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Palette.ink)
                .frame(width: 38, height: 38)
                .background(Circle().fill(ok ? Palette.yellow : Palette.salmon))
                .overlay(Circle().strokeBorder(Palette.ink, lineWidth: 2))
        }
        .padding(.leading, 16)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.white))
        .overlay(Capsule().strokeBorder(Palette.ink, lineWidth: 2.5))
    }

    private var list: some View {
        VStack(spacing: 0) {
            ForEach(Array(model.items.enumerated()), id: \.element.id) { i, it in
                if i > 0 { DashedLine() }
                ReviewRow(item: it) {
                    withAnimation(.springSoft) { model.remove(it) }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    newName = it.name
                    editing = it
                }
                .opacity(shown ? 1 : 0)
                .offset(y: shown ? 0 : 14)
                .animation(.springHard.delay(Double(min(i, 8)) * 0.025), value: shown)
                .transition(.asymmetric(insertion: .opacity, removal: .scale(scale: 0.9).combined(with: .opacity)))
            }
        }
        .padding(4)
        .inked(Palette.card, radius: 26)
    }
}

struct DashedLine: View {
    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(height: 2)
            .overlay(
                GeometryReader { g in
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: 1))
                        p.addLine(to: CGPoint(x: g.size.width, y: 1))
                    }
                    .stroke(Palette.line, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                }
            )
            .padding(.horizontal, 6)
    }
}

struct ReviewRow: View {
    var item: Item
    var onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Thumb(kind: item.kind, size: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.ui(16, 700))
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if !detail.isEmpty {
                    Text(detail)
                        .font(.ui(12, 500))
                        .foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 6)
            Text(euro(item.cents))
                .font(.ui(16, 600))
                .monospacedDigit()
                .foregroundStyle(item.cents < 0 ? Palette.mineText : Palette.ink)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 40, height: 40)
                    .contentShape(Circle())
            }
            .buttonStyle(PressScaleStyle())
            .accessibilityLabel("\(item.name) entfernen")
        }
        .padding(.leading, 10)
        .padding(.trailing, 4)
        .padding(.vertical, 10)
    }

    private var detail: String {
        var parts: [String] = []
        if !item.detail.isEmpty { parts.append(item.detail) }
        if item.discount != 0 { parts.append("Preisvorteil " + signed(item.discount)) }
        if item.deposit != 0 { parts.append("Pfand " + signed(item.deposit)) }
        if !item.raw.isEmpty, item.raw.lowercased() != item.name.lowercased() { parts.append("Bon: " + item.raw) }
        return parts.joined(separator: " · ")
    }
}

func signed(_ cents: Int) -> String {
    (cents < 0 ? "−" : "+") + euro(abs(cents))
}
