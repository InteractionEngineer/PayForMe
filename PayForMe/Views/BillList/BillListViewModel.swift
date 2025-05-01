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
    var cancellable: Cancellable?

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
        cancellable = currentProjectChanged
        $sortBy
            .map {
                $0.sort(bills: self.currentProject.bills)
            }
            .assign(to: &$sortedBills)
    }

    var currentProjectChanged: AnyCancellable {
        manager.$currentProject
            .assign(to: \.currentProject, on: self)
    }

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
                    a.lastchanged ?? 0 > b.lastchanged ?? 0
                }
            }
        }
    }
}
