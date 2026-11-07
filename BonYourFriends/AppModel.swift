import SwiftUI
import Observation

@MainActor
@Observable
final class AppModel {
    enum Screen {
        case home, review, swipe, result
    }

    var screen: Screen = .home
    var items: [Item] = []
    var meta = ReceiptMeta()
    var decisions: [Int: Decision] = [:]
    var index = 0
    var busy = false
    var status = ""
    var error: String?
    var rawText: [String] = []
    var namedByAI = false

    var current: Item? {
        index < items.count ? items[index] : nil
    }

    var sum: Int {
        items.reduce(0) { $0 + $1.cents }
    }

    var totals: (mine: Int, other: Int, all: Int) {
        var mine = 0
        for it in items {
            if let d = decisions[it.id] { mine += d.share(of: it) }
        }
        return (mine, sum - mine, sum)
    }

    var metaLine: String {
        var parts: [String] = []
        if let s = meta.store { parts.append(s) }
        if let d = meta.date { parts.append(d) }
        if meta.sample { parts.append("Beispiel") }
        return parts.joined(separator: " · ")
    }

    func analyze(_ images: [UIImage]) async {
        guard !images.isEmpty else { return }
        busy = true
        error = nil
        status = "Lese den Bon …"
        defer { busy = false }
        do {
            let lines = try await TextReader.lines(from: images)
            rawText = lines
            let parsed = ReceiptParser.parse(lines)
            guard !parsed.lines.isEmpty else {
                error = "Auf dem Foto habe ich keine Artikel mit Preis gefunden. Versuch es mit mehr Licht und dem ganzen Bon im Bild."
                return
            }
            status = Namer.isAvailable ? "KI räumt die Namen auf …" : "Sortiere die Artikel …"
            let names = await Namer.name(parsed.lines, store: parsed.meta.store)
            namedByAI = !names.isEmpty
            items = ItemBuilder.build(parsed.lines, names: names, total: parsed.meta.total)
            meta = parsed.meta
            decisions = [:]
            index = 0
            withAnimation(.snappy) { screen = .review }
        } catch {
            self.error = "Die Texterkennung hat nicht geklappt: \(error.localizedDescription)"
        }
    }

    func loadDemo() {
        items = Demo.lines
        meta = ReceiptMeta(store: "Markt am Eck", date: "03.11.2026", total: nil, sample: true)
        meta.total = sum
        decisions = [:]
        index = 0
        namedByAI = false
        withAnimation(.snappy) { screen = .review }
    }

    func remove(_ item: Item) {
        items.removeAll { $0.id == item.id }
    }

    func rename(_ item: Item, to name: String) {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty, let i = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[i].name = n
    }

    func startSwiping() {
        decisions = [:]
        index = 0
        withAnimation(.snappy) { screen = items.isEmpty ? .review : .swipe }
    }

    func decide(_ choice: Choice, count: Int? = nil) {
        guard let it = current else { return }
        if choice == .mine, let count {
            decisions[it.id] = Decision.from(count: count, item: it)
        } else {
            decisions[it.id] = Decision.from(choice, item: it)
        }
        index += 1
        if index >= items.count {
            withAnimation(.snappy) { screen = .result }
        }
    }

    func undo() {
        guard index > 0 else { return }
        index -= 1
        decisions[items[index].id] = nil
        if screen == .result {
            withAnimation(.snappy) { screen = .swipe }
        }
    }

    func reset() {
        items = []
        decisions = [:]
        index = 0
        meta = ReceiptMeta()
        error = nil
        withAnimation(.snappy) { screen = .home }
    }

    var summaryText: String {
        let t = totals
        var lines = ["Bon your Friends" +(metaLine.isEmpty ? "" : " · " + metaLine), "Mein Anteil: " + euro(t.mine) + " von " + euro(t.all), ""]
        for it in items {
            guard let d = decisions[it.id], d.state != .other else { continue }
            var note = ""
            if d.state == .split { note = " (geteilt)" }
            if d.state == .part { note = " (\(d.count) von \(it.qty))" }
            lines.append(it.name + note + "  " + euro(d.share(of: it)))
        }
        return lines.joined(separator: "\n")
    }
}
