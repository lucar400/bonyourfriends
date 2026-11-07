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
    var appendMode = false
    var busyImage: UIImage?
    var lastChoice: Choice?

    @ObservationIgnored private var job: Task<Void, Never>?

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

    var metaParts: [String] {
        var parts: [String] = []
        if let s = meta.store { parts.append(s) }
        if let d = meta.date { parts.append(d) }
        if meta.sample { parts.append("Beispielbon") }
        return parts
    }

    var metaLine: String {
        metaParts.joined(separator: " · ")
    }

    var dotStates: [DotState] {
        items.enumerated().map { i, it in
            if let d = decisions[it.id] {
                switch d.state {
                case .mine: return .mine
                case .other: return .other
                case .split: return .split
                case .part: return .part
                }
            }
            return i == index ? .now : .off
        }
    }

    func scan(_ images: [UIImage]) {
        guard !images.isEmpty else { return }
        busyImage = images.first
        run { try await TextReader.lines(from: images) }
    }

    func read(text: String) {
        let lines = text.components(separatedBy: .newlines)
        busyImage = nil
        run { lines }
    }

    func cancel() {
        job?.cancel()
        job = nil
        busy = false
    }

    private func run(_ source: @escaping () async throws -> [String]) {
        job?.cancel()
        busy = true
        error = nil
        status = "Cheffe liest den Bon"
        job = Task { [weak self] in
            guard let self else { return }
            defer { if !Task.isCancelled { self.busy = false } }
            do {
                let lines = try await source()
                if Task.isCancelled { return }
                self.rawText = lines
                let parsed = ReceiptParser.parse(lines)
                guard !parsed.lines.isEmpty else {
                    self.error = "Auf dem Bon habe ich keine Artikel mit Preis gefunden. Versuch es mit mehr Licht und dem ganzen Bon im Bild."
                    return
                }
                self.status = Namer.isAvailable ? "Die KI schreibt die Namen aus" : "Sortiere die Artikel"
                let names = await Namer.name(parsed.lines, store: parsed.meta.store)
                if Task.isCancelled { return }
                let fresh = ItemBuilder.build(parsed.lines, names: names, total: parsed.meta.total)
                self.namedByAI = !names.isEmpty
                if self.appendMode && !self.items.isEmpty {
                    let merged = self.items + fresh
                    self.items = merged.enumerated().map { i, it in
                        Item(id: i + 1, name: it.name, raw: it.raw, detail: it.detail, cents: it.cents, qty: it.qty, kind: it.kind, discount: it.discount, deposit: it.deposit)
                    }
                    self.meta = Self.combine(self.meta, parsed.meta)
                } else {
                    self.items = fresh
                    self.meta = parsed.meta
                }
                self.appendMode = false
                self.decisions = [:]
                self.index = 0
                withAnimation(.springSoft) { self.screen = .review }
            } catch {
                if Task.isCancelled { return }
                self.error = "Die Texterkennung hat nicht geklappt: \(error.localizedDescription)"
            }
        }
    }

    private static func combine(_ a: ReceiptMeta, _ b: ReceiptMeta) -> ReceiptMeta {
        var m = ReceiptMeta()
        let stores = [a.store, b.store].compactMap { $0 }
        m.store = stores.isEmpty ? nil : stores.joined(separator: " + ")
        m.date = a.date ?? b.date
        if let x = a.total, let y = b.total { m.total = x + y }
        return m
    }

    func loadDemo() {
        items = Demo.lines
        meta = ReceiptMeta(store: "Markt am Eck", date: "03.11.2026", total: nil, sample: true)
        meta.total = sum
        decisions = [:]
        index = 0
        namedByAI = false
        rawText = []
        withAnimation(.springSoft) { screen = .review }
    }

    func remove(_ item: Item) {
        items.removeAll { $0.id == item.id }
    }

    func rename(_ item: Item, to name: String) {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty, let i = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[i].name = n
    }

    func addAnother() {
        appendMode = true
        error = nil
        withAnimation(.springSoft) { screen = .home }
    }

    func cancelAppend() {
        appendMode = false
        withAnimation(.springSoft) { screen = .review }
    }

    func startSwiping() {
        decisions = [:]
        index = 0
        withAnimation(.springSoft) { screen = items.isEmpty ? .review : .swipe }
    }

    func decide(_ choice: Choice, count: Int? = nil) {
        guard let it = current else { return }
        if choice == .mine, let count {
            decisions[it.id] = Decision.from(count: count, item: it)
        } else {
            decisions[it.id] = Decision.from(choice, item: it)
        }
        lastChoice = choice
        index += 1
        if index >= items.count {
            withAnimation(.springSoft) { screen = .result }
        }
    }

    func undo() {
        guard index > 0 else { return }
        index -= 1
        decisions[items[index].id] = nil
        if screen == .result {
            withAnimation(.springSoft) { screen = .swipe }
        }
    }

    func cycle(_ item: Item) {
        let order: [Choice] = [.mine, .other, .split]
        let now: Choice = switch decisions[item.id]?.state {
        case .mine: .mine
        case .other: .other
        case .split: .split
        default: .split
        }
        let next = order[(order.firstIndex(of: now)! + 1) % order.count]
        decisions[item.id] = Decision.from(next, item: item)
    }

    func setCount(_ item: Item, _ n: Int) {
        decisions[item.id] = Decision.from(count: n, item: item)
    }

    func goHome() {
        appendMode = false
        error = nil
        withAnimation(.springSoft) { screen = .home }
    }

    func reset() {
        items = []
        decisions = [:]
        index = 0
        meta = ReceiptMeta()
        error = nil
        appendMode = false
        withAnimation(.springSoft) { screen = .home }
    }

    var summaryText: String {
        let t = totals
        var lines = ["Bon your Friends" + (metaLine.isEmpty ? "" : " · " + metaLine), "Mein Anteil: " + euro(t.mine) + " von " + euro(t.all), ""]
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
