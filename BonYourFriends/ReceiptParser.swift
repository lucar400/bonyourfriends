import Foundation

enum ReceiptParser {
    static let saveRe = "preisvorteil|rabatt|coupon|gutschein|nachlass|ersparnis|aktionsrabatt|sofortrabatt"
    static let infoRe = "sie sparen|ersp.rung|gespart|treuepunkte|punkte gesammelt|payback|bonuspunkte"
    static let depositRe = "pfand|leergut"
    static let totalRe = "(?<![a-zäöüß])(s\\s?[uü]\\s?m\\s?[mn]?\\s?e|gesamtsumme|gesamtbetrag|gesamt|zu\\s?zahlen|endsumme|total|zahlbetrag)(?![a-zäöüß])"
    static let skipRe = "^\\s*(zw\\.?\\s?-?summe|posten|anzahl|eur\\s*$|tel\\b|www)"
    static let stopRe = "zwischensumme|mwst|\\bust\\b|ust-id|steuer|\\bnetto\\b|brutto|\\bbar\\b|\\bec\\b|ec-cash|\\bkarte\\b|kartenzahlung|girocard|kontaktlos|visa|mastercard|maestro|r(ü|u)ckgeld|gegeben|\\bgeg\\.|bezahlt|zahlung|beleg|terminal|trace|genehmigung|autorisierung|transaktion|\\btse\\b|signatur|\\buid\\b|st\\.?\\s?-?nr|bon-?nr|kasse\\s?\\d|vielen dank|danke"
    static let stores = ["REWE", "EDEKA", "ALDI", "LIDL", "KAUFLAND", "NETTO", "PENNY", "NORMA", "TEGUT", "GLOBUS", "MARKTKAUF", "ROSSMANN", "DM", "HIT", "FAMILA", "WASGAU", "DENNS", "ALNATURA", "BIOMARKT", "REAL"]

    static let priceRe = "(?<![\\d.,])(-)?\\s?(\\d{1,4})[,.](\\d{2})(-)?(?:\\s*\\*|\\s*€|\\s*EUR|\\s+[A-Z]{1,2}|\\s+\\d)?\\s*$"
    static let multRe = "(\\d{1,2})\\s*(?:stk\\.?|st\\.?)?\\s*[x*×X]\\s*(\\d{1,3}[,.]\\d{2})(?!\\d)"
    static let weightRe = "(\\d{1,3}[,.]\\d{3})\\s*kg\\s*[x*×X]\\s*(\\d{1,3}[,.]\\d{2})"
    static let dateRe = "\\b(\\d{2})\\.(\\d{2})\\.(\\d{2}|\\d{4})\\b"

