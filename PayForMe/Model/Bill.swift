//
//  Bill.swift
//  PayForMe
//
//  Created by Max Tharr on 21.01.20.
//

import Foundation

struct Bill: Codable, Identifiable, Hashable {
    var id: Int
    var amount: Double
    var what: String
    var date: Date
    var payer_id: Int
    var owers: [Person]
    var `repeat`: String?
    var categoryid: Int?
    var paymentmodeid: Int?
    var lastchanged: Int?

    /// `features` are the capabilities an iHateMoney server announces; category fields are only
    /// sent to servers that know them (stock iHateMoney has none).
    func paramsFor(_ backend: ProjectBackend, features: Set<String> = []) -> [String: Any] {
        var dict: [String: Any] = [
            "date": DateFormatter.cospend.string(from: date),
            "what": what,
            "payer": payer_id.description,
            "amount": amount.description,
        ]
        if backend == .cospend {
            dict["payed_for"] = owers.map { $0.id.description }.joined(separator: ",")
            dict["categoryid"] = (categoryid ?? 0).description
            dict["paymentmodeid"] = (paymentmodeid ?? 0).description
            dict["paymentmode"] = "n"

            if let rep = self.repeat {
                dict["repeat"] = rep
            } else {
                dict["repeat"] = "n"
            }
        }
        if backend == .iHateMoney {
            dict["payed_for"] = owers.map { $0.id.description }
            // The fork's form treats "" as "none" and rejects "0".
            if features.contains("categoryid") {
                dict["categoryid"] = (categoryid ?? 0) == 0 ? "" : categoryid!.description
            }
            if features.contains("paymentmodes") {
                dict["paymentmodeid"] = (paymentmodeid ?? 0) == 0 ? "" : paymentmodeid!.description
            }
        }

        return dict
    }

    static func newBill() -> Bill {
        Bill(id: -1, amount: 0, what: "", date: Date(), payer_id: -1, owers: [], repeat: "n")
    }
}

let date = DateFormatter.cospend.date(from: "2019-12-21")!

let previewBills = [
    Bill(id: 1, amount: 5, what: "Erdnüsse", date: date, payer_id: 1, owers: [
        Person(id: 1, weight: 1, name: "Pikachu", activated: true),
        Person(id: 2, weight: 1, name: "Schiggy", activated: true),
        Person(id: 3, weight: 1, name: "Bisasam", activated: true),
    ], repeat: "n", lastchanged: 1_231_234),
    Bill(id: 2, amount: 5, what: "Nochmal Erdnüsse", date: date, payer_id: 1, owers: [
        Person(id: 1, weight: 1, name: "Pikachu", activated: true),
        Person(id: 2, weight: 1, name: "Schiggy", activated: true),
        Person(id: 3, weight: 1, name: "Bisasam", activated: true),
    ], repeat: "n", lastchanged: 1_231_234),
    Bill(id: 3, amount: 5, what: "Nochmal Erdnüsse", date: date, payer_id: 2, owers: [
        Person(id: 1, weight: 1, name: "Pikachu", activated: true),
        Person(id: 2, weight: 1, name: "Schiggy", activated: true),
    ], repeat: "n", lastchanged: 1_231_234),
    Bill(id: 4, amount: 5, what: "Nochmal Erdnüsse", date: date, payer_id: 3, owers: [
        Person(id: 1, weight: 1, name: "Pikachu", activated: true),
        Person(id: 2, weight: 1, name: "Schiggy", activated: true),
        Person(id: 3, weight: 1, name: "Bisasam", activated: true),
        Person(id: 4, weight: 1, name: "Glumanda", activated: true),
    ], repeat: "n", lastchanged: 1_231_234),
    Bill(id: 5, amount: 5, what: "Nochmal Erdnüsse", date: date, payer_id: 1, owers: [
        Person(id: 3, weight: 1, name: "Bisasam", activated: true),
    ], repeat: "n", lastchanged: 1_231_234),
]
