//
//  PotentialOwersViewModel.swift
//  PayForMe
//
//  Created by Max Tharr on 24.02.20.
//

import Combine
import Foundation

class PotentialOwersViewModel: ObservableObject {
    @Published
    var members: [Person]

    @Published
    var isOwing: [Bool] {
        didSet {
            owingStatus = 0
        }
    }

    @Published
    var owingStatus = 0

    var owersCancellable: AnyCancellable?

    var anyOwers: AnyPublisher<Bool, Never> {
        return Publishers.Map(upstream: $isOwing) {
            isOwing in
            isOwing.contains(true)
        }.eraseToAnyPublisher()
    }

    init(members: [Int: Person]) {
        self.members = Array(members.values).sorted(by: { $0.name.lowercased() < $1.name.lowercased() })
        isOwing = [Bool].init(repeating: false, count: members.count)

        owersCancellable = $owingStatus.sink { newValue in
            switch newValue {
            case 1:
                self.isOwing = self.isOwing.map { _ in false }
            case 2:
                self.isOwing = self.isOwing.map { _ in true }
            default:
                break
            }
        }
    }

    func actualOwers() -> [Person] {
        var persons = [Person]()
        for index in isOwing.indices {
            if isOwing[index] {
                persons.append(members[index])
            }
        }
        return persons
    }
}