    static func parse(_ input: [String]) -> (lines: [RawLine], meta: ReceiptMeta) {
        var meta = ReceiptMeta()
        meta.store = store(in: input)
        meta.date = date(in: input)

        var out: [RawLine] = []
        var pending: String?
        var awaitTotal = false

        for original in input {
            let line = original.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }

            if matches(line, totalRe) {
                if let t = priceAtEnd(line)?.cents ?? anyPrice(line) {
                    meta.total = t
                    if out.count > 0 { break }
                } else if out.count > 0 {
                    awaitTotal = true
                }
                pending = nil
                continue
            }
            if awaitTotal {
                if let t = priceAtEnd(line)?.cents ?? anyPrice(line) {
                    meta.total = t
                    break
                }
                continue
            }
            if matches(line, skipRe) || matches(line, infoRe) || matches(line, stopRe) || isTaxRow(line) {
                pending = nil
                continue
            }

            if let w = firstMatch(line, weightRe) {
                let kg = number(w[1])
                let unit = cents(w[2])
                let calc = Int((kg * Double(unit)).rounded())
                let tail = priceAtEnd(line)?.cents
                let total = (tail != nil && tail != unit) ? tail! : calc
                let detail = w[1].replacingOccurrences(of: ".", with: ",") + " kg × " + euroPlain(unit) + " €/kg"
                if let name = pending {
                    out.append(RawLine(raw: name, cents: total, qty: 1, detail: detail))
                    pending = nil
                } else if let last = out.indices.last, abs(out[last].cents - calc) <= 2 {
                    out[last].detail = detail
                }
                continue
            }

            if let m = firstMatch(line, "^\\s*" + multRe), let n = Int(m[1]) {
                let unit = cents(m[2])
                let rest = String(line.dropFirst(m[0].count))
                let total = priceAtEnd(rest)?.cents ?? n * unit
                let detail = "\(n) × " + euroPlain(unit) + " €"
                if let name = pending {
                    out.append(RawLine(raw: name, cents: total, qty: max(1, n), detail: detail))
                    pending = nil
                } else if let last = out.indices.last, out[last].qty == 1, abs(out[last].cents - n * unit) <= 2 {
                    out[last].qty = max(1, n)
                    out[last].detail = detail
                }
                continue
            }

            if let p = priceAtEnd(line) {
                var text = String(line.prefix(p.location)).trimmingCharacters(in: .whitespaces)
                var qty = 1
                var detail = ""
                if let m = firstMatch(text, multRe), let n = Int(m[1]), n >= 2, abs(n * cents(m[2]) - abs(p.cents)) <= 2 {
                    qty = n
                    detail = "\(n) × " + euroPlain(cents(m[2])) + " €"
                    text = text.replacingOccurrences(of: m[0], with: "").trimmingCharacters(in: .whitespaces)
                }
                text = text.replacingOccurrences(of: "(?i)\\b(eur|euro)\\b|€", with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces)
                if text.isEmpty || !text.contains(where: { $0.isLetter }) {
                    guard let name = pending else {
                        let running = out.reduce(0) { $0 + $1.cents }
                        if out.count >= 2, p.cents > 0, abs(p.cents - running) <= 1 {
                            meta.total = p.cents
                            break
                        }
                        continue
                    }
                    text = name
                }
                pending = nil
                if p.cents == 0 { continue }
                var c = p.cents
                if matches(text, saveRe) { c = -abs(c) }
                let running = out.reduce(0) { $0 + $1.cents }
                if out.count >= 3, c > 0, abs(c - running) <= 1, !matches(text, depositRe) {
                    meta.total = c
                    break
                }
                out.append(RawLine(raw: String(text.prefix(40)), cents: c, qty: qty, detail: detail))
                continue
            }

            if line.contains(where: { $0.isLetter }) && line.count >= 3 {
                pending = String(line.prefix(40))
            }
        }
        return (out, meta)
    }

    static func isTaxRow(_ line: String) -> Bool {
        if matches(line, "^[A-D]\\s*[=:]?\\s*\\d{1,2}([,.]\\d{1,2})?\\s*%") { return true }
        guard line.contains("%") else { return false }
        guard let re = try? NSRegularExpression(pattern: "\\d{1,4}[,.]\\d{2}(?!\\d)") else { return false }
        return re.numberOfMatches(in: line, range: NSRange(location: 0, length: (line as NSString).length)) >= 2
    }

    static func store(in lines: [String]) -> String? {
        let head = lines.prefix(8).joined(separator: " ").uppercased()
        let all = lines.joined(separator: " ").uppercased()
        for text in [head, all] {
            for s in stores where matches(text, "\\b" + s + "\\b") {
                return s
            }
        }
        return nil
    }

    static func date(in lines: [String]) -> String? {
        for line in lines {
            if let m = firstMatch(line, dateRe) {
                let y = m[3].count == 2 ? "20" + m[3] : m[3]
                return m[1] + "." + m[2] + "." + y
            }
        }
        return nil
    }

    static func priceAtEnd(_ line: String) -> (cents: Int, location: Int)? {
        guard let re = try? NSRegularExpression(pattern: priceRe) else { return nil }
        let ns = line as NSString
        guard let m = re.firstMatch(in: line, range: NSRange(location: 0, length: ns.length)) else { return nil }
        let euros = Int(ns.substring(with: m.range(at: 2))) ?? 0
        let ct = Int(ns.substring(with: m.range(at: 3))) ?? 0
        let negative = m.range(at: 1).location != NSNotFound || m.range(at: 4).location != NSNotFound
        let value = euros * 100 + ct
        let prefix = ns.substring(to: m.range.location)
        return (negative ? -value : value, prefix.count)
    }

    static func anyPrice(_ line: String) -> Int? {
        guard let m = firstMatch(line, "(\\d{1,4})[,.](\\d{2})(?!\\d)") else { return nil }
        return cents(m[0])
    }

    static func cents(_ s: String) -> Int {
        Int((number(s) * 100).rounded())
    }

    static func number(_ s: String) -> Double {
        Double(s.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    static func euroPlain(_ c: Int) -> String {
        "\(c / 100)," + String(format: "%02d", abs(c) % 100)
    }

    static func matches(_ s: String, _ pattern: String) -> Bool {
        s.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    static func firstMatch(_ s: String, _ pattern: String) -> [String]? {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let ns = s as NSString
        guard let m = re.firstMatch(in: s, range: NSRange(location: 0, length: ns.length)) else { return nil }
        return (0..<m.numberOfRanges).map { i in
            let r = m.range(at: i)
            return r.location == NSNotFound ? "" : ns.substring(with: r)
        }
    }
}

enum ItemBuilder {
    static func isDiscount(_ line: RawLine) -> Bool {
        ReceiptParser.matches(line.raw, ReceiptParser.saveRe) || (line.cents < 0 && ReceiptParser.matches(line.raw, "aktion|vorteil|coupon"))
    }

    static func isDeposit(_ line: RawLine) -> Bool {
        ReceiptParser.matches(line.raw, ReceiptParser.depositRe)
    }

    static func build(_ lines: [RawLine], names: [Int: (name: String, kind: Kind)], total: Int?) -> [Item] {
        var flat: [Item] = []
        for (i, l) in lines.enumerated() {
            var kind: Kind
            var name: String
            var c = l.cents
            if isDiscount(l) {
                kind = .discount
                name = pretty(l.raw)
                c = -abs(c)
            } else if isDeposit(l) {
                kind = .deposit
                name = pretty(l.raw)
            } else {
                kind = names[i]?.kind ?? Keywords.kind(for: l.raw)
                name = names[i]?.name ?? pretty(l.raw)
            }
            flat.append(Item(id: i + 1, name: name, raw: l.raw, detail: l.detail, cents: c, qty: kind == .discount ? 1 : max(1, min(99, l.qty)), kind: kind))
        }

        if let total {
            let diff = flat.reduce(0) { $0 + $1.cents } - total
            if diff != 0 {
                let hits = flat.indices.filter { flat[$0].kind == .discount && abs(flat[$0].cents) == abs(diff) }
                if hits.count == 1 { flat.remove(at: hits[0]) }
            }
        }

        var merged: [Item] = []
        for it in flat {
            let mergeable = it.kind == .discount || (it.kind == .deposit && it.cents > 0)
            if mergeable, let last = merged.indices.last, merged[last].kind != .discount {
                if it.kind == .discount { merged[last].discount += it.cents } else { merged[last].deposit += it.cents }
                merged[last].cents += it.cents
                continue
            }
            merged.append(it)
        }
        return merged.enumerated().map { i, it in
            Item(id: i + 1, name: it.name, raw: it.raw, detail: it.detail, cents: it.cents, qty: it.qty, kind: it.kind, discount: it.discount, deposit: it.deposit)
        }
    }

    static func pretty(_ raw: String) -> String {
        raw.lowercased()
            .split(separator: " ", omittingEmptySubsequences: true)
            .map { w in w.prefix(1).uppercased() + w.dropFirst() }
            .joined(separator: " ")
    }
}

enum Keywords {
    static let table: [(Kind, [String])] = [
        (.oatdrink, ["haferdrink", "hafer drink", "hafer-drink", "sojadrink", "soja drink", "mandeldrink", "oatly", "barista"]),
        (.milk, ["milch", "sahne", "butter", "schmand", "creme fraiche"]),
        (.yogurt, ["joghurt", "jogh", "quark", "skyr", "pudding", "dessert"]),
        (.oats, ["hafer", "müsli", "musli", "mehl", "zucker", "cornflakes", "flocken"]),
        (.banana, ["banane", "apfel", "äpfel", "birne", "traube", "orange", "zitrone", "beere", "obst", "kiwi", "mango"]),
        (.pasta, ["spaghetti", "nudel", "penne", "fusilli", "reis", "pasta", "tortellini"]),
        (.tomato, ["tomate", "passiert", "sauce", "soße", "ketchup", "dose", "mais", "bohnen"]),
        (.mozzarella, ["käse", "kaese", "mozzarella", "gouda", "emmentaler", "feta", "parmesan"]),
        (.meat, ["wurst", "schinken", "salami", "hähnchen", "haehnchen", "rind", "schwein", "hack", "fisch", "lachs", "thunfisch"]),
        (.veg, ["salat", "gurke", "paprika", "zwiebel", "kartoffel", "möhre", "karotte", "brokkoli", "zucchini", "gemüse"]),
        (.soda, ["wasser", "cola", "limo", "saft", "bier", "schorle", "fanta", "sprite", "mate", "energy", "eistee"]),
        (.coffee, ["kaffee", "tee ", "espresso"]),
        (.pizza, ["pizza", "tiefkühl", "lasagne", "pommes"]),
        (.gummy, ["gummi", "schoko", "chips", "keks", "bonbon", "haribo", "riegel", "nüsse"]),
        (.bread, ["brot", "brötchen", "broetchen", "toast", "croissant", "baguette", "laugen"]),
        (.toothpaste, ["zahn", "shampoo", "dusch", "deo", "seife"]),
        (.household, ["papier", "spül", "wasch", "reiniger", "müll", "beutel", "küchenrolle", "taschentuch"])
    ]

    static func kind(for raw: String) -> Kind {
        let s = raw.lowercased() + " "
        for (k, words) in table where words.contains(where: { s.contains($0) }) {
            return k
        }
        return .other
    }
}
