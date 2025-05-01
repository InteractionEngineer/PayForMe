//
//  BillDetailViewModel.swift
//  PayForMe
//
//  Created by Max Tharr on 24.02.20.
//

import Combine
import Foundation

class BillDetailViewModel: ObservableObject {
    var manager = ProjectManager.shared
    var cancellable: Cancellable?

    @Published
    var topic = ""

    @Published
    var amount = ""

    @Published
    var selectedPayer = 0

    @Published
    var currentProject: Project = demoProject

    @Published
    var currentBill: Bill
    
    @Published
    var billDate: Date = Date()

    var povm: PotentialOwersViewModel

    init(currentBill: Bill) {
        self.currentBill = currentBill
        povm = PotentialOwersViewModel(members: ProjectManager.shared.currentProject.members)

        manager.$currentProject.assign(to: &$currentProject)

        prefillData()
    }

    var validatedInput: AnyPublisher<Bool, Never> {
        return Publishers.CombineLatest3($topic, validatedAmount, povm.anyOwers)
            .map { topic, validatedAmount, anyOwers in
                !topic.isEmpty && validatedAmount && anyOwers
            }
            .eraseToAnyPublisher()
    }

    var validatedAmount: AnyPublisher<Bool, Never> {
        return $amount.map { amount in
            let safeAmount = amount.replacingOccurrences(of: ",", with: ".")
            return Double(safeAmount) != nil
        }
        .eraseToAnyPublisher()
    }

    func createBill() -> Bill? {
        let safeAmount = amount.replacingOccurrences(of: ",", with: ".")
        guard let doubleAmount = Double(safeAmount) else {
            return nil
        }

        let billID = currentBill.id
        let date = billDate

        let actualOwers = povm.actualOwers()

        return Bill(id: billID, amount: doubleAmount, what: topic, date: date, payer_id: selectedPayer, owers: actualOwers, repeat: currentProject.backend == .cospend ? "n" : nil, lastchanged: 0)
    }

    func prefillData() {
        topic = currentBill.what
        if currentBill.amount != 0 {
            amount = String(currentBill.amount)
        }

        selectedPayer = currentBill.payer_id ==  -1 ? currentProject.me ?? 0 : currentBill.payer_id
        currentBill.owers.forEach { person in
            if let index = povm.members.firstIndex(of: person) {
                povm.isOwing[index] = true
            }
        }
        billDate = currentBill.date
    }
}
