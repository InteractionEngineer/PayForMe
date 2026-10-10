//
//  CospendTag.swift
//  PayForMe
//

import Foundation

struct CospendTag: Codable, Identifiable, Hashable {
    let id: Int
    let name: String?
    let color: String?
    let icon: String?
    let order: Int?

    var displayName: String {
        guard let name = name, !name.isEmpty else { return "—" }
        return name
    }

    var label: String {
        guard let icon = icon, !icon.isEmpty else { return displayName }
        return "\(icon) \(displayName)"
    }
}

struct CospendProjectTags: Decodable {
    let categories: [CospendTag]
    let paymentModes: [CospendTag]

    static let empty = CospendProjectTags(categories: [], paymentModes: [])

    init(categories: [CospendTag], paymentModes: [CospendTag]) {
        self.categories = categories
        self.paymentModes = paymentModes
    }

    private enum CodingKeys: String, CodingKey {
        case categories
        case paymentmodes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        categories = Self.decodeList(from: container, forKey: .categories)
        paymentModes = Self.decodeList(from: container, forKey: .paymentmodes)
    }

    private static func decodeList(from container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> [CospendTag] {
        if let keyed = try? container.decode([String: CospendTag].self, forKey: key) {
            return sorted(Array(keyed.values))
        }
        if let list = try? container.decode([CospendTag].self, forKey: key) {
            return sorted(list)
        }
        return []
    }

    private static func sorted(_ tags: [CospendTag]) -> [CospendTag] {
        tags.sorted { lhs, rhs in
            let lhsOrder = lhs.order ?? Int.max
            let rhsOrder = rhs.order ?? Int.max
            guard lhsOrder == rhsOrder else { return lhsOrder < rhsOrder }
            return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
        }
    }
}

let previewCategories = [
    CospendTag(id: 122, name: "Grocery", color: "#ffaa00", icon: "🛒", order: 0),
    CospendTag(id: 126, name: "Excursion/Culture", color: "#0055ff", icon: "🚸", order: 0),
]
let previewPaymentModes = [
    CospendTag(id: 37, name: "Cash", color: "#556B2F", icon: "💵", order: 0),
    CospendTag(id: 40, name: "Online service", color: "#9932CC", icon: "🌎", order: 0),
]
