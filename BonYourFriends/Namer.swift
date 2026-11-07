import Foundation
import FoundationModels

@Generable
struct NamedLine {
    @Guide(description: "Die Nummer der Zeile aus der Eingabe")
    var index: Int
    @Guide(description: "Der vollständige deutsche Produktname in normaler Schreibweise, höchstens 32 Zeichen")
    var name: String
    @Guide(description: "Genau eine Kategorie aus der Liste in den Anweisungen")
    var kind: String
}

@Generable
struct NamedLines {
    @Guide(description: "Eine Zeile pro Eingabezeile, in derselben Reihenfolge")
    var lines: [NamedLine]
}

enum Namer {
    static var status: String {
        switch SystemLanguageModel.default.availability {
        case .available:
            return "KI auf dem iPhone aktiv"
        case .unavailable(.appleIntelligenceNotEnabled):
            return "Apple Intelligence ist ausgeschaltet"
        case .unavailable(.modelNotReady):
            return "KI-Modell lädt noch"
        case .unavailable(.deviceNotEligible):
            return "KI auf diesem Gerät nicht verfügbar"
        case .unavailable:
            return "KI nicht verfügbar"
        }
    }

    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    static let instructions = """
    Du bekommst Zeilen von einem deutschen Kassenzettel. Die Texte sind abgekürzt und stammen aus einer Texterkennung, einzelne Buchstaben können falsch sein.
    Gib für jede Zeile den vollständigen, richtigen deutschen Produktnamen zurück. Nutze dafür den Markt, den Preis, die Menge und die Nachbarzeilen.
    Beispiele: "BIO VOLLM 1,5" ist Bio-Vollmilch 1,5 %, "JOGH NAT" ist Naturjoghurt, "PASS TOM" ist Passierte Tomaten, "GOLDB" ist Gummibärchen, "OuG Beutel" ist Obst- und Gemüsebeutel.
    Kaufland: KLC ist K-Classic, KBio ist K-Bio, KVeg ist K-Take it Veggie.
    Nenne eine Marke nur, wenn sie aufgedruckt ist. Erfinde keine Zeilen und lass keine weg.
    Kategorien: milk (Milch, Sahne, Butter), oatdrink (Pflanzendrinks), yogurt (Joghurt, Quark, Dessert), oats (Müsli, Mehl, Backzutaten), banana (Obst), pasta (Nudeln, Reis), tomato (Konserven, Saucen), mozzarella (Käse), meat (Fleisch, Wurst, Fisch), veg (Gemüse, Salat), soda (Getränke, Wasser, Saft, Bier), coffee (Kaffee, Tee), pizza (Tiefkühl, Fertiggerichte), gummy (Süßes, Snacks, Chips), bread (Brot, Brötchen, Gebäck), toothpaste (Körperpflege), household (Putzmittel, Papier), other (alles andere).
    """

    static func name(_ lines: [RawLine], store: String?) async -> [Int: (name: String, kind: Kind)] {
        guard isAvailable else { return [:] }
        let wanted = lines.indices.filter { !ItemBuilder.isDiscount(lines[$0]) && !ItemBuilder.isDeposit(lines[$0]) }
        guard !wanted.isEmpty else { return [:] }

        var result: [Int: (name: String, kind: Kind)] = [:]
        let chunks = stride(from: 0, to: wanted.count, by: 14).map { Array(wanted[$0..<min($0 + 14, wanted.count)]) }

        for chunk in chunks {
            var prompt = "Markt: \(store ?? "unbekannt")\n\n"
            for (n, i) in chunk.enumerated() {
                let l = lines[i]
                prompt += "\(n + 1). \(l.raw) | \(euro(l.cents))"
                if l.qty > 1 { prompt += " | \(l.qty) Stück" }
                prompt += "\n"
            }
            do {
                let session = LanguageModelSession(instructions: instructions)
                let response = try await session.respond(
                    to: prompt,
                    generating: NamedLines.self,
                    options: GenerationOptions(sampling: .greedy)
                )
                for entry in response.content.lines {
                    let n = entry.index - 1
                    guard n >= 0, n < chunk.count else { continue }
                    let name = entry.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !name.isEmpty else { continue }
                    let kind = Kind(rawValue: entry.kind.lowercased()) ?? Keywords.kind(for: lines[chunk[n]].raw)
                    result[chunk[n]] = (String(name.prefix(40)), kind == .discount || kind == .deposit ? .other : kind)
                }
            } catch {
                continue
            }
        }
        return result
    }
}
