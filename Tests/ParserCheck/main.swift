import Foundation
import SwiftUI

let receipt = """
REWE Markt GmbH
Musterstr. 1, 74847 Obrigheim
EUR
BIO VOLLM 3,8%              1,19 B
JOGH NAT 6ER
  6 x 0,49                  2,94 B
BANANE
  1,204 kg x 1,99 EUR/kg    2,40 B
SPAGHETTI                   2,58 B
  2 Stk x 1,29
PREISVORTEIL               -0,30 B
MATE LIMO                   1,19 A
PFAND 0,15 EUR              0,15 A
KAFFEE BOHNEN              11,99 B
Eiweissbrot 2 * 1,79        3,58 B
--------------------------------
SUMME                 EUR  25,72
Geg. EC-Cash          EUR  25,72
03.11.26  18:22
"""

let parsed = ReceiptParser.parse(receipt.components(separatedBy: "\n"))
for l in parsed.lines {
    print(l.raw, "|", l.cents, "|", l.qty, "|", l.detail)
}
print("Markt:", parsed.meta.store ?? "-", "Datum:", parsed.meta.date ?? "-", "Summe:", parsed.meta.total ?? -1)

let items = ItemBuilder.build(parsed.lines, names: [:], total: parsed.meta.total)
for it in items {
    print(it.id, it.kind.rawValue, it.name, it.cents, "x\(it.qty)", "Rabatt \(it.discount)", "Pfand \(it.deposit)")
}

var failures: [String] = []
func expect(_ ok: Bool, _ what: String) {
    if !ok { failures.append(what) }
}

expect(parsed.lines.count == 9, "9 Rohzeilen erwartet, bekommen \(parsed.lines.count)")
expect(parsed.meta.store == "REWE", "Markt REWE")
expect(parsed.meta.date == "03.11.2026", "Datum 03.11.2026")
expect(parsed.meta.total == 2572, "Summe 2572")
expect(items.count == 7, "7 Artikel nach dem Zusammenführen, bekommen \(items.count)")
expect(items.reduce(0) { $0 + $1.cents } == 2572, "Artikelsumme passt zur Summe")
expect(items.first { $0.raw.hasPrefix("JOGH") }?.qty == 6, "Joghurt 6 Stück")
expect(items.first { $0.raw.hasPrefix("SPAGHETTI") }?.qty == 2, "Spaghetti 2 Stück")
expect(items.first { $0.raw.hasPrefix("SPAGHETTI") }?.discount == -30, "Preisvorteil bei Spaghetti")
expect(items.first { $0.raw.hasPrefix("MATE") }?.deposit == 15, "Pfand bei Mate")
expect(items.first { $0.raw.hasPrefix("BANANE") }?.cents == 240, "Bananen 2,40")
expect(items.first { $0.raw.hasPrefix("Eiweissbrot") }?.qty == 2, "Eiweissbrot 2 Stück")
expect(items.first { $0.raw.hasPrefix("Eiweissbrot") }?.raw == "Eiweissbrot", "Eiweissbrot ohne Multiplikator im Namen")

func receiptCase(_ name: String, _ text: String, items count: Int, total: Int, sum: Int? = nil, forbidden: [String] = []) {
    let p = ReceiptParser.parse(text.components(separatedBy: "\n"))
    let built = ItemBuilder.build(p.lines, names: [:], total: p.meta.total)
    print("--", name, "->", built.map { "\($0.raw) \($0.cents)" }.joined(separator: ", "), "| Summe", p.meta.total ?? -1)
    expect(built.count == count, "\(name): \(count) Artikel erwartet, bekommen \(built.count)")
    expect(p.meta.total == total, "\(name): Summe \(total) erwartet, bekommen \(p.meta.total ?? -1)")
    expect(built.reduce(0) { $0 + $1.cents } == (sum ?? total), "\(name): Artikelsumme")
    for f in forbidden {
        expect(!built.contains { $0.raw.lowercased().contains(f.lowercased()) }, "\(name): \(f) darf kein Artikel sein")
    }
}

receiptCase("Lidl mit Steuertabelle", """
LIDL
Butter                      2,29 A
Bananen                     1,49 A
Cola 1,5l                   1,19 B
Pfand 0,25 EUR              0,25 B
--------------------------------
zu zahlen                   5,22
Karte                       5,22
MWST%  MWST + Netto = Brutto
A 7 %   0,25    3,53    3,78
B 19 %  0,23    1,21    1,44
Summe   0,48    4,74    5,22
""", items: 3, total: 522, forbidden: ["karte", "mwst"])

receiptCase("Summe mit Posten in einer Zeile", """
EDEKA
Gouda jung                  2,49 B
Tomaten                     1,99 B
Brötchen 4 x 0,39           1,56 B
Posten: 3        SUMME EUR  6,04
Geg. EC-Cash                6,04
Steuer   Netto   MwSt   Brutto
B= 7,0%  5,64    0,40   6,04
""", items: 3, total: 604, forbidden: ["steuer", "posten", "ec-cash"])

receiptCase("Summe ohne Preis in der Zeile", """
ALDI SÜD
Milch 1,5%                  0,99 A
Eier 10er                   2,79 A
Toast                       1,29 A
SUMME
EUR                         5,07
Bar                        10,00
Rückgeld                    4,93
""", items: 3, total: 507, forbidden: ["bar", "rückgeld"])

receiptCase("Betrag vor dem Summe-Wort erkannt", """
KAUFLAND
KLC Joghurt                 0,49 B
KBio Bananen                1,79 B
Spülmittel                  1,15 A
EUR 3,43
Summe
MwSt  A 19%  0,18  0,97  1,15
""", items: 3, total: 343, forbidden: ["eur", "mwst"])

let bodyBox = SVGPath.parse("M34 10H92V104L84 97 76 104 68 97 60 104 52 97 44 104 36 97 34 104Z").boundingRect
expect(abs(bodyBox.minX - 34) < 0.01 && abs(bodyBox.maxX - 92) < 0.01 && abs(bodyBox.minY - 10) < 0.01 && abs(bodyBox.maxY - 104) < 0.01, "SVG-Pfad Körper \(bodyBox)")
let shoeBox = SVGPath.parse("M40 134Q40 126 52 128 56 134 56 136H40Z").boundingRect
expect(shoeBox.maxY <= 136.01 && shoeBox.minX >= 39.9 && shoeBox.maxX <= 56.01, "SVG-Pfad Schuh \(shoeBox)")
let armBox = SVGPath.parse("M92 54Q104 46 108 34").boundingRect
expect(abs(armBox.maxX - 108) < 0.5 && abs(armBox.minY - 34) < 0.5, "SVG-Pfad Arm \(armBox)")

if failures.isEmpty {
    print("Parser-Test bestanden")
} else {
    failures.forEach { print("FEHLER:", $0) }
    exit(1)
}
