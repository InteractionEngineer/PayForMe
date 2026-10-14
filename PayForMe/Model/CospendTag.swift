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

    /// Cospend's built-in categories (negative ids). Servers do not list them in the project
    /// info, but accept them as `categoryid`: Nextcloud Cospend and iHateMoney category forks.
    /// -11 (Reimbursement) is not a category.
    static let globalCategories: [CospendTag] = [
        CospendTag(id: -1, name: "Grocery", color: "#ffaa00", icon: "🛒", order: nil),
        CospendTag(id: -2, name: "Bar/Party", color: "#aa55ff", icon: "🎉", order: nil),
        CospendTag(id: -3, name: "Rent", color: "#da8733", icon: "🏠", order: nil),
        CospendTag(id: -4, name: "Bill", color: "#4aa6b0", icon: "🌩", order: nil),
        CospendTag(id: -5, name: "Excursion/Culture", color: "#0055ff", icon: "🚸", order: nil),
        CospendTag(id: -6, name: "Health", color: "#bf090c", icon: "💚", order: nil),
        CospendTag(id: -10, name: "Shopping", color: "#e167d1", icon: "🛍", order: nil),
        CospendTag(id: -12, name: "Restaurant", color: "#d0d5e1", icon: "🍴", order: nil),
        CospendTag(id: -13, name: "Accommodation", color: "#5de1a3", icon: "🛌", order: nil),
        CospendTag(id: -14, name: "Transport", color: "#6f2ee1", icon: "🚌", order: nil),
        CospendTag(id: -15, name: "Sport", color: "#69e177", icon: "🎾", order: nil),
    ]
}

struct CospendProjectTags: Decodable {
    let categories: [CospendTag]
    let paymentModes: [CospendTag]
    /// Optional capability list of iHateMoney category forks (`categoryid`, `categories`,
    /// `paymentmodes`, ...). Empty for Cospend and for stock iHateMoney.
    let features: Set<String>

    static let empty = CospendProjectTags(categories: [], paymentModes: [])

    init(categories: [CospendTag], paymentModes: [CospendTag], features: Set<String> = []) {
        self.categories = categories
        self.paymentModes = paymentModes
        self.features = features
    }

    private enum CodingKeys: String, CodingKey {
        case categories
        case paymentmodes
        case features
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        categories = Self.decodeList(from: container, forKey: .categories)
        paymentModes = Self.decodeList(from: container, forKey: .paymentmodes)
        features = Set((try? container.decode([String].self, forKey: .features)) ?? [])
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
