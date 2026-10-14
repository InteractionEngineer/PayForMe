//
//  CategoryClassifier.swift
//  PayForMe
//

import Foundation

/// A built-in category with the keywords that select it.
struct CategoryRule: Equatable {
    /// Matching Cospend global category id (also accepted by iHateMoney category forks).
    let cospendId: Int
    /// Names a project's own category may carry to be treated as this rule (normalized on compare).
    let names: [String]
    let keywords: [String]
}

/// Suggests a bill category from its title. Keyword based, longest phrase first, word-boundary
/// safe — the same rules the IHM Tracker Obsidian plugin uses, so both apps agree on a title.
enum CategoryClassifier {
    static func classify(title: String, rules: [CategoryRule] = defaultRules) -> CategoryRule? {
        let titleTokens = TextMatchUtils.tokenize(title)
        guard !titleTokens.isEmpty else { return nil }

        var index: [(tokens: [String], rule: CategoryRule)] = []
        for rule in rules {
            for keyword in rule.keywords {
                let tokens = TextMatchUtils.tokenize(keyword)
                if !tokens.isEmpty { index.append((tokens, rule)) }
            }
        }
        // Stable sort keeps rule order for equally long keywords.
        let sorted = index.enumerated()
            .sorted { lhs, rhs in
                lhs.element.tokens.count != rhs.element.tokens.count
                    ? lhs.element.tokens.count > rhs.element.tokens.count
                    : lhs.offset < rhs.offset
            }
            .map(\.element)
        return sorted.first { TextMatchUtils.containsTokenSequence(titleTokens, $0.tokens) }?.rule
    }

    /// The id of the entry in `categories` that fits `title`, or nil when nothing matches or the
    /// project has no matching category. An id match wins over a name match.
    static func suggestCategoryId(title: String, in categories: [CospendTag], rules: [CategoryRule] = defaultRules) -> Int? {
        guard let rule = classify(title: title, rules: rules) else { return nil }
        if let byId = categories.first(where: { $0.id == rule.cospendId }) {
            return byId.id
        }
        let wanted = Set(rule.names.map(TextMatchUtils.normalize))
        return categories.first { wanted.contains(TextMatchUtils.normalize($0.name ?? "")) }?.id
    }

    static let defaultRules: [CategoryRule] = [
        CategoryRule(
            cospendId: -1,
            names: ["grocery", "groceries", "lebensmittel", "einkauf", "supermarkt"],
            keywords: [
                "supermarkt", "supermarket", "groceries", "markt", "rewe", "edeka", "aldi", "lidl", "netto",
                "kaufland", "penny", "dm", "rossmann", "real", "tegut", "denns",
                "alnatura", "spar", "billa", "hofer", "migros", "coop", "norma",
                "nahkauf", "wochenmarkt",
                "gemüse", "obst", "frisches obst", "salat", "karotte", "karotten",
                "tomate", "tomaten", "kartoffel", "kartoffeln", "zwiebel", "zwiebeln",
                "gurke", "paprika", "brokkoli", "zucchini", "apfel", "äpfel",
                "banane", "bananen", "orange", "orangen", "beeren", "zitrone",
                "brot", "brötchen", "backwaren", "milch", "käse", "joghurt",
                "butter", "eier", "wurst", "fleisch", "hähnchen", "fisch",
                "nudeln", "pasta", "reis", "mehl", "zucker", "gewürze",
                "getränke", "wasser", "saft", "kaffee", "tee", "einkauf",
                "lebensmittel", "wocheneinkauf",
            ]
        ),
        CategoryRule(
            cospendId: -12,
            names: ["restaurant", "essen gehen"],
            keywords: [
                "restaurant", "café", "cafe", "imbiss", "pizza", "pizzeria", "burger",
                "sushi", "bar", "kneipe", "döner", "bistro", "bäckerei", "takeaway", "delivery",
                "lieferando", "wolt", "uber eats", "mcdonalds", "burger king",
            ]
        ),
        CategoryRule(
            cospendId: -14,
            names: ["transport", "verkehr", "mobilität"],
            keywords: [
                "bahn", "db", "uber", "taxi", "bus", "tram", "u-bahn", "s-bahn", "train", "fuel",
                "sprit", "tanken", "benzin", "diesel", "parken", "parking", "flixbus",
                "fahrkarte", "ticket", "sixt", "nextbike", "öbb", "oebb", "sbb",
            ]
        ),
        CategoryRule(
            cospendId: -3,
            names: ["rent", "miete", "housing", "wohnen"],
            keywords: [
                "miete", "rent", "nebenkosten", "kaution", "strom", "electricity", "stadtwerke", "gas",
                "internet", "telekom", "vodafone", "o2", "congstar", "möbel",
                "ikea", "rundfunkbeitrag",
            ]
        ),
        CategoryRule(
            cospendId: -5,
            names: ["excursion/culture", "freizeit", "leisure", "kultur"],
            keywords: [
                "kino", "cinema", "konzert", "concert", "event", "party", "spiel", "steam", "netflix",
                "spotify", "disney+", "amazon prime", "hobby", "sport", "fitness",
                "gym", "fitx", "mcfit", "schwimmbad",
            ]
        ),
        CategoryRule(
            cospendId: -6,
            names: ["health", "gesundheit"],
            keywords: [
                "arzt", "doctor", "apotheke", "pharmacy", "medikament", "zahnarzt", "dentist", "versicherung",
                "krankenkasse", "physiotherapie",
            ]
        ),
        CategoryRule(
            cospendId: -10,
            names: ["shopping", "purchases", "anschaffungen"],
            keywords: ["anschaffung", "gerät", "elektronik", "electronics", "saturn", "mediamarkt"]
        ),
    ]
}
