import SwiftUI

enum Kind: String, CaseIterable {
    case milk, oatdrink, yogurt, oats, banana, pasta, tomato, mozzarella, discount, soda, deposit, toothpaste, coffee, pizza, gummy, bread, meat, veg, household, other

    var emoji: String {
        switch self {
        case .milk: "🥛"
        case .oatdrink: "🧃"
        case .yogurt: "🍦"
        case .oats: "🥣"
        case .banana: "🍌"
        case .pasta: "🍝"
        case .tomato: "🥫"
        case .mozzarella: "🧀"
        case .discount: "🏷️"
        case .soda: "🥤"
        case .deposit: "♻️"
        case .toothpaste: "🪥"
        case .coffee: "☕️"
        case .pizza: "🍕"
        case .gummy: "🍬"
        case .bread: "🥖"
        case .meat: "🥩"
        case .veg: "🥦"
        case .household: "🧻"
        case .other: "🛒"
        }
    }

    var tile: Color {
        switch self {
        case .milk, .oatdrink, .yogurt, .toothpaste, .household: Palette.peri
        case .banana, .pasta, .oats, .bread, .pizza: Palette.yellow
        case .mozzarella, .soda, .deposit, .veg: Palette.mint
        case .coffee, .meat, .gummy, .other: Palette.blush
        case .tomato, .discount: Palette.salmon
        }
    }
}

struct RawLine {
    var raw: String
    var cents: Int
    var qty: Int
    var detail: String
}

struct ReceiptMeta {
    var store: String?
    var date: String?
    var total: Int?
    var sample = false
}

struct Item: Identifiable, Hashable {
    let id: Int
    var name: String
    var raw: String
    var detail: String
    var cents: Int
    var qty: Int
    var kind: Kind
    var discount: Int = 0
    var deposit: Int = 0
}

enum Choice {
    case mine, other, split
}

struct Decision: Hashable {
    enum State: Hashable {
        case mine, other, split, part
    }

    var state: State
    var count: Int

    static func from(_ choice: Choice, item: Item) -> Decision {
        switch choice {
        case .mine: Decision(state: .mine, count: item.qty)
        case .other: Decision(state: .other, count: 0)
        case .split: Decision(state: .split, count: Int((Double(item.qty) / 2).rounded()))
        }
    }

    static func from(count: Int, item: Item) -> Decision {
        if count >= item.qty { return Decision(state: .mine, count: item.qty) }
        if count <= 0 { return Decision(state: .other, count: 0) }
        return Decision(state: .part, count: count)
    }

    func share(of item: Item) -> Int {
        switch state {
        case .mine: item.cents
        case .other: 0
        case .split: Int((Double(item.cents) / 2).rounded())
        case .part: Int((Double(item.cents) * Double(count) / Double(item.qty)).rounded())
        }
    }

    func label(for item: Item) -> String {
        switch state {
        case .mine: "Deins"
        case .other: "Nicht deins"
        case .split: "Geteilt · " + euro(share(of: item))
        case .part: "\(count) von \(item.qty) deins · " + euro(share(of: item))
        }
    }
}

func euro(_ cents: Int) -> String {
    let sign = cents < 0 ? "−" : ""
    let v = abs(cents)
    return sign + "\(v / 100)," + String(format: "%02d", v % 100) + " €"
}

enum Demo {
    static let items: [(String, String, Int, Int, Kind)] = [
        ("Bio-Vollmilch 3,8 %", "1 L", 119, 1, .milk),
        ("Naturjoghurt", "6 × 0,49 €", 294, 6, .yogurt),
        ("Haferflocken zart", "500 g", 89, 1, .oats),
        ("Bananen", "1,204 kg × 1,99 €/kg", 240, 1, .banana),
        ("Spaghetti Nr. 5", "2 × 1,29 €", 258, 2, .pasta),
        ("Passierte Tomaten", "3 × 0,79 €", 237, 3, .tomato),
        ("Mozzarella light", "125 g", 109, 1, .mozzarella),
        ("Preisvorteil", "Aktion", -30, 1, .discount),
        ("Hafer-Drink Barista", "1 L", 189, 1, .oatdrink),
        ("Mate-Limonade", "0,5 L", 119, 1, .soda),
        ("Pfand Mehrweg", "1 Flasche", 15, 1, .deposit),
        ("Zahnpasta Minze", "75 ml", 245, 1, .toothpaste),
        ("Kaffeebohnen", "1 kg", 1199, 1, .coffee),
        ("Tiefkühlpizza Salami", "350 g", 279, 1, .pizza),
        ("Gummibärchen", "200 g", 129, 1, .gummy)
    ]

    static var lines: [Item] {
        items.enumerated().map { i, x in
            Item(id: i + 1, name: x.0, raw: x.0, detail: x.1, cents: x.2, qty: x.3, kind: x.4)
        }
    }
}
