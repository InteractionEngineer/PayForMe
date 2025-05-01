//
//  Person.swift
//  PayForMe
//
//  Created by Max Tharr on 26.01.20.
//

import Foundation

struct Person: Hashable, Codable, Identifiable {
    var id: Int
    var weight: Int
    var name: String
    var activated: Bool
    var color: PersonColor?

    static func == (lhs: Person, rhs: Person) -> Bool {
        return lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct PersonColor: Codable {
    var r: Int
    var g: Int
    var b: Int
}

let previewPerson = Person(id: 1, weight: 1, name: "Pikachu", activated: true, color: PersonColor(r: 60, g: 110, b: 186))
let previewPersons = [
    1: previewPerson,
    2: Person(id: 2, weight: 1, name: "Schiggy", activated: true, color: PersonColor(r: 60, g: 110, b: 186)),
    3: Person(id: 3, weight: 1, name: "Bisasam", activated: true),
    4: Person(id: 4, weight: 1, name: "Glumanda", activated: true),
]
let previewManyPersons = [
    1: previewPerson,
    2: Person(id: 2, weight: 1, name: "Schiggy", activated: true, color: PersonColor(r: 60, g: 110, b: 186)),
    3: Person(id: 3, weight: 1, name: "Bisasam", activated: true),
    4: Person(id: 4, weight: 1, name: "Glumanda", activated: true),
    5: Person(id: 5, weight: 1, name: "Fukano", activated: true),
    6: Person(id: 6, weight: 1, name: "Relaxo", activated: true),
]
