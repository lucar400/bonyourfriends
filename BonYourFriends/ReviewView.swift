import SwiftUI

struct ReviewView: View {
    @Environment(AppModel.self) private var model
    @State private var editing: Item?
    @State private var newName = ""
    @State private var showRaw = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    model.reset()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(RoundIconButtonStyle(fill: Palette.card, size: 44))
                Spacer()
                if !model.rawText.isEmpty && !model.meta.sample {
                    Button(showRaw ? "Artikel" : "Rohtext") { showRaw.toggle() }
                        .font(.rounded(15, .semibold))
                        .foregroundStyle(Palette.ink)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            VStack(alignment: .leading, spacing: 6) {
                Text("Stimmt das so?")
                    .font(.rounded(34, .heavy))
                    .foregroundStyle(Palette.ink)
                Text(subtitle)
                    .font(.rounded(15, .medium))
                    .foregroundStyle(Palette.muted)
                check
                    .padding(.top, 6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)

            if showRaw {
                ScrollView {
                    Text(model.rawText.joined(separator: "\n"))
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .inked(Palette.card, radius: 18, shadow: 3)
                        .padding(.horizontal, 20)
                }
            } else {
                List {
                    ForEach(model.items) { it in
                        ItemRow(item: it)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                newName = it.name
                                editing = it
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    withAnimation { model.remove(it) }
                                } label: {
                                    Label("Entfernen", systemImage: "trash")
                                }
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                    }
                    Text("Tippen zum Umbenennen, nach links wischen zum Entfernen. Pfand und Preisvorteile sind beim Artikel darüber schon eingerechnet.")
                        .font(.rounded(13, .medium))
                        .foregroundStyle(Palette.muted)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }

            Button("Los geht's · \(model.items.count) Karten") {
                model.startSwiping()
            }
            .buttonStyle(ChunkyButtonStyle(fill: Palette.yellow))
            .disabled(model.items.isEmpty)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
        }
        .alert("Name ändern", isPresented: Binding(get: { editing != nil }, set: { if !$0 { editing = nil } })) {
            TextField("Produktname", text: $newName)
            Button("Speichern") {
                if let e = editing { model.rename(e, to: newName) }
                editing = nil
            }
            Button("Abbrechen", role: .cancel) { editing = nil }
        } message: {
            if let e = editing, e.raw != e.name {
                Text("Auf dem Bon: \(e.raw)")
            }
        }
    }

    private var subtitle: String {
        var parts: [String] = []
        if !model.metaLine.isEmpty { parts.append(model.metaLine) }
        parts.append("\(model.items.count) Artikel")
        if model.namedByAI { parts.append("Namen von der KI") }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private var check: some View {
        if let total = model.meta.total {
            let diff = model.sum - total
            HStack(spacing: 8) {
                Image(systemName: diff == 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                Text(diff == 0 ? "Passt zur Summe \(euro(total))" : "Summe auf dem Bon \(euro(total)), erkannt \(euro(model.sum))")
            }
            .font(.rounded(14, .bold))
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .inked(diff == 0 ? Palette.mint : Palette.salmon, radius: 999, shadow: 2)
        } else {
            Text("Gesamt \(euro(model.sum))")
                .font(.rounded(14, .bold))
                .foregroundStyle(Palette.ink)
        }
    }
}

struct ItemRow: View {
    var item: Item

    var body: some View {
        HStack(spacing: 12) {
            Text(item.kind.emoji)
                .font(.system(size: 24))
                .frame(width: 46, height: 46)
                .inked(item.kind.tile, radius: 999, shadow: 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.rounded(16, .bold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Text(secondary)
                    .font(.rounded(13, .medium))
                    .foregroundStyle(Palette.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(euro(item.cents))
                .font(.rounded(16, .bold))
                .monospacedDigit()
                .foregroundStyle(Palette.ink)
        }
        .padding(12)
        .inked(Palette.card, radius: 20, shadow: 3)
    }

    private var secondary: String {
        var parts: [String] = []
        if !item.detail.isEmpty { parts.append(item.detail) }
        if item.discount != 0 { parts.append("Preisvorteil " + euro(item.discount)) }
        if item.deposit != 0 { parts.append("Pfand " + euro(item.deposit)) }
        if parts.isEmpty && item.raw != item.name { parts.append(item.raw) }
        return parts.isEmpty ? " " : parts.joined(separator: " · ")
    }
}
