//
//  BillListViewModel.swift
//  PayForMe
//
//  Created by Max Tharr on 23.01.20.
//

import Combine
import Foundation

class BillListViewModel: ObservableObject {
    var manager = ProjectManager.shared
    var cancellable: AnyCancellable?

    @Published
    var currentProject: Project

    @Published
    var sortBy = SortedBy.expenseDate

    @Published
    var sorter = ""

    @Published
    var sortedBills = [Bill]()

    init() {
        currentProject = manager.currentProject
        cancellable = manager.$currentProject.sink { [weak self] newProject in
            guard let self = self else { return }
            self.currentProject = newProject
            self.sortedBills = self.sortBy.sort(bills: newProject.bills)
        }
        $sortBy
            .sink { [weak self] sortBy in
                guard let self = self else { return }
                self.sortedBills = sortBy.sort(bills: self.currentProject.bills)
            }
            .store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()

    enum SortedBy: String {
        case expenseDate
        case changedDate

        func sort(bills: [Bill]) -> [Bill] {
            switch self {
            case .expenseDate:
                return bills.sorted { a, b in
                    a.date > b.date
                }
            case .changedDate:
                return bills.sorted { a, b in
                    (a.lastchanged ?? 0) > (b.lastchanged ?? 0)
                }
            }
        }
    }
}
