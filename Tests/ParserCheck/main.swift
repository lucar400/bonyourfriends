import Foundation

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

if failures.isEmpty {
    print("Parser-Test bestanden")
} else {
    failures.forEach { print("FEHLER:", $0) }
    exit(1)
}
